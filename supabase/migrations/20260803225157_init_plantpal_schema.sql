
-- plants
create table public.plants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null,
  species_common_name text,
  species_latin_name text,
  family text,
  photo_url text,
  health_score int,
  next_watering_date date,
  watering_interval_days int,
  watering_amount_ml int,
  added_date date not null default current_date,
  created_at timestamptz not null default now()
);

-- scans
create table public.scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plant_id uuid references public.plants(id) on delete cascade,
  photo_url text,
  scan_type text not null check (scan_type in ('identify','health','log')),
  captured_at timestamptz not null default now(),
  confidence numeric,
  health_status text,
  health_score int,
  ai_result_json jsonb
);

-- reminders
create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plant_id uuid not null references public.plants(id) on delete cascade,
  type text not null check (type in ('watering','feeding','custom')),
  due_at timestamptz not null,
  amount_label text,
  is_completed boolean not null default false,
  snoozed_until timestamptz,
  created_at timestamptz not null default now()
);

-- care_guides
create table public.care_guides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  plant_id uuid references public.plants(id) on delete cascade,
  species_latin_name text,
  light_requirement text,
  watering_frequency text,
  watering_amount text,
  soil_mix text,
  temperature_range text,
  humidity_range text,
  difficulty_level int,
  common_problems jsonb,
  generated_at timestamptz not null default now()
);

create index on public.plants (user_id);
create index on public.scans (user_id);
create index on public.scans (plant_id);
create index on public.reminders (user_id);
create index on public.reminders (plant_id);
create index on public.care_guides (user_id);
create index on public.care_guides (plant_id);

alter table public.plants enable row level security;
alter table public.scans enable row level security;
alter table public.reminders enable row level security;
alter table public.care_guides enable row level security;

create policy "plants_owner_select" on public.plants for select using (auth.uid() = user_id);
create policy "plants_owner_insert" on public.plants for insert with check (auth.uid() = user_id);
create policy "plants_owner_update" on public.plants for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "plants_owner_delete" on public.plants for delete using (auth.uid() = user_id);

create policy "scans_owner_select" on public.scans for select using (auth.uid() = user_id);
create policy "scans_owner_insert" on public.scans for insert with check (auth.uid() = user_id);
create policy "scans_owner_update" on public.scans for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "scans_owner_delete" on public.scans for delete using (auth.uid() = user_id);

create policy "reminders_owner_select" on public.reminders for select using (auth.uid() = user_id);
create policy "reminders_owner_insert" on public.reminders for insert with check (auth.uid() = user_id);
create policy "reminders_owner_update" on public.reminders for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reminders_owner_delete" on public.reminders for delete using (auth.uid() = user_id);

create policy "care_guides_owner_select" on public.care_guides for select using (auth.uid() = user_id);
create policy "care_guides_owner_insert" on public.care_guides for insert with check (auth.uid() = user_id);
create policy "care_guides_owner_update" on public.care_guides for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "care_guides_owner_delete" on public.care_guides for delete using (auth.uid() = user_id);
;
