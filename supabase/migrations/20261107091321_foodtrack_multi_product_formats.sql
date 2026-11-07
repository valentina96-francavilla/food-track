-- Reconstructed from the deployed schema on 2026-11-07.
-- Creates per-product formats and migrates existing pack sizes/prices without deleting records.
create table if not exists public.product_formats (
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.products(id) on delete cascade,
 name text not null,
 units numeric not null default 1 check(units>0),
 min_quantity numeric not null default 1 check(min_quantity>0),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint product_formats_name_nonempty check(length(trim(name))>0),
 constraint product_formats_product_id_id_key unique(product_id,id),
 constraint product_formats_product_name_key unique(product_id,name)
);
insert into public.product_formats(product_id,name,units,min_quantity)
select p.id,coalesce(nullif(trim(p.unit_label),''),'Pezzo'),greatest(coalesce(p.pack_size,1),1),greatest(coalesce(p.min_quantity,1),1)
from public.products p
where not exists(select 1 from public.product_formats f where f.product_id=p.id);

alter table public.customer_product_prices add column if not exists format_id uuid;
update public.customer_product_prices cp
set format_id=f.id
from public.product_formats f
where f.product_id=cp.product_id and f.active and cp.format_id is null
and f.id=(select f0.id from public.product_formats f0 where f0.product_id=cp.product_id order by f0.created_at,f0.id limit 1);
alter table public.customer_product_prices alter column format_id set not null;
alter table public.customer_product_prices drop constraint if exists customer_product_prices_pkey;
alter table public.customer_product_prices add constraint customer_product_prices_pkey primary key(customer_organization_id,product_id,format_id);
alter table public.customer_product_prices drop constraint if exists customer_product_prices_format_id_fkey;
alter table public.customer_product_prices add constraint customer_product_prices_format_id_fkey foreign key(format_id) references public.product_formats(id) on delete cascade;
alter table public.customer_product_prices drop constraint if exists customer_product_prices_product_format_fkey;
alter table public.customer_product_prices add constraint customer_product_prices_product_format_fkey foreign key(product_id,format_id) references public.product_formats(product_id,id) on delete cascade;

alter table public.order_items add column if not exists format_id uuid;
update public.order_items oi set format_id=f.id from public.product_formats f where f.product_id=oi.product_id and oi.format_id is null and f.id=(select f0.id from public.product_formats f0 where f0.product_id=oi.product_id order by f0.created_at,f0.id limit 1);
alter table public.order_items drop constraint if exists order_items_format_id_fkey;
alter table public.order_items add constraint order_items_format_id_fkey foreign key(format_id) references public.product_formats(id) on delete set null;
alter table public.order_items drop constraint if exists order_items_product_format_fkey;
alter table public.order_items add constraint order_items_product_format_fkey foreign key(product_id,format_id) references public.product_formats(product_id,id) on delete restrict;

alter table public.recurring_order_items add column if not exists format_id uuid;
update public.recurring_order_items ri set format_id=f.id from public.product_formats f where f.product_id=ri.product_id and ri.format_id is null and f.id=(select f0.id from public.product_formats f0 where f0.product_id=ri.product_id order by f0.created_at,f0.id limit 1);
alter table public.recurring_order_items alter column format_id set not null;
alter table public.recurring_order_items drop constraint if exists recurring_order_items_format_id_fkey;
alter table public.recurring_order_items add constraint recurring_order_items_format_id_fkey foreign key(format_id) references public.product_formats(id) on delete restrict;
alter table public.recurring_order_items drop constraint if exists recurring_order_items_product_format_fkey;
alter table public.recurring_order_items add constraint recurring_order_items_product_format_fkey foreign key(product_id,format_id) references public.product_formats(product_id,id) on delete restrict;
alter table public.recurring_order_items drop constraint if exists recurring_order_items_recurring_product_format_key;
alter table public.recurring_order_items add constraint recurring_order_items_recurring_product_format_key unique(recurring_order_id,product_id,format_id);

alter table public.shopping_cart_items add column if not exists format_id uuid;
update public.shopping_cart_items ci set format_id=f.id from public.product_formats f where f.product_id=ci.product_id and ci.format_id is null and f.id=(select f0.id from public.product_formats f0 where f0.product_id=ci.product_id order by f0.created_at,f0.id limit 1);
alter table public.shopping_cart_items alter column format_id set not null;
alter table public.shopping_cart_items drop constraint if exists shopping_cart_items_format_id_fkey;
alter table public.shopping_cart_items add constraint shopping_cart_items_format_id_fkey foreign key(format_id) references public.product_formats(id) on delete restrict;
alter table public.shopping_cart_items drop constraint if exists shopping_cart_items_product_format_fkey;
alter table public.shopping_cart_items add constraint shopping_cart_items_product_format_fkey foreign key(product_id,format_id) references public.product_formats(product_id,id) on delete restrict;
alter table public.shopping_cart_items drop constraint if exists shopping_cart_items_cart_product_format_key;
alter table public.shopping_cart_items add constraint shopping_cart_items_cart_product_format_key unique(cart_id,product_id,format_id);
