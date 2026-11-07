-- Format integrity constraints reconstructed from the deployed schema.
alter table public.product_formats drop constraint if exists product_formats_units_check;
alter table public.product_formats add constraint product_formats_units_check check(units>0);
alter table public.product_formats drop constraint if exists product_formats_min_quantity_check;
alter table public.product_formats add constraint product_formats_min_quantity_check check(min_quantity>0);
alter table public.customer_product_prices drop constraint if exists customer_product_prices_min_quantity_check;
alter table public.customer_product_prices add constraint customer_product_prices_min_quantity_check check(min_quantity>0);
alter table public.customer_product_prices drop constraint if exists customer_product_prices_price_check;
alter table public.customer_product_prices add constraint customer_product_prices_price_check check(price>=0);
alter table public.shopping_cart_items drop constraint if exists shopping_cart_items_quantity_check;
alter table public.shopping_cart_items add constraint shopping_cart_items_quantity_check check(quantity>0);
alter table public.shopping_cart_items drop constraint if exists shopping_cart_items_unit_price_snapshot_check;
alter table public.shopping_cart_items add constraint shopping_cart_items_unit_price_snapshot_check check(unit_price_snapshot is null or unit_price_snapshot>=0);
