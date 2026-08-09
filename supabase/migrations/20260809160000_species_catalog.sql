-- Global Perenual species cache. Shared across all users so each Perenual
-- response is stored once and never re-fetched for the same key.

create table if not exists public.species_catalog (
  id bigint primary key,
  common_name text,
  scientific_name text,
  other_names text[] default '{}',
  family text,
  genus text,
  cycle text,
  watering text,
  sunlight text[] default '{}',
  indoor boolean,
  description text,
  care_level text,
  growth_rate text,
  image_url text,
  cached_image_path text,
  image_license text,
  image_license_url text,
  details_fetched boolean not null default false,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists species_catalog_scientific_name_idx
  on public.species_catalog (lower(scientific_name));

create index if not exists species_catalog_common_name_idx
  on public.species_catalog (lower(common_name));

-- Cache for list/search requests keyed by normalized query string.
create table if not exists public.species_query_cache (
  cache_key text primary key,
  species_ids bigint[] not null default '{}',
  page integer not null default 1,
  last_page integer,
  total integer,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.species_catalog enable row level security;
alter table public.species_query_cache enable row level security;

-- Catalog is a shared read-only knowledge base for the app.
drop policy if exists "species_catalog_select_authenticated" on public.species_catalog;
create policy "species_catalog_select_authenticated"
  on public.species_catalog for select
  to authenticated, anon
  using (true);

drop policy if exists "species_query_cache_select_authenticated" on public.species_query_cache;
create policy "species_query_cache_select_authenticated"
  on public.species_query_cache for select
  to authenticated, anon
  using (true);

-- Writes happen only from the edge function via the service role (bypasses RLS).

-- Public bucket for mirrored species reference photos (optional; function
-- falls back to original Perenual URLs when mirroring fails).
insert into storage.buckets (id, name, public)
values ('species-images', 'species-images', true)
on conflict (id) do nothing;

drop policy if exists "species_images_public_read" on storage.objects;
create policy "species_images_public_read"
  on storage.objects for select
  to authenticated, anon
  using (bucket_id = 'species-images');
