import { FeedbackSchema } from "../types";
import type { Env } from "../index";

export async function handleFeedback(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonError(400, "Invalid JSON");
  }

  const parsed = FeedbackSchema.safeParse(body);
  if (!parsed.success) {
    return jsonError(400, `Invalid request: ${parsed.error.message}`);
  }
  const { bundleId, keys, reportType } = parsed.data;

  const feedbackKey = `feedback:${bundleId}`;
  const keysJoined = [...keys].sort().join("+");

  const raw = await env.FEEDBACK.get(feedbackKey);
  const counts: Record<string, number> = raw ? JSON.parse(raw) : {};
  counts[keysJoined] = (counts[keysJoined] ?? 0) + 1;
  await env.FEEDBACK.put(feedbackKey, JSON.stringify(counts));

  console.log(
    JSON.stringify({ type: "feedback", bundleId, keys, reportType, count: counts[keysJoined] }),
  );
  return new Response("OK", { status: 200 });
}

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
