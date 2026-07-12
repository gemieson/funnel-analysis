WITH user_events AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(device.category) AS device,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS shipping,
    MAX(IF(event_name = 'add_payment_info',  1, 0)) AS payment
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
),
by_device AS (
  SELECT device, SUM(shipping) AS shipping, SUM(payment) AS payment
  FROM user_events
  WHERE device IS NOT NULL AND shipping = 1
  GROUP BY device
)
SELECT device, shipping, payment, ROUND(payment / shipping, 3) AS shipping_to_payment
FROM by_device
ORDER BY shipping_to_payment;