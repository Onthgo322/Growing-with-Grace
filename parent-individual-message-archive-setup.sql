-- Individual message archive preferences. No existing messages are deleted.
create table if not exists public.parent_message_item_archives (
 message_id uuid not null references public.parent_messages(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 archived_at timestamptz not null default now(),
 primary key (message_id, user_id)
);
alter table public.parent_message_item_archives enable row level security;
create policy "Users see their own message archives"
on public.parent_message_item_archives for select to authenticated
using (user_id = auth.uid());
create policy "Users archive only messages they can read"
on public.parent_message_item_archives for insert to authenticated
with check (
 user_id = auth.uid() and exists (
  select 1 from public.parent_messages m
  where m.id = message_id
  and (public.is_parent_message_admin() or public.is_parent_family_member(m.family_id))
 )
);
create policy "Users restore their own archived messages"
on public.parent_message_item_archives for delete to authenticated
using (user_id = auth.uid());
