-- Seed demo catalog and create database-authoritative checkout.
-- All prices and products below are illustrative demo data, not commercial offers.

create or replace function public.submit_foodtrack_order(
  p_customer_organization_id uuid,
  p_items jsonb,
  p_requested_delivery_date date,
  p_delivery_contact text,
  p_delivery_notes text default null
)
returns table(order_id uuid, order_number bigint, supplier_organization_id uuid, subtotal numeric)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_role_ok boolean;
  v_supplier uuid;
  v_order_id uuid;
  v_order_number bigint;
  v_subtotal numeric(12,2);
  v_count integer;
begin
  if v_user is null then raise exception 'Devi accedere per inviare un ordine.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Il carrello è vuoto.'; end if;
  if p_requested_delivery_date is null or p_requested_delivery_date < current_date then raise exception 'La data di consegna non è valida.'; end if;
  if p_delivery_contact is null or length(trim(p_delivery_contact)) < 2 then raise exception 'Inserisci un referente per la consegna.'; end if;

  select exists (
    select 1 from public.memberships m
    where m.user_id=v_user and m.organization_id=p_customer_organization_id and m.role='customer'::public.member_role
  ) or public.is_foodtrack_platform_admin() into v_role_ok;
  if not v_role_ok then raise exception 'Non sei autorizzato a ordinare per questa gastronomia.'; end if;

  select count(*) into v_count from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric);
  if v_count=0 or exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric) where x.product_id is null or x.quantity is null or x.quantity<=0) then raise exception 'Le righe del carrello non sono valide.'; end if;
  if (select count(distinct x.product_id) from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric))<>v_count then raise exception 'Il carrello contiene prodotti duplicati.'; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
    left join public.products p on p.id=x.product_id
    left join public.customer_product_prices cp on cp.product_id=p.id and cp.customer_organization_id=p_customer_organization_id
    where p.id is null or not p.active or cp.price is null or x.quantity<greatest(p.min_quantity,cp.min_quantity)
  ) then raise exception 'Prodotto non disponibile, prezzo mancante o quantità minima non rispettata.'; end if;

  if exists (
    select 1 from (
      select distinct p.supplier_organization_id from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
      join public.products p on p.id=x.product_id
    ) s
    where not exists (
      select 1 from public.customer_suppliers cs
      where cs.customer_organization_id=p_customer_organization_id and cs.supplier_organization_id=s.supplier_organization_id and cs.active
    )
  ) then raise exception 'La gastronomia non è collegata a uno dei fornitori nel carrello.'; end if;

  for v_supplier in
    select distinct p.supplier_organization_id from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
    join public.products p on p.id=x.product_id order by p.supplier_organization_id
  loop
    select round(sum(x.quantity*cp.price),2) into v_subtotal
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
    join public.products p on p.id=x.product_id and p.supplier_organization_id=v_supplier
    join public.customer_product_prices cp on cp.product_id=p.id and cp.customer_organization_id=p_customer_organization_id;

    insert into public.orders(customer_organization_id,supplier_organization_id,created_by,status,requested_delivery_date,delivery_contact,delivery_notes,subtotal)
    values(p_customer_organization_id,v_supplier,v_user,'submitted',p_requested_delivery_date,trim(p_delivery_contact),nullif(trim(coalesce(p_delivery_notes,'')),''),v_subtotal)
    returning id, orders.order_number into v_order_id,v_order_number;

    insert into public.order_items(order_id,product_id,sku_snapshot,name_snapshot,unit_snapshot,quantity,unit_price)
    select v_order_id,p.id,p.sku,p.name,p.unit_label,x.quantity,cp.price
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity numeric)
    join public.products p on p.id=x.product_id and p.supplier_organization_id=v_supplier
    join public.customer_product_prices cp on cp.product_id=p.id and cp.customer_organization_id=p_customer_organization_id;

    order_id:=v_order_id; order_number:=v_order_number; supplier_organization_id:=v_supplier; subtotal:=v_subtotal; return next;
  end loop;
