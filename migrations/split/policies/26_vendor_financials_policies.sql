-- 26_vendor_financials_policies.sql
-- Policies for vendor financial configuration, bank accounts, ledgers, and payout line items.

-- vendor_financial_settings
drop policy if exists "vendor_fin_settings_owner_manage" on public.vendor_financial_settings;
drop policy if exists "vendor_fin_settings_staff_manage" on public.vendor_financial_settings;
drop policy if exists "vendor_fin_settings_admin_manage" on public.vendor_financial_settings;

create policy "vendor_fin_settings_owner_manage" on public.vendor_financial_settings
for all using (
  exists (
    select 1 from public.vendors v
    where v.id = vendor_financial_settings.vendor_id
      and v.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.vendors v
    where v.id = vendor_financial_settings.vendor_id
      and v.owner_user_id = auth.uid()
  )
);

create policy "vendor_fin_settings_staff_manage" on public.vendor_financial_settings
for all using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = vendor_financial_settings.vendor_id
      and vs.user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = vendor_financial_settings.vendor_id
      and vs.user_id = auth.uid()
  )
);

create policy "vendor_fin_settings_admin_manage" on public.vendor_financial_settings
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- vendor_bank_accounts
drop policy if exists "vendor_bank_owner_manage" on public.vendor_bank_accounts;
drop policy if exists "vendor_bank_staff_manage" on public.vendor_bank_accounts;
drop policy if exists "vendor_bank_admin_manage" on public.vendor_bank_accounts;

create policy "vendor_bank_owner_manage" on public.vendor_bank_accounts
for all using (
  exists (
    select 1 from public.vendors v
    where v.id = vendor_bank_accounts.vendor_id
      and v.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.vendors v
    where v.id = vendor_bank_accounts.vendor_id
      and v.owner_user_id = auth.uid()
  )
);

create policy "vendor_bank_staff_manage" on public.vendor_bank_accounts
for all using (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = vendor_bank_accounts.vendor_id
      and vs.user_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.vendor_staff vs
    where vs.vendor_id = vendor_bank_accounts.vendor_id
      and vs.user_id = auth.uid()
  )
);

create policy "vendor_bank_admin_manage" on public.vendor_bank_accounts
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- vendor_ledger_entries
drop policy if exists "vendor_ledger_vendor_read" on public.vendor_ledger_entries;
drop policy if exists "vendor_ledger_admin_manage" on public.vendor_ledger_entries;

create policy "vendor_ledger_vendor_read" on public.vendor_ledger_entries
for select using (
  exists (
    select 1 from public.vendors v
    where v.id = vendor_ledger_entries.vendor_id
      and (v.owner_user_id = auth.uid() or exists (
        select 1 from public.vendor_staff vs
        where vs.vendor_id = v.id and vs.user_id = auth.uid()
      ))
  )
);

create policy "vendor_ledger_admin_manage" on public.vendor_ledger_entries
for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- payout_line_items
drop policy if exists "payout_line_items_vendor_read" on public.payout_line_items;
drop policy if exists "payout_line_items_admin_manage" on public.payout_line_items;

create policy "payout_line_items_vendor_read" on public.payout_line_items
for select using (
  exists (
    select 1
    from public.payouts p
    join public.vendors v on v.id = p.vendor_id
    where p.id = payout_line_items.payout_id
      and (
        v.owner_user_id = auth.uid()
        or exists (
          select 1 from public.vendor_staff vs
          where vs.vendor_id = v.id and vs.user_id = auth.uid()
        )
      )
  )
);

create policy "payout_line_items_admin_manage" on public.payout_line_items
for all using (public.is_platform_admin()) with check (public.is_platform_admin());
