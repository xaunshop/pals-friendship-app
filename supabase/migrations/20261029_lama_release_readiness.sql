-- LAMA consolidated release migration
-- Run this ONE file in Supabase SQL Editor after supabase/schema.sql.
-- It is safe to re-run and supersedes the two 20261029 profile/auth migrations.
-- Public usernames: 1-35 chars, lowercase letters, numbers, underscore.
-- Phone number and date of birth remain in a separate owner-only table.

create extension if not exists pgcrypto;

-- Private profile data: clients can read only their own row; writes happen via a
-- SECURITY DEFINER RPC after validating the authenticated user's input.
create table if not exists public.private_profile_details (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_number text not null check (char_length(phone_number) between 7 and 20),
  date_of_birth date not null,
  consent_accepted boolean not null default false,
  consent_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.private_profile_details enable row level security;
drop policy if exists "Users read own private profile details" on public.private_profile_details;
create policy "Users read own private profile details"
  on public.private_profile_details for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "Users insert own private profile details" on public.private_profile_details;
drop policy if exists "Users update own private profile details" on public.private_profile_details;

-- Ghost is a personal feed preference, not a report or a public action.
create table if not exists public.ghosted_posts (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
alter table public.ghosted_posts enable row level security;
drop policy if exists "Users read own ghosted posts" on public.ghosted_posts;
create policy "Users read own ghosted posts" on public.ghosted_posts
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users ghost posts as self" on public.ghosted_posts;
create policy "Users ghost posts as self" on public.ghosted_posts
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users unghost own posts" on public.ghosted_posts;
create policy "Users unghost own posts" on public.ghosted_posts
  for delete to authenticated using (user_id = auth.uid());

-- Replace the original 3-30 character check created by schema.sql.
alter table public.profiles drop constraint if exists profiles_username_check;
alter table public.profiles drop constraint if exists profiles_username_format_check;
alter table public.profiles add constraint profiles_username_format_check
  check (char_length(username) between 1 and 35 and username ~ '^[a-z0-9_]{1,35}$');

create or replace function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select candidate is not null
    and candidate = lower(trim(candidate))
    and candidate ~ '^[a-z0-9_]{1,35}$'
    and not exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(candidate)
        and (auth.uid() is null or p.id <> auth.uid())
    );
$$;
revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;

-- A starter profile is always created when a new Supabase auth user is created.
-- Google accounts get a temporary username until profile onboarding is completed.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  base_name text;
  requested_username text;
  safe_username text;
  phone text;
  dob date;
  consent boolean;
begin
  base_name := left(coalesce(
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'New friend'
  ), 60);
  requested_username := lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', ''), '^@', ''));

  if requested_username ~ '^[a-z0-9_]{1,35}$'
     and not exists (select 1 from public.profiles p where lower(p.username) = requested_username) then
    safe_username := requested_username;
  else
    safe_username := left('friend_' || replace(new.id::text, '-', ''), 30);
  end if;

  insert into public.profiles(id, username, display_name)
  values (new.id, safe_username, base_name)
  on conflict (id) do nothing;

  phone := nullif(trim(new.raw_user_meta_data ->> 'phone_number'), '');
  consent := coalesce((new.raw_user_meta_data ->> 'consent_accepted')::boolean, false);
  if phone is not null and nullif(new.raw_user_meta_data ->> 'date_of_birth', '') is not null then
    dob := (new.raw_user_meta_data ->> 'date_of_birth')::date;
    if dob > current_date or date_part('year', age(current_date, dob)) < 12 then
      raise exception 'You must be at least 12 years old to use LAMA.';
    end if;
    if char_length(phone) < 7 or char_length(phone) > 20 then
      raise exception 'Enter a valid phone number.';
    end if;
    if not consent then raise exception 'Consent is required to create a LAMA account.'; end if;
    insert into public.private_profile_details(user_id, phone_number, date_of_birth, consent_accepted, consent_at)
    values (new.id, phone, dob, true, now())
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.complete_my_profile(
  p_display_name text,
  p_username text,
  p_phone_number text,
  p_date_of_birth date,
  p_consent_accepted boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
  clean_username text := lower(regexp_replace(coalesce(p_username, ''), '^@', ''));
begin
  if uid is null then raise exception 'Sign in first.'; end if;
  if p_display_name is null or char_length(trim(p_display_name)) < 1 or char_length(trim(p_display_name)) > 60 then
    raise exception 'Name must be between 1 and 60 characters.';
  end if;
  if clean_username !~ '^[a-z0-9_]{1,35}$' then
    raise exception 'Username must be 1-35 characters using lowercase letters, numbers or underscores.';
  end if;
  if p_phone_number is null or char_length(trim(p_phone_number)) < 7 or char_length(trim(p_phone_number)) > 20 then
    raise exception 'Enter a valid phone number.';
  end if;
  if p_date_of_birth is null or p_date_of_birth > current_date or date_part('year', age(current_date, p_date_of_birth)) < 12 then
    raise exception 'You must be at least 12 years old to use LAMA.';
  end if;
  if coalesce(p_consent_accepted, false) is not true then
    raise exception 'Please accept the terms and privacy consent.';
  end if;
  if exists (select 1 from public.profiles p where lower(p.username) = clean_username and p.id <> uid) then
    raise exception 'That username is already taken. Try another one.';
  end if;

  update public.profiles set display_name = trim(p_display_name), username = clean_username where id = uid;
  if not found then
    insert into public.profiles(id, display_name, username) values (uid, trim(p_display_name), clean_username);
  end if;

  insert into public.private_profile_details(user_id, phone_number, date_of_birth, consent_accepted, consent_at, updated_at)
  values (uid, trim(p_phone_number), p_date_of_birth, true, now(), now())
  on conflict (user_id) do update
    set phone_number = excluded.phone_number,
        date_of_birth = excluded.date_of_birth,
        consent_accepted = true,
        consent_at = coalesce(public.private_profile_details.consent_at, now()),
        updated_at = now();
end;
$$;
revoke all on function public.complete_my_profile(text, text, text, date, boolean) from public;
grant execute on function public.complete_my_profile(text, text, text, date, boolean) to authenticated;

-- Repair existing auth accounts whose profile trigger previously failed or was absent.
insert into public.profiles (id, username, display_name)
select u.id,
       left('friend_' || replace(u.id::text, '-', ''), 30),
       left(coalesce(nullif(u.raw_user_meta_data ->> 'display_name', ''),
                     nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
                     'New friend'), 60)
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;

-- Release-readiness note: this migration covers auth/profile onboarding only.
-- Messaging, feed, friendship, community and moderation features also require
-- schema.sql and must be tested with real authenticated accounts before release.
