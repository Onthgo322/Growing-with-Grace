-- Run in Supabase SQL Editor only after reviewing the access model.
-- IMPORTANT: parent family memberships must be assigned by an authorized administrator.
create table if not exists public.parent_families (
 id uuid primary key default gen_random_uuid(),
 display_name text not null,
 created_at timestamptz not null default now()
);
create table if not exists public.parent_family_members (
 family_id uuid not null references public.parent_families(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 primary key(family_id,user_id)
);
create table if not exists public.parent_message_admins (
 user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.parent_messages (
 id uuid primary key default gen_random_uuid(),
 family_id uuid not null references public.parent_families(id) on delete cascade,
 sender_id uuid not null references auth.users(id),
 body text not null check(char_length(body) between 1 and 4000),
 created_at timestamptz not null default now()
);
alter table public.parent_families enable row level security;
alter table public.parent_family_members enable row level security;
alter table public.parent_message_admins enable row level security;
alter table public.parent_messages enable row level security;
create or replace function public.is_parent_message_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.parent_message_admins where user_id=auth.uid());
$$;
create or replace function public.is_parent_family_member(fid uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.parent_family_members where user_id=auth.uid() and family_id=fid);
$$;
revoke all on function public.is_parent_message_admin() from public;
revoke all on function public.is_parent_family_member(uuid) from public;
grant execute on function public.is_parent_message_admin() to authenticated;
grant execute on function public.is_parent_family_member(uuid) to authenticated;
create policy "Family names visible to members and admins" on public.parent_families for select to authenticated using (public.is_parent_family_member(id) or public.is_parent_message_admin());
create policy "Membership visible to own user and admins" on public.parent_family_members for select to authenticated using (user_id=auth.uid() or public.is_parent_message_admin());
create policy "Admin list visible to admins" on public.parent_message_admins for select to authenticated using (public.is_parent_message_admin());
create policy "Messages visible to family or admins" on public.parent_messages for select to authenticated using (public.is_parent_family_member(family_id) or public.is_parent_message_admin());
create policy "Members and admins can send their own messages" on public.parent_messages for insert to authenticated with check (sender_id=auth.uid() and (public.is_parent_family_member(family_id) or public.is_parent_message_admin()));
-- No client-side UPDATE/DELETE or membership write policies: onboarding via trusted administrator only.
-- Before going live, add admin users with a trusted SQL operation and verify cross-family isolation.
