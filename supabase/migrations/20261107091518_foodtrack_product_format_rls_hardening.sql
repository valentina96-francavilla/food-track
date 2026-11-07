-- Product format row-level access, reconstructed from the deployed policy definitions.
alter table public.product_formats enable row level security;
drop policy if exists "members can read formats of accessible products" on public.product_formats;
drop policy if exists "foodtrack members read accessible formats" on public.product_formats;
drop policy if exists "suppliers and admins manage product formats" on public.product_formats;
create policy "foodtrack members read accessible formats" on public.product_formats
for select to authenticated
using (
 private.foodtrack_account_enabled() and exists(
  select 1 from public.products p where p.id=product_formats.product_id and (
   public.is_foodtrack_platform_admin()
   or exists(select 1 from public.memberships m where m.user_id=(select auth.uid()) and m.organization_id=p.supplier_organization_id)
   or (p.active and exists(select 1 from public.customer_suppliers cs join public.memberships m on m.organization_id=cs.customer_organization_id where cs.supplier_organization_id=p.supplier_organization_id and cs.active and m.user_id=(select auth.uid())))
  )
 )
);
create policy "suppliers and admins manage product formats" on public.product_formats
for all to authenticated
using (
 private.foodtrack_account_enabled() and (
  public.is_foodtrack_platform_admin() or exists(
   select 1 from public.products p join public.memberships m on m.organization_id=p.supplier_organization_id
   where p.id=product_formats.product_id and m.user_id=(select auth.uid()) and m.role in ('supplier'::public.member_role,'admin'::public.member_role)
  )
 )
)
with check (
 private.foodtrack_account_enabled() and (
  public.is_foodtrack_platform_admin() or exists(
   select 1 from public.products p join public.memberships m on m.organization_id=p.supplier_organization_id
   where p.id=product_formats.product_id and m.user_id=(select auth.uid()) and m.role in ('supplier'::public.member_role,'admin'::public.member_role)
  )
 )
);
