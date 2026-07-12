WITH user_events AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(traffic_source.medium) AS medium,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS shipping,
    MAX(IF(event_name = 'add_payment_info',  1, 0)) AS payment
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
),
by_medium AS (
  SELECT
    medium,
    SUM(shipping) AS shipping,
    SUM(payment)  AS payment
  FROM user_events
  WHERE medium IS NOT NULL
    AND medium != '(data deleted)'
    AND shipping = 1
  GROUP BY medium
)
SELECT medium, shipping, payment, ROUND(payment / shipping, 3) AS shipping_to_payment
FROM by_medium
WHERE shipping >= 200        -- smaller threshold; this population is much smaller
ORDER BY shipping_to_payment;