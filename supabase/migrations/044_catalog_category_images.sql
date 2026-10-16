-- 044_catalog_category_images.sql
--
-- Gives every category a working picture. The seed never populated
-- `catalog.categories.image_url`, so the home grid could only render the
-- `icon_key` glyph. Every URL below was verified with an HTTP 200 check
-- before being written here. Only rows with no picture are touched, so the
-- statement is safe to re-run and never overwrites a custom image.

update catalog.categories
set image_url = case slug
  when 'hot-coffee'  then 'https://images.unsplash.com/photo-1517487881594-2787fef5ebf7?auto=format&fit=crop&w=800&q=80'
  when 'cold-coffee' then 'https://images.unsplash.com/photo-1585494156145-1c60a4fe952b?auto=format&fit=crop&w=800&q=80'
  when 'tea'         then 'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?auto=format&fit=crop&w=800&q=80'
  when 'desserts'    then 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=800&q=80'
  when 'snacks'      then 'https://images.unsplash.com/photo-1587248720327-8eb72564be1e?auto=format&fit=crop&w=800&q=80'
  when 'milkshakes'  then 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80'
  when 'soft-drinks' then 'https://images.unsplash.com/photo-1554866585-cd94860890b7?auto=format&fit=crop&w=800&q=80'
  when 'bakery'      then 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80'
  when 'donuts'      then 'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=800&q=80'
  when 'bundles'     then 'https://images.unsplash.com/photo-1512568400610-62da28bc8a13?auto=format&fit=crop&w=800&q=80'
  else image_url
end
where image_url is null or btrim(image_url) = '';
