-- PALS friendship app database schema for Supabase
-- Run this in Supabase Dashboard > SQL Editor.
-- This schema is designed for platonic friendships, not dating.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 30),
  display_name text not null default 'New friend' check (char_length(display_name) between 1 and 60),
  bio text not null default '' check (char_length(bio) <= 240),
  avatar_url text,
  interests text[] not null default '{}',
  is_private boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  image_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 2 and 80),
  category text not null default 'General',
  description text not null default '',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  is_group boolean not null default false,
  title text
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  reason text not null check (char_length(reason) between 3 and 500),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);

create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists posts_author_idx on public.posts(author_id);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at);
create index if not exists friendships_addressee_status_idx on public.friendships(addressee_id, status);
create index if not exists community_members_user_idx on public.community_members(user_id);

-- Automatically create a profile for every new authenticated user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  base_name text;
  safe_username text;
begin
  base_name := coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1), 'friend');
  safe_username := left(lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1), 'friend'), '[^a-zA-Z0-9_]', '', 'g')), 20);
  if char_length(safe_username) < 3 then safe_username := 'friend' || substr(new.id::text, 1, 6); end if;
  insert into public.profiles(id, username, display_name)
  values (new.id, safe_username || '_' || substr(new.id::text, 1, 4), left(base_name, 60))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Security-definer helper avoids recursive RLS checks on conversation_members.
create or replace function public.is_conversation_member(target_conversation_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $
  select exists (
    select 1 from public.conversation_members
    where conversation_id = target_conversation_id and user_id = auth.uid()
  );
$;

-- Create a direct chat only between accepted friends, and return its id.
create or replace function public.create_direct_conversation(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $
declare
  current_user_id uuid := auth.uid();
  found_id uuid;
begin
  if current_user_id is null then raise exception 'Sign in first'; end if;
  if other_user_id is null or other_user_id = current_user_id then raise exception 'Invalid friend'; end if;
  if not exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = current_user_id and f.addressee_id = other_user_id)
        or (f.requester_id = other_user_id and f.addressee_id = current_user_id))
  ) then raise exception 'You can message accepted friends only'; end if;
  if exists (
    select 1 from public.blocks b
    where (b.blocker_id = current_user_id and b.blocked_id = other_user_id)
       or (b.blocker_id = other_user_id and b.blocked_id = current_user_id)
  ) then raise exception 'Messaging is unavailable for this connection'; end if;

  select c.id into found_id
  from public.conversations c
  where c.is_group = false
    and exists (select 1 from public.conversation_members m where m.conversation_id = c.id and m.user_id = current_user_id)
    and exists (select 1 from public.conversation_members m where m.conversation_id = c.id and m.user_id = other_user_id)
    and (select count(*) from public.conversation_members m where m.conversation_id = c.id) = 2
  limit 1;
  if found_id is not null then return found_id; end if;

  insert into public.conversations(is_group) values (false) returning id into found_id;
  insert into public.conversation_members(conversation_id, user_id)
    values (found_id, current_user_id), (found_id, other_user_id);
  return found_id;
end;
$;

grant execute on function public.create_direct_conversation(uuid) to authenticated;

-- Enable RLS on every user-data table.
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.friendships enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

-- Profiles: authenticated users can discover public profiles; owners edit their own.
create policy "Users view public profiles and their friends" on public.profiles for select to authenticated using (id = auth.uid() or is_private = false or exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.requester_id = auth.uid() and f.addressee_id = id) or (f.addressee_id = auth.uid() and f.requester_id = id))));
create policy "Users insert own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "Users update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "Users delete own profile" on public.profiles for delete to authenticated using (id = auth.uid());

-- Posts and comments are visible to signed-in members; users only create/edit/delete their own.
create policy "Members read posts" on public.posts for select to authenticated using (not exists (select 1 from public.blocks b where (b.blocker_id = auth.uid() and b.blocked_id = author_id) or (b.blocker_id = author_id and b.blocked_id = auth.uid())));
create policy "Users create own posts" on public.posts for insert to authenticated with check (author_id = auth.uid());
create policy "Users update own posts" on public.posts for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "Users delete own posts" on public.posts for delete to authenticated using (author_id = auth.uid());
create policy "Members read comments" on public.comments for select to authenticated using (true);
create policy "Users create own comments" on public.comments for insert to authenticated with check (author_id = auth.uid());
create policy "Users delete own comments" on public.comments for delete to authenticated using (author_id = auth.uid());

-- Likes: signed-in users can see and manage only their own likes.
create policy "Members read likes" on public.post_likes for select to authenticated using (true);
create policy "Users like as self" on public.post_likes for insert to authenticated with check (user_id = auth.uid());
create policy "Users unlike as self" on public.post_likes for delete to authenticated using (user_id = auth.uid());

-- Friend requests: participants can read; requester creates; addressee responds.
create policy "Participants read friendships" on public.friendships for select to authenticated using (requester_id = auth.uid() or addressee_id = auth.uid());
create policy "Users send friend requests" on public.friendships for insert to authenticated with check (requester_id = auth.uid());
create policy "Recipient responds to request" on public.friendships for update to authenticated using (addressee_id = auth.uid()) with check (addressee_id = auth.uid());
create policy "Participants remove friendship" on public.friendships for delete to authenticated using (requester_id = auth.uid() or addressee_id = auth.uid());

-- Communities are discoverable by authenticated users; members manage their own membership.
create policy "Members read communities" on public.communities for select to authenticated using (true);
create policy "Members create communities" on public.communities for insert to authenticated with check (created_by = auth.uid());
create policy "Members read memberships" on public.community_members for select to authenticated using (true);
create policy "Users join as self" on public.community_members for insert to authenticated with check (user_id = auth.uid());
create policy "Users leave as self" on public.community_members for delete to authenticated using (user_id = auth.uid());

-- Conversation rows and messages are visible only to conversation members.
create policy "Members read conversations" on public.conversations for select to authenticated using (exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid()));
create policy "Authenticated users create conversations" on public.conversations for insert to authenticated with check (true);
create policy "Members read conversation membership" on public.conversation_members for select to authenticated using (user_id = auth.uid() or public.is_conversation_member(conversation_id));
create policy "Users add themselves to conversation" on public.conversation_members for insert to authenticated with check (user_id = auth.uid());
create policy "Members read messages" on public.messages for select to authenticated using (public.is_conversation_member(conversation_id));
create policy "Members send as self" on public.messages for insert to authenticated with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id));

-- Blocks and reports remain private to the person who created them.
create policy "Users read own blocks" on public.blocks for select to authenticated using (blocker_id = auth.uid());
create policy "Users block as self" on public.blocks for insert to authenticated with check (blocker_id = auth.uid());
create policy "Users unblock as self" on public.blocks for delete to authenticated using (blocker_id = auth.uid());
create policy "Users create reports" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "Users read own reports" on public.reports for select to authenticated using (reporter_id = auth.uid());

-- Seed communities safely; no user accounts or personal data are created.
insert into public.communities(name, category, description) values
 ('Creative Corner','Art & design','Share your work, prompts and creative process.'),
 ('Study Buddies','Learning','Study sessions, accountability and helpful notes.'),
 ('Game Night','Gaming','Find teammates for casual games and weekly events.'),
 ('Code Together','Technology','Build projects, solve bugs and learn in public.'),
 ('Music People','Music','Discover artists, playlists and instruments.'),
 ('Outside Club','Outdoors','Walks, hikes, photography and fresh-air plans.')
on conflict (name) do nothing;

-- Enable realtime updates for chat messages (idempotent).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
