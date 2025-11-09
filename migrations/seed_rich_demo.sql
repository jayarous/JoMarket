-- migrations/seed_rich_demo.sql
-- Purpose: populate the JoMarket schema with richer demo data covering shoppers,
--          vendors, catalog, carts, orders, logistics, and reviews.
-- Instructions:
--   1. Create or pick the Supabase Auth users you want to reuse.
--   2. Either:
--        * set `single_user_id` below to reuse one ID for every role, or
--        * override the role-specific variables with distinct `auth.users.id` values.
--      The script will raise if any variable still equals the placeholder UUID.
--   3. Run after the base migrations are applied (pgcrypto + schema + enums).
--   4. The script is idempotent; rerunning it keeps the same reference data.

DO $$
DECLARE
  placeholder constant uuid := '00000000-0000-0000-0000-000000000000';

  single_user_id uuid := placeholder; -- set to '910a8067-9ffb-42cc-b80e-6c4cfc40818b' to reuse one auth user for every role

  -- Default Supabase Auth users available in the current project (update if they change)
  shopper_ayla uuid := 'd0d7d1a1-740e-4b07-9355-e2c7f831d78c';
  shopper_sami uuid := 'd0d7d1a1-740e-4b07-9355-e2c7f831d78c';
  shopper_nour uuid := 'd0d7d1a1-740e-4b07-9355-e2c7f831d78c';

  vendor_owner_lina uuid := 'daf4a9da-a69d-454f-bd1a-f3b7e1d2a2f4';
  vendor_owner_faris uuid := 'daf4a9da-a69d-454f-bd1a-f3b7e1d2a2f4';
  vendor_owner_hassan uuid := 'daf4a9da-a69d-454f-bd1a-f3b7e1d2a2f4';

  vendor_staff_mira uuid := '800b6c1e-2552-4664-8d6c-9450d50db05b';
  vendor_staff_omar uuid := '800b6c1e-2552-4664-8d6c-9450d50db05b';

  delivery_sara uuid := '4f26f12d-5d7a-4297-8cc6-1228557aee90';

  electronics_id uuid;
  mobiles_id uuid;
  laptops_id uuid;
  audio_id uuid;

  fashion_id uuid;
  mens_id uuid;
  womens_id uuid;

  home_id uuid;
  kitchen_id uuid;
  decor_id uuid;

  beauty_id uuid;
  skincare_id uuid;
  personal_id uuid;

  grocery_id uuid;
  fresh_id uuid;
  pantry_id uuid;

  vendor_ae uuid;
  vendor_dt uuid;
  vendor_gb uuid;
  vendor_rg uuid;

  shopper_ayla_addr uuid;
  shopper_sami_addr uuid;
  shopper_nour_addr uuid;

  vendor_ae_addr uuid;
  vendor_dt_addr uuid;
  vendor_gb_addr uuid;
  vendor_rg_addr uuid;

  warehouse_ae_city uuid;
  warehouse_ae_north uuid;
  warehouse_dt uuid;
  warehouse_gb uuid;
  warehouse_rg uuid;

  product_falcon uuid;
  variant_falcon_128 uuid;
  variant_falcon_256 uuid;

  product_wadi_laptop uuid;
  variant_wadi_i5 uuid;
  variant_wadi_i7 uuid;

  product_thobe uuid;
  variant_thobe_s uuid;
  variant_thobe_m uuid;
  variant_thobe_l uuid;

  product_dress uuid;
  variant_dress_s uuid;
  variant_dress_m uuid;

  product_tomatoes uuid;
  variant_tomatoes_1kg uuid;
  product_honey uuid;
  variant_honey_500 uuid;

  product_mask uuid;
  variant_mask_100 uuid;
  variant_mask_200 uuid;

  coupon_welcome uuid;
  coupon_green uuid;

  cart_ayla uuid;
  cart_sami uuid;
  cart_nour uuid;

  order_one uuid;
  order_two uuid;
  order_three uuid;

  shipment_order_one_ae uuid;
  shipment_order_one_rg uuid;
  shipment_order_two uuid;
  shipment_order_three uuid;

  provider_cityswift uuid;
  delivery_staff_sara uuid;

  tmp_id uuid;
