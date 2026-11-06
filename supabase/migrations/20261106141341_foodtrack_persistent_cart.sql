create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.shopping_carts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  customer_organization_id uuid references public.organizations(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.shopping_cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.shopping_carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric not null check (quantity > 0),
  created_at timestamptz not null default now(),
  unique (cart_id, product_id)
);

create index shopping_cart_items_product_id_idx on public.shopping_cart_items(product_id);

alter table public.shopping_carts enable row level security;
alter table public.shopping_cart_items enable row level security;

grant select, insert, update, delete on public.shopping_carts to authenticated;
grant select, insert, update, delete on public.shopping_cart_items to authenticated;

create or replace function private.can_manage_foodtrack_cart(target_customer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (select auth.uid()) is not null and (
    public.is_foodtrack_platform_admin()
    or (
      target_customer is null
      and exists (
        select 1 from public.memberships m
        where m.user_id = (select auth.uid())
          and m.role = 'supplier'::public.member_role
      )
    )
    or (
      target_customer is not null
      and exists (
        select 1 from public.memberships m
        where m.user_id = (select auth.uid())
          and m.organization_id = target_customer
          and m.role = 'customer'::public.member_role
      )
    )
    or (
      target_customer is not null
      and exists (
        select 1
        from public.customer_suppliers cs
        join public.memberships m on m.organization_id = cs.supplier_organization_id
        where cs.customer_organization_id = target_customer
          and cs.active = true
          and m.user_id = (select auth.uid())
          and m.role = 'supplier'::public.member_role
      )
    )
  );
$function$;

revoke all on function private.can_manage_foodtrack_cart(uuid) from public, anon;
grant execute on function private.can_manage_foodtrack_cart(uuid) to authenticated;

create policy "owners manage authorized shopping carts"
on public.shopping_carts
for all
to authenticated
using (
  owner_user_id = (select auth.uid())
  and (select private.can_manage_foodtrack_cart(customer_organization_id))
)
with check (
  owner_user_id = (select auth.uid())
  and (select private.can_manage_foodtrack_cart(customer_organization_id))
);

create policy "owners manage shopping cart items"
on public.shopping_cart_items
for all
to authenticated
using (
  exists (
    select 1 from public.shopping_carts c
    where c.id = cart_id
      and c.owner_user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.shopping_carts c
    where c.id = cart_id
      and c.owner_user_id = (select auth.uid())
  )
);

create or replace function public.save_foodtrack_cart(
  p_customer_organization_id uuid,
  p_items jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_cart_id uuid;
  v_count integer;
begin
  if v_user is null then
    raise exception 'Devi accedere per salvare il carrello.';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 100 then
    raise exception 'Il carrello deve contenere da 1 a 100 righe.';
  end if;
  if not (select private.can_manage_foodtrack_cart(p_customer_organization_id)) then
    raise exception 'Non sei autorizzato a salvare un carrello per questo negozio.';
  end if;

  select count(*) into v_count
  from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric);

  if v_count = 0 or exists (
    select 1
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
    where x.product_id is null or x.quantity is null or x.quantity <= 0
  ) then
    raise exception 'Le righe del carrello non sono valide.';
  end if;

  if (
    select count(distinct x.product_id)
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
  ) <> v_count then
    raise exception 'Il carrello contiene prodotti duplicati.';
  end if;

  if p_customer_organization_id is null then
    if not public.is_foodtrack_platform_admin() and exists (
      select 1
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
      left join public.products p on p.id = x.product_id
      where p.id is null
         or not p.active
         or not exists (
           select 1 from public.memberships m
           where m.user_id = v_user
             and m.role = 'supplier'::public.member_role
             and m.organization_id = p.supplier_organization_id
         )
    ) then
      raise exception 'Il carrello contiene prodotti non appartenenti al tuo catalogo o non disponibili.';
    end if;
  else
    if exists (
      select 1
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
      left join public.products p on p.id = x.product_id
      left join public.customer_product_prices cp
        on cp.product_id = p.id
       and cp.customer_organization_id = p_customer_organization_id
      where p.id is null
         or not p.active
         or cp.product_id is null
         or public.foodtrack_effective_price(
              cp.price, cp.promotion_type, cp.discount_percent,
              cp.promotional_price, cp.promotion_start_at,
              cp.promotion_end_at, (now() at time zone 'Europe/Rome')::date
            ) is null
         or public.foodtrack_effective_price(
              cp.price, cp.promotion_type, cp.discount_percent,
              cp.promotional_price, cp.promotion_start_at,
              cp.promotion_end_at, (now() at time zone 'Europe/Rome')::date
            ) <= 0
         or x.quantity < greatest(p.min_quantity, coalesce(cp.min_quantity, 1))
         or not exists (
           select 1 from public.customer_suppliers cs
           where cs.customer_organization_id = p_customer_organization_id
             and cs.supplier_organization_id = p.supplier_organization_id
             and cs.active = true
         )
    ) then
      raise exception 'Un prodotto non è disponibile per il negozio, non ha un prezzo valido o non rispetta i collegamenti e le quantità minime.';
    end if;
  end if;

  insert into public.shopping_carts(owner_user_id, customer_organization_id, updated_at)
  values (v_user, p_customer_organization_id, now())
  on conflict (owner_user_id)
  do update set customer_organization_id = excluded.customer_organization_id,
                updated_at = now()
  returning id into v_cart_id;

  delete from public.shopping_cart_items where cart_id = v_cart_id;

  insert into public.shopping_cart_items(cart_id, product_id, quantity)
  select v_cart_id, x.product_id, x.quantity
  from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric);

  return v_cart_id;
end;
$function$;

revoke all on function public.save_foodtrack_cart(uuid, jsonb) from public, anon;
grant execute on function public.save_foodtrack_cart(uuid, jsonb) to authenticated;
