-- Complete platform-admin permissions and persist customer cancellation safely.
drop policy if exists "platform admins can manage all products" on public.products;
create policy "platform admins can manage all products"
on public.products for all to authenticated
using (public.is_foodtrack_platform_admin())
with check (public.is_foodtrack_platform_admin());

drop policy if exists "platform admins can manage all customer prices" on public.customer_product_prices;
create policy "platform admins can manage all customer prices"
on public.customer_product_prices for all to authenticated
using (public.is_foodtrack_platform_admin())
with check (public.is_foodtrack_platform_admin());

drop policy if exists "platform admins can update all orders" on public.orders;
create policy "platform admins can update all orders"
on public.orders for update to authenticated
using (public.is_foodtrack_platform_admin())
with check (public.is_foodtrack_platform_admin());

drop policy if exists "customers can cancel their submitted orders" on public.orders;
create policy "customers can cancel their submitted orders"
on public.orders for update to authenticated
using (
  status = 'submitted'::public.order_status
  and exists (
    select 1 from public.memberships m
    where m.organization_id = orders.customer_organization_id
      and m.user_id = (select auth.uid())
      and m.role = 'customer'::public.member_role
  )
)
with check (
  status = 'cancelled'::public.order_status
  and exists (
    select 1 from public.memberships m
    where m.organization_id = orders.customer_organization_id
      and m.user_id = (select auth.uid())
      and m.role = 'customer'::public.member_role
  )
);
