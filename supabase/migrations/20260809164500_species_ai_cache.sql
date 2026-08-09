-- Shared AI caches so each species care guide (and identify profile) is
-- generated once and reused across all users.

create table if not exists public.species_care_guides (
  species_key text primary key,
  species_latin_name text not null,
  species_common_name text,
  light_requirement text,
  watering_frequency text,
  watering_amount text,
  soil_mix text,
  temperature_range text,
  humidity_range text,
  difficulty_level int,
  common_problems jsonb not null default '[]'::jsonb,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists species_care_guides_latin_idx
  on public.species_care_guides (lower(species_latin_name));

-- Species profile facts returned by identify (text-only, reusable).
create table if not exists public.species_ai_profiles (
  species_key text primary key,
  species_latin_name text not null,
  species_common_name text,
  family text,
  light_requirement text,
  watering_interval_days int,
  description text,
  native_region text,
  mature_size text,
  growth_rate text,
  toxicity text,
  fun_fact text,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists species_ai_profiles_latin_idx
  on public.species_ai_profiles (lower(species_latin_name));

alter table public.species_care_guides enable row level security;
alter table public.species_ai_profiles enable row level security;

-- Shared knowledge base: anyone can read; authenticated/anon can enrich.
drop policy if exists "species_care_guides_select" on public.species_care_guides;
create policy "species_care_guides_select"
  on public.species_care_guides for select
  to authenticated, anon
  using (true);

drop policy if exists "species_care_guides_insert" on public.species_care_guides;
create policy "species_care_guides_insert"
  on public.species_care_guides for insert
  to authenticated, anon
  with check (true);

drop policy if exists "species_care_guides_update" on public.species_care_guides;
create policy "species_care_guides_update"
  on public.species_care_guides for update
  to authenticated, anon
  using (true)
  with check (true);

drop policy if exists "species_ai_profiles_select" on public.species_ai_profiles;
create policy "species_ai_profiles_select"
  on public.species_ai_profiles for select
  to authenticated, anon
  using (true);

drop policy if exists "species_ai_profiles_insert" on public.species_ai_profiles;
create policy "species_ai_profiles_insert"
  on public.species_ai_profiles for insert
  to authenticated, anon
  with check (true);

drop policy if exists "species_ai_profiles_update" on public.species_ai_profiles;
create policy "species_ai_profiles_update"
  on public.species_ai_profiles for update
  to authenticated, anon
  using (true)
  with check (true);
