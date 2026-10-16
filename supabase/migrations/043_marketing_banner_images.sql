-- 043_marketing_banner_images.sql
--
-- Gives each legacy category banner its own real photo. The seed pointed all
-- five at one shared asset (`assets/images/banar.png`), so the carousel
-- rendered the same picture five times. Every URL below was verified with an
-- HTTP 200 check. Only rows still on the legacy asset path are touched, so
-- custom banners (including the 042 rows) are never overwritten, and the
-- statement is safe to re-run.

update marketing.banners
set image_url = case title_en
  when 'Morning Boost' then 'https://images.unsplash.com/photo-1447933601403-0c6688de566e?auto=format&fit=crop&w=800&q=80'
  when 'Iced & Fresh'  then 'https://images.unsplash.com/photo-1524350876685-274059332603?auto=format&fit=crop&w=800&q=80'
  when 'Tea Time'      then 'https://images.unsplash.com/photo-1556881286-fc6915169721?auto=format&fit=crop&w=800&q=80'
  when 'Sweet Treats'  then 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=800&q=80'
  when 'Snack Corner'  then 'https://images.unsplash.com/photo-1587248720327-8eb72564be1e?auto=format&fit=crop&w=800&q=80'
  else image_url
end
where image_url = 'assets/images/banar.png';
