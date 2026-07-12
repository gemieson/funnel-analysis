WITH shipping AS (
  SELECT user_pseudo_id,
         MAX(IF(event_name = 'add_payment_info', 1, 0)) AS completed,
         MIN(IF(event_name = 'add_shipping_info', event_timestamp, NULL)) AS ship_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
  HAVING MAX(IF(event_name = 'add_shipping_info', 1, 0)) = 1
),
later_activity AS (
  SELECT e.user_pseudo_id,
         MAX(IF(e.event_timestamp > s.ship_ts + 86400 * 1e6, 1, 0)) AS returned_next_day
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
  JOIN shipping s USING (user_pseudo_id)
  GROUP BY e.user_pseudo_id
)
SELECT
  IF(s.completed = 1, 'completer', 'dropper') AS outcome,
  COUNT(*) AS users,
  ROUND(AVG(a.returned_next_day), 3) AS pct_returned_after_24h
FROM shipping s
JOIN later_activity a USING (user_pseudo_id)
GROUP BY outcome;