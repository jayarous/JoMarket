Split migration files

Purpose
- Each numbered SQL in this folder contains the minimal CREATE TABLE (and closely related indexes/constraints) statements for a single logical group.
- Files are ordered roughly by dependency so you can run them one-by-one and catch issues early.

Recommended execution order

Run each table file, then its corresponding policy file (when present). Policies are located in `migrations/split/policies/` and are named with the same numeric prefix for clarity. This lets you validate table creation first and then enable RLS for that table before proceeding to dependent child tables.

1. 01_extensions_and_types.sql
2. 02_categories.sql
	- policies/20_categories_policies.sql
3. 03_coupons.sql
	- policies/19_coupons_policies.sql
4. 04_audit_logs.sql
5. 05_device_tokens.sql
6. 06_notifications.sql
7. 07_transactions_disputes_refunds.sql
8. 08_profiles.sql
	- policies/01_profiles_policies.sql
9. 09_user_roles.sql
	- policies/18_user_roles_policies.sql
10. 10_addresses.sql
	- policies/02_addresses_policies.sql
11. 11_vendors.sql
	- policies/03_vendors_policies.sql
12. 12_vendor_staff.sql
	- policies/04_vendor_staff_policies.sql
13. 13_products.sql
	- policies/05_products_policies.sql
14. 14_product_variants.sql
	- policies/06_product_variants_policies.sql
15. 15_product_images.sql
	- policies/07_product_images_policies.sql
16. 16_carts_and_cart_items_and_favorites.sql
	- policies/08_carts_policies.sql
17. 17_orders_and_items_and_coupons.sql
	- policies/09_orders_policies.sql
	- policies/10_order_items_policies.sql
	- policies/11_order_coupons_policies.sql
18. 18_payments.sql
	- policies/12_payments_policies.sql
19. 19_delivery_tables.sql
	- policies/13_delivery_providers_policies.sql
	- policies/14_delivery_staff_policies.sql
	- policies/15_shipments_policies.sql
	- policies/16_delivery_assignments_policies.sql
20. 20_reviews.sql
	- policies/17_reviews_policies.sql
21. 21_vendor_documents_warehouses_inventory_restock.sql
22. 22_order_events_and_support.sql
23. 23_payouts.sql
24. 24_triggers_and_rls.sql
99. 99_run_full_migration_original.sql (runs original full migration)

Notes
- Many tables reference `auth.users` and use `auth.uid()` inside RLS policies: this is specific to Supabase. Ensure Supabase Auth exists before running.
- Run the scripts using a privileged role (service_role or DB superuser) because CREATE EXTENSION and CREATE FUNCTION require elevated privileges.
- After running the table scripts, review and run the RLS/policies segment (24_triggers_and_rls.sql or the policies in the original migration) while logged in as the privileged role.
- The original full migration file remains unchanged at migrations/sql_migration.sql.

How to run (psql example on Windows PowerShell)
psql -h <host> -U <user> -d <db> -f "c:/Users/jayar/Desktop/JoMarket/migrations/split/01_extensions_and_types.sql"
psql -h <host> -U <user> -d <db> -f "c:/Users/jayar/Desktop/JoMarket/migrations/split/02_categories.sql"
# ... proceed through files in order

If you'd like I can:
- Add a single orchestrating PowerShell script that runs each in order and stops on error.
- Create per-table RLS policies (split from the main file) and a script to attach triggers created in 24_triggers_and_rls.sql.
