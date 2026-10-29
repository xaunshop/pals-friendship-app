-- LAMA auth hardening migration: safe username checks and guaranteed profile trigger.
-- Run this AFTER schema.sql and 20261029_lama_private_profile_and_username.sql.

create or replace function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select candidate is not null
    and candidate = lower(trim(candidate))
    and candidate ~ '^[a-z0-9_]{3,30}$'
    and not exists (
      select 1
      from public.profiles p
      where lower(p.username) = lower(candidate)
        and (auth.uid() is null or p.id <> auth.uid())
    );
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;

-- Recreate the trigger explicitly so projects that had the function but no trigger
-- still create a starter profile for Google/OAuth accounts.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Backfill any auth users whose profile trigger was missing or failed previously.
-- These are temporary usernames; OAuth onboarding asks the user to choose a real one.
insert into public.profiles (id, username, display_name)
select
  u.id,
  left('friend_' || replace(u.id::text, '-', ''), 30),
  left(coalesce(nullif(u.raw_user_meta_data ->> 'display_name', ''), nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'New friend'), 60)
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;
