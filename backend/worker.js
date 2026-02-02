const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

const STILLFRESH_SCHEMA = {
  name: "stillfresh_receipt_v1",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["scan_group_id", "items", "meta"],
    properties: {
      scan_group_id: { type: "string" },
      items: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: [
            "id",
            "name",
            "normalized_name",
            "category",
            "is_perishable",
            "perishability_confidence",
            "default_storage",
            "expiry",
            "assumptions",
          ],
          properties: {
            id: { type: "string" },
            name: { type: "string" },
            normalized_name: { type: "string" },
            category: { type: "string" },

            is_perishable: { type: "boolean" },
            perishability_confidence: { type: "number", minimum: 0, maximum: 1 },

            default_storage: { type: "string", enum: ["outside", "fridge", "freezer"] },

            expiry: {
              type: "object",
              additionalProperties: false,
              required: ["outside", "fridge", "freezer"],
              properties: {
                outside: {
                  type: "object",
                  additionalProperties: false,
                  required: ["date", "days_from_now"],
                  properties: {
                    date: { type: "string" }, // YYYY-MM-DD
                    days_from_now: { type: "integer", minimum: 0 },
                  },
                },
                fridge: {
                  type: "object",
                  additionalProperties: false,
                  required: ["date", "days_from_now"],
                  properties: {
                    date: { type: "string" },
                    days_from_now: { type: "integer", minimum: 0 },
                  },
                },
                freezer: {
                  type: "object",
                  additionalProperties: false,
                  required: ["date", "days_from_now"],
                  properties: {
                    date: { type: "string" },
                    days_from_now: { type: "integer", minimum: 0 },
                  },
                },
              },
            },

            assumptions: { type: "array", items: { type: "string" } },
          },
        },
      },
      meta: {
        type: "object",
        additionalProperties: false,
        required: ["timezone", "receipt_language", "partial_scan", "warnings"],
        properties: {
          timezone: { type: "string" },
          receipt_language: { type: "string" },
          partial_scan: { type: "boolean" },
          warnings: { type: "array", items: { type: "string" } },
        },
      },
    },
  },
};

const SYSTEM_PROMPT = `You are a food inventory and perishability expert.

Analyze a grocery receipt image and extract ONLY food items that are perishable or semi-perishable.

You must:
- Ignore non-food items
- Ignore shelf-stable items with long lifespans (e.g., canned food, dry grains, spices)
- Normalize abbreviated or truncated item names
- Infer realistic perishability and storage behavior for an average household
- Estimate expiration dates based on TODAY, receipt context, and common food safety guidelines

For EACH item, you must:
1. Provide a clean, user-friendly name
2. Provide a normalized canonical name
3. Classify the food category
4. Decide whether it is perishable
5. Assign a perishability confidence (0.0–1.0)
6. Determine the DEFAULT storage (outside, fridge, freezer)
7. Provide expiration dates for outside/fridge/freezer
8. Include assumptions made (if any)

IMPORTANT RULES:
- Always return all three storage expiry options
- Expiry dates must be realistic, conservative, and safety-first
- If uncertain, choose shorter expiry rather than longer
- Use ISO date format (YYYY-MM-DD)
- Output must be valid JSON only (no markdown, no extra keys).`;

async function callOpenAI({ apiKey, model, scan_group_id, timezone, partial_scan, image_data_url }) {
  const payload = {
    model,
    input: [
      {
        role: "system",
        content: [{ type: "text", text: SYSTEM_PROMPT }],
      },
      {
        role: "user",
        content: [
          {
            type: "text",
            text:
              `scan_group_id: ${scan_group_id}\n` +
              `timezone: ${timezone}\n` +
              `partial_scan: ${partial_scan}\n` +
              `Return items and meta exactly per schema.`,
          },
          {
            type: "input_image",
            image_url: image_data_url, // must be a data URL
          },
        ],
      },
    ],
    text: {
      format: {
        type: "json_schema",
        name: STILLFRESH_SCHEMA.name,
        strict: true,
        schema: STILLFRESH_SCHEMA.schema,
      },
    },
  };

  const res = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenAI error ${res.status}: ${errText}`);
  }

  const data = await res.json();

  // Find structured output text
  const out = data.output || [];
  for (const item of out) {
    if (item.type === "message") {
      const content = item.content || [];
      for (const c of content) {
        if (c.type === "output_text" && typeof c.text === "string") {
          return JSON.parse(c.text);
        }
      }
    }
  }

  if (typeof data.output_text === "string") {
    return JSON.parse(data.output_text);
  }

  throw new Error("Could not find structured JSON in OpenAI response.");
}

export default {
  async fetch(request, env) {
    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, service: "stillfresh-worker" });
    }

    if (request.method !== "POST" || url.pathname !== "/classify") {
      return json({ error: "Use POST /classify or GET /health" }, 404);
    }

    try {
      const body = await request.json();

      const scan_group_id = body.scan_group_id || crypto.randomUUID();
      const timezone = body.timezone || "America/Los_Angeles";
      const partial_scan = body.partial_scan ?? true;
      const image_data_url = body.image_data_url;

      if (!image_data_url || typeof image_data_url !== "string" || !image_data_url.startsWith("data:image/")) {
        return json(
          { error: "Missing/invalid image_data_url. Provide a data:image/...;base64,... string." },
          400
        );
      }

      const apiKey = env.OPENAI_API_KEY;
      if (!apiKey) {
        return json({ error: "OPENAI_API_KEY not configured in Worker secrets." }, 500);
      }

      // Pick a vision-capable model; you can change later.
      const model = env.OPENAI_MODEL || "gpt-4.1-mini";

      const result = await callOpenAI({
        apiKey,
        model,
        scan_group_id,
        timezone,
        partial_scan,
        image_data_url,
      });

      // Ensure scan_group_id is echoed (even if model didn't)
      result.scan_group_id = result.scan_group_id || scan_group_id;

      return json(result);
    } catch (e) {
      return json({ error: String(e?.message || e) }, 500);
    }
  },
};
