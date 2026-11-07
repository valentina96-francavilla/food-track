CREATE OR REPLACE FUNCTION public.save_foodtrack_cart(p_customer_organization_id uuid, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public', 'private'
AS $function$
declare v_user uuid:=auth.uid();v_cart_id uuid;v_count integer;
begin
 if v_user is null then raise exception 'Devi accedere per salvare il carrello.'; end if;
 if not private.foodtrack_account_enabled() then raise exception 'Account disabilitato: accesso a FoodTrack sospeso.'; end if;
 if p_customer_organization_id is not null and not exists(select 1 from public.organizations o where o.id=p_customer_organization_id and o.kind='customer' and o.active) then
  raise exception 'Il Negozio è disabilitato o non disponibile.';
 end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>100 then raise exception 'Il carrello deve contenere da 1 a 100 righe.'; end if;
 if not (select private.can_manage_foodtrack_cart(p_customer_organization_id)) then raise exception 'Non sei autorizzato a salvare un carrello per questo negozio.'; end if;
 select count(*) into v_count from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric,unit_price_snapshot numeric);
 if v_count=0 or exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric,unit_price_snapshot numeric) where x.product_id is null or x.format_id is null or x.quantity is null or x.quantity<=0 or (x.unit_price_snapshot is not null and x.unit_price_snapshot<0)) then raise exception 'Le righe del carrello non sono valide.'; end if;
 if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric,unit_price_snapshot numeric) group by x.product_id,x.format_id having count(*)>1) then raise exception 'Il carrello contiene formati duplicati.'; end if;
 if exists(
  select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric,unit_price_snapshot numeric)
  join public.products p on p.id=x.product_id
  left join public.organizations so on so.id=p.supplier_organization_id
  left join public.product_formats f on f.id=x.format_id and f.product_id=p.id
  where not p.active or so.active is distinct from true or f.id is null or not f.active
 ) then raise exception 'Un prodotto, fornitore o formato non è attivo o non è valido.'; end if;
 if p_customer_organization_id is null then
  if not public.is_foodtrack_platform_admin() and exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric,unit_price_snapshot numeric) left join public.products p on p.id=x.product_id where p.id is null or not exists(select 1 from public.memberships m where m.user_id=v_user and m.role='supplier'::public.member_role and m.organization_id=p.supplier_organization_id)) then raise exception 'Il carrello contiene prodotti non appartenenti al tuo catalogo.'; end if;
 else
  if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric,unit_price_snapshot numeric) left join public.products p on p.id=x.product_id where p.id is null or not exists(select 1 from public.customer_suppliers cs where cs.customer_organization_id=p_customer_organization_id and cs.supplier_organization_id=p.supplier_organization_id and cs.active)) then raise exception 'Un prodotto non appartiene a un fornitore attualmente collegato al negozio.'; end if;
 end if;
 insert into public.shopping_carts(owner_user_id,customer_organization_id,updated_at) values(v_user,p_customer_organization_id,now())
 on conflict(owner_user_id) do update set customer_organization_id=excluded.customer_organization_id,updated_at=now() returning id into v_cart_id;
 delete from public.shopping_cart_items where cart_id=v_cart_id;
 insert into public.shopping_cart_items(cart_id,product_id,format_id,quantity,unit_price_snapshot)
 select v_cart_id,x.product_id,x.format_id,x.quantity,x.unit_price_snapshot from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric,unit_price_snapshot numeric);
 return v_cart_id;
end $function$


