alter table public.organizations
  add column if not exists contact_name text;

revoke execute on function public.can_read_foodtrack_organization(uuid) from public, anon;
grant execute on function public.can_read_foodtrack_organization(uuid) to authenticated;

create index if not exists customer_favorites_product_id_idx on public.customer_favorites(product_id);
create index if not exists recurring_order_items_product_id_idx on public.recurring_order_items(product_id);
create index if not exists recurring_order_occurrences_order_id_idx on public.recurring_order_occurrences(order_id);
create index if not exists recurring_orders_created_by_idx on public.recurring_orders(created_by);
create index if not exists recurring_orders_customer_organization_id_idx on public.recurring_orders(customer_organization_id);
create index if not exists recurring_orders_supplier_organization_id_idx on public.recurring_orders(supplier_organization_id);

drop policy if exists "customers read own organization favorites" on public.customer_favorites;
create policy "customers read own organization favorites"
on public.customer_favorites
for select
to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.organization_id = customer_favorites.customer_organization_id
      and m.user_id = (select auth.uid())
      and m.role = 'customer'::public.member_role
  )
);

drop policy if exists "customers add own organization favorites" on public.customer_favorites;
create policy "customers add own organization favorites"
on public.customer_favorites
for insert
to authenticated
with check (
  exists (
    select 1 from public.memberships m
    where m.organization_id = customer_favorites.customer_organization_id
      and m.user_id = (select auth.uid())
      and m.role = 'customer'::public.member_role
  )
  and exists (
    select 1
    from public.products p
    join public.customer_suppliers cs on cs.supplier_organization_id = p.supplier_organization_id
    where p.id = customer_favorites.product_id
      and p.active = true
      and cs.customer_organization_id = customer_favorites.customer_organization_id
      and cs.active = true
  )
);

drop policy if exists "customers remove own organization favorites" on public.customer_favorites;
create policy "customers remove own organization favorites"
on public.customer_favorites
for delete
to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.organization_id = customer_favorites.customer_organization_id
      and m.user_id = (select auth.uid())
      and m.role = 'customer'::public.member_role
  )
);
