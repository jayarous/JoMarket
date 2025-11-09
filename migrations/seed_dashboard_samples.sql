-- seed_dashboard_samples.sql
-- Purpose: seed representative shopper/vendor/delivery data so the Flutter role dashboards
--          have live Supabase rows during development.
--
-- Usage:
--   1. Option A – quick smoke test: set `single_user_id` to one real `auth.users.id`. The script
--      reuses that ID for shopper, vendor owner, vendor staff, and delivery staff roles.
--   2. Option B – richer demo: leave `single_user_id` as all zeros and override each role-specific
--      variable with distinct `auth.users.id` values.
--   3. Run this file after the core migrations have been applied. The script is idempotent.

DO $$
DECLARE
  placeholder_single constant uuid := '00000000-0000-0000-0000-000000000000';
  placeholder_shopper constant uuid := '11111111-1111-1111-1111-111111111111';
  placeholder_owner constant uuid := '22222222-2222-2222-2222-222222222222';
  placeholder_staff constant uuid := '33333333-3333-3333-3333-333333333333';
  placeholder_delivery constant uuid := '44444444-4444-4444-4444-444444444444';

  -- keep single_user_id as the all-zero placeholder so we can assign
  -- distinct UIDs per role below (do not overwrite them automatically)
  single_user_id uuid := placeholder_single;
  shopper_id uuid := 'd0d7d1a1-740e-4b07-9355-e2c7f831d78c';
  vendor_owner_id uuid := 'daf4a9da-a69d-454f-bd1a-f3b7e1d2a2f4';
  vendor_staff_id uuid := '800b6c1e-2552-4664-8d6c-9450d50db05b';
  delivery_user_id uuid := '4f26f12d-5d7a-4297-8cc6-1228557aee90';

  electronics_id uuid;
  mobile_id uuid;
  grocery_id uuid;
  demo_vendor_id uuid;
  phone_product_id uuid;
  coffee_product_id uuid;
  address_id uuid;
  primary_order_id uuid;
  marketplace_order_id uuid;
  provider_row_id uuid;
  delivery_staff_row_id uuid;
