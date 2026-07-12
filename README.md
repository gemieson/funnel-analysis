# Checkout Abandonment: Funnel Analysis & A/B Test Design

**Where does an e-commerce checkout funnel leak, why, and what experiment would actually fix it?**

SQL (BigQuery) · Python (statsmodels) · GA4 e-commerce event data (~270K users, ~92 days)

---

## TL;DR

- Built a six-step checkout funnel; the actionable leak is **shipping → payment**, where **41% of users** who enter shipping info never reach the payment step.
- Tested three abandonment hypotheses against user behavior. **Refuted the textbook explanation (cost surprise)** — droppers carry 3x *smaller* carts, not larger. Evidence supports **low purchase intent** as the dominant mechanism (droppers are 4x less likely to ever return).
- Found one real segment: **organic traffic converts 9.9pp worse than referral** at the payment step ([z-test: p = TODO]) — consistent with the intent mechanism.
- Since low intent can't be fixed with UI changes, **designed an A/B test targeting the recoverable population instead**: cart-recovery outreach to organic-channel abandoners, with a pre-registered decision rule and a power analysis sized to actual traffic volume.

**The arc:** measured the leak → proposed the textbook fix → the data killed it → found the real mechanism → aimed the experiment where it can win.

---

## 1. The Funnel

Six-step funnel from the GA4 event log: `view_item → add_to_cart → begin_checkout → add_shipping_info → add_payment_info → purchase`.

Defined two ways, because the definition changes the answer:

| Step | User-level (ever/never) | Session-level (per attempt) |
|---|---|---|
| view → cart | 0.205 | 0.197 |
| cart → checkout/shipping | 0.774 | 0.731 |
| **shipping → payment** | **0.592** | **0.614** |
| payment → purchase | 0.768 | 0.711 |

User-level asks "what share of *users* ever get through?"; session-level asks "what share of *checkout attempts* succeed?"

†begin_checkout and add_shipping_info co-occur in 100% of both users and sessions — effectively one event in this dataset, treated as a single step

The definitions nearly agree, and the reason why is itself a finding. The 9,714 users reaching shipping produced 11,105 attempts (~1.14 per user); per-attempt abandonment is 38.7% vs. 40.8% at the user level. Repeat attempts are rare and overwhelmingly successful — of ~1,400 retry sessions, only ~104 were repeat abandonments. In other words: abandoners almost never try again. One failed attempt, gone. This is the first hint of the low-intent mechanism established in §4. Session-level is used as the experiment baseline as the per-attempt operational view.


## 2. Choosing the Target

view→cart is numerically the biggest drop (79.5% loss), but those are casual browsers — most window-shoppers don't buy, and that's normal. **shipping→payment is the actionable leak**: these users viewed, carted, began checkout, and typed their address — then 41% walked away at the payment screen. High demonstrated intent, high loss, one screen.

## 3. Heterogeneity: Who Leaks?

Segmented both major leaks by device and traffic source.

- **Device:** flat at both steps (view→cart spread: 19.1–20.8%; shipping→payment: flat). No device effect.
- **Traffic source, view→cart:** modest (organic 18.9% vs. referral 22.1%).
- 
- 
- **Traffic source, shipping→payment:** the real finding —

| Medium | Shipping | Payment | Conversion |
|---|---|---|---|
| `<Other>` | 1,267 | 632 | 0.499 |
| cpc | 348 | 181 | 0.520 |
| **organic** | 3,111 | 1,698 | **0.546** |
| (none) | 2,223 | 1,300 | 0.585 |
| **referral** | 1,863 | 1,202 | **0.645** |

**Organic converts 9.9pp worse than referral** ([two-proportion z-test: p = TODO]). Referral users arrive via a specific link with specific intent; organic searchers browse. (cpc is also low but n=348 — noted, not leaned on.)

> Excluded: `(data deleted)` — an obfuscation artifact, not a real channel. It showed the *highest* rate in the table (0.309 at view→cart) and would have been the headline finding if taken at face value.

## 4. Mechanism: Why Do They Leave?

The funnel says *where*; it can't say *why*. Three candidate explanations, each with a testable behavioral fingerprint, checked by comparing **droppers** (reached shipping, never reached payment) vs. **completers**:

