-- Demo branch requested for testing the customer app. Its location mirrors
-- Ahmed's saved "اي حاجه" address so delivery coverage can be exercised there.
insert into core.branches (
  brand_id,
  code,
  name_ar,
  name_en,
  address,
  address_ar,
  address_en,
  latitude,
  longitude,
  is_active
)
values (
  '00000000-0000-4000-8000-000000000001'::uuid,
  'BAHTHAN',
  'فرع بطحان',
  'Bahtan Branch',
  'بطحان, Al Aridah, Jazan Province, Saudi Arabia',
  'بطحان، العارضة، منطقة جازان، السعودية',
  'Bahtan, Al Aridah, Jazan Province, Saudi Arabia',
  17.028150,
  43.042409,
  true
)
on conflict (code) do update set
  address = excluded.address,
  address_ar = excluded.address_ar,
  address_en = excluded.address_en,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  is_active = excluded.is_active;