BEGIN
  IF single_user_id <> placeholder THEN
    IF shopper_ayla = placeholder THEN shopper_ayla := single_user_id; END IF;
    IF shopper_sami = placeholder THEN shopper_sami := single_user_id; END IF;
    IF shopper_nour = placeholder THEN shopper_nour := single_user_id; END IF;
    IF vendor_owner_lina = placeholder THEN vendor_owner_lina := single_user_id; END IF;
    IF vendor_owner_faris = placeholder THEN vendor_owner_faris := single_user_id; END IF;
    IF vendor_owner_hassan = placeholder THEN vendor_owner_hassan := single_user_id; END IF;
    IF vendor_staff_mira = placeholder THEN vendor_staff_mira := single_user_id; END IF;
    IF vendor_staff_omar = placeholder THEN vendor_staff_omar := single_user_id; END IF;
    IF delivery_sara = placeholder THEN delivery_sara := single_user_id; END IF;
  END IF;

  IF shopper_ayla = placeholder OR shopper_sami = placeholder OR shopper_nour = placeholder
     OR vendor_owner_lina = placeholder OR vendor_owner_faris = placeholder OR vendor_owner_hassan = placeholder
     OR vendor_staff_mira = placeholder OR vendor_staff_omar = placeholder OR delivery_sara = placeholder THEN
    RAISE EXCEPTION
      'Replace the placeholder UUIDs in migrations/seed_rich_demo.sql (set single_user_id for quick testing).';
  END IF;

  -- Upsert shopper/vendor profiles
  WITH profile_rows AS (
    SELECT *
    FROM (VALUES
      (shopper_ayla, 'Ayla Haddad', '+962790000001', 'https://cdn.jomarket.test/avatars/ayla.png', 'JO'),
      (shopper_sami, 'Sami Odeh', '+962790000002', 'https://cdn.jomarket.test/avatars/sami.png', 'JO'),
      (shopper_nour, 'Nour Khoury', '+962790000003', 'https://cdn.jomarket.test/avatars/nour.png', 'JO'),
      (vendor_owner_lina, 'Lina Saqqaf', '+962790000101', 'https://cdn.jomarket.test/avatars/lina.png', 'JO'),
      (vendor_owner_faris, 'Faris Qudah', '+962790000102', 'https://cdn.jomarket.test/avatars/faris.png', 'JO'),
      (vendor_owner_hassan, 'Hassan Al-Salem', '+962790000103', 'https://cdn.jomarket.test/avatars/hassan.png', 'JO'),
      (vendor_staff_mira, 'Mira Alayan', '+962790000201', 'https://cdn.jomarket.test/avatars/mira.png', 'JO'),
      (vendor_staff_omar, 'Omar Srour', '+962790000202', 'https://cdn.jomarket.test/avatars/omar.png', 'JO'),
      (delivery_sara, 'Sara Khalil', '+962790000301', 'https://cdn.jomarket.test/avatars/sara.png', 'JO')
    ) AS p(user_id, full_name, phone, avatar_url, default_country)
  ),
  dedup_profiles AS (
    SELECT DISTINCT ON (user_id) user_id, full_name, phone, avatar_url, default_country
    FROM profile_rows
    ORDER BY user_id
  )
  INSERT INTO public.profiles (user_id, full_name, phone, avatar_url, default_country)
  SELECT user_id, full_name, phone, avatar_url, default_country
  FROM dedup_profiles
  ON CONFLICT (user_id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        avatar_url = EXCLUDED.avatar_url,
        default_country = EXCLUDED.default_country;

  -- User roles (platform + vendor scoped)
  WITH role_rows AS (
    SELECT *
    FROM (VALUES
      (shopper_ayla::uuid, 'shopper'::public.user_role, NULL::uuid),
      (shopper_sami::uuid, 'shopper'::public.user_role, NULL::uuid),
      (shopper_nour::uuid, 'shopper'::public.user_role, NULL::uuid),
      (vendor_owner_lina::uuid, 'vendor_owner'::public.user_role, NULL::uuid),
      (vendor_owner_faris::uuid, 'vendor_owner'::public.user_role, NULL::uuid),
      (vendor_owner_hassan::uuid, 'vendor_owner'::public.user_role, NULL::uuid),
      (vendor_staff_mira::uuid, 'vendor_staff'::public.user_role, NULL::uuid),
      (vendor_staff_omar::uuid, 'vendor_staff'::public.user_role, NULL::uuid),
      (delivery_sara::uuid, 'delivery'::public.user_role, NULL::uuid)
    ) AS r(user_id, role, vendor_id)
  ),
  dedup_roles AS (
    SELECT DISTINCT ON (user_id, role, COALESCE(vendor_id, '00000000-0000-0000-0000-000000000000'))
           user_id, role, vendor_id
    FROM role_rows
    ORDER BY user_id, role, COALESCE(vendor_id, '00000000-0000-0000-0000-000000000000')
  )
  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT user_id, role, vendor_id
  FROM dedup_roles
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = dedup_roles.user_id
      AND ur.role = dedup_roles.role
      AND ((dedup_roles.vendor_id IS NULL AND ur.vendor_id IS NULL)
           OR (dedup_roles.vendor_id IS NOT NULL AND ur.vendor_id = dedup_roles.vendor_id))
  );

  -- ---------------------------------------------------------------------------
  -- Category tree
  -- ---------------------------------------------------------------------------
  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), NULL, 'Electronics & Gadgets', 'electronics', 0)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO electronics_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), electronics_id, 'Mobile Phones', 'mobile-phones', 1)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO mobiles_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), electronics_id, 'Laptops & PCs', 'laptops', 2)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO laptops_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), electronics_id, 'Audio & Accessories', 'audio', 3)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO audio_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), NULL, 'Fashion & Lifestyle', 'fashion', 1)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO fashion_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), fashion_id, 'Menswear', 'mens-fashion', 0)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO mens_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), fashion_id, 'Womenswear', 'womens-fashion', 1)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO womens_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), NULL, 'Home & Living', 'home-living', 2)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO home_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), home_id, 'Kitchen Essentials', 'kitchen', 0)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO kitchen_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), home_id, 'Decor & Lighting', 'decor', 1)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO decor_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), NULL, 'Beauty & Wellness', 'beauty-health', 3)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO beauty_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), beauty_id, 'Skincare Rituals', 'skincare', 0)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO skincare_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), beauty_id, 'Personal Care', 'personal-care', 1)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO personal_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), NULL, 'Grocery & Pantry', 'grocery', 4)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO grocery_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), grocery_id, 'Fresh Produce', 'fresh-produce', 0)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO fresh_id;

  INSERT INTO public.categories (id, parent_id, name, slug, position)
  VALUES (gen_random_uuid(), grocery_id, 'Pantry Staples', 'pantry', 1)
  ON CONFLICT (parent_id, slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO pantry_id;

  -- ---------------------------------------------------------------------------
  -- Shopper addresses
  -- ---------------------------------------------------------------------------
  SELECT id INTO shopper_ayla_addr
  FROM public.addresses
  WHERE user_id = shopper_ayla AND label = 'Ayla - Weibdeh Apartment'
  LIMIT 1;
  IF shopper_ayla_addr IS NULL THEN
    INSERT INTO public.addresses (id, user_id, label, line1, city, country, latitude, longitude, is_default)
    VALUES (gen_random_uuid(), shopper_ayla, 'Ayla - Weibdeh Apartment', 'Rainbow St 12', 'Amman', 'Jordan', 31.9515, 35.9231, true)
    RETURNING id INTO shopper_ayla_addr;
  END IF;

  SELECT id INTO shopper_sami_addr
  FROM public.addresses
  WHERE user_id = shopper_sami AND label = 'Sami - Abdoun Loft'
  LIMIT 1;
  IF shopper_sami_addr IS NULL THEN
    INSERT INTO public.addresses (id, user_id, label, line1, city, country, latitude, longitude, is_default)
    VALUES (gen_random_uuid(), shopper_sami, 'Sami - Abdoun Loft', 'Abdoun Circle 3', 'Amman', 'Jordan', 31.9497, 35.9019, true)
    RETURNING id INTO shopper_sami_addr;
  END IF;

  SELECT id INTO shopper_nour_addr
  FROM public.addresses
  WHERE user_id = shopper_nour AND label = 'Nour - Irbid Family Home'
  LIMIT 1;
  IF shopper_nour_addr IS NULL THEN
    INSERT INTO public.addresses (id, user_id, label, line1, city, country, is_default)
    VALUES (gen_random_uuid(), shopper_nour, 'Nour - Irbid Family Home', 'University St 45', 'Irbid', 'Jordan', true)
    RETURNING id INTO shopper_nour_addr;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Vendors
  -- ---------------------------------------------------------------------------
  INSERT INTO public.vendors (id, owner_user_id, name, slug, description, support_email, support_phone, kyc_status)
  VALUES (
    gen_random_uuid(),
    vendor_owner_faris,
    'Amman Electronics Hub',
    'amman-electronics',
    'Premium gadgets, phones, and laptops curated for Jordanian shoppers.',
    'support@amman-electronics.test',
    '+962700111111',
    'approved'
  )
  ON CONFLICT (slug) DO UPDATE
    SET owner_user_id = EXCLUDED.owner_user_id,
        description = EXCLUDED.description,
        support_email = EXCLUDED.support_email,
        support_phone = EXCLUDED.support_phone,
        kyc_status = EXCLUDED.kyc_status,
        active = true
  RETURNING id INTO vendor_ae;

  INSERT INTO public.vendors (id, owner_user_id, name, slug, description, support_email, support_phone, kyc_status)
  VALUES (
    gen_random_uuid(),
    vendor_owner_lina,
    'Desert Threads Collective',
    'desert-threads',
    'Independent designers modernizing traditional Jordanian garments.',
    'help@desert-threads.test',
    '+962700222222',
    'approved'
  )
  ON CONFLICT (slug) DO UPDATE
    SET owner_user_id = EXCLUDED.owner_user_id,
        description = EXCLUDED.description,
        support_email = EXCLUDED.support_email,
        support_phone = EXCLUDED.support_phone,
        kyc_status = EXCLUDED.kyc_status,
        active = true
  RETURNING id INTO vendor_dt;

  INSERT INTO public.vendors (id, owner_user_id, name, slug, description, support_email, support_phone, kyc_status)
  VALUES (
    gen_random_uuid(),
    vendor_owner_hassan,
    'Green Basket Cooperative',
    'green-basket',
    'Farmer-owned marketplace for produce and artisan pantry goods.',
    'fresh@green-basket.test',
    '+962700333333',
    'approved'
  )
  ON CONFLICT (slug) DO UPDATE
    SET owner_user_id = EXCLUDED.owner_user_id,
        description = EXCLUDED.description,
        support_email = EXCLUDED.support_email,
        support_phone = EXCLUDED.support_phone,
        kyc_status = EXCLUDED.kyc_status,
        active = true
  RETURNING id INTO vendor_gb;

  INSERT INTO public.vendors (id, owner_user_id, name, slug, description, support_email, support_phone, kyc_status)
  VALUES (
    gen_random_uuid(),
    vendor_owner_lina,
    'Radiant Glow Studio',
    'radiant-glow',
    'Dead Sea inspired skincare lab with sustainable sourcing.',
    'care@radiant-glow.test',
    '+962700444444',
    'approved'
  )
  ON CONFLICT (slug) DO UPDATE
    SET owner_user_id = EXCLUDED.owner_user_id,
        description = EXCLUDED.description,
        support_email = EXCLUDED.support_email,
        support_phone = EXCLUDED.support_phone,
        kyc_status = EXCLUDED.kyc_status,
        active = true
  RETURNING id INTO vendor_rg;

  -- Vendor staff assignments
  INSERT INTO public.vendor_staff (vendor_id, user_id, role)
  VALUES
    (vendor_ae, vendor_staff_mira, 'manager'),
    (vendor_dt, vendor_staff_omar, 'operations'),
    (vendor_gb, vendor_staff_mira, 'inventory'),
    (vendor_rg, vendor_staff_omar, 'marketing')
  ON CONFLICT (vendor_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- Vendor-scoped user roles
  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_owner_faris::uuid, 'vendor_owner'::public.user_role, vendor_ae::uuid
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = vendor_owner_faris AND ur.role = 'vendor_owner' AND ur.vendor_id = vendor_ae
  );
  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_owner_lina::uuid, 'vendor_owner'::public.user_role, vendor_dt::uuid
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = vendor_owner_lina AND ur.role = 'vendor_owner' AND ur.vendor_id = vendor_dt
  );
  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_owner_hassan::uuid, 'vendor_owner'::public.user_role, vendor_gb::uuid
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = vendor_owner_hassan AND ur.role = 'vendor_owner' AND ur.vendor_id = vendor_gb
  );
  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_owner_lina::uuid, 'vendor_owner'::public.user_role, vendor_rg::uuid
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = vendor_owner_lina AND ur.role = 'vendor_owner' AND ur.vendor_id = vendor_rg
  );
  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_staff_mira::uuid, 'vendor_staff'::public.user_role, vendor_ae::uuid
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = vendor_staff_mira AND ur.role = 'vendor_staff' AND ur.vendor_id = vendor_ae
  );
  INSERT INTO public.user_roles (user_id, role, vendor_id)
  SELECT vendor_staff_omar::uuid, 'vendor_staff'::public.user_role, vendor_dt::uuid
  WHERE NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = vendor_staff_omar AND ur.role = 'vendor_staff' AND ur.vendor_id = vendor_dt
  );

  -- Vendor addresses
  SELECT id INTO vendor_ae_addr
  FROM public.addresses
  WHERE vendor_id = vendor_ae AND label = 'Amman Electronics HQ'
  LIMIT 1;
  IF vendor_ae_addr IS NULL THEN
    INSERT INTO public.addresses (id, vendor_id, label, line1, city, country, latitude, longitude, is_default)
    VALUES (gen_random_uuid(), vendor_ae, 'Amman Electronics HQ', 'Abdali Boulevard 5', 'Amman', 'Jordan', 31.9631, 35.9102, true)
    RETURNING id INTO vendor_ae_addr;
  END IF;
  UPDATE public.vendors SET address_id = vendor_ae_addr WHERE id = vendor_ae;

  SELECT id INTO vendor_dt_addr
  FROM public.addresses
  WHERE vendor_id = vendor_dt AND label = 'Desert Threads Atelier'
  LIMIT 1;
  IF vendor_dt_addr IS NULL THEN
    INSERT INTO public.addresses (id, vendor_id, label, line1, city, country, is_default)
    VALUES (gen_random_uuid(), vendor_dt, 'Desert Threads Atelier', 'Jabal Amman 3rd Circle', 'Amman', 'Jordan', true)
    RETURNING id INTO vendor_dt_addr;
  END IF;
  UPDATE public.vendors SET address_id = vendor_dt_addr WHERE id = vendor_dt;

  SELECT id INTO vendor_gb_addr
  FROM public.addresses
  WHERE vendor_id = vendor_gb AND label = 'Green Basket Packing House'
  LIMIT 1;
  IF vendor_gb_addr IS NULL THEN
    INSERT INTO public.addresses (id, vendor_id, label, line1, city, country, is_default)
    VALUES (gen_random_uuid(), vendor_gb, 'Green Basket Packing House', 'Madaba Hwy KM 8', 'Madaba', 'Jordan', true)
    RETURNING id INTO vendor_gb_addr;
  END IF;
  UPDATE public.vendors SET address_id = vendor_gb_addr WHERE id = vendor_gb;

  SELECT id INTO vendor_rg_addr
  FROM public.addresses
  WHERE vendor_id = vendor_rg AND label = 'Radiant Glow Lab'
  LIMIT 1;
  IF vendor_rg_addr IS NULL THEN
    INSERT INTO public.addresses (id, vendor_id, label, line1, city, country, is_default)
    VALUES (gen_random_uuid(), vendor_rg, 'Radiant Glow Lab', 'King Hussein Business Park', 'Amman', 'Jordan', true)
    RETURNING id INTO vendor_rg_addr;
  END IF;
  UPDATE public.vendors SET address_id = vendor_rg_addr WHERE id = vendor_rg;

  -- Warehouses
  SELECT id INTO warehouse_ae_city
  FROM public.warehouses
  WHERE vendor_id = vendor_ae AND name = 'AE - City Fulfillment'
  LIMIT 1;
  IF warehouse_ae_city IS NULL THEN
    INSERT INTO public.warehouses (id, vendor_id, name, address_id, active)
    VALUES (gen_random_uuid(), vendor_ae, 'AE - City Fulfillment', vendor_ae_addr, true)
    RETURNING id INTO warehouse_ae_city;
  END IF;

  SELECT id INTO warehouse_ae_north
  FROM public.warehouses
  WHERE vendor_id = vendor_ae AND name = 'AE - North Hub'
  LIMIT 1;
  IF warehouse_ae_north IS NULL THEN
    INSERT INTO public.warehouses (id, vendor_id, name, address_id, active)
    VALUES (gen_random_uuid(), vendor_ae, 'AE - North Hub', vendor_ae_addr, true)
    RETURNING id INTO warehouse_ae_north;
  END IF;

  SELECT id INTO warehouse_dt
  FROM public.warehouses
  WHERE vendor_id = vendor_dt AND name = 'DT - Atelier Stock'
  LIMIT 1;
  IF warehouse_dt IS NULL THEN
    INSERT INTO public.warehouses (id, vendor_id, name, address_id, active)
    VALUES (gen_random_uuid(), vendor_dt, 'DT - Atelier Stock', vendor_dt_addr, true)
    RETURNING id INTO warehouse_dt;
  END IF;

  SELECT id INTO warehouse_gb
  FROM public.warehouses
  WHERE vendor_id = vendor_gb AND name = 'GB - Cold Chain'
  LIMIT 1;
  IF warehouse_gb IS NULL THEN
    INSERT INTO public.warehouses (id, vendor_id, name, address_id, active)
    VALUES (gen_random_uuid(), vendor_gb, 'GB - Cold Chain', vendor_gb_addr, true)
    RETURNING id INTO warehouse_gb;
  END IF;

  SELECT id INTO warehouse_rg
  FROM public.warehouses
  WHERE vendor_id = vendor_rg AND name = 'RG - Lab Inventory'
  LIMIT 1;
  IF warehouse_rg IS NULL THEN
    INSERT INTO public.warehouses (id, vendor_id, name, address_id, active)
    VALUES (gen_random_uuid(), vendor_rg, 'RG - Lab Inventory', vendor_rg_addr, true)
    RETURNING id INTO warehouse_rg;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Products, variants, and images
  -- ---------------------------------------------------------------------------
  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, status, has_variants, base_sku, base_price_cents, currency)
  VALUES (
    gen_random_uuid(),
    vendor_ae,
    mobiles_id,
    'Falcon X Pro',
    'falcon-x-pro',
    'Flagship smartphone with 120Hz AMOLED display and 5G modem.',
    'active',
    true,
    'FALCON-X',
    54900,
    'JOD'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE
    SET description = EXCLUDED.description,
        status = EXCLUDED.status,
        has_variants = EXCLUDED.has_variants,
        base_price_cents = EXCLUDED.base_price_cents
  RETURNING id INTO product_falcon;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_falcon, 'FALCON-X-128', jsonb_build_object('storage', '128GB', 'color', 'Obsidian'), 49900, 20)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_falcon_128;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_falcon, 'FALCON-X-256', jsonb_build_object('storage', '256GB', 'color', 'Aurora'), 54900, 15)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_falcon_256;

  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, status, has_variants, base_sku, base_price_cents, currency)
  VALUES (
    gen_random_uuid(),
    vendor_ae,
    laptops_id,
    'WadiBook Slim 14',
    'wadi-slim-14',
    'Ultra-light laptop tuned for bilingual creators with 18h battery life.',
    'active',
    true,
    'WADI14',
    91500,
    'JOD'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE
    SET description = EXCLUDED.description,
        status = EXCLUDED.status,
        has_variants = EXCLUDED.has_variants,
        base_price_cents = EXCLUDED.base_price_cents
  RETURNING id INTO product_wadi_laptop;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_wadi_laptop, 'WADI14-I5', jsonb_build_object('cpu', 'i5', 'ram', '16GB'), 79900, 12)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_wadi_i5;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_wadi_laptop, 'WADI14-I7', jsonb_build_object('cpu', 'i7', 'ram', '32GB'), 91500, 8)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_wadi_i7;

  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, status, has_variants, base_sku, base_price_cents, currency)
  VALUES (
    gen_random_uuid(),
    vendor_dt,
    mens_id,
    'Heritage Embroidered Thobe',
    'heritage-thobe',
    'Hand-finished thobe with modern tailored fit and breathable cotton.',
    'active',
    true,
    'THB-HERITAGE',
    6800,
    'JOD'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE
    SET description = EXCLUDED.description,
        status = EXCLUDED.status,
        has_variants = EXCLUDED.has_variants,
        base_price_cents = EXCLUDED.base_price_cents
  RETURNING id INTO product_thobe;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_thobe, 'THB-S', jsonb_build_object('size', 'S'), 6500, 10)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_thobe_s;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_thobe, 'THB-M', jsonb_build_object('size', 'M'), 6800, 8)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_thobe_m;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_thobe, 'THB-L', jsonb_build_object('size', 'L'), 7000, 6)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_thobe_l;

  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, status, has_variants, base_sku, base_price_cents, currency)
  VALUES (
    gen_random_uuid(),
    vendor_dt,
    womens_id,
    'Sunset Linen Wrap Dress',
    'sunset-linen-dress',
    'Soft linen dress dyed with natural pigments from Petra sandstones.',
    'active',
    true,
    'DRS-SUNSET',
    6200,
    'JOD'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE
    SET description = EXCLUDED.description,
        status = EXCLUDED.status,
        has_variants = EXCLUDED.has_variants,
        base_price_cents = EXCLUDED.base_price_cents
  RETURNING id INTO product_dress;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_dress, 'DRS-S', jsonb_build_object('size', 'S'), 5900, 7)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_dress_s;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_dress, 'DRS-M', jsonb_build_object('size', 'M'), 6200, 5)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_dress_m;

  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, status, has_variants, base_sku, base_price_cents, currency)
  VALUES (
    gen_random_uuid(),
    vendor_gb,
    fresh_id,
    'Valley Organic Tomatoes (1kg)',
    'organic-tomatoes',
    'Picked pre-dawn from Jerash valley farms, delivered same day.',
    'active',
    false,
    'GB-TOM-1KG',
    350,
    'JOD'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE
    SET description = EXCLUDED.description,
        status = EXCLUDED.status,
        has_variants = EXCLUDED.has_variants,
        base_price_cents = EXCLUDED.base_price_cents
  RETURNING id INTO product_tomatoes;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_tomatoes, 'GB-TOM-1KG', jsonb_build_object('weight', '1kg'), 350, 45)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_tomatoes_1kg;

  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, status, has_variants, base_sku, base_price_cents, currency)
  VALUES (
    gen_random_uuid(),
    vendor_gb,
    pantry_id,
    'Bedouin Desert Honey (500g)',
    'desert-honey',
    'Wildflower honey collected near Wadi Rum dunes, cold-filtered.',
    'active',
    false,
    'GB-HNY-500',
    1150,
    'JOD'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE
    SET description = EXCLUDED.description,
        status = EXCLUDED.status,
        has_variants = EXCLUDED.has_variants,
        base_price_cents = EXCLUDED.base_price_cents
  RETURNING id INTO product_honey;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_honey, 'GB-HNY-500', jsonb_build_object('weight', '500g'), 1150, 25)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_honey_500;

  INSERT INTO public.products (id, vendor_id, category_id, name, slug, description, status, has_variants, base_sku, base_price_cents, currency)
  VALUES (
    gen_random_uuid(),
    vendor_rg,
    skincare_id,
    'Dead Sea Clay Reset Mask',
    'dead-sea-clay-mask',
    'Concentrated detox mask infused with chamomile steam distillate.',
    'active',
    true,
    'RG-CLAY',
    3200,
    'JOD'
  )
  ON CONFLICT (vendor_id, slug) DO UPDATE
    SET description = EXCLUDED.description,
        status = EXCLUDED.status,
        has_variants = EXCLUDED.has_variants,
        base_price_cents = EXCLUDED.base_price_cents
  RETURNING id INTO product_mask;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_mask, 'RG-CLAY-100', jsonb_build_object('size', '100ml'), 2200, 30)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_mask_100;

  INSERT INTO public.product_variants (id, product_id, sku, attributes, price_cents, stock)
  VALUES (gen_random_uuid(), product_mask, 'RG-CLAY-200', jsonb_build_object('size', '200ml'), 3200, 18)
  ON CONFLICT (product_id, sku) DO UPDATE
    SET attributes = EXCLUDED.attributes,
        price_cents = EXCLUDED.price_cents,
        stock = EXCLUDED.stock
  RETURNING id INTO variant_mask_200;

  -- Product imagery (storage paths mimic Supabase storage)
  INSERT INTO public.product_images (id, product_id, storage_path, position)
  SELECT gen_random_uuid(), prod, path, pos
  FROM (VALUES
    (product_falcon, 'public/products/falcon-x-pro/front.png', 0),
    (product_wadi_laptop, 'public/products/wadi-slim-14/hero.png', 0),
    (product_thobe, 'public/products/heritage-thobe/look1.png', 0),
    (product_dress, 'public/products/sunset-linen-dress/flat.png', 0),
    (product_tomatoes, 'public/products/organic-tomatoes/crate.png', 0),
    (product_honey, 'public/products/desert-honey/jar.png', 0),
    (product_mask, 'public/products/dead-sea-clay-mask/jar.png', 0)
  ) AS img(prod, path, pos)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.product_images pi
    WHERE pi.product_id = img.prod
      AND pi.storage_path = img.path
  );

  -- ---------------------------------------------------------------------------
  -- Inventory snapshot (per variant per warehouse)
  -- ---------------------------------------------------------------------------
  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_falcon_128 AND warehouse_id = warehouse_ae_city
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_falcon_128, warehouse_ae_city, 24, 3, 5)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 24, reserved = 3, safety_stock = 5, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_falcon_256 AND warehouse_id = warehouse_ae_city
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_falcon_256, warehouse_ae_city, 15, 2, 4)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 15, reserved = 2, safety_stock = 4, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_wadi_i5 AND warehouse_id = warehouse_ae_north
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_wadi_i5, warehouse_ae_north, 12, 1, 3)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 12, reserved = 1, safety_stock = 3, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_wadi_i7 AND warehouse_id = warehouse_ae_city
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_wadi_i7, warehouse_ae_city, 8, 1, 2)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 8, reserved = 1, safety_stock = 2, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_thobe_s AND warehouse_id = warehouse_dt
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_thobe_s, warehouse_dt, 10, 1, 2)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 10, reserved = 1, safety_stock = 2, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_thobe_m AND warehouse_id = warehouse_dt
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_thobe_m, warehouse_dt, 8, 2, 2)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 8, reserved = 2, safety_stock = 2, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_thobe_l AND warehouse_id = warehouse_dt
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_thobe_l, warehouse_dt, 6, 1, 1)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 6, reserved = 1, safety_stock = 1, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_dress_s AND warehouse_id = warehouse_dt
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_dress_s, warehouse_dt, 7, 1, 1)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 7, reserved = 1, safety_stock = 1, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_dress_m AND warehouse_id = warehouse_dt
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_dress_m, warehouse_dt, 5, 1, 1)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 5, reserved = 1, safety_stock = 1, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_tomatoes_1kg AND warehouse_id = warehouse_gb
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_tomatoes_1kg, warehouse_gb, 45, 5, 6)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 45, reserved = 5, safety_stock = 6, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_honey_500 AND warehouse_id = warehouse_gb
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_honey_500, warehouse_gb, 25, 2, 3)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 25, reserved = 2, safety_stock = 3, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_mask_100 AND warehouse_id = warehouse_rg
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_mask_100, warehouse_rg, 30, 4, 4)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 30, reserved = 4, safety_stock = 4, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  tmp_id := NULL;
  SELECT id INTO tmp_id
  FROM public.inventory
  WHERE variant_id = variant_mask_200 AND warehouse_id = warehouse_rg
  LIMIT 1;
  IF tmp_id IS NULL THEN
    INSERT INTO public.inventory (id, variant_id, warehouse_id, stock, reserved, safety_stock)
    VALUES (gen_random_uuid(), variant_mask_200, warehouse_rg, 18, 2, 3)
    RETURNING id INTO tmp_id;
  ELSE
    UPDATE public.inventory
    SET stock = 18, reserved = 2, safety_stock = 3, updated_at = now()
    WHERE id = tmp_id;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Coupons
  -- ---------------------------------------------------------------------------
  INSERT INTO public.coupons (id, code, discount_type, discount_value, vendor_id, starts_at, ends_at, metadata)
  VALUES (
    gen_random_uuid(),
    'WELCOME10',
    'percent',
    10.0,
    NULL,
    now() - interval '30 days',
    now() + interval '90 days',
    jsonb_build_object('channel', 'app_launch')
  )
  ON CONFLICT (code) DO UPDATE
    SET discount_type = EXCLUDED.discount_type,
        discount_value = EXCLUDED.discount_value,
        vendor_id = EXCLUDED.vendor_id,
        starts_at = EXCLUDED.starts_at,
        ends_at = EXCLUDED.ends_at,
        metadata = EXCLUDED.metadata
  RETURNING id INTO coupon_welcome;

  INSERT INTO public.coupons (id, code, discount_type, discount_value, vendor_id, starts_at, ends_at, metadata)
  VALUES (
    gen_random_uuid(),
    'GREENFRESH5',
    'fixed',
    5.00,
    vendor_gb,
    now() - interval '15 days',
    now() + interval '45 days',
    jsonb_build_object('minimum_cart', 1500)
  )
  ON CONFLICT (code) DO UPDATE
    SET discount_type = EXCLUDED.discount_type,
        discount_value = EXCLUDED.discount_value,
        vendor_id = EXCLUDED.vendor_id,
        starts_at = EXCLUDED.starts_at,
        ends_at = EXCLUDED.ends_at,
        metadata = EXCLUDED.metadata
  RETURNING id INTO coupon_green;

  -- ---------------------------------------------------------------------------
  -- Shopper carts and favorites
  -- ---------------------------------------------------------------------------
  SELECT id INTO cart_ayla FROM public.carts WHERE user_id = shopper_ayla AND status = 'active' LIMIT 1;
  IF cart_ayla IS NULL THEN
    INSERT INTO public.carts (id, user_id, status) VALUES (gen_random_uuid(), shopper_ayla, 'active')
    RETURNING id INTO cart_ayla;
  END IF;

  SELECT id INTO cart_sami FROM public.carts WHERE user_id = shopper_sami AND status = 'active' LIMIT 1;
  IF cart_sami IS NULL THEN
    INSERT INTO public.carts (id, user_id, status) VALUES (gen_random_uuid(), shopper_sami, 'active')
    RETURNING id INTO cart_sami;
  END IF;

  SELECT id INTO cart_nour FROM public.carts WHERE user_id = shopper_nour AND status = 'active' LIMIT 1;
  IF cart_nour IS NULL THEN
    INSERT INTO public.carts (id, user_id, status) VALUES (gen_random_uuid(), shopper_nour, 'active')
    RETURNING id INTO cart_nour;
  END IF;

  INSERT INTO public.cart_items (id, cart_id, product_id, variant_id, quantity, unit_price_cents, currency)
  SELECT gen_random_uuid(), cart_ayla, product_falcon, variant_falcon_256, 1, 54900, 'JOD'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.cart_items
    WHERE cart_id = cart_ayla AND variant_id = variant_falcon_256
  );

  INSERT INTO public.cart_items (id, cart_id, product_id, variant_id, quantity, unit_price_cents, currency)
  SELECT gen_random_uuid(), cart_ayla, product_mask, variant_mask_100, 2, 2200, 'JOD'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.cart_items
    WHERE cart_id = cart_ayla AND variant_id = variant_mask_100
  );

  INSERT INTO public.cart_items (id, cart_id, product_id, variant_id, quantity, unit_price_cents, currency)
  SELECT gen_random_uuid(), cart_sami, product_dress, variant_dress_m, 1, 6200, 'JOD'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.cart_items
    WHERE cart_id = cart_sami AND variant_id = variant_dress_m
  );

  INSERT INTO public.cart_items (id, cart_id, product_id, variant_id, quantity, unit_price_cents, currency)
  SELECT gen_random_uuid(), cart_nour, product_tomatoes, variant_tomatoes_1kg, 2, 350, 'JOD'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.cart_items
    WHERE cart_id = cart_nour AND variant_id = variant_tomatoes_1kg
  );

  INSERT INTO public.favorites (user_id, product_id)
  VALUES
    (shopper_ayla, product_wadi_laptop),
    (shopper_ayla, product_mask),
    (shopper_sami, product_thobe),
    (shopper_nour, product_honey),
    (shopper_nour, product_falcon)
  ON CONFLICT (user_id, product_id) DO NOTHING;

  -- ---------------------------------------------------------------------------
  -- Orders, order items, and coupons
  -- ---------------------------------------------------------------------------
  SELECT id INTO order_one
  FROM public.orders
  WHERE user_id = shopper_ayla AND notes = 'Tech + beauty bundle demo order'
  LIMIT 1;
  IF order_one IS NULL THEN
    INSERT INTO public.orders (
      id, user_id, status, subtotal_cents, discount_cents, shipping_cents, tax_cents, total_cents,
      currency, shipping_address_id, billing_address_id, notes
    )
    VALUES (
      gen_random_uuid(), shopper_ayla, 'confirmed', 57100, 5710, 400, 800, 52590,
      'JOD', shopper_ayla_addr, shopper_ayla_addr, 'Tech + beauty bundle demo order'
    )
    RETURNING id INTO order_one;
  ELSE
    UPDATE public.orders
    SET status = 'confirmed',
        subtotal_cents = 57100,
        discount_cents = 5710,
        shipping_cents = 400,
        tax_cents = 800,
        total_cents = 52590,
        shipping_address_id = shopper_ayla_addr,
        billing_address_id = shopper_ayla_addr,
        updated_at = now()
    WHERE id = order_one;
  END IF;

  SELECT id INTO order_two
  FROM public.orders
  WHERE user_id = shopper_sami AND notes = 'Wardrobe refresh demo order'
  LIMIT 1;
  IF order_two IS NULL THEN
    INSERT INTO public.orders (
      id, user_id, status, subtotal_cents, discount_cents, shipping_cents, tax_cents, total_cents,
      currency, shipping_address_id, billing_address_id, notes
    )
    VALUES (
      gen_random_uuid(), shopper_sami, 'packed', 12700, 0, 300, 254, 13254,
      'JOD', shopper_sami_addr, shopper_sami_addr, 'Wardrobe refresh demo order'
    )
    RETURNING id INTO order_two;
  ELSE
    UPDATE public.orders
    SET status = 'packed',
        subtotal_cents = 12700,
        discount_cents = 0,
        shipping_cents = 300,
        tax_cents = 254,
        total_cents = 13254,
        shipping_address_id = shopper_sami_addr,
        billing_address_id = shopper_sami_addr,
        updated_at = now()
    WHERE id = order_two;
  END IF;

  SELECT id INTO order_three
  FROM public.orders
  WHERE user_id = shopper_nour AND notes = 'Weekly pantry demo order'
  LIMIT 1;
  IF order_three IS NULL THEN
    INSERT INTO public.orders (
      id, user_id, status, subtotal_cents, discount_cents, shipping_cents, tax_cents, total_cents,
      currency, shipping_address_id, billing_address_id, notes
    )
    VALUES (
      gen_random_uuid(), shopper_nour, 'delivered', 1850, 500, 250, 90, 1690,
      'JOD', shopper_nour_addr, shopper_nour_addr, 'Weekly pantry demo order'
    )
    RETURNING id INTO order_three;
  ELSE
    UPDATE public.orders
    SET status = 'delivered',
        subtotal_cents = 1850,
        discount_cents = 500,
        shipping_cents = 250,
        tax_cents = 90,
        total_cents = 1690,
        shipping_address_id = shopper_nour_addr,
        billing_address_id = shopper_nour_addr,
        updated_at = now()
    WHERE id = order_three;
  END IF;

  INSERT INTO public.order_items (id, order_id, vendor_id, product_id, variant_id, name, sku, quantity, unit_price_cents)
  SELECT gen_random_uuid(), order_one, vendor_ae, product_falcon, variant_falcon_256, 'Falcon X Pro', 'FALCON-X-256', 1, 54900
  WHERE NOT EXISTS (
    SELECT 1 FROM public.order_items WHERE order_id = order_one AND sku = 'FALCON-X-256'
  );

  INSERT INTO public.order_items (id, order_id, vendor_id, product_id, variant_id, name, sku, quantity, unit_price_cents)
  SELECT gen_random_uuid(), order_one, vendor_rg, product_mask, variant_mask_100, 'Dead Sea Clay Reset Mask', 'RG-CLAY-100', 1, 2200
  WHERE NOT EXISTS (
    SELECT 1 FROM public.order_items WHERE order_id = order_one AND sku = 'RG-CLAY-100'
  );

  INSERT INTO public.order_items (id, order_id, vendor_id, product_id, variant_id, name, sku, quantity, unit_price_cents)
  SELECT gen_random_uuid(), order_two, vendor_dt, product_thobe, variant_thobe_m, 'Heritage Embroidered Thobe', 'THB-M', 1, 6800
  WHERE NOT EXISTS (
    SELECT 1 FROM public.order_items WHERE order_id = order_two AND sku = 'THB-M'
  );

  INSERT INTO public.order_items (id, order_id, vendor_id, product_id, variant_id, name, sku, quantity, unit_price_cents)
  SELECT gen_random_uuid(), order_two, vendor_dt, product_dress, variant_dress_s, 'Sunset Linen Wrap Dress', 'DRS-S', 1, 5900
  WHERE NOT EXISTS (
    SELECT 1 FROM public.order_items WHERE order_id = order_two AND sku = 'DRS-S'
  );

  INSERT INTO public.order_items (id, order_id, vendor_id, product_id, variant_id, name, sku, quantity, unit_price_cents)
  SELECT gen_random_uuid(), order_three, vendor_gb, product_tomatoes, variant_tomatoes_1kg, 'Valley Organic Tomatoes (1kg)', 'GB-TOM-1KG', 2, 350
  WHERE NOT EXISTS (
    SELECT 1 FROM public.order_items WHERE order_id = order_three AND sku = 'GB-TOM-1KG'
  );

  INSERT INTO public.order_items (id, order_id, vendor_id, product_id, variant_id, name, sku, quantity, unit_price_cents)
  SELECT gen_random_uuid(), order_three, vendor_gb, product_honey, variant_honey_500, 'Bedouin Desert Honey (500g)', 'GB-HNY-500', 1, 1150
  WHERE NOT EXISTS (
    SELECT 1 FROM public.order_items WHERE order_id = order_three AND sku = 'GB-HNY-500'
  );

  INSERT INTO public.order_coupons (order_id, coupon_id, amount_cents)
  VALUES (order_one, coupon_welcome, 5710)
  ON CONFLICT (order_id, coupon_id) DO UPDATE SET amount_cents = EXCLUDED.amount_cents;

  INSERT INTO public.order_coupons (order_id, coupon_id, amount_cents)
  VALUES (order_three, coupon_green, 500)
  ON CONFLICT (order_id, coupon_id) DO UPDATE SET amount_cents = EXCLUDED.amount_cents;

  -- ---------------------------------------------------------------------------
  -- Payments and transactions
  -- ---------------------------------------------------------------------------
  INSERT INTO public.payments (id, order_id, provider, provider_ref, status, amount_cents, currency)
  SELECT gen_random_uuid(), order_one, 'tap_pay', 'PAY-DEMO-001', 'paid', 52590, 'JOD'
  WHERE NOT EXISTS (SELECT 1 FROM public.payments WHERE provider_ref = 'PAY-DEMO-001');

  INSERT INTO public.payments (id, order_id, provider, provider_ref, status, amount_cents, currency)
  SELECT gen_random_uuid(), order_two, 'tap_pay', 'PAY-DEMO-002', 'paid', 13254, 'JOD'
  WHERE NOT EXISTS (SELECT 1 FROM public.payments WHERE provider_ref = 'PAY-DEMO-002');

  INSERT INTO public.payments (id, order_id, provider, provider_ref, status, amount_cents, currency)
  SELECT gen_random_uuid(), order_three, 'cod', 'PAY-DEMO-003', 'paid', 1690, 'JOD'
  WHERE NOT EXISTS (SELECT 1 FROM public.payments WHERE provider_ref = 'PAY-DEMO-003');

  INSERT INTO public.transactions (id, related_payment_id, order_id, type, provider, provider_ref, amount_cents, currency, metadata)
  SELECT gen_random_uuid(), p.id, p.order_id, 'charge', p.provider, p.provider_ref, p.amount_cents, p.currency, jsonb_build_object('channel', 'demo-seed')
  FROM public.payments p
  WHERE p.provider_ref IN ('PAY-DEMO-001', 'PAY-DEMO-002', 'PAY-DEMO-003')
    AND NOT EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.related_payment_id = p.id AND t.type = 'charge'
    );

  -- ---------------------------------------------------------------------------
  -- Delivery provider, staff, shipments, and assignments
  -- ---------------------------------------------------------------------------
  SELECT id INTO provider_cityswift
  FROM public.delivery_providers
  WHERE name = 'CitySwift Couriers'
  LIMIT 1;
  IF provider_cityswift IS NULL THEN
    INSERT INTO public.delivery_providers (id, owner_user_id, name, provider_type, phone, email, active)
    VALUES (
      gen_random_uuid(),
      delivery_sara,
      'CitySwift Couriers',
      'company',
      '+962790000555',
      'ops@cityswift.test',
      true
    )
    RETURNING id INTO provider_cityswift;
  END IF;

  SELECT id INTO delivery_staff_sara
  FROM public.delivery_staff
  WHERE user_id = delivery_sara
  LIMIT 1;
  IF delivery_staff_sara IS NULL THEN
    INSERT INTO public.delivery_staff (id, user_id, provider_id, active, is_available, max_concurrent_jobs, vehicle_type)
    VALUES (
      gen_random_uuid(),
      delivery_sara,
      provider_cityswift,
      true,
      true,
      4,
      'car'
    )
    RETURNING id INTO delivery_staff_sara;
  ELSE
    UPDATE public.delivery_staff
    SET provider_id = provider_cityswift,
        active = true,
        is_available = true,
        max_concurrent_jobs = 4,
        vehicle_type = 'car'
    WHERE id = delivery_staff_sara;
  END IF;

  SELECT id INTO shipment_order_one_ae
  FROM public.shipments
  WHERE order_id = order_one AND vendor_id = vendor_ae
  LIMIT 1;
  IF shipment_order_one_ae IS NULL THEN
    INSERT INTO public.shipments (id, order_id, vendor_id, status, tracking_number, shipping_address_id, visibility, posted_at, accepted_by_staff_id, accepted_at)
    VALUES (
      gen_random_uuid(), order_one, vendor_ae, 'in_transit', 'JMK-AE-1001', shopper_ayla_addr, 'marketplace',
      now() - interval '2 days', delivery_staff_sara, now() - interval '1 day'
    )
    RETURNING id INTO shipment_order_one_ae;
  ELSE
    UPDATE public.shipments
    SET status = 'in_transit',
        tracking_number = 'JMK-AE-1001',
        shipping_address_id = shopper_ayla_addr,
        visibility = 'marketplace',
        accepted_by_staff_id = delivery_staff_sara,
        accepted_at = now() - interval '1 day',
        posted_at = now() - interval '2 days',
        updated_at = now()
    WHERE id = shipment_order_one_ae;
  END IF;

  SELECT id INTO shipment_order_one_rg
  FROM public.shipments
  WHERE order_id = order_one AND vendor_id = vendor_rg
  LIMIT 1;
  IF shipment_order_one_rg IS NULL THEN
    INSERT INTO public.shipments (id, order_id, vendor_id, status, tracking_number, shipping_address_id, visibility)
    VALUES (
      gen_random_uuid(), order_one, vendor_rg, 'pending', 'JMK-RG-2001', shopper_ayla_addr, 'marketplace'
    )
    RETURNING id INTO shipment_order_one_rg;
  ELSE
    UPDATE public.shipments
    SET status = 'pending',
        tracking_number = 'JMK-RG-2001',
        shipping_address_id = shopper_ayla_addr,
        visibility = 'marketplace',
        updated_at = now()
    WHERE id = shipment_order_one_rg;
  END IF;

  SELECT id INTO shipment_order_two
  FROM public.shipments
  WHERE order_id = order_two AND vendor_id = vendor_dt
  LIMIT 1;
  IF shipment_order_two IS NULL THEN
    INSERT INTO public.shipments (id, order_id, vendor_id, status, tracking_number, shipping_address_id, visibility, posted_at)
    VALUES (
      gen_random_uuid(), order_two, vendor_dt, 'pending', 'JMK-DT-3001', shopper_sami_addr, 'marketplace', now() - interval '1 day'
    )
    RETURNING id INTO shipment_order_two;
  ELSE
    UPDATE public.shipments
    SET status = 'pending',
        tracking_number = 'JMK-DT-3001',
        shipping_address_id = shopper_sami_addr,
        visibility = 'marketplace',
        posted_at = now() - interval '1 day',
        updated_at = now()
    WHERE id = shipment_order_two;
  END IF;

  SELECT id INTO shipment_order_three
  FROM public.shipments
  WHERE order_id = order_three AND vendor_id = vendor_gb
  LIMIT 1;
  IF shipment_order_three IS NULL THEN
    INSERT INTO public.shipments (id, order_id, vendor_id, status, tracking_number, shipping_address_id, visibility, posted_at, delivered_at)
    VALUES (
      gen_random_uuid(), order_three, vendor_gb, 'delivered', 'JMK-GB-4001', shopper_nour_addr, 'marketplace',
      now() - interval '3 days', now() - interval '1 day'
    )
    RETURNING id INTO shipment_order_three;
  ELSE
    UPDATE public.shipments
    SET status = 'delivered',
        tracking_number = 'JMK-GB-4001',
        shipping_address_id = shopper_nour_addr,
        visibility = 'marketplace',
        posted_at = now() - interval '3 days',
        delivered_at = now() - interval '1 day',
        updated_at = now()
    WHERE id = shipment_order_three;
  END IF;

  INSERT INTO public.delivery_assignments (id, shipment_id, delivery_staff_id, status, assigned_at, picked_up_at)
  SELECT gen_random_uuid(), shipment_order_one_ae, delivery_staff_sara, 'in_transit', now() - interval '1 day', now() - interval '12 hours'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.delivery_assignments
    WHERE shipment_id = shipment_order_one_ae AND delivery_staff_id = delivery_staff_sara
  );

  INSERT INTO public.delivery_assignments (id, shipment_id, delivery_staff_id, status, assigned_at, delivered_at)
  SELECT gen_random_uuid(), shipment_order_three, delivery_staff_sara, 'delivered', now() - interval '2 days', now() - interval '1 day'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.delivery_assignments
    WHERE shipment_id = shipment_order_three AND delivery_staff_id = delivery_staff_sara
  );

  -- ---------------------------------------------------------------------------
  -- Restock queue
  -- ---------------------------------------------------------------------------
  INSERT INTO public.restock_requests (id, vendor_id, warehouse_id, variant_id, qty, status, requested_at)
  SELECT gen_random_uuid(), vendor_gb, warehouse_gb, variant_tomatoes_1kg, 60, 'requested', now() - interval '6 hours'
  WHERE NOT EXISTS (
    SELECT 1 FROM public.restock_requests
    WHERE vendor_id = vendor_gb AND variant_id = variant_tomatoes_1kg AND status = 'requested'
  );

  -- ---------------------------------------------------------------------------
  -- Reviews across entities
  -- ---------------------------------------------------------------------------
  INSERT INTO public.reviews (id, user_id, subject, product_id, overall_rating, aspects, title, body)
  VALUES (
    gen_random_uuid(),
    shopper_ayla,
    'product',
    product_falcon,
    5,
    jsonb_build_object('battery', 5, 'camera', 4),
    'Worth the wait',
    'Smooth animations, stellar battery, and premium feel.'
  )
  ON CONFLICT (user_id, product_id) WHERE product_id IS NOT NULL DO UPDATE
    SET overall_rating = EXCLUDED.overall_rating,
        aspects = EXCLUDED.aspects,
        title = EXCLUDED.title,
        body = EXCLUDED.body;

  INSERT INTO public.reviews (id, user_id, subject, vendor_id, overall_rating, title, body)
  VALUES (
    gen_random_uuid(),
    shopper_sami,
    'vendor',
    vendor_dt,
    5,
    'Tailoring perfection',
    'Measurements were spot on and packaging was elegant.'
  )
  ON CONFLICT (user_id, vendor_id) WHERE vendor_id IS NOT NULL DO UPDATE
    SET overall_rating = EXCLUDED.overall_rating,
        title = EXCLUDED.title,
        body = EXCLUDED.body;

  INSERT INTO public.reviews (id, user_id, subject, delivery_staff_id, overall_rating, title, body)
  VALUES (
    gen_random_uuid(),
    shopper_nour,
    'delivery',
    delivery_staff_sara,
    4,
    'Fast doorstep handoff',
    'Produce arrived chilled and the courier called ahead.'
  )
  ON CONFLICT (user_id, delivery_staff_id) WHERE delivery_staff_id IS NOT NULL DO UPDATE
    SET overall_rating = EXCLUDED.overall_rating,
        title = EXCLUDED.title,
        body = EXCLUDED.body;

  INSERT INTO public.reviews (id, user_id, subject, platform, app_version, overall_rating, title, body)
  VALUES (
    gen_random_uuid(),
    shopper_sami,
    'app',
    'web',
    '1.0.0',
    4,
    'Dashboard already feels alive',
    'App is snappy; would love dark mode next.'
  )
  ON CONFLICT (user_id, platform) WHERE platform IS NOT NULL DO UPDATE
    SET overall_rating = EXCLUDED.overall_rating,
        title = EXCLUDED.title,
        body = EXCLUDED.body;

  RAISE NOTICE 'Rich demo seed complete: vendors %, orders %, shipments %', vendor_ae, order_three, shipment_order_two;
END $$;
