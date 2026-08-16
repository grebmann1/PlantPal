-- Keep a single canonical guide for each user/species pair before adding the
-- constraint used by the mobile upsert path.
delete from public.care_guides older
using public.care_guides newer
where older.user_id = newer.user_id
  and older.species_latin_name = newer.species_latin_name
  and older.generated_at < newer.generated_at;

create unique index if not exists care_guides_user_species_unique
  on public.care_guides (user_id, species_latin_name);

-- A plant can have at most one outstanding automatic watering task. Historical
-- completed reminders remain intact as the watering ledger.
create unique index if not exists reminders_one_active_watering_per_plant
  on public.reminders (plant_id)
  where type = 'watering' and is_completed = false;
