# Proposed bundled rules

> Draft rule sets dla apek **jeszcze nie objętych** SFlow. Stworzone offline
> 2026-05-16 jako bumpery — gotowe do promotion do `bundled/` po **U-4
> (web-as-app)** w przypadku web apek, lub po reseedzie w przypadku natywnych.
>
> **Format:** identyczny z `bundled/*.json`. Klucz `bundleId` z prefix `web:`
> dla web apek.
>
> **Workflow:**
> 1. Po U-4 zaimplementowane → pseudo-bundleId `web:gmail.com` działa
> 2. `cp docs/proposed-bundled/web-mail.google.com.json bundled/web__mail.google.com.json`
>    (escape `:` → `__` w nazwie pliku, decyzja w U-4 plan §6 ryzyko 3)
> 3. Manual eval — kliknij każdą akcję, oznacz ✅/⚠️/❌ w
>    `docs/coverage-report.md`
> 4. Po 80%+ HIT — promote (oznacz `rulesVersion` z `-proposed` na `1.0`)

## Pliki

| Plik | Apka | Źródło reguł | Status |
|---|---|---|---|
| `web-mail.google.com.json` | Gmail | support.google.com/mail/answer/6594 | proposed, 20 rules |
| `web-github.com.json` | GitHub | docs.github.com/keyboard-shortcuts | proposed, 14 rules |
| `web-notion.so.json` | Notion (web) | notion.so/help/keyboard-shortcuts | proposed, 15 rules |

## Następne kandydaty (do napisania)

- `web-slack.com.json` (Slack web — Slack-app-like)
- `web-linear.app.json` (Linear web)
- `web-figma.com.json` (Figma web — wymaga U-7 tool-mode też)
- `web-docs.google.com.json` (Google Docs)
- `web-trello.com.json` (Trello)
- `web-app.asana.com.json` (Asana)

## Caveat — single-key mode requirement

Gmail wymaga że user **włączył skróty** w Settings → Keyboard shortcuts: ON.
Bez tego klawisze nie działają w Gmailu nawet po wyswipowaniu w SFlow.

**Implication dla SFlow:**
- Toast jest **prawdziwy** w sensie "ten skrót MOŻE działać" — ale wymaga
  jednorazowej konfiguracji
- Powinniśmy w Settings SFlow pokazać "Te apki wymagają włączenia
  keyboard shortcuts w samej apce: Gmail (Settings → Keyboard shortcuts), ..."
- Albo: pierwszy toast dla Gmaila → expanded "(wymaga: Settings → Keyboard
  shortcuts ON)"

**Status:** problemu nie rozwiązuje U-4 ani U-7 — to nowy P-X w przyszłej
sesji ("user-app config requirement disclosure"). Sub-cel 1.7 (beta) może
to złapać empirycznie — beta tester pokaże "te skróty nie działają u mnie".

---

*Folder utworzony 2026-05-16 offline przez AI jako pre-fetch dla U-4.*
