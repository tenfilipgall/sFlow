export interface Env {
  RULES_CACHE: KVNamespace;
  FEEDBACK: KVNamespace;
  RATE_LIMIT: KVNamespace;
  ANTHROPIC_API_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return new Response("SFlow Rules Worker", { status: 200 });
  },
};