CREATE OR REPLACE FUNCTION public.submit_foodtrack_order(p_customer_organization_id uuid, p_items jsonb, p_requested_delivery_date date, p_delivery_contact text, p_delivery_notes text DEFAULT NULL::text)
 RETURNS TABLE(order_id uuid, order_number bigint, supplier_organization_id uuid, subtotal numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare v_user uuid:=auth.uid();v_actor_supplier uuid;v_supplier uuid;v_order_id uuid;v_order_number bigint;v_subtotal numeric(12,2);v_count integer;v_role_ok boolean;
begin
 if v_user is null then raise exception 'Devi accedere per inviare un ordine.'; end if;
 if not private.foodtrack_account_enabled() then raise exception 'Account disabilitato: accesso a FoodTrack sospeso.'; end if;
 if not exists(select 1 from public.organizations o where o.id=p_customer_organization_id and o.kind='customer' and o.active) then raise exception 'Il Negozio è disabilitato o non disponibile.'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Il carrello è vuoto.'; end if;
 if p_requested_delivery_date is null or p_requested_delivery_date<=(now() at time zone 'Europe/Rome')::date then raise exception 'La data di consegna deve essere successiva a oggi.'; end if;
 if p_delivery_contact is null or length(trim(p_delivery_contact))<2 then raise exception 'Inserisci un referente per la consegna.'; end if;
 select m.organization_id into v_actor_supplier from public.memberships m where m.user_id=v_user and m.role='supplier'::public.member_role limit 1;
 select exists(select 1 from public.memberships m where m.user_id=v_user and m.organization_id=p_customer_organization_id and m.role='customer'::public.member_role) or public.is_foodtrack_platform_admin()
  or (v_actor_supplier is not null and exists(select 1 from public.customer_suppliers cs where cs.customer_organization_id=p_customer_organization_id and cs.supplier_organization_id=v_actor_supplier and cs.active))
 into v_role_ok;
 if not v_role_ok then raise exception 'Non sei autorizzato a creare un ordine per questo negozio.'; end if;
 select count(*) into v_count from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric);
 if v_count=0 or exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric) where x.product_id is null or x.format_id is null or x.quantity is null or x.quantity<=0) then raise exception 'Le righe del carrello non sono valide.'; end if;
 if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric) group by x.product_id,x.format_id having count(*)>1) then raise exception 'Il carrello contiene formati duplicati.'; end if;
 if v_actor_supplier is not null and not public.is_foodtrack_platform_admin() and exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric) left join public.products p on p.id=x.product_id where p.id is null or p.supplier_organization_id<>v_actor_supplier) then raise exception 'Un fornitore può inserire nell’ordine solo prodotti del proprio catalogo.'; end if;
 if exists(
  select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric)
  left join public.products p on p.id=x.product_id
  left join public.organizations so on so.id=p.supplier_organization_id
  left join public.product_formats f on f.id=x.format_id and f.product_id=p.id
  left join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=p_customer_organization_id
  where p.id is null or not p.active or so.active is distinct from true or f.id is null or not f.active
   or public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date) is null
   or public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)<=0
   or x.quantity<greatest(f.min_quantity,coalesce(cp.min_quantity,1))
 ) then raise exception 'Un prodotto, fornitore o formato non è disponibile, non ha un prezzo valido o non rispetta la quantità minima.'; end if;
 if exists(select 1 from (select distinct p.supplier_organization_id from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric) join public.products p on p.id=x.product_id) s where not exists(select 1 from public.customer_suppliers cs where cs.customer_organization_id=p_customer_organization_id and cs.supplier_organization_id=s.supplier_organization_id and cs.active)) then raise exception 'Il negozio non è collegato a uno dei fornitori presenti nel carrello.'; end if;
 for v_supplier in select distinct p.supplier_organization_id from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric) join public.products p on p.id=x.product_id order by p.supplier_organization_id loop
  select round(sum(x.quantity*public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)),2) into v_subtotal
  from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric)
  join public.products p on p.id=x.product_id and p.supplier_organization_id=v_supplier
  join public.product_formats f on f.id=x.format_id and f.product_id=p.id
  join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=p_customer_organization_id;
  insert into public.orders(customer_organization_id,supplier_organization_id,created_by,status,requested_delivery_date,delivery_contact,delivery_notes,subtotal)
  values(p_customer_organization_id,v_supplier,v_user,'submitted',p_requested_delivery_date,trim(p_delivery_contact),nullif(trim(coalesce(p_delivery_notes,'')),''),v_subtotal)
  returning id,orders.order_number into v_order_id,v_order_number;
  insert into public.order_items(order_id,product_id,format_id,sku_snapshot,name_snapshot,unit_snapshot,quantity,unit_price)
  select v_order_id,p.id,f.id,p.sku,p.name,f.name||' · '||f.units||' unità',x.quantity,public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)
  from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric)
  join public.products p on p.id=x.product_id and p.supplier_organization_id=v_supplier
  join public.product_formats f on f.id=x.format_id and f.product_id=p.id
  join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=p_customer_organization_id;
  order_id:=v_order_id;order_number:=v_order_number;supplier_organization_id:=v_supplier;subtotal:=v_subtotal;return next;
 end loop;
end $function$

revoke all on function public.save_foodtrack_cart(uuid,jsonb) from public,anon;
grant execute on function public.save_foodtrack_cart(uuid,jsonb) to authenticated;
revoke all on function public.submit_foodtrack_order(uuid,jsonb,date,text,text) from public,anon;
grant execute on function public.submit_foodtrack_order(uuid,jsonb,date,text,text) to authenticated;
