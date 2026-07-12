WITH shipping_users AS (
  SELECT
    user_pseudo_id,
    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS completed
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
  HAVING MAX(IF(event_name = 'add_shipping_info', 1, 0)) = 1
),
cart_value AS (
  SELECT
    user_pseudo_id,
    SUM(item.price * item.quantity) AS cart_value
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
       UNNEST(items) AS item
  WHERE event_name = 'add_to_cart'
  GROUP BY user_pseudo_id
)
SELECT
  IF(s.completed = 1, 'completer', 'dropper') AS outcome,
  COUNT(*) AS users,
  ROUND(AVG(c.cart_value), 2)  AS avg_cart_value,
  ROUND(APPROX_QUANTILES(c.cart_value, 2)[OFFSET(1)], 2) AS median_cart_value
FROM shipping_users s
JOIN cart_value c USING (user_pseudo_id)
GROUP BY outcome;