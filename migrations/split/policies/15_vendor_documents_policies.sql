-- vendor_documents_policies.sql
drop policy if exists "vendor_documents_vendor_staff" on public.vendor_documents;
create policy "vendor_documents_vendor_staff" on public.vendor_documents
for all using (
  exists (
    select 1 from public.vendor_staff vs where vs.vendor_id = vendor_documents.vendor_id and vs.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.vendor_staff vs where vs.vendor_id = vendor_documents.vendor_id and vs.user_id = auth.uid()
  )
);
