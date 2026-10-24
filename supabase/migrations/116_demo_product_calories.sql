-- Demo nutrition values for the current sample catalogue.
-- Replace with supplier-approved nutrition data before production.
update catalog.products as p
set calories = demo.calories
from (values
  ('187fd909-5914-4759-aa2a-b4cf81196c95'::uuid, 5),   -- Americano
  ('62f48898-6c44-47bc-b83a-38b206af3457'::uuid, 290), -- Butter Bread
  ('887c1fac-4e86-47e4-9a85-e6d9414d681f'::uuid, 300), -- Butter Croissant
  ('a2522a72-dfbe-4812-8bf7-a87f7d29223e'::uuid, 120), -- Cappuccino
  ('afbb6696-a826-43f3-974f-5709f3e318b2'::uuid, 420), -- Cheesecake
  ('934121b1-9917-4ef3-b98c-275458b4f648'::uuid, 380), -- Chocolate Brownie
  ('7f358716-7156-48a4-8cd6-8b0b59b4e77c'::uuid, 280), -- Chocolate Chip Cookie
  ('7a2ebf5b-32a2-4b70-929c-bf5ea4db0bfc'::uuid, 450), -- Chocolate Milkshake
  ('962f260a-8b14-47f7-ac2e-1484940fbc95'::uuid, 140), -- Cola
  ('66c2cc01-0983-4a87-ad1a-638a0aba8b0d'::uuid, 5),   -- Espresso
  ('bfa60133-ec46-4a6f-85be-47488aeeb64f'::uuid, 290), -- Glazed Donut
  ('c2ca0eb7-ab33-457a-bcf4-2674371bcac9'::uuid, 2),   -- Green Tea
  ('425ba241-b647-4d06-a968-d9a530a6df1a'::uuid, 180), -- Iced Latte
  ('7c6fca1e-b48f-4669-aab0-7dd4f314690b'::uuid, 190), -- Latte
  ('f7cacc15-73f1-45b9-91b7-76dacd7473f6'::uuid, 100), -- Masala Tea
  ('58bd79b1-bb3f-4c32-a0e9-d3b3ac131812'::uuid, 330)  -- Mocha
) as demo(id, calories)
where p.id = demo.id and p.calories is null;
