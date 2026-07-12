WITH user_events AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(device.category) AS device,
    MAX(IF(event_name = 'view_item',   1, 0)) AS viewed,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS carted
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
),
by_device AS (
  SELECT
    device,
    SUM(viewed) AS viewed,
    SUM(carted) AS carted
  FROM user_events
  WHERE device IS NOT NULL AND viewed = 1
  GROUP BY device
)
SELECT device, viewed, carted, ROUND(carted / viewed, 3) AS view_to_cart
FROM by_device
ORDER BY view_to_cart;