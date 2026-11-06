# FoodTrack migration audit

Last checked: 2026-11-06

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
