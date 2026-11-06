alter table public.shopping_cart_items
  add column if not exists unit_price_snapshot numeric;

do $constraint$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='shopping_cart_items_unit_price_snapshot_check'
      and conrelid='public.shopping_cart_items'::regclass
  ) then
    alter table public.shopping_cart_items
      add constraint shopping_cart_items_unit_price_snapshot_check
      check (unit_price_snapshot is null or unit_price_snapshot >= 0);
  end if;
end
$constraint$;

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
  from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric, unit_price_snapshot numeric);

  if v_count = 0 or exists (
    select 1
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric, unit_price_snapshot numeric)
    where x.product_id is null
       or x.quantity is null
       or x.quantity <= 0
       or (x.unit_price_snapshot is not null and x.unit_price_snapshot < 0)
  ) then
    raise exception 'Le righe del carrello non sono valide.';
  end if;

  if (
    select count(distinct x.product_id)
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric, unit_price_snapshot numeric)
  ) <> v_count then
    raise exception 'Il carrello contiene prodotti duplicati.';
  end if;

  if p_customer_organization_id is null then
    if not public.is_foodtrack_platform_admin() and exists (
      select 1
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric, unit_price_snapshot numeric)
      left join public.products p on p.id = x.product_id
      where p.id is null
         or not exists (
           select 1 from public.memberships m
           where m.user_id = v_user
             and m.role = 'supplier'::public.member_role
             and m.organization_id = p.supplier_organization_id
         )
    ) then
      raise exception 'Il carrello contiene prodotti non appartenenti al tuo catalogo.';
    end if;
  else
    if exists (
      select 1
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric, unit_price_snapshot numeric)
      left join public.products p on p.id = x.product_id
      where p.id is null
         or not exists (
           select 1 from public.customer_suppliers cs
           where cs.customer_organization_id = p_customer_organization_id
             and cs.supplier_organization_id = p.supplier_organization_id
             and cs.active = true
         )
    ) then
      raise exception 'Un prodotto non appartiene a un fornitore attualmente collegato al negozio.';
    end if;
  end if;

  insert into public.shopping_carts(owner_user_id, customer_organization_id, updated_at)
  values (v_user, p_customer_organization_id, now())
  on conflict (owner_user_id)
  do update set customer_organization_id = excluded.customer_organization_id,
                updated_at = now()
  returning id into v_cart_id;

  delete from public.shopping_cart_items where cart_id = v_cart_id;

  insert into public.shopping_cart_items(cart_id, product_id, quantity, unit_price_snapshot)
  select v_cart_id, x.product_id, x.quantity, x.unit_price_snapshot
  from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric, unit_price_snapshot numeric);

  return v_cart_id;
end;
$function$;

revoke all on function public.save_foodtrack_cart(uuid, jsonb) from public, anon;
grant execute on function public.save_foodtrack_cart(uuid, jsonb) to authenticated;