end;
$$;
revoke all on function public.submit_foodtrack_order(uuid,jsonb,date,text,text) from public,anon;
grant execute on function public.submit_foodtrack_order(uuid,jsonb,date,text,text) to authenticated;

drop policy if exists "platform admins can read all products" on public.products;
create policy "platform admins can read all products" on public.products for select to authenticated using (public.is_foodtrack_platform_admin());
drop policy if exists "platform admins can read all customer prices" on public.customer_product_prices;
create policy "platform admins can read all customer prices" on public.customer_product_prices for select to authenticated using (public.is_foodtrack_platform_admin());
drop policy if exists "platform admins can read all orders" on public.orders;
create policy "platform admins can read all orders" on public.orders for select to authenticated using (public.is_foodtrack_platform_admin());
drop policy if exists "platform admins can read all order items" on public.order_items;
create policy "platform admins can read all order items" on public.order_items for select to authenticated using (public.is_foodtrack_platform_admin());
drop policy if exists "members and linked parties can read organizations" on public.organizations;
create policy "members and linked parties can read organizations" on public.organizations for select to authenticated using (
  public.is_foodtrack_platform_admin()
  or exists(select 1 from public.memberships m where m.organization_id=organizations.id and m.user_id=auth.uid())
  or exists(select 1 from public.customer_suppliers cs where cs.active and (
    (cs.customer_organization_id=organizations.id and exists(select 1 from public.memberships m where m.organization_id=cs.supplier_organization_id and m.user_id=auth.uid()))
    or (cs.supplier_organization_id=organizations.id and exists(select 1 from public.memberships m where m.organization_id=cs.customer_organization_id and m.user_id=auth.uid()))
  ))
);

insert into public.organizations(name,kind,email) values
 ('Fornitore Nord','supplier','commerciale.nord@example.it'),
 ('Fornitore Sud','supplier','ordini.sud@example.it'),
 ('Gastronomia Milano','customer','ordini.milano@example.it'),
 ('Gastronomia Bari','customer','ordini.bari@example.it')
on conflict do nothing;

insert into public.customer_suppliers(customer_organization_id,supplier_organization_id,active)
select c.id,s.id,true from public.organizations c cross join public.organizations s
where c.kind='customer' and s.kind='supplier' and c.name in ('Gastronomia Milano','Gastronomia Bari') and s.name in ('Fornitore Nord','Fornitore Sud')
on conflict(customer_organization_id,supplier_organization_id) do update set active=true;

insert into public.products(supplier_organization_id,sku,name,description,category,unit_label,pack_size,min_quantity,active)
select s.id,v.sku,v.name,v.description,v.category,v.unit_label,v.pack_size,v.min_quantity,true
from (values
 ('Fornitore Sud','FR-SUD-001','Supplì classico','Supplì al pomodoro e mozzarella, surgelato.','Fritti','cartone da 20 pezzi',20::numeric,1::numeric),
 ('Fornitore Nord','FR-NOR-002','Crocchette di patate','Crocchette panate, surgelate.','Fritti','cartone da 30 pezzi',30::numeric,1::numeric),
 ('Fornitore Sud','FR-SUD-003','Arancini al ragù','Arancini ripieni al ragù, surgelati.','Fritti','cartone da 24 pezzi',24::numeric,1::numeric),
 ('Fornitore Nord','PZ-NOR-004','Base pinsa romana','Basi pinsa precotte.','Pizza','confezione da 10 pezzi',10::numeric,1::numeric),
 ('Fornitore Nord','PZ-NOR-005','Base pizza classica','Basi pizza pronte da condire.','Pizza','cartone da 20 pezzi',20::numeric,1::numeric),
 ('Fornitore Sud','SN-SUD-006','Mozzarelline panate','Snack panato da friggere.','Snack','cartone da 50 pezzi',50::numeric,1::numeric),
 ('Fornitore Nord','SN-NOR-007','Olive ascolane','Olive ascolane panate, surgelate.','Snack','cartone da 40 pezzi',40::numeric,1::numeric),
 ('Fornitore Sud','SN-SUD-008','Panzerottini pomodoro e mozzarella','Panzerottini mignon surgelati.','Fritti','cartone da 36 pezzi',36::numeric,1::numeric),
 ('Fornitore Nord','DL-NOR-009','Cannoli mignon','Cannoli mignon da farcire.','Dolci','confezione da 25 pezzi',25::numeric,1::numeric),
 ('Fornitore Sud','DL-SUD-010','Pasticciotto leccese mignon','Pasticciotti mignon surgelati.','Dolci','cartone da 20 pezzi',20::numeric,1::numeric),
 ('Fornitore Nord','SN-NOR-011','Anelli di cipolla','Anelli di cipolla impanati.','Snack','cartone da 30 pezzi',30::numeric,1::numeric),
 ('Fornitore Sud','FR-SUD-012','Frittatina di pasta','Frittatine di pasta napoletane.','Fritti','cartone da 24 pezzi',24::numeric,1::numeric)
) as v(supplier_name,sku,name,description,category,unit_label,pack_size,min_quantity)
join public.organizations s on s.name=v.supplier_name and s.kind='supplier'
on conflict(supplier_organization_id,sku) do update set name=excluded.name,description=excluded.description,category=excluded.category,unit_label=excluded.unit_label,pack_size=excluded.pack_size,min_quantity=excluded.min_quantity,active=true;