| Hypothesis | Prediction | Observed | Verdict |
|---|---|---|---|
| **Cost surprise** — shipping cost revealed at this step shocks users | Droppers have *bigger* carts | Droppers: **$26 median** vs. completers' $77 (means $52 vs. $210) | ✗ **Refuted** — opposite of predicted |
| **Form friction** — payment entry is painful | Droppers linger, struggling | 85.8s vs. 55.5s, but measured inconsistently across groups | ~ Inconclusive |
| **Low intent** — they were never really buying | Droppers vanish, never return | Droppers return within 24h at **9.7%** vs. completers' **40.4%** | ✓ **Supported** |

**Conclusion:** the payment-step leak is dominated by low purchase intent — small carts, no return. This converges with the channel finding (low-intent organic/cpc traffic leaks worst; high-intent referral leaks least). Two independent analyses, one mechanism.

**Consequence:** most of the 41% is not recoverable by improving the payment page. You cannot design someone into wanting a product. The experiment must target the slice with latent intent instead.

*Notes:* mechanism checks are user-level by design — return behavior and intent are properties of users, not sessions. The comparison is observational: falsification (cost surprise) is strong; the positive conclusion (low intent) is supported, not proven — which is exactly why the experiment exists. The ever/never split right-censors late converters (a user abandoning on day 90 who would convert on day 95 is misclassified) — a survival-analysis-shaped limitation, minor at this window length.

## 5. Experiment Design

**Population:** organic-channel checkout abandonments — the worst-converting, highest-volume segment (3,111 users reach shipping via organic).

**Hypothesis:** cart-recovery outreach (email with saved cart) increases purchase completion among abandoners with latent intent.

**Design:**
- **Randomization:** on the **user**, 50/50, triggered at **first abandonment**. (Per-session randomization would place repeat abandoners in both arms, contaminating the comparison.)
- **Treatment:** cart-recovery email with saved cart. **Control:** status quo — no contact.
- **Primary metric:** purchase within 7 days of abandonment.
- **Guardrails:** unsubscribe rate; revenue per user. Neither may degrade.
- **Baseline:** [TODO — session-level 7-day unprompted purchase rate after abandonment, organic channel]
- **Power analysis:** [TODO — α=0.05, power=0.80, MDE chosen to fit runtime given [TODO] daily eligible abandonments; statsmodels calculation in `analysis/power_analysis.py`]
- **Decision rule (pre-registered):** ship iff the primary metric lifts significantly at α=0.05 AND no guardrail degrades. Run full weeks; no interim peeking.
- **Validity:** randomization balance check at start; monitor for novelty effect.

**Why this experiment and not a payment-page fix:** the mechanism analysis bounds the opportunity. With ~90% of droppers never returning, a UI experiment on the payment step would chase users who were never buying. Re-engagement targets the ~10% with demonstrated latent intent.

## 6. Data Quality — Three Catches

This is an obfuscated public dataset, and three findings turned out to be artifacts rather than insights:

1. **checkout→shipping = 1.000** (user-level). Impossible — no funnel step converts perfectly. Likely event co-firing or an obfuscation artifact. [TODO: does the session-level funnel resolve this?]
2. **Category-level cart→purchase ratios > 1.0** — more buyers than carters, logically impossible. Root cause: view/cart events and purchase events use *inconsistent category taxonomies* (hierarchical paths vs. flat names), silently double-counting products. Category analysis excluded entirely rather than reported.
3. **`(data deleted)` as the "best-converting channel"** — a scrubbed placeholder value, not a channel. Excluded.

Each looked like a finding. None was. They are documented here because knowing what *not* to report is part of the analysis.

## 7. Limitations

- Obfuscated sample data with documented internal inconsistencies; results demonstrate method, not conclusions about the real store.
- Mechanism checks are observational and user-level; see §4 notes.
- `traffic_source` reflects the user's *acquisition* channel, not per-session source.
- Friction hypothesis untested cleanly — time-to-exit is measured differently for droppers (to last event) vs. completers (to payment).

## Repo Structure

```
├── README.md
├── sql/
│   ├── 00_data_quality.sql
│   ├── 01_funnel_user_level.sql
│   ├── 02a_segment_device.sql
│   ├── 02b_segment_traffic_source.sql
│   ├── 03_segment_payment_step.sql
│   ├── 10_session_extract.sql
│   ├── 11_session_funnel.sql
│   ├── 12_funnel_comparison.sql
│   ├── 14_repeat_attempts.sql
│   ├── 20_mechanism_cart_value.sql
│   ├── 21_mechanism_time_to_drop.sql
│   └── 22_mechanism_return_rate.sql
├── analysis/
│   ├── power_analysis.py
│   └── z_tests.py
└── figures/
    └── funnel_chart.png
```
