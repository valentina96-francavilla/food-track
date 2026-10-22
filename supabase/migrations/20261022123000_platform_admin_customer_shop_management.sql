-- Platform-admin-only management of gastronomi/shops and customer-supplier links.
-- A platform admin is a user with role=admin in an organization of kind=platform.
create or replace function public.is_foodtrack_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    join public.organizations o on o.id = m.organization_id
    where m.user_id = (select auth.uid())
      and m.role = 'admin'::public.member_role
      and o.kind = 'platform'::public.org_kind
  );
$$;

revoke all on function public.is_foodtrack_platform_admin() from public;
grant execute on function public.is_foodtrack_platform_admin() to authenticated;

drop policy if exists "members can read their organizations" on public.organizations;
create policy "members and platform admins can read organizations"
on public.organizations for select to authenticated
using (
  public.is_foodtrack_platform_admin()
  or exists (
    select 1 from public.memberships m
    where m.organization_id = organizations.id and m.user_id = (select auth.uid())
  )
);

create policy "platform admins can create organizations"
on public.organizations for insert to authenticated
with check (public.is_foodtrack_platform_admin());

create policy "platform admins can update organizations"
on public.organizations for update to authenticated
using (public.is_foodtrack_platform_admin())
with check (public.is_foodtrack_platform_admin());

create policy "platform admins can delete organizations"
on public.organizations for delete to authenticated
using (public.is_foodtrack_platform_admin());

create policy "platform admins can manage customer supplier links"
on public.customer_suppliers for all to authenticated
using (public.is_foodtrack_platform_admin())
with check (
  public.is_foodtrack_platform_admin()
  and customer_organization_id <> supplier_organization_id
  and exists (select 1 from public.organizations c where c.id = customer_organization_id and c.kind = 'customer')
  and exists (select 1 from public.organizations s where s.id = supplier_organization_id and s.kind = 'supplier')
);

create policy "platform admins can manage memberships"
on public.memberships for all to authenticated
using (public.is_foodtrack_platform_admin())
with check (public.is_foodtrack_platform_admin());
