-- Starter venue photos from Unsplash; admins can replace them in the table editor.
update floor.tables
set image_url = case id
  when '33949930-bed6-4844-8542-61defa43d8e8' then 'https://images.unsplash.com/photo-1669310970620-42fbd32fd3c0?auto=format&fit=crop&w=1200&q=80'
  when '2f4d409e-6fe8-46b2-85fe-b4f07605ae9d' then 'https://images.unsplash.com/photo-1608816042754-d69cb2271bea?auto=format&fit=crop&w=1200&q=80'
  when '7f60df16-8435-4def-af88-de40a9ffd3ed' then 'https://images.unsplash.com/photo-1669310970620-42fbd32fd3c0?auto=format&fit=crop&w=1200&q=80'
  when '1dfa3e3c-8a88-4ce9-a1e2-ea1a38770cb7' then 'https://images.unsplash.com/photo-1748228885234-1f289f95a2a4?auto=format&fit=crop&w=1200&q=80'
  when '88e1b01d-324b-42b1-9dcd-52c46164be28' then 'https://images.unsplash.com/photo-1748228885234-1f289f95a2a4?auto=format&fit=crop&w=1200&q=80'
  when 'dc3bd4cb-b8c9-4d1c-9f8d-9dc2c283420f' then 'https://images.unsplash.com/photo-1608816042754-d69cb2271bea?auto=format&fit=crop&w=1200&q=80'
  else image_url
end
where id in (
  '33949930-bed6-4844-8542-61defa43d8e8',
  '2f4d409e-6fe8-46b2-85fe-b4f07605ae9d',
  '7f60df16-8435-4def-af88-de40a9ffd3ed',
  '1dfa3e3c-8a88-4ce9-a1e2-ea1a38770cb7',
  '88e1b01d-324b-42b1-9dcd-52c46164be28',
  'dc3bd4cb-b8c9-4d1c-9f8d-9dc2c283420f'
);
