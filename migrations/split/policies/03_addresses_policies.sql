-- 03_addresses_policies.sql
-- Copied from migrations/split/policies/02_addresses_policies.sql
-- WARNING: Policies reference `auth` objects (auth.users / auth.uid()).
-- Ensure you only apply these on Supabase or after creating local `auth` stubs for testing.

-- Drop existing policies if present so the file can be reapplied idempotently
drop policy if exists "addresses_owner_crud" on public.addresses;
drop policy if exists "addresses_vendor_manage" on public.addresses;
drop policy if exists "addresses_delivery_provider_manage" on public.addresses;

create policy "addresses_owner_crud" on public.addresses
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- Create vendor-management policy only if the vendor_staff table exists (prevents errors when running this file standalone)
DO $$
BEGIN
	IF EXISTS (
		SELECT 1 FROM information_schema.tables
		WHERE table_schema = 'public' AND table_name = 'vendor_staff'
	) THEN
		EXECUTE $sql$
			create policy "addresses_vendor_manage" on public.addresses
			for all using (exists (select 1 from public.vendor_staff vs where vs.vendor_id = addresses.vendor_id and vs.user_id = auth.uid()))
			with check (exists (select 1 from public.vendor_staff vs where vs.vendor_id = addresses.vendor_id and vs.user_id = auth.uid()));
		$sql$;
	END IF;
END
$$;

-- Create delivery-provider-management policy only if the delivery_providers table exists
DO $$
BEGIN
	IF EXISTS (
		SELECT 1 FROM information_schema.tables
		WHERE table_schema = 'public' AND table_name = 'delivery_providers'
	) THEN
		EXECUTE $sql$
			create policy "addresses_delivery_provider_manage" on public.addresses
			for all using (exists (select 1 from public.delivery_providers dp where dp.id = addresses.delivery_provider_id and dp.owner_user_id = auth.uid()))
			with check (exists (select 1 from public.delivery_providers dp where dp.id = addresses.delivery_provider_id and dp.owner_user_id = auth.uid()));
		$sql$;
	END IF;
END
$$;
