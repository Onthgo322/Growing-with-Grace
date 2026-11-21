-- Parent message archive status. Run once in Supabase SQL Editor.
create table if not exists public.parent_message_archives (
 family_id uuid primary key references public.parent_families(id) on delete cascade,
 archived_at timestamptz not null default now(),
 archived_by uuid not null references auth.users(id)
);
alter table public.parent_message_archives enable row level security;
drop policy if exists "Messaging admins view archives" on public.parent_message_archives;
create policy "Messaging admins view archives" on public.parent_message_archives for select to authenticated using (public.is_parent_message_admin());
drop policy if exists "Messaging admins archive families" on public.parent_message_archives;
create policy "Messaging admins archive families" on public.parent_message_archives for insert to authenticated with check (public.is_parent_message_admin() and archived_by = auth.uid());
drop policy if exists "Messaging admins update archives" on public.parent_message_archives;
create policy "Messaging admins update archives" on public.parent_message_archives for update to authenticated using (public.is_parent_message_admin()) with check (public.is_parent_message_admin() and archived_by = auth.uid());
