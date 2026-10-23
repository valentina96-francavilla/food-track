-- FoodTrack product image storage.
-- Public reads are intentional for catalog thumbnails; uploads and changes require
-- a supplier membership for the organization folder or a platform administrator.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('foodtrack-product-images','foodtrack-product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Public can view FoodTrack product images" on storage.objects;
create policy "Public can view FoodTrack product images" on storage.objects for select to public
using (bucket_id = 'foodtrack-product-images');

drop policy if exists "Suppliers and platform admins upload FoodTrack product images" on storage.objects;
create policy "Suppliers and platform admins upload FoodTrack product images" on storage.objects for insert to authenticated
with check (bucket_id = 'foodtrack-product-images' and (
  public.is_foodtrack_platform_admin()
  or exists (select 1 from public.memberships m where m.user_id=auth.uid() and m.role='supplier'::public.member_role and m.organization_id::text=(storage.foldername(name))[1])
));

drop policy if exists "Suppliers and platform admins update FoodTrack product images" on storage.objects;
create policy "Suppliers and platform admins update FoodTrack product images" on storage.objects for update to authenticated
using (bucket_id = 'foodtrack-product-images' and (
  public.is_foodtrack_platform_admin()
  or exists (select 1 from public.memberships m where m.user_id=auth.uid() and m.role='supplier'::public.member_role and m.organization_id::text=(storage.foldername(name))[1])
))
with check (bucket_id = 'foodtrack-product-images' and (
  public.is_foodtrack_platform_admin()
  or exists (select 1 from public.memberships m where m.user_id=auth.uid() and m.role='supplier'::public.member_role and m.organization_id::text=(storage.foldername(name))[1])
));

drop policy if exists "Suppliers and platform admins delete FoodTrack product images" on storage.objects;
create policy "Suppliers and platform admins delete FoodTrack product images" on storage.objects for delete to authenticated
using (bucket_id = 'foodtrack-product-images' and (
  public.is_foodtrack_platform_admin()
  or exists (select 1 from public.memberships m where m.user_id=auth.uid() and m.role='supplier'::public.member_role and m.organization_id::text=(storage.foldername(name))[1])
));
