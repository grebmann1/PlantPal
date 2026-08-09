-- Support up to 3 reference images per species (default + other_images).
-- Keep image_url / cached_image_path as the primary (first) for backward compat.

alter table public.species_catalog
  add column if not exists image_urls text[] not null default '{}',
  add column if not exists cached_image_paths text[] not null default '{}';

-- Backfill arrays from the single-image columns when present.
update public.species_catalog
set image_urls = array[image_url]
where image_url is not null
  and length(trim(image_url)) > 0
  and cardinality(image_urls) = 0;

update public.species_catalog
set cached_image_paths = array[cached_image_path]
where cached_image_path is not null
  and length(trim(cached_image_path)) > 0
  and cardinality(cached_image_paths) = 0;
