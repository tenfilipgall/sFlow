import { handleDiscover } from "./handlers/discover";
import { handleFeedback } from "./handlers/feedback";
import { handleBundled } from "./handlers/bundled";

export interface Env {
  RULES_CACHE: KVNamespace;
  FEEDBACK: KVNamespace;
  RATE_LIMIT: KVNamespace;
  ANTHROPIC_API_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/v1/discover") {
      return handleDiscover(request, env);
    }

    if (url.pathname === "/v1/feedback") {
      return handleFeedback(request, env);
    }

    if (url.pathname === "/v1/bundled") {
      return handleBundled(request, env);
    }

    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("SFlow Rules Worker", { status: 200 });
    }

    return new Response("Not Found", { status: 404 });
  },
};
