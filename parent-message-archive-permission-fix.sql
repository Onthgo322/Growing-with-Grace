-- Repair archive permission without changing or deleting messages.
create or replace function public.can_archive_parent_message(mid uuid)
returns boolean language sql stable security definer
set search_path = public
as $$
 select exists (
  select 1 from public.parent_messages m
  where m.id = mid
    and (public.is_parent_message_admin()
      or public.is_parent_family_member(m.family_id))
 );
$$;
revoke all on function public.can_archive_parent_message(uuid) from public;
grant execute on function public.can_archive_parent_message(uuid) to authenticated;
drop policy if exists "Users archive only messages they can read" on public.parent_message_item_archives;
create policy "Users archive only messages they can read"
on public.parent_message_item_archives for insert to authenticated
with check (user_id = auth.uid() and public.can_archive_parent_message(message_id));
