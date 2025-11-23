-- 41_promos_seed.sql
-- Populate the promos table with initial sample data for the buyer home screen.
insert into public.promos (title, subtitle, cta_label, cta_action, primary_color, secondary_color, icon_name, sort_order)
values
  (
    'Winter Essentials',
    'Cozy throws, candles, and seasonal surprises',
    'Shop Winter',
    'category://home-living',
    '#0d6efd',
    '#cfe2ff',
    'winter_accessories',
    0
  ),
  (
    'Fresh Arrivals',
    'New makers launching weekly',
    'Discover Now',
    'category://fashion-misc',
    '#0275d8',
    '#d0ebff',
    'sparkles',
    1
  );
