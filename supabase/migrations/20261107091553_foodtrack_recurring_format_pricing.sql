CREATE OR REPLACE FUNCTION public.generate_recurring_foodtrack_orders()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare r record; v_order_id uuid; v_total numeric(12,2); v_missing boolean; v_count integer:=0;
begin
 perform pg_advisory_xact_lock(hashtext('foodtrack-recurring-orders'));
 for r in
  select ro.*,d.delivery_date::date as occurrence_date
  from public.recurring_orders ro
  cross join generate_series(((now() at time zone 'Europe/Rome')::date+3)::timestamp,((now() at time zone 'Europe/Rome')::date+7)::timestamp,interval '1 day') as d(delivery_date)
  where ro.active and ro.start_date<=d.delivery_date::date and (ro.end_date is null or ro.end_date>=d.delivery_date::date)
   and ro.delivery_weekday=extract(dow from d.delivery_date)::smallint
   and exists(select 1 from public.customer_suppliers cs where cs.customer_organization_id=ro.customer_organization_id and cs.supplier_organization_id=ro.supplier_organization_id and cs.active)
  order by d.delivery_date,ro.id
 loop
  if exists(select 1 from public.recurring_order_occurrences x where x.recurring_order_id=r.id and x.delivery_date=r.occurrence_date and x.status in ('generated','cancelled')) then continue; end if;
  select count(*)=0 or bool_or(p.id is null or not p.active or f.id is null or not f.active
   or public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date) is null
   or public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)<=0
   or ri.quantity<greatest(coalesce(f.min_quantity,1),coalesce(cp.min_quantity,1)))
  into v_missing
  from public.recurring_order_items ri
  left join public.products p on p.id=ri.product_id and p.supplier_organization_id=r.supplier_organization_id
  left join public.product_formats f on f.id=ri.format_id and f.product_id=ri.product_id
  left join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=r.customer_organization_id
  where ri.recurring_order_id=r.id;
  if v_missing then
   insert into public.recurring_order_occurrences(recurring_order_id,delivery_date,status,error_message)
   values(r.id,r.occurrence_date,'blocked','Ordine non generato: verifica prodotti, formati, prezzi e quantità minima nel listino del negozio.')
   on conflict(recurring_order_id,delivery_date) do update set status='blocked',error_message=excluded.error_message,generated_at=now();
   continue;
  end if;
  select round(sum(ri.quantity*public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)),2)
  into v_total
  from public.recurring_order_items ri
  join public.products p on p.id=ri.product_id and p.supplier_organization_id=r.supplier_organization_id
  join public.product_formats f on f.id=ri.format_id and f.product_id=p.id
  join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=r.customer_organization_id
  where ri.recurring_order_id=r.id;
  insert into public.orders(customer_organization_id,supplier_organization_id,created_by,status,requested_delivery_date,delivery_contact,delivery_notes,subtotal)
  values(r.customer_organization_id,r.supplier_organization_id,r.created_by,'submitted',r.occurrence_date,r.delivery_contact,nullif(trim(coalesce(r.delivery_notes,'')),''),v_total)
  returning id into v_order_id;
  insert into public.order_items(order_id,product_id,format_id,sku_snapshot,name_snapshot,unit_snapshot,quantity,unit_price)
  select v_order_id,p.id,f.id,p.sku,p.name,f.name||' · '||f.units||' unità',ri.quantity,
   public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)
  from public.recurring_order_items ri
  join public.products p on p.id=ri.product_id and p.supplier_organization_id=r.supplier_organization_id
  join public.product_formats f on f.id=ri.format_id and f.product_id=p.id
  join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=r.customer_organization_id
  where ri.recurring_order_id=r.id;
  insert into public.recurring_order_occurrences(recurring_order_id,delivery_date,order_id,status)
  values(r.id,r.occurrence_date,v_order_id,'generated')
  on conflict(recurring_order_id,delivery_date) do update set order_id=excluded.order_id,status='generated',error_message=null,generated_at=now();
  v_count:=v_count+1;
 end loop;
 return v_count;
end;
$function$


CREATE OR REPLACE FUNCTION public.update_recurring_order_occurrence(p_occurrence_id uuid, p_items jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_user uuid:=auth.uid(); v_order_id uuid; v_customer uuid; v_supplier uuid; v_delivery date; v_total numeric(12,2); v_count integer;
begin
 if v_user is null then raise exception 'Devi accedere.'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'L’ordine deve contenere almeno un prodotto.'; end if;
 select o.id,o.customer_organization_id,o.supplier_organization_id,o.requested_delivery_date
 into v_order_id,v_customer,v_supplier,v_delivery
 from public.recurring_order_occurrences x
 join public.orders o on o.id=x.order_id
 join public.memberships m on m.organization_id=o.customer_organization_id and m.user_id=v_user and m.role='customer'::public.member_role
 where x.id=p_occurrence_id and x.status='generated' and o.status='submitted' for update of o;
 if v_order_id is null then raise exception 'Consegna ricorrente non trovata o non modificabile.'; end if;
 if now()>=((v_delivery::timestamp at time zone 'Europe/Rome')-interval '48 hours') then raise exception 'Modifiche non consentite: il limite è 48 ore prima della consegna.'; end if;
 select count(*) into v_count from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric);
 if v_count=0 or exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric) where x.product_id is null or x.format_id is null or x.quantity is null or x.quantity<=0)
  or exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric) group by x.product_id,x.format_id having count(*)>1)
 then raise exception 'Le righe dell’ordine non sono valide.'; end if;
 if exists(
  select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric)
  left join public.products p on p.id=x.product_id
  left join public.product_formats f on f.id=x.format_id and f.product_id=p.id
  left join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=v_customer
  where p.id is null or p.supplier_organization_id<>v_supplier or not p.active or f.id is null or not f.active
   or public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date) is null
   or public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)<=0
   or x.quantity<greatest(f.min_quantity,coalesce(cp.min_quantity,1))
 ) then raise exception 'Prodotto o formato non disponibile, prezzo mancante o quantità minima non rispettata.'; end if;
 select round(sum(x.quantity*public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)),2)
 into v_total
 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric)
 join public.customer_product_prices cp on cp.product_id=x.product_id and cp.format_id=x.format_id and cp.customer_organization_id=v_customer;
 delete from public.order_items where order_id=v_order_id;
 insert into public.order_items(order_id,product_id,format_id,sku_snapshot,name_snapshot,unit_snapshot,quantity,unit_price)
 select v_order_id,p.id,f.id,p.sku,p.name,f.name||' · '||f.units||' unità',x.quantity,
  public.foodtrack_effective_price(cp.price,cp.promotion_type,cp.discount_percent,cp.promotional_price,cp.promotion_start_at,cp.promotion_end_at,(now() at time zone 'Europe/Rome')::date)
 from jsonb_to_recordset(p_items) as x(product_id uuid,format_id uuid,quantity numeric)
 join public.products p on p.id=x.product_id
 join public.product_formats f on f.id=x.format_id and f.product_id=p.id
 join public.customer_product_prices cp on cp.product_id=p.id and cp.format_id=f.id and cp.customer_organization_id=v_customer;
 update public.orders set subtotal=v_total,updated_at=now() where id=v_order_id;
end;
$function$

