-- Account access controls and in-app order notifications.
-- Existing organizations.active is the source of truth; no business records are changed.

create schema if not exists private;
create or replace function private.foodtrack_account_enabled()
returns boolean language sql stable security definer set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (select 1 from public.memberships m where m.user_id=(select auth.uid()))
    and not exists (
      select 1 from public.memberships m
      join public.organizations o on o.id=m.organization_id
      where m.user_id=(select auth.uid()) and o.active is not true
    );
$$;
revoke all on function private.foodtrack_account_enabled() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.foodtrack_account_enabled() to authenticated;

do $$
declare t text;
begin
  foreach t in array array['organizations','memberships','customer_suppliers','products','customer_product_prices','orders','order_items','recurring_orders','recurring_order_items','recurring_order_occurrences','shopping_carts','shopping_cart_items','customer_favorites','favorites'] loop
    execute format('drop policy if exists foodtrack_account_must_be_enabled on public.%I',t);
    execute format('create policy foodtrack_account_must_be_enabled on public.%I as restrictive for all to authenticated using (private.foodtrack_account_enabled()) with check (private.foodtrack_account_enabled())',t);
  end loop;
end $$;

create or replace function private.enforce_foodtrack_active_order()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not private.foodtrack_account_enabled() then
    raise exception 'Account FoodTrack disabilitato. Contatta l’amministratore.';
  end if;
  if tg_op='INSERT' or new.customer_organization_id is distinct from old.customer_organization_id or new.supplier_organization_id is distinct from old.supplier_organization_id then
    if not exists(select 1 from public.organizations c where c.id=new.customer_organization_id and c.kind='customer' and c.active) then raise exception 'Il negozio è disabilitato o non disponibile.'; end if;
    if not exists(select 1 from public.organizations s where s.id=new.supplier_organization_id and s.kind='supplier' and s.active) then raise exception 'Il fornitore è disabilitato o non disponibile.'; end if;
  end if;
  return new;
end $$;
revoke all on function private.enforce_foodtrack_active_order() from public, anon, authenticated;
drop trigger if exists foodtrack_enforce_active_order on public.orders;
create trigger foodtrack_enforce_active_order before insert or update on public.orders for each row execute function private.enforce_foodtrack_active_order();

create or replace function private.enforce_foodtrack_active_order_item()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_order_id uuid;
begin
  if (select auth.uid()) is not null and not private.foodtrack_account_enabled() then raise exception 'Account FoodTrack disabilitato. Contatta l’amministratore.'; end if;
  v_order_id := case when tg_op='DELETE' then old.order_id else new.order_id end;
  if (select auth.uid()) is not null and not exists(
    select 1 from public.orders o
    join public.organizations c on c.id=o.customer_organization_id and c.active
    join public.organizations s on s.id=o.supplier_organization_id and s.active
    where o.id=v_order_id
  ) then raise exception 'Ordine non disponibile per un negozio o fornitore disabilitato.'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function private.enforce_foodtrack_active_order_item() from public, anon, authenticated;
drop trigger if exists foodtrack_enforce_active_order_item on public.order_items;
create trigger foodtrack_enforce_active_order_item before insert or update or delete on public.order_items for each row execute function private.enforce_foodtrack_active_order_item();

create table if not exists public.notifications(
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  recipient_organization_id uuid references public.organizations(id) on delete set null,
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type text not null check(event_type in ('new_order','order_accepted','delivery_reminder')),
  title text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique(recipient_user_id,order_id,event_type)
);
create index if not exists notifications_recipient_created_idx on public.notifications(recipient_user_id,created_at desc);
alter table public.notifications enable row level security;
grant select,update on public.notifications to authenticated;
drop policy if exists notifications_read_own on public.notifications;
create policy notifications_read_own on public.notifications for select to authenticated using(recipient_user_id=(select auth.uid()));
drop policy if exists notifications_mark_own_read on public.notifications;
create policy notifications_mark_own_read on public.notifications for update to authenticated using(recipient_user_id=(select auth.uid())) with check(recipient_user_id=(select auth.uid()) and read_at is not null);
create policy foodtrack_account_must_be_enabled on public.notifications as restrictive for all to authenticated using(private.foodtrack_account_enabled()) with check(private.foodtrack_account_enabled());

