// Proxies Perenual Plant API calls and permanently caches results in
// species_catalog / species_query_cache so identical requests never hit
// Perenual again. Stores up to 3 reference images per species (default +
// other_images) and mirrors them into the public species-images bucket.
//
// Secrets required:
//   PERENUAL_API_KEY
//   SUPABASE_URL (auto)
//   SUPABASE_SERVICE_ROLE_KEY (auto)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const PERENUAL_BASE = "https://perenual.com/api/v2";

type ProxyAction = "search" | "details" | "lookup";

interface ProxyRequest {
  action: ProxyAction;
  q?: string;
  page?: number;
  indoor?: boolean;
  id?: number;
  scientific_name?: string;
}

const MAX_SPECIES_IMAGES = 3;

interface SpeciesRow {
  id: number;
  common_name: string | null;
  scientific_name: string | null;
  other_names: string[] | null;
  family: string | null;
  genus: string | null;
  cycle: string | null;
  watering: string | null;
  sunlight: string[] | null;
  indoor: boolean | null;
  description: string | null;
  care_level: string | null;
  growth_rate: string | null;
  image_url: string | null;
  cached_image_path: string | null;
  image_urls: string[];
  cached_image_paths: string[];
  image_license: string | null;
  image_license_url: string | null;
  details_fetched: boolean;
  raw: unknown;
  created_at?: string;
  updated_at?: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("PERENUAL_API_KEY");
    if (!apiKey) {
      return json(
        { error: "not_configured", message: "PERENUAL_API_KEY is not set" },
        500,
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const body = (await req.json()) as ProxyRequest;
    if (!body?.action) {
      return json({ error: "bad_request", message: "action is required" }, 400);
    }

    switch (body.action) {
      case "search":
        return json(
          await handleSearch(supabase, apiKey, body),
        );
      case "details":
        return json(
          await handleDetails(supabase, apiKey, body.id),
        );
      case "lookup":
        return json(
          await handleLookup(supabase, apiKey, body.scientific_name),
        );
      default:
        return json({ error: "bad_request", message: "unknown action" }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("perenual-proxy error", message);
    return json({ error: "failed", message }, 500);
  }
});

async function handleSearch(
  supabase: ReturnType<typeof createClient>,
  apiKey: string,
  body: ProxyRequest,
) {
  const page = body.page ?? 1;
  const q = (body.q ?? "").trim();
  const indoor = body.indoor ?? true;
  const cacheKey = buildSearchCacheKey({ q, page, indoor });

  const { data: cached } = await supabase
    .from("species_query_cache")
    .select("*")
    .eq("cache_key", cacheKey)
    .maybeSingle();

  if (cached) {
    const ids = (cached.species_ids as number[]) ?? [];
    const species = ids.length
      ? await loadSpeciesByIds(supabase, ids)
      : [];
    return {
      cached: true,
      page: cached.page,
      last_page: cached.last_page,
      total: cached.total,
      data: species.map(toClientSpecies),
    };
  }

  const params = new URLSearchParams({
    key: apiKey,
    page: String(page),
  });
  if (q) params.set("q", q);
  if (indoor) params.set("indoor", "1");

  const upstream = await fetch(
    `${PERENUAL_BASE}/species-list?${params.toString()}`,
  );
  if (!upstream.ok) {
    const text = await upstream.text();
    throw new Error(`Perenual search failed (${upstream.status}): ${text}`);
  }
  const payload = await upstream.json();
  const rows = Array.isArray(payload.data) ? payload.data : [];

  const upserted: SpeciesRow[] = [];
  for (const item of rows) {
    const mapped = mapListItem(item);
    const saved = await upsertSpecies(supabase, mapped, /*detailsFetched*/ false);
    upserted.push(await maybeMirrorImages(supabase, saved));
  }

  const speciesIds = upserted.map((s) => s.id);
  await supabase.from("species_query_cache").upsert({
    cache_key: cacheKey,
    species_ids: speciesIds,
    page: payload.current_page ?? page,
    last_page: payload.last_page ?? null,
    total: payload.total ?? speciesIds.length,
    raw: payload,
  });

  // Reload so we return any mirrored image paths written above.
  const fresh = await loadSpeciesByIds(supabase, speciesIds);

  return {
    cached: false,
    page: payload.current_page ?? page,
    last_page: payload.last_page ?? null,
    total: payload.total ?? fresh.length,
    data: fresh.map(toClientSpecies),
  };
}

async function handleDetails(
  supabase: ReturnType<typeof createClient>,
  apiKey: string,
  id?: number,
) {
  if (!id || !Number.isFinite(id)) {
    throw new Error("id is required for details");
  }

  const { data: existing } = await supabase
    .from("species_catalog")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (
    existing?.details_fetched &&
    hasUsableDetails(existing as SpeciesRow)
  ) {
    return { cached: true, data: toClientSpecies(existing as SpeciesRow) };
  }

  try {
    const species = await fetchAndStoreDetails(supabase, apiKey, id);
    return { cached: false, data: toClientSpecies(species) };
  } catch (error) {
    // Free Perenual tiers often block /species/details (HTTP 429).
    // Fall back to whatever list-level row we already cached.
    if (existing) {
      console.warn(
        "details upstream failed; returning cached list row",
        id,
        error instanceof Error ? error.message : String(error),
      );
      return {
        cached: true,
        data: toClientSpecies(existing as SpeciesRow),
        details_limited: true,
      };
    }
    throw error;
  }
}

async function handleLookup(
  supabase: ReturnType<typeof createClient>,
  apiKey: string,
  scientificName?: string,
) {
  const name = (scientificName ?? "").trim();
  if (!name) {
    throw new Error("scientific_name is required for lookup");
  }

  const { data: existing } = await supabase
    .from("species_catalog")
    .select("*")
    .ilike("scientific_name", name)
    .limit(1)
    .maybeSingle();

  if (
    existing?.details_fetched &&
    hasUsableDetails(existing as SpeciesRow)
  ) {
    return { cached: true, data: toClientSpecies(existing as SpeciesRow) };
  }

  // Search Perenual (or use query cache), then fetch full details for best match.
  const search = await handleSearch(supabase, apiKey, {
    action: "search",
    q: name,
    page: 1,
    indoor: false,
  });

  const match =
    (search.data as ReturnType<typeof toClientSpecies>[]).find((s) =>
      (s.scientific_name ?? "").toLowerCase() === name.toLowerCase()
    ) ??
    (search.data as ReturnType<typeof toClientSpecies>[])[0];

  if (!match) {
    return { cached: search.cached, data: null };
  }

  const detailed = await handleDetails(supabase, apiKey, match.id);
  return detailed;
}

async function fetchAndStoreDetails(
  supabase: ReturnType<typeof createClient>,
  apiKey: string,
  id: number,
) {
  const upstream = await fetch(
    `${PERENUAL_BASE}/species/details/${id}?key=${encodeURIComponent(apiKey)}`,
  );
  if (!upstream.ok) {
    const text = await upstream.text();
    throw new Error(`Perenual details failed (${upstream.status}): ${text}`);
  }
  const payload = await upstream.json();
  const mapped = mapDetailsItem(payload);
  const saved = await upsertSpecies(supabase, mapped, /*detailsFetched*/ true);
  return await maybeMirrorImages(supabase, saved);
}

function mapListItem(item: Record<string, unknown>): SpeciesRow {
  const image = (item.default_image ?? null) as Record<string, unknown> | null;
  const imageUrls = collectImageUrls(item);
  return {
    id: Number(item.id),
    common_name: str(item.common_name),
    scientific_name: firstString(item.scientific_name),
    other_names: stringArray(item.other_name),
    family: str(item.family),
    genus: str(item.genus),
    cycle: str(item.cycle),
    watering: str(item.watering),
    sunlight: stringArray(item.sunlight),
    indoor: typeof item.indoor === "boolean" ? item.indoor : null,
    description: null,
    care_level: null,
    growth_rate: null,
    image_url: imageUrls[0] ?? null,
    cached_image_path: null,
    image_urls: imageUrls,
    cached_image_paths: [],
    image_license: str(image?.license_name),
    image_license_url: str(image?.license_url),
    details_fetched: false,
    raw: item,
  };
}

function mapDetailsItem(item: Record<string, unknown>): SpeciesRow {
  const base = mapListItem(item);
  return {
    ...base,
    description: str(item.description),
    care_level: str(item.care_level),
    growth_rate: str(item.growth_rate),
    watering: str(item.watering) ?? base.watering,
    sunlight: stringArray(item.sunlight).length
      ? stringArray(item.sunlight)
      : base.sunlight,
    indoor: typeof item.indoor === "boolean" ? item.indoor : base.indoor,
    cycle: str(item.cycle) ?? base.cycle,
    family: str(item.family) ?? base.family,
    details_fetched: true,
    raw: item,
  };
}

async function upsertSpecies(
  supabase: ReturnType<typeof createClient>,
  row: SpeciesRow,
  detailsFetched: boolean,
): Promise<SpeciesRow> {
  const { data: existing } = await supabase
    .from("species_catalog")
    .select("*")
    .eq("id", row.id)
    .maybeSingle();

  const merged: SpeciesRow = {
    ...(existing as SpeciesRow | null),
    ...row,
    // Prefer newly discovered upstream URLs; keep prior mirrors when still valid.
    image_urls: mergeUniqueUrls(
      row.image_urls,
      (existing as SpeciesRow | null)?.image_urls ?? [],
    ),
    cached_image_paths:
      ((existing as SpeciesRow | null)?.cached_image_paths?.length ?? 0) > 0 &&
      row.image_urls.length === 0
        ? (existing as SpeciesRow).cached_image_paths
        : row.cached_image_paths?.length
        ? row.cached_image_paths
        : (existing as SpeciesRow | null)?.cached_image_paths ?? [],
    cached_image_path:
      row.cached_image_path ??
      (existing as SpeciesRow | null)?.cached_image_path ??
      null,
    details_fetched:
      detailsFetched ||
      Boolean((existing as SpeciesRow | null)?.details_fetched),
    updated_at: new Date().toISOString(),
  };

  // List responses are intentionally sparse. Once full details have been
  // fetched, a later search must not replace those fields with nulls/empties.
  if (!detailsFetched && (existing as SpeciesRow | null)?.details_fetched) {
    const detailed = existing as SpeciesRow;
    merged.other_names = detailed.other_names?.length
      ? detailed.other_names
      : row.other_names;
    merged.family = detailed.family ?? row.family;
    merged.genus = detailed.genus ?? row.genus;
    merged.cycle = detailed.cycle ?? row.cycle;
    merged.watering = detailed.watering ?? row.watering;
    merged.sunlight = detailed.sunlight?.length
      ? detailed.sunlight
      : row.sunlight;
    merged.indoor = detailed.indoor ?? row.indoor;
    merged.description = detailed.description ?? row.description;
    merged.care_level = detailed.care_level ?? row.care_level;
    merged.growth_rate = detailed.growth_rate ?? row.growth_rate;
    merged.raw = detailed.raw ?? row.raw;
  }

  // Keep primary columns aligned with arrays.
  merged.image_url = merged.image_urls[0] ?? merged.image_url ?? null;
  merged.cached_image_path =
    merged.cached_image_paths[0] ?? merged.cached_image_path ?? null;

  const { data, error } = await supabase
    .from("species_catalog")
    .upsert(merged)
    .select("*")
    .single();

  if (error) throw new Error(`Failed to upsert species ${row.id}: ${error.message}`);
  return normalizeSpeciesRow(data as SpeciesRow);
}

async function maybeMirrorImages(
  supabase: ReturnType<typeof createClient>,
  species: SpeciesRow,
): Promise<SpeciesRow> {
  const sourceUrls = (species.image_urls?.length
    ? species.image_urls
    : species.image_url
    ? [species.image_url]
    : []
  )
    .filter((url) => url && !url.includes("upgrade_access"))
    .slice(0, MAX_SPECIES_IMAGES);

  if (!sourceUrls.length) return species;

  const existingPaths = species.cached_image_paths ?? [];
  // Already mirrored a full set for the current URL count.
  if (
    existingPaths.length >= sourceUrls.length &&
    existingPaths.slice(0, sourceUrls.length).every((p) => Boolean(p))
  ) {
    return species;
  }

  const mirroredPaths: (string | null)[] = sourceUrls.map((_, i) =>
    existingPaths[i] || null
  );

  for (let i = 0; i < sourceUrls.length; i++) {
    if (mirroredPaths[i]) continue;

    const url = sourceUrls[i];
    try {
      const res = await fetch(url, {
        headers: { "User-Agent": "PlantPal/1.0 (species-cache)" },
      });
      if (!res.ok) continue;

      const bytes = new Uint8Array(await res.arrayBuffer());
      if (bytes.byteLength < 256) continue;

      const contentType = res.headers.get("content-type") ?? "image/jpeg";
      const ext = contentType.includes("png")
        ? "png"
        : contentType.includes("webp")
        ? "webp"
        : "jpg";
      const path = `${species.id}/${i}.${ext}`;

      const { error } = await supabase.storage
        .from("species-images")
        .upload(path, bytes, { contentType, upsert: true });
      if (error) {
        console.warn("image mirror failed", species.id, i, error.message);
        continue;
      }

      mirroredPaths[i] = path;
    } catch (err) {
      console.warn("image mirror error", species.id, i, err);
    }
  }

  // Parallel arrays: empty string marks "not mirrored yet" at that index.
  const paths = mirroredPaths.map((p) => p ?? "");
  if (!paths.some(Boolean)) return species;

  const { data, error: updateError } = await supabase
    .from("species_catalog")
    .update({
      image_urls: sourceUrls,
      cached_image_paths: paths,
      image_url: sourceUrls[0] ?? null,
      cached_image_path: paths.find((p) => p) ?? null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", species.id)
    .select("*")
    .single();

  if (updateError) return species;
  return normalizeSpeciesRow(data as SpeciesRow);
}

async function loadSpeciesByIds(
  supabase: ReturnType<typeof createClient>,
  ids: number[],
): Promise<SpeciesRow[]> {
  if (!ids.length) return [];
  const { data, error } = await supabase
    .from("species_catalog")
    .select("*")
    .in("id", ids);
  if (error) throw new Error(error.message);

  const byId = new Map(
    (data as SpeciesRow[]).map((s) => [s.id, normalizeSpeciesRow(s)]),
  );
  return ids.map((id) => byId.get(id)).filter(Boolean) as SpeciesRow[];
}

function toClientSpecies(row: SpeciesRow) {
  const normalized = normalizeSpeciesRow(row);
  const publicUrls = publicImageUrls(normalized);

  return {
    id: normalized.id,
    common_name: normalized.common_name,
    scientific_name: normalized.scientific_name,
    other_names: normalized.other_names ?? [],
    family: normalized.family,
    genus: normalized.genus,
    cycle: normalized.cycle,
    watering: normalized.watering,
    sunlight: normalized.sunlight ?? [],
    indoor: normalized.indoor,
    description: normalized.description,
    care_level: normalized.care_level,
    growth_rate: normalized.growth_rate,
    image_url: publicUrls[0] ?? null,
    image_urls: publicUrls,
    image_license: normalized.image_license,
    image_license_url: normalized.image_license_url,
    details_fetched: normalized.details_fetched,
  };
}

function normalizeSpeciesRow(row: SpeciesRow): SpeciesRow {
  const imageUrls = Array.isArray(row.image_urls)
    ? row.image_urls.filter((u) => Boolean(u))
    : row.image_url
    ? [row.image_url]
    : [];
  // Keep empty-string placeholders so indices stay aligned with image_urls.
  const rawPaths = Array.isArray(row.cached_image_paths)
    ? row.cached_image_paths
    : row.cached_image_path
    ? [row.cached_image_path]
    : [];
  const cachedPaths = imageUrls.map((_, i) => rawPaths[i] ?? "");

  return {
    ...row,
    image_urls: imageUrls.slice(0, MAX_SPECIES_IMAGES),
    cached_image_paths: cachedPaths.slice(0, MAX_SPECIES_IMAGES),
    image_url: imageUrls[0] ?? row.image_url ?? null,
    cached_image_path:
      cachedPaths.find((p) => Boolean(p)) ?? row.cached_image_path ?? null,
  };
}

function publicImageUrls(row: SpeciesRow): string[] {
  const base = Deno.env.get("SUPABASE_URL");
  const paths = row.cached_image_paths ?? [];
  const originals = row.image_urls?.length
    ? row.image_urls
    : row.image_url
    ? [row.image_url]
    : [];
  const urls: string[] = [];

  for (let i = 0; i < Math.min(originals.length, MAX_SPECIES_IMAGES); i++) {
    const path = paths[i];
    if (path && base) {
      urls.push(
        `${base}/storage/v1/object/public/species-images/${path}`,
      );
      continue;
    }
    const original = originals[i];
    if (original && !original.includes("upgrade_access")) {
      urls.push(original);
    }
  }

  return urls;
}

function collectImageUrls(item: Record<string, unknown>): string[] {
  const urls: string[] = [];
  const seen = new Set<string>();

  const push = (image: Record<string, unknown> | null) => {
    const url = pickImageUrl(image);
    if (!url || url.includes("upgrade_access") || seen.has(url)) return;
    seen.add(url);
    urls.push(url);
  };

  push((item.default_image ?? null) as Record<string, unknown> | null);

  const others = item.other_images;
  if (Array.isArray(others)) {
    for (const entry of others) {
      if (urls.length >= MAX_SPECIES_IMAGES) break;
      if (entry && typeof entry === "object") {
        push(entry as Record<string, unknown>);
      }
    }
  }

  return urls.slice(0, MAX_SPECIES_IMAGES);
}

function mergeUniqueUrls(primary: string[], secondary: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const url of [...primary, ...secondary]) {
    if (!url || url.includes("upgrade_access") || seen.has(url)) continue;
    seen.add(url);
    out.push(url);
    if (out.length >= MAX_SPECIES_IMAGES) break;
  }
  return out;
}

function buildSearchCacheKey(input: {
  q: string;
  page: number;
  indoor: boolean;
}) {
  return [
    "species-list",
    `q=${input.q.toLowerCase()}`,
    `page=${input.page}`,
    `indoor=${input.indoor ? 1 : 0}`,
  ].join("|");
}

function str(value: unknown): string | null {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length ? trimmed : null;
  }
  if (typeof value === "number") return String(value);
  return null;
}

function firstString(value: unknown): string | null {
  if (Array.isArray(value)) {
    for (const item of value) {
      const s = str(item);
      if (s) return s;
    }
    return null;
  }
  return str(value);
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    const single = str(value);
    return single ? [single] : [];
  }
  return value.map(str).filter((v): v is string => Boolean(v));
}

function hasUsableDetails(row: SpeciesRow): boolean {
  return Boolean(
    row.description ||
      row.care_level ||
      row.growth_rate
  );
}

function pickImageUrl(image: Record<string, unknown> | null): string | null {
  if (!image) return null;
  return (
    str(image.regular_url) ??
    str(image.medium_url) ??
    str(image.original_url) ??
    str(image.small_url) ??
    str(image.thumbnail)
  );
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
