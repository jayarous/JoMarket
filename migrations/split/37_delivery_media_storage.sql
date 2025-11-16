-- 37_delivery_media_storage.sql
-- Creates Supabase Storage buckets and policies for proof-of-delivery media

-- Create (or ensure) public buckets for delivery photos and signatures
insert into storage.buckets (id, name, public)
values
  ('delivery_photos', 'delivery_photos', true),
  ('signatures', 'signatures', true)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public;

-- Clean up any prior policies to keep the migration idempotent
drop policy if exists "delivery_media_upload" on storage.objects;
drop policy if exists "delivery_media_update" on storage.objects;
drop policy if exists "delivery_media_read" on storage.objects;

-- Allow active delivery staff (and platform admins) to upload POD media
create policy "delivery_media_upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id in ('delivery_photos', 'signatures')
  and (
    public.is_platform_admin()
    or exists (
      select 1
      from public.delivery_staff ds
where ds.user_id = auth.uid()
        and ds.active
    )
  )
);

-- Support re-uploads (Supabase's upsert uses update operations)
create policy "delivery_media_update"
on storage.objects
for update
to authenticated
using (
  bucket_id in ('delivery_photos', 'signatures')
  and (
    public.is_platform_admin()
    or exists (
      select 1
      from public.delivery_staff ds
where ds.user_id = auth.uid()
        and ds.active
    )
  )
)
with check (
  bucket_id in ('delivery_photos', 'signatures')
  and (
    public.is_platform_admin()
    or exists (
      select 1
      from public.delivery_staff ds
where ds.user_id = auth.uid()
        and ds.active
    )
  )
);

-- Buckets are intentionally public so anyone can view proof attachments
create policy "delivery_media_read"
on storage.objects
for select
to public
using (bucket_id in ('delivery_photos', 'signatures'));
