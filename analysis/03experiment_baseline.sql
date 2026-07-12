-- sql/30_experiment_baseline.sql (corrected: session-level eligibility)
WITH abandoned_sessions AS (
  SELECT
    user_pseudo_id,
    MIN(IF(event_name = 'add_shipping_info', event_timestamp, NULL)) AS abandon_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')
  HAVING MAX(IF(event_name = 'add_shipping_info', 1, 0)) = 1
     AND MAX(IF(event_name = 'add_payment_info',  1, 0)) = 0
),
first_abandonment AS (
  SELECT user_pseudo_id, MIN(abandon_ts) AS abandon_ts
  FROM abandoned_sessions
  GROUP BY user_pseudo_id
),
outcome AS (
  SELECT f.user_pseudo_id,
         MAX(IF(e.event_name = 'purchase'
                AND e.event_timestamp BETWEEN f.abandon_ts
                AND f.abandon_ts + 7 * 86400 * 1000000, 1, 0)) AS purchased_7d
  FROM first_abandonment f
  JOIN `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
    USING (user_pseudo_id)
  GROUP BY f.user_pseudo_id
)
SELECT COUNT(*) AS abandoners,
       SUM(purchased_7d) AS purchased_7d,
       ROUND(AVG(purchased_7d), 4) AS baseline
FROM outcome;