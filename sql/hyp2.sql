WITH ship_time AS (
  SELECT user_pseudo_id, MIN(event_timestamp) AS ship_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'add_shipping_info'
  GROUP BY user_pseudo_id
),
pay_flag AS (
  SELECT user_pseudo_id, MIN(event_timestamp) AS pay_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'add_payment_info'
  GROUP BY user_pseudo_id
),
last_event AS (
  SELECT user_pseudo_id, MAX(event_timestamp) AS last_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
)
SELECT
  IF(p.user_pseudo_id IS NOT NULL, 'completer', 'dropper') AS outcome,
  COUNT(*) AS users,
  ROUND(APPROX_QUANTILES(
    IF(p.user_pseudo_id IS NOT NULL,
       (p.pay_ts - s.ship_ts) / 1e6,          -- seconds to payment
       (l.last_ts - s.ship_ts) / 1e6           -- seconds of lingering before exit
    ), 2)[OFFSET(1)], 1) AS median_seconds_after_shipping
FROM ship_time s
LEFT JOIN pay_flag p USING (user_pseudo_id)
JOIN last_event l USING (user_pseudo_id)
GROUP BY outcome;