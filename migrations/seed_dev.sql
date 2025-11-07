-- migrations/seed_dev.sql
-- Minimal development seed data for staging/testing. Replace placeholder user IDs with real `auth.users` IDs created via Supabase Auth.

-- Note: this script assumes the main migration has already run and pgcrypto is available.

-- Example: create a top-level category and a leaf subcategory
INSERT INTO public.categories (id, parent_id, name, slug, position)
VALUES (gen_random_uuid(), NULL, 'Electronics', 'electronics', 0)
RETURNING id;

-- Replace this parent id in the next insert with the returned id or do a SELECT.
-- For convenience we insert a leaf category using a subselect.
INSERT INTO public.categories (id, parent_id, name, slug, position)
VALUES (gen_random_uuid(), (select id from public.categories where slug='electronics' limit 1), 'Mobile Phones', 'mobile-phones', 0);

-- Create a vendor (replace owner_user_id with a real auth.users.id for full end-to-end tests)
-- Use a placeholder UUID if you don't have auth.users created yet.
DO $$
DECLARE
  owner uuid := gen_random_uuid(); -- replace with real user id when available
  v_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.vendors (id, owner_user_id, name, slug, description)
  VALUES (v_id, owner, 'Acme Store', 'acme-store', 'Test vendor for dev');

  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, base_price_cents, currency, status)
  VALUES (gen_random_uuid(), v_id, (select id from public.categories where slug='mobile-phones' limit 1), 'Example Phone', 'example-phone', 'A sample product', 19999, 'JOD', 'active');

  INSERT INTO public.product_variants (id, product_id, sku, price_cents, stock)
  SELECT gen_random_uuid(), p.id, 'EX-PHONE-1', 19999, 10 FROM public.products p WHERE p.slug='example-phone' LIMIT 1;
END $$;

-- Simple address record (replace user_id with real auth.user id to test RLS)
INSERT INTO public.addresses (id, user_id, label, line1, city, country, is_default)
VALUES (gen_random_uuid(), NULL, 'Dev HQ', '123 Dev Street', 'Amman', 'Jordan', true);

-- End of seed file
