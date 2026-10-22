create index if not exists memberships_user_id_idx on public.memberships (user_id);
create index if not exists customer_suppliers_supplier_idx on public.customer_suppliers (supplier_organization_id);
create index if not exists customer_product_prices_product_idx on public.customer_product_prices (product_id);
create index if not exists orders_created_by_idx on public.orders (created_by);
create index if not exists order_items_product_idx on public.order_items (product_id);
create index if not exists favorites_product_idx on public.favorites (product_id);

drop policy if exists "supplier members manage prices for their products" on public.customer_product_prices;
create policy "supplier members insert prices for their products"
on public.customer_product_prices for insert to authenticated
with check (exists (
  select 1 from public.products p join public.memberships m on m.organization_id = p.supplier_organization_id
  where p.id = product_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
));
create policy "supplier members update prices for their products"
on public.customer_product_prices for update to authenticated
using (exists (
  select 1 from public.products p join public.memberships m on m.organization_id = p.supplier_organization_id
  where p.id = product_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
))
with check (exists (
  select 1 from public.products p join public.memberships m on m.organization_id = p.supplier_organization_id
  where p.id = product_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
));
