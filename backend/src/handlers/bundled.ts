import type { Env } from "../index";

export async function handleBundled(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== "GET") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const [version, latest] = await Promise.all([
    env.RULES_CACHE.get("bundled:version"),
    env.RULES_CACHE.get("bundled:latest"),
  ]);

  if (!version || !latest) {
    return new Response(JSON.stringify({ error: "Not available" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({ version, rules: JSON.parse(latest) }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=3600",
      },
    },
  );
}
