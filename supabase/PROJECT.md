# FoodTrack backend

- Supabase project: `FoodTrack`
- Project ref: `itzdbziwfwnhqbnhlczy`
- Region: `eu-west-1`
- Project URL: `https://itzdbziwfwnhqbnhlczy.supabase.co`

## Backend responsibilities
- Supabase Auth for account access and password recovery.
- PostgreSQL for organizations, memberships, supplier-customer links, products, customer-specific prices, persistent shopping carts, orders, order items and recurring orders.
- Row Level Security on application tables.
- Storage bucket `foodtrack-product-images` for product imagery.
- `submit_foodtrack_order` validates customer membership, active commercial links, product availability, minimum quantities and current customer prices on the server. It creates one order per supplier in a single transaction.
- `generate_recurring_foodtrack_orders` is scheduled through `pg_cron`.
- `update_recurring_order_occurrence` allows a customer to change a generated occurrence only within the configured 48-hour deadline and without changing the recurring template.
- `shopping_carts` and `shopping_cart_items` persist one cart per authenticated account. RLS and the private `can_manage_foodtrack_cart` helper restrict access to the owner and authorized customer/supplier relationship. `save_foodtrack_cart` is SECURITY INVOKER and validates account ownership, supplier-customer links and product identity before saving. `unit_price_snapshot` is display-only; the checkout RPC recalculates the authoritative price and revalidates availability and minimum quantities.
- Shopping cart tables are included in the `supabase_realtime` publication so the same account sees cart updates across active sessions.

## Security
- Only the Supabase publishable/anon key may be present in public frontend code.
- Never put the `service_role` key or secret keys in the repository or browser.
- Roles are assigned through `memberships`; users must not be able to assign themselves privileged roles.
- Privileged functions use explicit identity and organization checks. Keep `SECURITY DEFINER` grants restricted to the roles that need them.
- All new public-schema tables must have RLS enabled and policies matching the organization-level access model.

## Operational notes
- The frontend is hosted on GitHub Pages and communicates with this Supabase project.
- The owner has confirmed that organizations, suppliers, products, price lists, commercial links and orders currently in the database are official records. Do not treat them as disposable test data or delete them without explicit approval.
- Fiorucci and Venditti currently have no supplier membership. The admin UI now supports inviting an account into each existing supplier organization without creating a duplicate. Existing supplier memberships are not reassigned automatically.
- Migration history drift is documented in `supabase/MIGRATION_AUDIT.md`. Do not reset or rebuild the production database until historical migration files have been reconciled.
- Do not enable paid plans, automatic upgrades or services that create recurring charges without explicit approval.
- The Supabase free tier has quotas and availability limits; it is not a service-level guarantee for a nationwide commercial service.


## Account e notifiche
- `organizations.active` controlla l'accesso degli account Negozio/Fornitore. Una policy RLS restrittiva blocca tutte le tabelle applicative quando un utente è associato a un'organizzazione disabilitata; i trigger impediscono anche le scritture tramite funzioni privilegiate.
- `public.notifications` contiene notifiche in-app per destinatario. I trigger generano `new_order` per il fornitore coinvolto e l'Admin, `order_accepted` per il Negozio e `delivery_reminder` il giorno prima della consegna per fornitore e Admin. Realtime aggiorna la campanella.
- `public.generate_foodtrack_delivery_reminders()` è pianificata ogni giorno tramite `pg_cron`.
