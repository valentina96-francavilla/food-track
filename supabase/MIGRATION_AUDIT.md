# FoodTrack migration audit

Last checked: 2026-11-07

## Nuove migrazioni account e notifiche
- `20261106145102_foodtrack_account_controls_and_notifications`
- `20261106145321_foodtrack_notification_indexes`

Le migrazioni aggiungono il blocco RLS per account disabilitati, controlli sui trigger ordine, notifiche in-app per nuovo ordine/accettazione/promemoria, sincronizzazione Realtime e gli indici delle notifiche. Le organizzazioni, i prodotti, i listini e gli ordini già presenti non sono stati modificati.

## New changes versioned in both Supabase and GitHub

The following migrations were applied to the active Supabase project and committed with matching versioned filenames:

- `20261106141341_foodtrack_persistent_cart.sql`
- `20261106141707_foodtrack_cart_realtime.sql`
- `20261106141952_foodtrack_cart_customer_index.sql`
- `20261106142123_foodtrack_cart_preserve_legacy_snapshot.sql`
- `20261106142545_foodtrack_admin_data_hardening.sql`

They cover persistent carts, RLS, cart authorization, Realtime publication, the customer foreign-key index, legacy cart price snapshots, the supplier contact field, favorite policies, indexes and helper-function grants.

## Historical drift

The remote Supabase migration history contains older versions that do not have a matching same-version SQL file in this repository. Some older repository migrations appear to cover similar changes, but their filenames/versions differ. The historical SQL for several remote migrations is not recoverable from the migration-history table alone.

This means the repository is **not yet proven to recreate the entire active database from an empty Supabase project**. Remote history entries without a same-version file include:

- `20261026154820`, `20261026154832`, `20261026154853`
- `20261029112436`, `20261029112531`, `20261029112757`
- `20261030150602`, `20261030150618`, `20261030150651`
- `20261031101225`, `20261031194434`, `20261031205113`, `20261031205759`
- `20261105144306`, `20261105144323`, `20261105144431`, `20261105144546`, `20261105145224`

Some older files may contain equivalent logic under a different filename/version, but equivalence has not been proven line by line. Do not run `supabase db reset`, drop/recreate production tables, or treat the active project as disposable.

Before a disaster-recovery restore or a new environment is created, reconstruct and validate the missing historical migrations from the current schema, functions, triggers, policies and storage configuration. Do not recreate business data as seed data: the owner has confirmed that current organizations, suppliers, products, price lists, links and orders are official records.

## Operating rule

For each future database change:
1. Create a versioned SQL migration in `supabase/migrations`.
2. Apply it to the intended Supabase project.
3. Verify the resulting schema, RLS and grants.
4. Commit the migration file.
5. Never modify or delete official business records as part of schema deployment.


## Formati multipli e prezzi per formato (2026-11-07)

Le seguenti versioni sono state applicate al progetto remoto:

- `20261107091321_foodtrack_multi_product_formats`
- `20261107091457_foodtrack_format_integrity_and_recurring_default`
- `20261107091518_foodtrack_product_format_rls_hardening`
- `20261107091553_foodtrack_recurring_format_pricing`
- `20261107091609_foodtrack_product_format_sort_order`
- `20261107091645_foodtrack_order_account_and_supplier_status_checks`

Il database ora usa `product_formats` e un prezzo distinto per combinazione Negozio/Prodotto/Formato. Le righe carrello, gli ordini e gli ordini ricorrenti memorizzano il formato scelto. I formati già esistenti sono stati migrati come formato predefinito, mantenendo i prezzi e gli ordini già registrati. Le nuove quantità libere si gestiscono creando un formato unitario, ad esempio `Pezzo` con 1 unità, e assegnando il relativo prezzo unitario nel listino.

**Allineamento eseguito il 2026-11-07:** i sei file SQL mancanti per le versioni sopra elencate sono stati aggiunti a `supabase/migrations`. I contenuti sono stati ricostruiti confrontando lo schema e le definizioni delle funzioni attualmente distribuite nel progetto remoto. Sono quindi una ricostruzione verificabile dello stato distribuito, non una copia byte-per-byte degli script originali usati al momento dell'applicazione. Prima di un ripristino completo su un progetto vuoto è ancora necessario validare l'intera catena di migrazioni in un ambiente isolato.


## Allineamento repository del 2026-11-07

Aggiunti i sei file mancanti corrispondenti alle versioni remote:

- `20261107091321_foodtrack_multi_product_formats.sql`
- `20261107091457_foodtrack_format_integrity_and_recurring_default.sql`
- `20261107091518_foodtrack_product_format_rls_hardening.sql`
- `20261107091553_foodtrack_recurring_format_pricing.sql`
- `20261107091609_foodtrack_product_format_sort_order.sql`
- `20261107091645_foodtrack_order_account_and_supplier_status_checks.sql`

Le funzioni per gli ordini ricorrenti, il carrello e l'invio ordini sono state copiate dalle definizioni correnti del database. Le migrazioni di schema e policy sono state ricostruite dallo schema attivo e dalle policy effettive. Le versioni remote risultano già applicate: non vanno riapplicate al database attivo.
