import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_URL = "https://api.openai.com/v1/responses";
const IDENTIFY_MODEL = "gpt-4.1";
const HEALTH_MODEL = "gpt-4.1";
const TEXT_MODEL = "gpt-4.1";
const PLANT_EXPERT_MODEL = "gpt-5.6-luna";
const UPSTREAM_TIMEOUT_MS = 25000;
const MAX_CHAT_TURNS = 12;

type Task = "identify" | "health" | "care_guide" | "plant_expert";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  image_base64?: string;
  image_mime_type?: string;
}

interface RequestImage {
  image_base64: string;
  image_mime_type?: string;
}

interface RequestBody {
  task: Task;
  image_base64?: string;
  image_mime_type?: string;
  images?: RequestImage[];
  species_latin_name?: string;
  species_common_name?: string;
  messages?: ChatMessage[];
  plant_context?: string;
}

const IDENTIFY_SCHEMA = {
  type: "object",
  properties: {
    species_common_name: { type: "string" },
    species_latin_name: { type: "string" },
    family: { type: "string" },
    confidence: { type: "number" },
    light_requirement: { type: "string" },
    watering_interval_days: { type: "integer" },
    alternate_matches: {
      type: "array",
      items: {
        type: "object",
        properties: {
          species_common_name: { type: "string" },
          species_latin_name: { type: "string" },
          confidence: { type: "number" },
        },
        required: ["species_common_name", "species_latin_name", "confidence"],
        additionalProperties: false,
      },
    },
    description: { type: ["string", "null"] },
    native_region: { type: ["string", "null"] },
    mature_size: { type: ["string", "null"] },
    growth_rate: { type: ["string", "null"] },
    toxicity: { type: ["string", "null"] },
    fun_fact: { type: ["string", "null"] },
  },
  required: [
    "species_common_name",
    "species_latin_name",
    "family",
    "confidence",
    "light_requirement",
    "watering_interval_days",
    "alternate_matches",
    "description",
    "native_region",
    "mature_size",
    "growth_rate",
    "toxicity",
    "fun_fact",
  ],
  additionalProperties: false,
};

const HEALTH_SCHEMA = {
  type: "object",
  properties: {
    status: { type: "string", enum: ["Healthy", "Needs Attention", "At Risk"] },
    health_score: { type: "integer" },
    issues: {
      type: "array",
      items: {
        type: "object",
        properties: {
          label: { type: "string" },
          severity: {
            type: "string",
            enum: ["Watch", "Mild", "Moderate", "Severe"],
          },
        },
        required: ["label", "severity"],
        additionalProperties: false,
      },
    },
    recommendations: { type: "array", items: { type: "string" } },
  },
  required: ["status", "health_score", "issues", "recommendations"],
  additionalProperties: false,
};

const CARE_GUIDE_SCHEMA = {
  type: "object",
  properties: {
    light_requirement: { type: "string" },
    watering_frequency: { type: "string" },
    watering_amount: { type: "string" },
    soil_mix: { type: "string" },
    temperature_range: { type: "string" },
    humidity_range: { type: "string" },
    difficulty_level: { type: "integer" },
    common_problems: {
      type: "array",
      items: {
        type: "object",
        properties: {
          problem: { type: "string" },
          cause: { type: "string" },
          fix: { type: "string" },
          recovery_time: { type: "string" },
        },
        required: ["problem", "cause", "fix", "recovery_time"],
        additionalProperties: false,
      },
    },
  },
  required: [
    "light_requirement",
    "watering_frequency",
    "watering_amount",
    "soil_mix",
    "temperature_range",
    "humidity_range",
    "difficulty_level",
    "common_problems",
  ],
  additionalProperties: false,
};

const PLANT_EXPERT_SCHEMA = {
  type: "object",
  properties: {
    reply: { type: "string" },
  },
  required: ["reply"],
  additionalProperties: false,
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      Connection: "keep-alive",
    },
  });
}

