# Checkout Abandonment: Funnel Analysis and A/B Test Design

**Where does an e-commerce checkout funnel leak, why, and what experiment would actually fix it?**

SQL (BigQuery) | Python (statsmodels) | GA4 e-commerce event data, 270K+ users, 92 days

---

## TL;DR

- Built a five-step checkout funnel. The actionable leak is **shipping to payment**, where **39% of checkout attempts** are abandoned.
- Tested three abandonment hypotheses. **Refuted the textbook explanation, cost surprise**: droppers carry 3x smaller carts, not larger. Evidence supports **low purchase intent**: droppers are 4x less likely to return (p < 0.001) and almost never retry.
- Found one real segment: **organic traffic converts 9.9pp worse than referral** at the payment step (p < 0.001).
- Since low intent cannot be fixed with UI changes, **designed an A/B test for the recoverable population instead**: cart-recovery outreach to organic-channel abandoners, with a pre-registered decision rule and a power analysis sized to real traffic.


---

## 1. The Funnel

Five steps from the GA4 event log: view_item, add_to_cart, begin_checkout/add_shipping_info, add_payment_info, purchase.

Defined two ways, because the definition changes the answer:

| Step | User-level (ever/never) | Session-level (per attempt) |
|---|---|---|
| view to cart | 0.205 | 0.197 |
| cart to checkout/shipping* | 0.774 | 0.731 |
| **shipping to payment** | **0.592** | **0.614** |
| payment to purchase | 0.768 | 0.711 |

User-level asks what share of users ever get through. Session-level asks what share of checkout attempts succeed.

## 2. Choosing the Target

view to cart is the biggest numerical drop, but those are casual browsers and that attrition is normal. Shipping to payment is the actionable leak: these users viewed, carted, began checkout, and typed their address, then 39% of attempts ended there. High demonstrated intent, one screen.

## 3. Heterogeneity: Who Leaks?

Segmented both leaks by device and traffic source. Device is flat at both steps. Traffic source at view to cart is modest. Traffic source at the payment step is the real finding:

| Medium | Shipping | Payment | Conversion |
|---|---|---|---|
| Other | 1,267 | 632 | 0.499 |
| cpc | 348 | 181 | 0.520 |
| **organic** | 3,111 | 1,698 | **0.546** |
| none (direct) | 2,223 | 1,300 | 0.585 |
| **referral** | 1,863 | 1,202 | **0.645** |

**Organic converts 9.9pp worse than referral** (two-proportion z-test: z = -6.88, p < 0.001). Referral users arrive through a specific link with specific intent; organic searchers browse. At these sample sizes significance is expected, so the meaningful result is the magnitude. The "(data deleted)" channel was excluded as an obfuscation artifact despite showing the highest raw conversion (see Data Quality).

## 4. Mechanism: Why Do They Leave?

Three candidate explanations, each with a testable prediction, checked by comparing droppers (reached shipping, never reached payment) against completers:

| Hypothesis | Prediction | Observed | Verdict |
|---|---|---|---|
| **Cost surprise**: shipping cost shocks users | Droppers have bigger carts | Droppers: $26 median vs. $77 | **Refuted**, opposite of predicted |
| **Form friction**: payment entry is painful | Droppers linger | 85.8s vs. 55.5s, measured inconsistently | Inconclusive |
| **Low intent**: never really buying | Droppers vanish | 9.7% return vs. 40.4% (z = -33.16, p < 0.001) | **Supported** |

**Conclusion:** the leak is dominated by low purchase intent. Three independent lines of evidence converge: small carts, no return, no retry. The channel gap fits the same picture, since low-intent organic traffic leaks worst and high-intent referral leaks least. Most of the 39% is not recoverable by improving the payment page. The experiment must target the slice with latent intent.

## 5. Experiment Design

**Population:** all-channel checkout abandonments (~46 eligible per day). Organic, the worst-converting channel, is a pre-registered subgroup analysis: at ~15 per day it is underpowered as a primary population.

**Eligibility:** a session that reaches shipping info without reaching payment. Session-based by necessity: defining abandoners as never-paid users makes later purchase impossible by construction (see Data Quality).

**Hypothesis:** cart-recovery outreach (email with saved cart) increases purchase completion among abandoners with latent intent.

**Design:**

- **Randomization:** on the user, 50/50, triggered at first abandonment. Per-session randomization would place repeat abandoners in both arms, contaminating the comparison.
- **Treatment:** cart-recovery email with saved cart. **Control:** status quo, no contact.
- **Primary metric:** purchase within 7 days of first abandonment.
- **Guardrails:** unsubscribe rate; revenue per user. Neither may degrade.
- **Baseline:** 2.84% purchase unprompted within 7 days (119 of 4,189 abandoners).
- **Power analysis:** alpha 0.05, power 0.80, MDE +2.0pp requires 1,425 users per arm, roughly 9 weeks at 46 per day (`analysis/power_analysis.py`).
- **Decision rule (pre-registered):** ship iff the primary metric lifts significantly at alpha 0.05 AND no guardrail degrades. Run full weeks; no interim peeking.
- **Validity:** randomization balance check at start; monitor for novelty effect.

**The power constraint is a finding, not a footnote.** Effects below ~2pp are undetectable in a practical window at this traffic, and +2pp on a 2.84% baseline is a 70% relative lift. The test is powered only for a large effect; a modest real improvement of +1pp would take 8 months to detect. The MDE was chosen as the smallest effect measurable in a two-month runtime.

**Why this experiment and not a payment-page fix:** the mechanism analysis bounds the opportunity. With 90% of droppers never returning, a UI experiment on the payment step would chase users who were never buying. Re-engagement targets the roughly 10% with demonstrated latent intent.


## 6. Limitations

- Obfuscated sample data with documented internal inconsistencies; results demonstrate method, not conclusions about the real store.
- Mechanism checks are observational and user-level; see §4 notes.
- `traffic_source` reflects the user's *acquisition* channel, not per-session source.
- Friction hypothesis untested cleanly — time-to-exit is measured differently for droppers (to last event) vs. completers (to payment).
