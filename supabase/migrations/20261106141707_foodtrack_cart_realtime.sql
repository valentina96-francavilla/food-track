do $migration$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='shopping_carts') then
      alter publication supabase_realtime add table public.shopping_carts;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='shopping_cart_items') then
      alter publication supabase_realtime add table public.shopping_cart_items;
    end if;
  end if;
end
$migration$;