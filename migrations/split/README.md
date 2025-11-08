Split migration files

Purpose
- Each numbered SQL in this folder contains the minimal CREATE TABLE (and closely related indexes/constraints) statements for a single logical group.
- Files are ordered by dependency so you can run them one-by-one and catch issues early.

Recommended execution order

Run each table file, then its corresponding policy file (when present). Policies are located in `migrations/split/policies/` and are named with the same numeric prefix for clarity. This lets you validate table creation first and then enable RLS for that table before proceeding to dependent child tables.

1. 01_extensions_and_types.sql
2. 02_categories.sql
   - policies/02_categories_policies.sql
3. 03_addresses.sql
   - policies/03_addresses_policies.sql
4. 04_vendors.sql
   - policies/04_vendors_policies.sql
5. 05_vendor_staff.sql
   - policies/05_vendor_staff_policies.sql
6. 06_products.sql
   - policies/06_products_policies.sql
7. 07_product_variants.sql
   - policies/07_product_variants_policies.sql
8. 08_product_images.sql
   - policies/08_product_images_policies.sql
9. 09_coupons.sql
   - policies/09_coupons_policies.sql
10. 10_carts_and_cart_items_and_favorites.sql
   - policies/10_carts_policies.sql
   - policies/10_cart_items_policies.sql
   - policies/10_favorites_policies.sql
11. 11_orders_and_items_and_coupons.sql
   - policies/11_orders_policies.sql
   - policies/11_order_items_policies.sql
   - policies/11_order_coupons_policies.sql
12. 12_payments.sql
   - policies/12_payments_policies.sql
13. 13_delivery_tables.sql
   - policies/13_delivery_providers_policies.sql
   - policies/13_delivery_staff_policies.sql
   - policies/13_shipments_policies.sql
   - policies/13_delivery_assignments_policies.sql
14. 14_reviews.sql
   - policies/14_reviews_policies.sql
15. 15_vendor_documents_warehouses_inventory_restock.sql
16. 16_order_events_and_support.sql
17. 17_transactions_disputes_refunds.sql
18. 18_payouts.sql
19. 19_audit_logs.sql
20. 20_device_tokens.sql
21. 21_notifications.sql
22. 22_user_roles.sql
23. 23_profiles.sql
24. 24_triggers_and_rls.sql
99. 99_run_full_migration_original.sql (runs original full migration)

Notes
- Many tables reference `auth.users` and use `auth.uid()` inside RLS policies: this is specific to Supabase. Ensure Supabase Auth exists before running.
- Run the scripts using a privileged role (service_role or DB superuser) because CREATE EXTENSION and CREATE FUNCTION require elevated privileges.
- `24_triggers_and_rls.sql` now mirrors the full migration by enabling RLS on every table; run it after the numbered tables (and again after policies if needed).
- The original full migration file remains unchanged at migrations/sql_migration.sql.
- Local-only helpers (e.g. `local_only/00_auth_stubs-LOCAL-ONLY.sql`) exist strictly for running against a vanilla Postgres instance. **Do not** apply them to Supabase projects.

How to run (psql example on Windows PowerShell)
psql -h <host> -U <user> -d <db> -f "c:/Users/jayar/Desktop/JoMarket/migrations/split/01_extensions_and_types.sql"
psql -h <host> -U <user> -d <db> -f "c:/Users/jayar/Desktop/JoMarket/migrations/split/02_categories.sql"
# ... proceed through files in order

If you'd like I can:
- Update the orchestrating PowerShell script to run each in order and stop on error (done: `run_migrations.ps1` in this folder).
- Create a local-only `00_auth_stubs.sql` to enable policy creation on a fresh local DB for testing.