create or replace function private.create_foodtrack_delivery_reminders(p_order_id uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare v_order public.orders%rowtype; v_code text; v_customer text; v_rows integer; v_total integer:=0;
begin
  select * into v_order from public.orders where id=p_order_id;
  if not found or v_order.requested_delivery_date is distinct from (now() at time zone 'Europe/Rome')::date+1 or v_order.status in ('cancelled'::public.order_status,'delivered'::public.order_status) then return 0; end if;
  v_code:='FT-'||extract(year from v_order.submitted_at)::text||'-'||lpad(v_order.order_number::text,6,'0');
  select name into v_customer from public.organizations where id=v_order.customer_organization_id;
  insert into public.notifications(recipient_user_id,recipient_organization_id,order_id,event_type,title,message)
  select m.user_id,m.organization_id,v_order.id,'delivery_reminder','Consegna prevista domani · '||v_code,'Ricorda di consegnare domani l’ordine '||v_code||' a '||coalesce(v_customer,'il negozio')||'.'
  from public.memberships m join public.organizations o on o.id=m.organization_id and o.active
  where m.organization_id=v_order.supplier_organization_id and m.role='supplier'
  on conflict(recipient_user_id,order_id,event_type) do nothing;
  get diagnostics v_rows=row_count; v_total:=v_total+v_rows;
  insert into public.notifications(recipient_user_id,recipient_organization_id,order_id,event_type,title,message)
  select m.user_id,m.organization_id,v_order.id,'delivery_reminder','Consegna prevista domani · '||v_code,'Ricorda la consegna di domani dell’ordine '||v_code||' per '||coalesce(v_customer,'il negozio')||'.'
  from public.memberships m join public.organizations o on o.id=m.organization_id and o.active and o.kind='platform'
  where m.role='admin'
  on conflict(recipient_user_id,order_id,event_type) do nothing;
  get diagnostics v_rows=row_count; v_total:=v_total+v_rows;
  return v_total;
end $$;
revoke all on function private.create_foodtrack_delivery_reminders(uuid) from public,anon,authenticated;

create or replace function private.notify_foodtrack_new_order()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_code text:='FT-'||extract(year from new.submitted_at)::text||'-'||lpad(new.order_number::text,6,'0'); v_customer text;
begin
  select name into v_customer from public.organizations where id=new.customer_organization_id;
  insert into public.notifications(recipient_user_id,recipient_organization_id,order_id,event_type,title,message)
  select m.user_id,m.organization_id,new.id,'new_order','Nuovo ordine '||v_code,'Nuovo ordine da '||coalesce(v_customer,'un negozio')||'. Apri il dettaglio per consultare i prodotti.'
  from public.memberships m join public.organizations o on o.id=m.organization_id and o.active
  where m.organization_id=new.supplier_organization_id and m.role='supplier'
  on conflict(recipient_user_id,order_id,event_type) do nothing;
  insert into public.notifications(recipient_user_id,recipient_organization_id,order_id,event_type,title,message)
  select m.user_id,m.organization_id,new.id,'new_order','Nuovo ordine '||v_code,'Nuovo ordine ricevuto da '||coalesce(v_customer,'un negozio')||'.'
  from public.memberships m join public.organizations o on o.id=m.organization_id and o.active and o.kind='platform'
  where m.role='admin'
  on conflict(recipient_user_id,order_id,event_type) do nothing;
  if new.requested_delivery_date=(now() at time zone 'Europe/Rome')::date+1 then perform private.create_foodtrack_delivery_reminders(new.id); end if;
  return new;
end $$;
revoke all on function private.notify_foodtrack_new_order() from public,anon,authenticated;

create or replace function private.notify_foodtrack_order_accepted()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_code text:='FT-'||extract(year from new.submitted_at)::text||'-'||lpad(new.order_number::text,6,'0'); v_supplier text;
begin
  if new.status='accepted'::public.order_status and old.status is distinct from new.status then
    select name into v_supplier from public.organizations where id=new.supplier_organization_id;
    insert into public.notifications(recipient_user_id,recipient_organization_id,order_id,event_type,title,message)
    select m.user_id,m.organization_id,new.id,'order_accepted','Ordine '||v_code||' accettato',coalesce(v_supplier,'Il fornitore')||' ha accettato il tuo ordine.'
    from public.memberships m join public.organizations o on o.id=m.organization_id and o.active
    where m.organization_id=new.customer_organization_id and m.role='customer'
    on conflict(recipient_user_id,order_id,event_type) do nothing;
  end if;
  return new;
end $$;
revoke all on function private.notify_foodtrack_order_accepted() from public,anon,authenticated;

create or replace function public.generate_foodtrack_delivery_reminders()
returns integer language plpgsql security definer set search_path = ''
as $$
declare r record; v_total integer:=0;
begin
  for r in select id from public.orders where requested_delivery_date=(now() at time zone 'Europe/Rome')::date+1 and status not in ('cancelled'::public.order_status,'delivered'::public.order_status) loop
    v_total:=v_total+private.create_foodtrack_delivery_reminders(r.id);
  end loop;
  return v_total;
end $$;
revoke all on function public.generate_foodtrack_delivery_reminders() from public,anon,authenticated;

drop trigger if exists foodtrack_notify_new_order on public.orders;
create trigger foodtrack_notify_new_order after insert on public.orders for each row execute function private.notify_foodtrack_new_order();
drop trigger if exists foodtrack_notify_order_accepted on public.orders;
create trigger foodtrack_notify_order_accepted after update of status on public.orders for each row execute function private.notify_foodtrack_order_accepted();

do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then alter publication supabase_realtime add table public.notifications; end if;
end $$;
select cron.schedule('foodtrack-delivery-reminders-daily','0 5 * * *','select public.generate_foodtrack_delivery_reminders();');
