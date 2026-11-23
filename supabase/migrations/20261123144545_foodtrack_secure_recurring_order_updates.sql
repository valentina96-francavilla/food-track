-- Restrict recurring checkout to signed-in users and enforce account status
-- in the SECURITY DEFINER routine used to edit generated occurrences.
REVOKE EXECUTE ON FUNCTION public.submit_foodtrack_order_with_recurrence(uuid,jsonb,date,text,text,smallint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_foodtrack_order_with_recurrence(uuid,jsonb,date,text,text,smallint[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_recurring_order_occurrence(p_occurrence_id uuid, p_items jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_user uuid:=auth.uid(); v_order_id uuid; v_customer uuid; v_supplier uuid; v_delivery date; v_total numeric(12,2); v_count integer;
begin
 if v_user is null then raise exception 'Devi accedere.'; end if;
 if not private.foodtrack_account_enabled() then raise exception 'Account disabilitato: accesso a FoodTrack sospeso.'; end if;
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
