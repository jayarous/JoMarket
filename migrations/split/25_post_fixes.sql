-- 25_post_fixes.sql
-- Small idempotent fixes to match consolidated migration. Safe to run after the split migrations.

-- Ensure vendor_id on user_roles has a FK to vendors (added if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_user_roles_vendor'
      AND conrelid = 'public.user_roles'::regclass
  ) THEN
    ALTER TABLE public.user_roles
      ADD CONSTRAINT fk_user_roles_vendor
      FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Ensure addresses.vendor_id has an FK to public.vendors (added if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_addresses_vendor'
      AND conrelid = 'public.addresses'::regclass
  ) THEN
    ALTER TABLE public.addresses
      ADD CONSTRAINT fk_addresses_vendor
      FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add deleted_at to products if missing (soft-delete helper)
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Add other small guard rails here if you want to track parity with the consolidated migration.
