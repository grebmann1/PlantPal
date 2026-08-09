// Proxies OpenAI translation of species-stable English API content and
 // permanently caches FR/DE overlays in species_i18n so each (kind, species,
 // locale) is translated at most once.
 //
 // Secrets required:
 //   OPENAI_API_KEY
 //   SUPABASE_URL (auto)
 //   SUPABASE_SERVICE_ROLE_KEY (auto)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";
const SUPPORTED_LOCALES = new Set(["de", "fr"]);
const SUPPORTED_KINDS = new Set(["care_guide", "ai_profile", "catalog"]);

interface TranslateRequest {
  kind: string;
  species_key: string;
  locale: string;
  fields: Record<string, unknown>;
  source_updated_at?: string | null;
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
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      return json(
        { error: "not_configured", message: "OPENAI_API_KEY is not set" },
        500,
      );
    }

    const body = (await req.json()) as TranslateRequest;
    const kind = (body.kind ?? "").trim();
    const speciesKey = (body.species_key ?? "").trim().toLowerCase();
    const locale = (body.locale ?? "").trim().toLowerCase();
    const fields = body.fields ?? {};

    if (!SUPPORTED_KINDS.has(kind)) {
      return json({ error: "bad_request", message: "invalid kind" }, 400);
    }
    if (!speciesKey) {
      return json({ error: "bad_request", message: "species_key is required" }, 400);
    }
    if (!SUPPORTED_LOCALES.has(locale)) {
      return json({ error: "bad_request", message: "locale must be de or fr" }, 400);
    }
    if (!fields || typeof fields !== "object" || Array.isArray(fields)) {
      return json({ error: "bad_request", message: "fields must be an object" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: existing } = await supabase
      .from("species_i18n")
      .select("*")
      .eq("kind", kind)
      .eq("species_key", speciesKey)
      .eq("locale", locale)
      .maybeSingle();

    if (existing?.fields) {
      return json({
        cached: true,
        kind,
        species_key: speciesKey,
        locale,
        fields: existing.fields,
      });
    }

    const translated = await translateFields(apiKey, locale, fields);
    const now = new Date().toISOString();

    const { error } = await supabase.from("species_i18n").upsert({
      kind,
      species_key: speciesKey,
      locale,
      fields: translated,
      source_updated_at: body.source_updated_at ?? null,
      updated_at: now,
    });

    if (error) {
      console.error("species_i18n upsert failed", error.message);
      // Still return the translation even if cache write fails.
    }

    return json({
      cached: false,
      kind,
      species_key: speciesKey,
      locale,
      fields: translated,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("translate-proxy error", message);
    return json({ error: "failed", message }, 500);
  }
});

async function translateFields(
  apiKey: string,
  locale: string,
  fields: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const languageName = locale === "de" ? "German" : "French";
  const payload = JSON.stringify(fields);
  const maxCompletionTokens = estimateMaxCompletionTokens(payload);

  const system = [
    `Translate plant-care JSON EN→${languageName}.`,
    "Same keys/nesting. Strings only; keep Latin names, numbers, units.",
    "JSON only.",
  ].join(" ");

  const upstream = await fetch(OPENAI_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      // Fast non-reasoning model — translation is a short structured rewrite.
      model: "gpt-4.1-nano",
      temperature: 0,
      max_completion_tokens: maxCompletionTokens,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system },
        { role: "user", content: payload },
      ],
    }),
  });

  if (!upstream.ok) {
    const text = await upstream.text();
    throw new Error(`OpenAI translate failed (${upstream.status}): ${text}`);
  }

  const data = await upstream.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("OpenAI returned empty translation");
  }

  const parsed = JSON.parse(content) as Record<string, unknown>;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("OpenAI returned non-object JSON");
  }
  return parsed;
}

/** Cap completion size to ~input size (with FR/DE expansion headroom). */
function estimateMaxCompletionTokens(payloadJson: string): number {
  // Rough char→token estimate for English JSON; translation can run ~1.5× longer.
  const approxInputTokens = Math.max(1, Math.ceil(payloadJson.length / 4));
  const withHeadroom = Math.ceil(approxInputTokens * 1.55) + 32;
  // Plant payloads are small; keep a tight floor/ceiling.
  return Math.min(900, Math.max(96, withHeadroom));
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