BEGIN
  IF single_user_id <> placeholder_single THEN
    IF shopper_id = placeholder_shopper THEN shopper_id := single_user_id; END IF;
    IF vendor_owner_id = placeholder_owner THEN vendor_owner_id := single_user_id; END IF;
    IF vendor_staff_id = placeholder_staff THEN vendor_staff_id := single_user_id; END IF;
    IF delivery_user_id = placeholder_delivery THEN delivery_user_id := single_user_id; END IF;
  END IF;

  IF shopper_id = placeholder_shopper
     OR vendor_owner_id = placeholder_owner
     OR vendor_staff_id = placeholder_staff
     OR delivery_user_id = placeholder_delivery THEN
    RAISE EXCEPTION
      'Replace the placeholder UUIDs in seed_dashboard_samples.sql with real auth.users IDs before running.';
  END IF;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), NULL, 'Electronics', 'electronics', 0)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO electronics_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), electronics_id, 'Mobile Phones', 'mobile-phones', 1)
  ON CONFLICT (parent_id, slug) DO UPDATE SET parent_id = EXCLUDED.parent_id
  RETURNING id INTO mobile_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), NULL, 'Grocery Basics', 'grocery-basics', 2)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO grocery_id;

  INSERT INTO public.vendors (id, owner_user_id, name, slug, description, support_email, support_phone)
  VALUES (
    gen_random_uuid(),
    vendor_owner_id,
    'Amman Market',
    'amman-market',
    'Primary JoMarket demo vendor',
    'support@amman-market.test',
    '+962700000000'
  )
  ON CONFLICT (slug) DO UPDATE SET owner_user_id = EXCLUDED.owner_user_id
  RETURNING id INTO demo_vendor_id;

  INSERT INTO public.vendor_staff (vendor_id, user_id, role)
  VALUES (demo_vendor_id, vendor_staff_id, 'manager')
  ON CONFLICT (vendor_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT shopper_id, 'shopper', NULL
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = shopper_id AND role = 'shopper' AND vendor_id IS NULL
  );

  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_owner_id, 'vendor_owner', demo_vendor_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = vendor_owner_id AND role = 'vendor_owner' AND vendor_id = demo_vendor_id
  );

  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_staff_id, 'vendor_staff', demo_vendor_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = vendor_staff_id AND role = 'vendor_staff' AND vendor_id = demo_vendor_id
  );

  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT delivery_user_id, 'delivery', NULL
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = delivery_user_id AND role = 'delivery' AND vendor_id IS NULL
  );

  INSERT INTO public.products (
    id,
    vendor_id,
    category_id,
    name,
    slug,
    description,
    base_price_cents,
    currency,
    status
  )
  VALUES (
    gen_random_uuid(),
    demo_vendor_id,
    mobile_id,
    'Falcon X1 Smartphone',
    'falcon-x1-smartphone',
    '6.7" AMOLED, 256GB storage, dual SIM.',
    329990,
    'JOD',
    'active'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE SET description = EXCLUDED.description
  RETURNING id INTO phone_product_id;

  INSERT INTO public.products (
    id,
    vendor_id,
    category_id,
    name,
    slug,
    description,
    base_price_cents,
    currency,
    status
  )
  VALUES (
    gen_random_uuid(),
    demo_vendor_id,
    grocery_id,
    'Bedouin Coffee Blend',
    'bedouin-coffee-blend',
    '500g premium Jordanian roast.',
    1499,
    'JOD',
    'active'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE SET description = EXCLUDED.description
  RETURNING id INTO coffee_product_id;

  SELECT id INTO address_id
  FROM public.addresses
  WHERE user_id = shopper_id AND label = 'Home'
  LIMIT 1;

  IF address_id IS NULL THEN
    INSERT INTO public.addresses (id, user_id, label, line1, city, country, is_default)
    VALUES (gen_random_uuid(), shopper_id, 'Home', '7th Circle', 'Amman', 'JO', true)
    RETURNING id INTO address_id;
  ELSE
    UPDATE public.addresses
    SET line1 = '7th Circle',
        city = 'Amman',
        country = 'JO',
        is_default = true
    WHERE id = address_id;
  END IF;

  INSERT INTO public.orders (
    id,
    user_id,
    status,
    subtotal_cents,
    shipping_cents,
    tax_cents,
    total_cents,
    currency,
    shipping_address_id
  )
  VALUES (
    gen_random_uuid(),
    shopper_id,
    'confirmed',
    331489,
    1500,
    0,
    332989,
    'JOD',
    address_id
  )
  RETURNING id INTO primary_order_id;

  INSERT INTO public.order_items (
    id,
    order_id,
    vendor_id,
    product_id,
    name,
    quantity,
    unit_price_cents
  )
  VALUES
    (
      gen_random_uuid(),
      primary_order_id,
      demo_vendor_id,
      phone_product_id,
      'Falcon X1 Smartphone',
      1,
      329990
    ),
    (
      gen_random_uuid(),
      primary_order_id,
      demo_vendor_id,
      coffee_product_id,
      'Bedouin Coffee Blend',
      1,
      1499
    );

  INSERT INTO public.orders (
    id,
    user_id,
    status,
    subtotal_cents,
    total_cents,
    currency,
    shipping_address_id
  )
  VALUES (
    gen_random_uuid(),
    shopper_id,
    'pending',
    1499,
    1499,
    'JOD',
    address_id
  )
  RETURNING id INTO marketplace_order_id;

  PERFORM 1
  FROM public.shipments
  WHERE order_id = primary_order_id AND vendor_id = demo_vendor_id
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.shipments (
      id,
      order_id,
      vendor_id,
      status,
      visibility,
      tracking_number,
      accepted_by_staff_id,
      accepted_at,
      updated_at
    )
    VALUES (
      gen_random_uuid(),
      primary_order_id,
      demo_vendor_id,
      'assigned',
      'private',
      'AMM-ASSIGN-001',
      NULL,
      NULL,
      now()
    );
  ELSE
    UPDATE public.shipments
    SET status = 'assigned',
        visibility = 'private',
        tracking_number = 'AMM-ASSIGN-001',
        updated_at = now()
    WHERE order_id = primary_order_id AND vendor_id = demo_vendor_id;
  END IF;

  PERFORM 1
  FROM public.shipments
  WHERE order_id = marketplace_order_id AND vendor_id IS NULL
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.shipments (
      id,
      order_id,
      vendor_id,
      status,
      visibility,
      tracking_number,
      posted_at,
      updated_at
    )
    VALUES (
      gen_random_uuid(),
      marketplace_order_id,
      NULL,
      'pending',
      'marketplace',
      'JMK-MKT-001',
      now(),
      now()
    );
  ELSE
    UPDATE public.shipments
    SET status = 'pending',
        visibility = 'marketplace',
        tracking_number = 'JMK-MKT-001',
        updated_at = now()
    WHERE order_id = marketplace_order_id AND vendor_id IS NULL;
  END IF;

  SELECT id INTO provider_row_id
  FROM public.delivery_providers
  WHERE name = 'JoExpress Logistics'
  LIMIT 1;

  IF provider_row_id IS NULL THEN
    provider_row_id := gen_random_uuid();
    INSERT INTO public.delivery_providers (
      id,
      owner_user_id,
      name,
      provider_type,
      phone,
      active
    )
    VALUES (
      provider_row_id,
      delivery_user_id,
      'JoExpress Logistics',
      'individual',
      '+962710000000',
      true
    );
  END IF;

  SELECT id INTO delivery_staff_row_id
  FROM public.delivery_staff
  WHERE user_id = delivery_user_id
  LIMIT 1;

  IF delivery_staff_row_id IS NULL THEN
    INSERT INTO public.delivery_staff (
      id,
      user_id,
      provider_id,
      active,
      is_available,
      max_concurrent_jobs,
      vehicle_type
    )
    VALUES (
      gen_random_uuid(),
      delivery_user_id,
      provider_row_id,
      true,
      true,
      3,
      'car'
    )
    RETURNING id INTO delivery_staff_row_id;
  ELSE
    UPDATE public.delivery_staff
    SET provider_id = provider_row_id,
        active = true,
        is_available = true
    WHERE id = delivery_staff_row_id;
  END IF;

  UPDATE public.shipments
  SET accepted_by_staff_id = delivery_staff_row_id,
      accepted_at = now(),
      status = 'in_transit'
  WHERE order_id = primary_order_id
    AND vendor_id = demo_vendor_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.delivery_assignments da
    JOIN public.shipments s ON s.id = da.shipment_id
    WHERE da.delivery_staff_id = delivery_staff_row_id
      AND s.order_id = primary_order_id
      AND s.vendor_id = demo_vendor_id
  ) THEN
    INSERT INTO public.delivery_assignments (
      id,
      shipment_id,
      delivery_staff_id,
      status,
      assigned_at
    )
    SELECT
      gen_random_uuid(),
      s.id,
      delivery_staff_row_id,
      s.status,
      now()
    FROM public.shipments s
    WHERE s.order_id = primary_order_id
      AND s.vendor_id = demo_vendor_id
    LIMIT 1;
  END IF;

  RAISE NOTICE 'Dashboard seed complete: shopper %, vendor %, delivery staff %', shopper_id, demo_vendor_id, delivery_staff_row_id;
END $$;
