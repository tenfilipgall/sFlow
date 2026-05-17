# Pricing decision matrix — SFlow

> **Cel:** wybór modelu cenowego dla launch'u (Faza 6). Analizuje 3 modele
> z product-vision §6.1: A (one-time), B (subscription), C (free + B2B).
>
> **Decyzja czasowa:** po beta-debriefie (Sub-cel 1.7 + 2 tygodnie).

---

## Recap z product-vision

Filip rozważał:
- **A.** $25 one-time forever — najprostsze
- **B.** $5/mc subscription — recurring
- **C.** Free B2C + B2B team licensing

Sugestia w doc: **A dla pierwszych 100 userów (Gumroad), potem B z grandfathered.**

---

## 4-osiowa analiza

### Wymiary
- **Friction (F):** jak łatwo userowi przejść z trial do paid (1=trudne, 10=łatwe)
- **Revenue per user (R):** annualized $ value (estymata)
- **Retention pressure (Re):** stopień motywacji do utrzymania payment (1=brak, 10=duża)
- **Acquisition viability (A):** czy łatwo sprzedać 100 userów (1=trudne, 10=łatwe)

### Tabela

| Model | F | R/user/year | Re | A | Score (F+R/10+Re+A) |
|---|---|---|---|---|---|
| A. $25 one-time | 9 | $25 | 1 | 7 | **19.5** |
| B. $5/mc subscription | 5 | $60 | 7 | 4 | **22.0** |
| B'. $40/year billed yearly | 7 | $40 | 6 | 6 | **23.0** |
| C. Free + B2B ($5/user/mc, min 10) | 10 | $600/team | 8 | 3 | **27.0** for B2B teams; 0 dla solo |
| D. Freemium (free basic, $10/mc pro) | 10 | $30 (10% conv × $10/mc × 30%) | 7 | 8 | **28.0** |

### Wniosek wstępny

**D (freemium)** ma najwyższy total score, ALE wymaga assumption że
SFlow dostarcza dwa wyraźne tiers funkcjonalności. Co byłoby pro:
- ✓ Wszystkie warstwy detekcji
- ✓ Curriculum / lekcje (Faza 4)
- ✓ Tygodniowy raport (Faza 5)
- ✗ Free: tylko toasty + basic detection, top-5 apek

**Risk freemium:** dewaluacja produktu — power-userzy oczekują "wszystko
za darmo", convert rate niski. **Spotify problem.**

---

## Empiryczne benchmarki konkurencji

| Konkurent | Model | Cena | Co payed |
|---|---|---|---|
| KeyCue | one-time | $20 | wszystko |
| CheatSheet | freemium | $5 lifetime / free basic | pro: custom shortcuts |
| Keystroke Pro | subscription | $4.99/mc | wszystko |
| Mouseless | one-time | $10 | wszystko |
| BetterTouchTool (utility analog) | one-time | $20-30 | wszystko |

**Wniosek:** w tej kategorii dominuje **one-time $10-30**. Subscription
**niezaadoptowane** przez kategorię.

---

## Sequencing rekomendacja (refined)

**Faza 6.1 — pierwsze 100 userów (Q4 2026):**
- Model **A — $25 one-time** (zgodnie z product-vision sugestią)
- Sprzedaż przez Gumroad
- Lifetime updates (cheap implementation)
- **Cel:** waliduj willingness-to-pay + zbierz testimonials

**Faza 6.2 — pricing experiment (Q1 2027):**
- Model **D — freemium** test na nowym segment (npm enterprise dev'ów)
- Free: 5 apek, basic toasty
- Pro $10/mc: wszystkie apki, curriculum, raport
- A/B test za pomocą landing page A vs landing page D

**Faza 7 — B2B (Q2 2027+):**
- Model **C** dla team accounts ≥10 userów
- $4/user/mc billed annually = $480/year for 10-person team

---

## Edge case: Polski rynek

Filip jest w PL. $25 = ~100 PLN. PL software users akceptują 50-100 PLN
zakupu jednorazowego, ale **niechętnie subscription** poniżej 30 PLN/mc.
$5/mc = 20 PLN/mc — marginal.

**Implication:** dla PL marketu **lepszy** A. Dla US — może być D.
Geo-pricing rozważyć **po 100 userów + danych distribution**.

---

## Open questions wymagające beta debrief

1. **Czy testerzy zapłaciliby $25?** — explicit question w debrief
2. **Czy widzą wartość $5/mc?** — porównaj z innymi subskrypcjami (Spotify
   $9, Notion $8, etc.)
3. **Czy oczekują darmowej wersji?** — sprawdza freemium TAM
4. **Czy ich firma zapłaciłaby za team license?** — sprawdza B2B viability

Bez tych odpowiedzi → **default do A** (najmniej ryzyka, najprostsze
do walidacji).

---

*Pricing matrix napisany 2026-05-17 offline. Re-evaluate post beta-debrief.*
