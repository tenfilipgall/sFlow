import { defineConfig } from "vitest/config";
import { cloudflareTest } from "@cloudflare/vitest-pool-workers";

export default defineConfig({
  plugins: [
    cloudflareTest({
      miniflare: {
        compatibilityDate: "2026-01-01",
        compatibilityFlags: ["nodejs_compat"],
        kvNamespaces: ["RULES_CACHE", "FEEDBACK", "RATE_LIMIT"],
      },
    }),
  ],
});
