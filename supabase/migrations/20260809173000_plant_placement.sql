-- Add placement for Indoor / Balcony filtering and plant detail editing.
alter table public.plants
  add column if not exists placement text not null default 'unknown'
  check (placement in ('indoor', 'balcony', 'unknown'));
