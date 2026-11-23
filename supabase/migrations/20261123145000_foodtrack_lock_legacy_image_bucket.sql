-- Disable writes to the legacy bucket. Existing objects remain untouched and readable.
DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update product images" ON storage.objects;