function openAIBody(
  model: string,
  instructions: string,
  input: unknown[],
  schemaName: string,
  schema: unknown,
  maxOutputTokens = 1200,
  reasoningEffort?: "none" | "low" | "medium" | "high",
) {
  const body: Record<string, unknown> = {
    model,
    instructions,
    input,
    max_output_tokens: maxOutputTokens,
    store: false,
    text: {
      format: {
        type: "json_schema",
        name: schemaName,
        schema,
        strict: true,
      },
    },
  };
  if (reasoningEffort) {
    body.reasoning = { effort: reasoningEffort };
  }
  return body;
}

async function openAI(body: unknown) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  try {
    const res = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    if (!res.ok) {
      throw new Error(`OpenAI error ${res.status}: ${await res.text()}`);
    }
    return res;
  } catch (err) {
    if (err instanceof DOMException && err.name === "AbortError") {
      throw new Error("OpenAI request timed out upstream");
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

function outputText(data: any) {
  return (
    data.output_text ??
    data.output?.flatMap((o: any) => o.content ?? []).find((c: any) =>
      c.type === "output_text"
    )?.text
  );
}

async function buffered(
  model: string,
  instructions: string,
  input: unknown[],
  schemaName: string,
  schema: unknown,
  maxOutputTokens = 1200,
  reasoningEffort?: "none" | "low" | "medium" | "high",
) {
  const data = await (await openAI(
    openAIBody(
      model,
      instructions,
      input,
      schemaName,
      schema,
      maxOutputTokens,
      reasoningEffort,
    ),
  )).json();
  const text = outputText(data);
  if (!text) throw new Error("No output_text in OpenAI response");
  return JSON.parse(text);
}

function userContent(items: unknown[]) {
  return [{ role: "user", content: items }];
}

function requestImages(body: RequestBody): RequestImage[] {
  const images = Array.isArray(body.images)
    ? body.images
      .filter((image) =>
        image && typeof image.image_base64 === "string" &&
        image.image_base64.length > 0
      )
      .slice(0, 5)
    : [];
  if (images.length > 0) return images;
  if (body.image_base64) {
    return [{
      image_base64: body.image_base64,
      image_mime_type: body.image_mime_type,
    }];
  }
  return [];
}

function imageParts(images: RequestImage[]): unknown[] {
  return images.map((image) => ({
    type: "input_image",
    image_url: `data:${image.image_mime_type ?? "image/jpeg"};base64,${image.image_base64}`,
  }));
}

function normalizeMessages(raw: ChatMessage[] | undefined): ChatMessage[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((m) => {
      if (!m || (m.role !== "user" && m.role !== "assistant")) return false;
      const text = typeof m.content === "string" ? m.content.trim() : "";
      const hasImage = typeof m.image_base64 === "string" &&
        m.image_base64.length > 0;
      // Assistants need text; users may send image-only.
      if (m.role === "assistant") return text.length > 0;
      return text.length > 0 || hasImage;
    })
    .map((m) => ({
      role: m.role,
      content: typeof m.content === "string" ? m.content.trim() : "",
      image_base64: typeof m.image_base64 === "string" && m.image_base64.length > 0
        ? m.image_base64
        : undefined,
      image_mime_type: typeof m.image_mime_type === "string" &&
          m.image_mime_type.length > 0
        ? m.image_mime_type
        : undefined,
    }))
    .slice(-MAX_CHAT_TURNS);
}

function toPlantExpertInput(messages: ChatMessage[]): unknown[] {
  return messages.map((m) => {
    if (m.role === "assistant") {
      return { role: "assistant", content: m.content };
    }

    const parts: unknown[] = [];
    if (m.content) {
      parts.push({ type: "input_text", text: m.content });
    }
    if (m.image_base64) {
      const mime = m.image_mime_type ?? "image/jpeg";
      parts.push({
        type: "input_image",
        image_url: `data:${mime};base64,${m.image_base64}`,
      });
    }
    if (parts.length === 0) {
      parts.push({
        type: "input_text",
        text: "Please look at this plant photo and advise.",
      });
    }
    // Text-only stays a plain string for compatibility with prior turns.
    if (parts.length === 1 && !m.image_base64) {
      return { role: "user", content: m.content };
    }
    return { role: "user", content: parts };
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }
  if (!OPENAI_API_KEY) {
    return jsonResponse({
      error: "Server not configured: missing OPENAI_API_KEY",
    }, 500);
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  try {
    if (body.task === "identify") {
      const images = requestImages(body);
      if (images.length === 0) {
        return jsonResponse({ error: "at least one image is required for identify" }, 400);
      }
      const instructions =
        "You are a botanist. Identify the houseplant quickly and precisely from visible leaf shape, venation, texture, growth habit, and coloration. Return the best Latin binomial and up to 3 plausible alternatives. Keep descriptive fields concise. Also always populate: a 2-3 sentence general description of the species; its native_region (short phrase); mature_size (short phrase, indoor context); growth_rate (short phrase); toxicity (short phrase noting risk to pets/humans, or 'Non-toxic' if safe); and one short interesting fun_fact about the species. Use null only if truly identifiable information does not apply.";
      const items = [
        {
          type: "input_text",
          text: "Identify this plant using all provided photos as views of the same specimen.",
        },
        ...imageParts(images),
      ];
      const result = await buffered(
        IDENTIFY_MODEL,
        instructions,
        userContent(items),
        "plant_identification",
        IDENTIFY_SCHEMA,
      );
      return jsonResponse({ task: "identify", result });
    }

    if (body.task === "health") {
      const images = requestImages(body);
      if (images.length === 0) {
        return jsonResponse({ error: "at least one image is required for health" }, 400);
      }
      const hint = body.species_latin_name
        ? ` The plant is a ${body.species_latin_name}.`
        : "";
      const instructions =
        `You are a plant pathologist. Assess visible plant health.${hint} Return a concise status, score, issues, and concrete recommendations.`;
      const items = [
        {
          type: "input_text",
          text: "Assess this plant's health using all provided photos as views of the same specimen.",
        },
        ...imageParts(images),
      ];
      const result = await buffered(
        HEALTH_MODEL,
        instructions,
        userContent(items),
        "plant_health_assessment",
        HEALTH_SCHEMA,
      );
      return jsonResponse({ task: "health", result });
    }

    if (body.task === "care_guide") {
      const species = body.species_latin_name || body.species_common_name;
      if (!species) {
        return jsonResponse({ error: "species name is required" }, 400);
      }
      const instructions =
        "You are a horticulture expert. Generate a concise practical indoor care guide.";
      const items = [{
        type: "input_text",
        text: `Generate a care guide for: ${species}`,
      }];
      const result = await buffered(
        TEXT_MODEL,
        instructions,
        userContent(items),
        "plant_care_guide",
        CARE_GUIDE_SCHEMA,
      );
      return jsonResponse({ task: "care_guide", result });
    }

    if (body.task === "plant_expert") {
      const messages = normalizeMessages(body.messages);
      if (messages.length === 0) {
        return jsonResponse({ error: "messages are required for plant_expert" }, 400);
      }
      if (messages[messages.length - 1].role !== "user") {
        return jsonResponse({
          error: "last message must be from the user",
        }, 400);
      }

      const context = (body.plant_context ?? "").trim().slice(0, 2000);
      const instructions = [
        "You are PlantPal's Plant Expert — a practical horticulture advisor for houseplants and balcony plants.",
        "Answer only plant-care questions about the specimen described in the context (watering, light, soil, pests, placement, feeding, recovery).",
        "When the user attaches a photo, use it to ground your advice (symptoms, leaf condition, potting, light).",
        "Use the specimen context when relevant. If context is missing a detail, say what you are assuming.",
        "Keep replies short, concrete, and actionable (usually 2–6 sentences). Prefer plain language over jargon.",
        "Refuse medical, legal, or non-plant topics politely and steer back to plant care.",
        "Do not invent exact sensor readings you were not given.",
        context
          ? `Specimen context:\n${context}`
          : "Specimen context: (none provided — ask clarifying questions if needed.)",
      ].join("\n\n");

      const input = toPlantExpertInput(messages);

      const result = await buffered(
        PLANT_EXPERT_MODEL,
        instructions,
        input,
        "plant_expert_reply",
        PLANT_EXPERT_SCHEMA,
        900,
        "low",
      );
      return jsonResponse({ task: "plant_expert", result });
    }

    return jsonResponse({
      error: "Unknown task. Use identify | health | care_guide | plant_expert",
    }, 400);
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: String(err) }, 502);
  }
});
