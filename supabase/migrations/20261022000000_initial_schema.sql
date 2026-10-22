-- FoodTrack initial multi-tenant schema.
-- Apply only to a dedicated FoodTrack Supabase project, never to Lookera.
create extension if not exists pgcrypto;

create type public.org_kind as enum ('customer', 'supplier', 'platform');
create type public.member_role as enum ('admin', 'supplier', 'customer');
create type public.order_status as enum ('draft', 'submitted', 'accepted', 'preparing', 'shipped', 'delivered', 'cancelled');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 160),
  kind public.org_kind not null,
  vat_number text,
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null,
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create table public.customer_suppliers (
  customer_organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_organization_id uuid not null references public.organizations(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (customer_organization_id, supplier_organization_id),
  check (customer_organization_id <> supplier_organization_id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  supplier_organization_id uuid not null references public.organizations(id) on delete restrict,
  sku text not null,
  name text not null check (length(trim(name)) between 2 and 200),
  description text,
  category text,
  unit_label text not null default 'pz',
  pack_size numeric(12,3) not null default 1 check (pack_size > 0),
  min_quantity numeric(12,3) not null default 1 check (min_quantity > 0),
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (supplier_organization_id, sku)
);

create table public.customer_product_prices (
  customer_organization_id uuid not null references public.organizations(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  price numeric(12,2) not null check (price >= 0),
  currency char(3) not null default 'EUR',
  min_quantity numeric(12,3) not null default 1 check (min_quantity > 0),
  updated_at timestamptz not null default now(),
  primary key (customer_organization_id, product_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique,
  customer_organization_id uuid not null references public.organizations(id) on delete restrict,
  supplier_organization_id uuid not null references public.organizations(id) on delete restrict,
  created_by uuid not null default auth.uid() references auth.users(id),
  status public.order_status not null default 'submitted',
  requested_delivery_date date,
  delivery_contact text,
  delivery_notes text,
  customer_reference text,
  currency char(3) not null default 'EUR',
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (customer_organization_id <> supplier_organization_id)
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  sku_snapshot text not null,
  name_snapshot text not null,
  unit_snapshot text not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) generated always as (round(quantity * unit_price, 2)) stored
);

create table public.favorites (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index products_supplier_active_idx on public.products (supplier_organization_id, active);
create index prices_customer_idx on public.customer_product_prices (customer_organization_id);
create index orders_customer_date_idx on public.orders (customer_organization_id, submitted_at desc);
create index orders_supplier_date_idx on public.orders (supplier_organization_id, submitted_at desc);
create index order_items_order_idx on public.order_items (order_id);

alter table public.organizations enable row level security;
alter table public.memberships enable row level security;
alter table public.customer_suppliers enable row level security;
alter table public.products enable row level security;
alter table public.customer_product_prices enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.favorites enable row level security;

-- Organization and membership visibility is restricted to signed-in members.
create policy "members can read their organizations"
on public.organizations for select to authenticated
using (exists (
  select 1 from public.memberships m
  where m.organization_id = organizations.id and m.user_id = (select auth.uid())
));

create policy "users can read their own memberships"
on public.memberships for select to authenticated
using (user_id = (select auth.uid()));

create policy "linked customers and suppliers can read their link"
on public.customer_suppliers for select to authenticated
using (
  exists (select 1 from public.memberships m where m.organization_id = customer_organization_id and m.user_id = (select auth.uid()))
  or exists (select 1 from public.memberships m where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()))
);

create policy "supplier members can read their products and linked customers can read active products"
on public.products for select to authenticated
using (
  exists (select 1 from public.memberships m where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()))
  or (
    active and exists (
      select 1 from public.customer_suppliers cs
      join public.memberships m on m.organization_id = cs.customer_organization_id
      where cs.supplier_organization_id = products.supplier_organization_id
        and cs.active and m.user_id = (select auth.uid())
    )
  )
);

create policy "supplier members can insert products"
on public.products for insert to authenticated
with check (exists (
  select 1 from public.memberships m
  where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
));

create policy "supplier members can update products"
on public.products for update to authenticated
using (exists (
  select 1 from public.memberships m
  where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
))
with check (exists (
  select 1 from public.memberships m
  where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
));

create policy "customers and supplier owners can read prices"
on public.customer_product_prices for select to authenticated
using (
  exists (select 1 from public.memberships m where m.organization_id = customer_organization_id and m.user_id = (select auth.uid()))
  or exists (
    select 1 from public.products p join public.memberships m on m.organization_id = p.supplier_organization_id
    where p.id = product_id and m.user_id = (select auth.uid())
  )
);

create policy "supplier members manage prices for their products"
on public.customer_product_prices for all to authenticated
using (exists (
  select 1 from public.products p join public.memberships m on m.organization_id = p.supplier_organization_id
  where p.id = product_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
))
with check (exists (
  select 1 from public.products p join public.memberships m on m.organization_id = p.supplier_organization_id
  where p.id = product_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
));

create policy "order parties can read orders"
on public.orders for select to authenticated
using (
  exists (select 1 from public.memberships m where m.organization_id = customer_organization_id and m.user_id = (select auth.uid()))
  or exists (select 1 from public.memberships m where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()))
);

create policy "linked customer members can place orders"
on public.orders for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (select 1 from public.memberships m where m.organization_id = customer_organization_id and m.user_id = (select auth.uid()) and m.role in ('customer','admin'))
  and exists (select 1 from public.customer_suppliers cs where cs.customer_organization_id = orders.customer_organization_id and cs.supplier_organization_id = orders.supplier_organization_id and cs.active)
);

create policy "supplier members can update order status"
on public.orders for update to authenticated
using (exists (
  select 1 from public.memberships m where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
))
with check (exists (
  select 1 from public.memberships m where m.organization_id = supplier_organization_id and m.user_id = (select auth.uid()) and m.role in ('supplier','admin')
));

create policy "order parties can read line items"
on public.order_items for select to authenticated
using (exists (
  select 1 from public.orders o
  where o.id = order_id and (
    exists (select 1 from public.memberships m where m.organization_id = o.customer_organization_id and m.user_id = (select auth.uid()))
    or exists (select 1 from public.memberships m where m.organization_id = o.supplier_organization_id and m.user_id = (select auth.uid()))
  )
));

create policy "linked customers can add line items to their orders"
on public.order_items for insert to authenticated
with check (exists (
  select 1 from public.orders o
  join public.customer_suppliers cs on cs.customer_organization_id = o.customer_organization_id and cs.supplier_organization_id = o.supplier_organization_id and cs.active
  join public.memberships m on m.organization_id = o.customer_organization_id
  where o.id = order_id and o.status = 'submitted' and m.user_id = (select auth.uid())
));

create policy "users manage their own favorites"
on public.favorites for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Explicit grants keep the Data API contract clear; RLS remains the row-level guard.
grant select on public.organizations, public.memberships, public.customer_suppliers, public.products, public.customer_product_prices, public.orders, public.order_items, public.favorites to authenticated;
grant insert, update on public.products, public.customer_product_prices, public.orders, public.order_items to authenticated;
grant insert, delete on public.favorites to authenticated;
grant usage, select on all sequences in schema public to authenticated;
