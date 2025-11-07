-- 01_extensions_and_types.sql
-- Create required extensions, enums, sequence used by other table scripts.

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- ENUMS
DO $$ BEGIN
  CREATE TYPE order_status AS ENUM ('pending','confirmed','packed','shipped','delivered','cancelled','refunded');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending','authorized','paid','failed','refunded','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE shipment_status AS ENUM ('pending','assigned','picked_up','in_transit','delivered','failed','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE discount_type AS ENUM ('fixed','percent');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('shopper','vendor_owner','vendor_staff','delivery','admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE product_status AS ENUM ('draft','active','archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE delivery_provider_type AS ENUM ('individual','company');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE job_visibility AS ENUM ('private','marketplace');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE review_subject AS ENUM ('product','vendor','delivery','app');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE app_platform AS ENUM ('ios','android','web');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Sequence used for order numbers
CREATE SEQUENCE IF NOT EXISTS public.order_number_seq;

-- Helper function referenced by default order_number (keeps it here so per-table scripts can run)
CREATE OR REPLACE FUNCTION public.next_order_number()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE seq bigint;
BEGIN
  SELECT nextval('public.order_number_seq') INTO seq;
  RETURN 'JM-' || to_char(now(),'YYYYMMDD') || '-' || lpad(seq::text, 10, '0');
END $$;
-- 01_extensions_and_types.sql
-- Create required extensions, enums, sequence used by other table scripts.

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- ENUMS
DO $$ BEGIN
  CREATE TYPE order_status AS ENUM ('pending','confirmed','packed','shipped','delivered','cancelled','refunded');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending','authorized','paid','failed','refunded','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE shipment_status AS ENUM ('pending','assigned','picked_up','in_transit','delivered','failed','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE discount_type AS ENUM ('fixed','percent');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('shopper','vendor_owner','vendor_staff','delivery','admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE product_status AS ENUM ('draft','active','archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE delivery_provider_type AS ENUM ('individual','company');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE job_visibility AS ENUM ('private','marketplace');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE review_subject AS ENUM ('product','vendor','delivery','app');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE app_platform AS ENUM ('ios','android','web');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Sequence used for order numbers
CREATE SEQUENCE IF NOT EXISTS public.order_number_seq;

-- Helper function referenced by default order_number (keeps it here so per-table scripts can run)
CREATE OR REPLACE FUNCTION public.next_order_number()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE seq bigint;
BEGIN
  SELECT nextval('public.order_number_seq') INTO seq;
  RETURN 'JM-' || to_char(now(),'YYYYMMDD') || '-' || lpad(seq::text, 10, '0');
END $$;
