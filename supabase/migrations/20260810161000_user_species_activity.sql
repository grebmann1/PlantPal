create table if not exists public.user_species_activity (
  user_id uuid not null references auth.users(id) on delete cascade,
  species_id bigint not null references public.species_catalog(id) on delete cascade,
  is_favorite boolean not null default false,
  last_viewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, species_id)
);

create index if not exists user_species_activity_recent_idx
  on public.user_species_activity (user_id, last_viewed_at desc)
  where last_viewed_at is not null;

create index if not exists user_species_activity_favorites_idx
  on public.user_species_activity (user_id, updated_at desc)
  where is_favorite = true;

alter table public.user_species_activity enable row level security;

drop policy if exists "user_species_activity_owner_select"
  on public.user_species_activity;
create policy "user_species_activity_owner_select"
  on public.user_species_activity for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_species_activity_owner_insert"
  on public.user_species_activity;
create policy "user_species_activity_owner_insert"
  on public.user_species_activity for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "user_species_activity_owner_update"
  on public.user_species_activity;
create policy "user_species_activity_owner_update"
  on public.user_species_activity for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_species_activity_owner_delete"
  on public.user_species_activity;
create policy "user_species_activity_owner_delete"
  on public.user_species_activity for delete
  to authenticated
  using (auth.uid() = user_id);
