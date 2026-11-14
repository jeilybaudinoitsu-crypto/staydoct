const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const tools = [
  {
    functionDeclarations: [
      {
        name: "dispatch_emergency_services",
        description:
          "Notifica al servicio de emergencias con la gravedad y un resumen. Úsala en cuanto conozcas la emergencia; no esperes a tener todos los detalles.",
        parameters: {
          type: "OBJECT",
          properties: {
            severity: {
              type: "STRING",
              enum: ["low", "moderate", "high", "critical"],
              description: "Gravedad estimada de la emergencia.",
            },
            summary: {
              type: "STRING",
              description:
                "Resumen de una frase para el despachador: qué ocurre, edad aproximada si se conoce, estado de consciencia y respiración.",
            },
            recommendations: {
              type: "ARRAY",
              items: { type: "STRING" },
              description: "De 2 a 4 acciones inmediatas y seguras para el usuario.",
            },
            needs_ambulance: {
              type: "BOOLEAN",
              description:
                "true si requiere ambulancia; false solo si requiere orientación o traslado propio.",
            },
          },
          required: ["severity", "summary", "recommendations"],
        },
      },
    ],
  },
];

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Cache-Control": "no-store",
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  if (!supabaseUrl || !geminiApiKey) {
    console.error("Missing SUPABASE_URL or GEMINI_API_KEY function secret.");
    return jsonResponse({ error: "AI service is not configured." }, 503);
  }

  const apiKey = request.headers.get("apikey");
  if (!apiKey) {
    return jsonResponse({ error: "Missing Supabase API key." }, 401);
  }

  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).length > 64_000) {
    return jsonResponse({ error: "Request is too large." }, 413);
  }

  let input: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(rawBody);
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return jsonResponse({ error: "Invalid request body." }, 400);
    }
    input = parsed as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "Invalid JSON request body." }, 400);
  }

  const incidentId = input.incident_id;
  const accessToken = input.access_token;
  const systemInstruction = input.system_instruction;
  const contents = input.contents;
  const validContents = Array.isArray(contents) &&
    contents.every((entry) => {
      if (typeof entry !== "object" || entry === null || Array.isArray(entry)) {
        return false;
      }
      const message = entry as Record<string, unknown>;
      if (
        (message.role !== "user" && message.role !== "model") ||
        !Array.isArray(message.parts) ||
        message.parts.length !== 1
      ) {
        return false;
      }
      const part = message.parts[0];
      if (typeof part !== "object" || part === null || Array.isArray(part)) {
        return false;
      }
      const text = (part as Record<string, unknown>).text;
      return typeof text === "string" && text.length <= 8_000;
    });
  if (
    typeof incidentId !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(incidentId) ||
    typeof accessToken !== "string" ||
    accessToken.length < 20 ||
    accessToken.length > 256 ||
    typeof systemInstruction !== "string" ||
    systemInstruction.length > 16_000 ||
    !Array.isArray(contents) ||
    contents.length === 0 ||
    contents.length > 60 ||
    !validContents
  ) {
    return jsonResponse({ error: "Invalid request fields." }, 400);
  }

  let validationResponse: Response;
  try {
    validationResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/get_emergency_status`,
      {
        method: "POST",
        headers: {
          apikey: apiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_incident_id: incidentId,
          p_access_token: accessToken,
        }),
      },
    );
  } catch (error) {
    console.error("Emergency access validation request failed.", error);
    return jsonResponse({ error: "Unable to validate emergency access." }, 503);
  }

  if (!validationResponse.ok) {
    console.error(
      "Emergency access validation failed.",
      validationResponse.status,
    );
    return jsonResponse(
      { error: "Invalid or expired emergency access." },
      validationResponse.status >= 500 ? 503 : 403,
    );
  }

  const model = Deno.env.get("GEMINI_MODEL") || "gemini-2.0-flash";
  const geminiUrl = new URL(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
  );
  geminiUrl.searchParams.set("key", geminiApiKey);

  let geminiResponse: Response;
  try {
    geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: AbortSignal.timeout(30_000),
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: systemInstruction }],
        },
        contents,
        tools,
        toolConfig: {
          functionCallingConfig: { mode: "AUTO" },
        },
        generationConfig: {
          temperature: 0.35,
          topP: 0.9,
          maxOutputTokens: 700,
        },
        safetySettings: [
          {
            category: "HARM_CATEGORY_DANGEROUS_CONTENT",
            threshold: "BLOCK_ONLY_HIGH",
          },
          {
            category: "HARM_CATEGORY_HARASSMENT",
            threshold: "BLOCK_ONLY_HIGH",
          },
        ],
      }),
    });
  } catch (error) {
    console.error("Gemini request failed.", error);
    return jsonResponse({ error: "AI service is unavailable." }, 502);
  }

  const responseBody = await geminiResponse.text();
  return new Response(responseBody, {
    status: geminiResponse.status,
    headers: {
      ...corsHeaders,
      "Cache-Control": "no-store",
      "Content-Type": "application/json",
    },
  });
});
