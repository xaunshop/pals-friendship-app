-- LAMA account/profile onboarding migration
-- Run once in Supabase Dashboard > SQL Editor after the original schema.
-- Private phone/DOB data is stored separately and is readable only by its owner.

create table if not exists public.private_profile_details (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_number text not null check (char_length(phone_number) between 7 and 20),
  date_of_birth date not null,
  consent_accepted boolean not null default false,
  consent_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint private_profile_min_age check (date_of_birth <= (current_date - interval '12 years')::date)
);

alter table public.private_profile_details enable row level security;

drop policy if exists "Users read own private profile details" on public.private_profile_details;
create policy "Users read own private profile details"
  on public.private_profile_details for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users insert own private profile details" on public.private_profile_details;
create policy "Users insert own private profile details"
  on public.private_profile_details for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users update own private profile details" on public.private_profile_details;
create policy "Users update own private profile details"
  on public.private_profile_details for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select candidate is not null
    and candidate ~ '^[a-z0-9_]{3,30}$'
    and not exists (
      select 1 from public.profiles p where lower(p.username) = lower(candidate)
    );
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;

-- Replace the auth trigger so an email signup can reserve its requested username,
-- while OAuth users receive a temporary unique username until onboarding is complete.
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
  dob date;
  phone text;
  consent boolean;
begin
  base_name := left(coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, 'friend@example.com'), '@', 1), 'New friend'), 60);
  requested_username := lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', ''), '^@', ''));
  if requested_username ~ '^[a-z0-9_]{3,30}$' then
    if exists (select 1 from public.profiles p where lower(p.username) = requested_username) then
      raise exception 'Username is already taken. Choose another username.';
    end if;
    safe_username := requested_username;
  else
    safe_username := left(lower(regexp_replace(coalesce(split_part(coalesce(new.email, 'friend@example.com'), '@', 1), 'friend'), '[^a-z0-9_]', '', 'g')), 20);
    if char_length(safe_username) < 3 then safe_username := 'friend'; end if;
    safe_username := left(safe_username, 20) || '_' || substr(replace(new.id::text, '-', ''), 1, 8);
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
  if clean_username !~ '^[a-z0-9_]{3,30}$' then
    raise exception 'Username must be 3–30 characters using letters, numbers or underscores.';
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

  update public.profiles
    set display_name = trim(p_display_name), username = clean_username
    where id = uid;
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
