-- The first care-guide dedupe migration retained rows with identical timestamps.
-- Use the primary key as a deterministic tiebreaker before enforcing uniqueness.
delete from public.care_guides guide
using (
  select id,
         row_number() over (
           partition by user_id, species_latin_name
           order by generated_at desc, id desc
         ) as row_number
  from public.care_guides
  where user_id is not null and species_latin_name is not null
) duplicate
where guide.id = duplicate.id
  and duplicate.row_number > 1;

create unique index if not exists care_guides_user_species_unique
  on public.care_guides (user_id, species_latin_name);

-- Completing a watering task changes three records. Keep the ledger entry, plant
-- schedule, and following task in one transaction so a client retry is safe.
create or replace function public.complete_watering_reminder(
  p_reminder_id uuid,
  p_next_watering_date date,
  p_next_due_at timestamptz,
  p_next_amount_label text
)
returns table (
  next_watering_date date,
  next_reminder_id uuid,
  next_reminder_due_at timestamptz,
  next_reminder_amount_label text
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_reminder public.reminders%rowtype;
  next_reminder public.reminders%rowtype;
begin
  select *
  into current_reminder
  from public.reminders
  where id = p_reminder_id
    and user_id = auth.uid()
    and type = 'watering'
  for update;

  if not found then
    raise exception 'Watering reminder not found';
  end if;

  perform 1
  from public.plants
  where id = current_reminder.plant_id
    and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Plant not found';
  end if;

  if not current_reminder.is_completed then
    update public.reminders
    set is_completed = true
    where id = current_reminder.id;

    update public.plants
    set next_watering_date = p_next_watering_date
    where id = current_reminder.plant_id;

    insert into public.reminders (
      user_id,
      plant_id,
      type,
      due_at,
      amount_label
    ) values (
      auth.uid(),
      current_reminder.plant_id,
      'watering',
      p_next_due_at,
      p_next_amount_label
    ) returning * into next_reminder;
  else
    select *
    into next_reminder
    from public.reminders
    where plant_id = current_reminder.plant_id
      and type = 'watering'
      and is_completed = false
    order by due_at asc
    limit 1;

    if not found then
      update public.plants
      set next_watering_date = p_next_watering_date
      where id = current_reminder.plant_id;

      insert into public.reminders (
        user_id,
        plant_id,
        type,
        due_at,
        amount_label
      ) values (
        auth.uid(),
        current_reminder.plant_id,
        'watering',
        p_next_due_at,
        p_next_amount_label
      ) returning * into next_reminder;
    end if;
  end if;

  return query
  select plants.next_watering_date,
         next_reminder.id,
         next_reminder.due_at,
         next_reminder.amount_label
  from public.plants plants
  where plants.id = current_reminder.plant_id;
end;
$$;
