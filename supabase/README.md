# PlantPal Supabase

## Perenual proxy

Caches [Perenual](https://perenual.com/) plant species responses so each unique API call is made at most once. Stores names plus up to **3 reference images** per species (mirrored into the public `species-images` bucket when available).

### Setup

```bash
supabase link --project-ref jgacczbgxyrysboyyhsj
supabase db push
supabase secrets set PERENUAL_API_KEY=your_key_here
supabase functions deploy perenual-proxy --use-api
```

### Actions

`POST /functions/v1/perenual-proxy`

| action | body | behavior |
|--------|------|----------|
| `search` | `{ q?, page?, indoor? }` | Cached species list |
| `details` | `{ id }` | Full species profile (falls back to list cache on free-tier 429) |
| `lookup` | `{ scientific_name }` | Match by Latin name for AI ID enrichment |

Client species payloads include `image_url` (primary) and `image_urls` (up to 3). Extra images come from Perenual `other_images` when the details tier returns them.

## Translate proxy

Lazily translates English species API text (care guides, identify profiles, catalog fields) into **French** / **German** and caches each `(kind, species, locale)` forever in `species_i18n`.

```bash
supabase secrets set OPENAI_API_KEY=your_key_here
supabase functions deploy translate-proxy --use-api
```

`POST /functions/v1/translate-proxy` body: `{ kind, species_key, locale, fields }` → `{ cached, fields }`.

## AI proxy

OpenAI edge function for identify / health / care_guide / **plant_expert**.

```bash
supabase functions deploy ai-proxy --use-api
```

`plant_expert` body: `{ task, messages: [{role, content, image_base64?, image_mime_type?}], plant_context }` → `{ task, result: { reply } }` (model: `gpt-5.6-luna`, optional photo per user turn).

## Shared AI caches

| Table | Key | Filled by | Reused for |
|-------|-----|-----------|------------|
| `species_care_guides` | normalized Latin name | first `care_guide` AI call | every later care sheet for that species |
| `species_ai_profiles` | normalized Latin name | each successful `identify` | species facts without re-calling vision |
| `species_i18n` | kind + species key + locale | first FR/DE request | every later localized display of that content |

`identify` / `health` still need a photo each time (vision). Full JSON is also stored on `scans.ai_result_json` when the scan is saved.
