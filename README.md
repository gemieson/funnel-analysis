# Checkout Abandonment: Funnel Analysis and A/B Test Design

**Where does an e-commerce checkout funnel leak, why, and what experiment would fix it?**

SQL (BigQuery) | Python (statsmodels) | GA4 e-commerce data, 270K+ users, 92 days

---

## TL;DR

- The actionable leak is shipping to payment, where **39% of checkout attempts** are abandoned.
- Cost surprise, the textbook explanation, is **refuted**. Abandoners carry a quarter the basket value of completers, not more.
- Evidence points to **low intent**. Only 2.84% of abandoners buy anything in the next 7 days.
- Organic traffic converts 9.9pp worse than referral at the payment step (z = -6.88, p < 0.001).
- Low intent cannot be fixed with UI, so the experiment targets re-engagement instead, with a power analysis showing the test is only viable for a large effect.

---

## 1. The Funnel

view_item, add_to_cart, add_shipping_info, add_payment_info, purchase.

| Step | User-level | Session-level |
|---|---|---|
| view to cart | 0.205 | 0.197 |
| cart to shipping | 0.774 | 0.731 |
| **shipping to payment** | **0.592** | **0.614** |
| payment to purchase | 0.768 | 0.711 |

Session rates are lower everywhere except shipping to payment, the one step where some users attempt repeatedly and fail every time. That pattern foreshadows the mechanism finding.

## 2. Choosing the Target

View to cart is the bigger drop, but that is browsers leaving, which is normal. Shipping to payment is actionable. These users typed their address, then 39% of attempts ended. High demonstrated intent, one screen.

## 3. Who Leaks?

Device is flat at both steps. Traffic source at the payment step is the finding:

| Medium | Shipping | Payment | Conversion |
|---|---|---|---|
| Other | 1,267 | 632 | 0.499 |
| cpc | 348 | 181 | 0.520 |
| **organic** | 3,111 | 1,698 | **0.546** |
| none (direct) | 2,223 | 1,300 | 0.585 |
| **referral** | 1,863 | 1,202 | **0.645** |

Organic converts 9.9pp worse than referral (z = -6.88, p < 0.001). Referral users arrive through a specific link. Organic searchers browse. At these sample sizes significance is automatic, so the magnitude is the result. "(data deleted)" was excluded as an obfuscation artifact.

## 4. Why Do They Leave?

Three explanations, each with a prediction that could fail. Unit of analysis is stated per row rather than assumed.

| Hypothesis | Prediction | Observed | Unit | Verdict |
|---|---|---|---|---|
| Cost surprise | Abandoners have bigger baskets | $14 vs $57 median | session | **Refuted**, opposite sign |
| Form friction | Abandoners linger | 75.8s vs 49.4s, asymmetric | session | Inconclusive |
| Low intent | Abandoners do not return | 2.84% purchase in 7 days | user | **Supported** |

**Cost surprise.** Basket value is summed within the abandonment session and cut off at the shipping event, so it reflects what was on screen when the user walked away. The prediction was directional and the sign came out backwards, so no significance test is needed to call it.

**Form friction.** Right direction, unusable measurement. Completers are timed to their payment click and abandoners to the end of their session, which are not the same quantity. The upper tail runs past 90 minutes in a single session, which is a browser tab left open rather than someone deliberating. Event logs record clicks, not attention.

**Low intent.** Anchored on each user's first abandonment and measured forward 7 days, 119 of 4,189 users bought anything at all.

Two lines of evidence support low intent, and they are not fully independent, since small baskets and non-return both follow from casual browsing. The implication holds either way. Most of the 39% is not recoverable by fixing the payment page, and the channel gap fits the same picture, with low-intent organic leaking worst and high-intent referral leaking least.

## 5. Experiment Design

**Population:** all-channel abandonments, roughly 46 per day. Organic is a pre-registered subgroup, since at roughly 15 per day it is underpowered as a primary population.

**Eligibility:** a session that reaches shipping without reaching payment. Session-based by necessity, because defining abandoners as never-paid users makes later purchase impossible by construction.

**Hypothesis:** cart-recovery email increases purchase completion among abandoners with latent intent.

- **Randomization:** user-level, 50/50, triggered at first abandonment. Per-session randomization would split repeat abandoners across both arms.
- **Primary metric:** purchase within 7 days. **Baseline:** 2.84%.
- **Guardrails:** unsubscribe rate and revenue per user. Neither may degrade.
- **Power:** alpha 0.05, power 0.80, MDE +2.0pp requires 1,425 users per arm, roughly 9 weeks.
- **Decision rule, pre-registered:** ship only if the primary metric lifts at alpha 0.05 **and** no guardrail degrades. Run full weeks with no interim peeking.

**If purchases lift but unsubscribes rise**, the rule says do not ship. That is the realistic outcome for recovery email and the reason revenue per user is a guardrail rather than a secondary metric. The next step would be reducing send frequency, not overriding the rule.

**The power constraint is a finding, not a footnote.** A lift of +2pp on a 2.84% baseline is a 70% relative lift. The test can only detect a large effect, and a plausible +1pp improvement would take eight months to detect. The MDE was chosen as the smallest effect measurable in a two-month runtime, not as a guess at the true effect.

**Why not a payment-page fix:** with 97% of abandoners not purchasing within a week, a UI test would chase users who were never buying.

## 6. Limitations

- Obfuscated sample data with documented inconsistencies. Results demonstrate method, not conclusions about the real store.
- The basket comparison covers same-session carters only, 1,574 of 4,294 abandonment sessions. The other 63% carted on an earlier visit and arguably arrived with more intent, so including them would likely narrow the gap.
- Basket value counts add_to_cart events, so re-adds double-count and removals do not subtract.
- Time-to-exit is measured to session end for abandoners and to the payment event for completers.
- `traffic_source` is acquisition channel, not per-session source.
- The treatment is one email at one send time. A null result would be about this email, not about re-engagement in general.
- Cart-recovery requires an email on file, which not all abandoners have. Real eligible volume is likely below 46 per day, which tightens the power constraint further.
- Observational throughout. Nothing here is causal.

## Reproduce

Requires a BigQuery dataset in the **US** multi-region, matching the location of the public GA4 data.

```sql
CREATE SCHEMA IF NOT EXISTS `yourproject.funnel` OPTIONS (location = 'US');
```

Run the files in `sql/` in numeric order. `00_sessions_view.sql` defines what counts as a session and as an abandonment, and everything downstream reads from it. `analysis/power_analysis.py` takes the baseline from `05`.
