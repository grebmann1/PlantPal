-- Shared FR/DE (and future locale) overlays for English species API content.
-- English remains canonical in species_care_guides / species_ai_profiles / species_catalog.

create table if not exists public.species_i18n (
  kind text not null check (kind in ('care_guide', 'ai_profile', 'catalog')),
  species_key text not null,
  locale text not null check (locale in ('de', 'fr')),
  fields jsonb not null default '{}'::jsonb,
  source_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (kind, species_key, locale)
);

create index if not exists species_i18n_species_key_idx
  on public.species_i18n (species_key);

create index if not exists species_i18n_locale_idx
  on public.species_i18n (locale);

alter table public.species_i18n enable row level security;

drop policy if exists "species_i18n_select" on public.species_i18n;
create policy "species_i18n_select"
  on public.species_i18n for select
  to authenticated, anon
  using (true);

drop policy if exists "species_i18n_insert" on public.species_i18n;
create policy "species_i18n_insert"
  on public.species_i18n for insert
  to authenticated, anon
  with check (true);

drop policy if exists "species_i18n_update" on public.species_i18n;
create policy "species_i18n_update"
  on public.species_i18n for update
  to authenticated, anon
  using (true)
  with check (true);