insert into public.customer_product_prices(customer_organization_id,product_id,price,currency,min_quantity)
select c.id,p.id,
case
 when c.name='Gastronomia Milano' and p.sku='FR-SUD-001' then 18.90
 when c.name='Gastronomia Bari' and p.sku='FR-SUD-001' then 17.50
 when c.name='Gastronomia Milano' and p.sku='FR-NOR-002' then 16.50
 when c.name='Gastronomia Bari' and p.sku='FR-NOR-002' then 17.20
 when c.name='Gastronomia Milano' and p.sku='FR-SUD-003' then 25.80
 when c.name='Gastronomia Bari' and p.sku='FR-SUD-003' then 23.50
 when c.name='Gastronomia Milano' and p.sku='PZ-NOR-004' then 31.50
 when c.name='Gastronomia Bari' and p.sku='PZ-NOR-004' then 30.90
 when c.name='Gastronomia Milano' and p.sku='PZ-NOR-005' then 25.50
 when c.name='Gastronomia Bari' and p.sku='PZ-NOR-005' then 24.90
 when c.name='Gastronomia Milano' and p.sku='SN-SUD-006' then 21.40
 when c.name='Gastronomia Bari' and p.sku='SN-SUD-006' then 20.90
 when c.name='Gastronomia Milano' and p.sku='SN-NOR-007' then 19.80
 when c.name='Gastronomia Bari' and p.sku='SN-NOR-007' then 20.40
 when c.name='Gastronomia Milano' and p.sku='SN-SUD-008' then 22.50
 when c.name='Gastronomia Bari' and p.sku='SN-SUD-008' then 21.90
 when c.name='Gastronomia Milano' and p.sku='DL-NOR-009' then 27.50
 when c.name='Gastronomia Bari' and p.sku='DL-NOR-009' then 26.90
 when c.name='Gastronomia Milano' and p.sku='DL-SUD-010' then 29.00
 when c.name='Gastronomia Bari' and p.sku='DL-SUD-010' then 28.50
 when c.name='Gastronomia Milano' and p.sku='SN-NOR-011' then 18.50
 when c.name='Gastronomia Bari' and p.sku='SN-NOR-011' then 18.90
 when c.name='Gastronomia Milano' and p.sku='FR-SUD-012' then 24.50
 else 23.90
end,'EUR',1
from public.organizations c cross join public.products p
where c.kind='customer' and c.name in ('Gastronomia Milano','Gastronomia Bari')
and p.sku in ('FR-SUD-001','FR-NOR-002','FR-SUD-003','PZ-NOR-004','PZ-NOR-005','SN-SUD-006','SN-NOR-007','SN-SUD-008','DL-NOR-009','DL-SUD-010','SN-NOR-011','FR-SUD-012')
on conflict(customer_organization_id,product_id) do update set price=excluded.price,currency=excluded.currency,min_quantity=excluded.min_quantity,updated_at=now();
