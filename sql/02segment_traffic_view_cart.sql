WITH user_events AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(traffic_source.medium) AS medium,
    MAX(IF(event_name = 'view_item',   1, 0)) AS viewed,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS carted
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
),
by_medium AS (
  SELECT
    medium,
    SUM(viewed) AS viewed,
    SUM(carted) AS carted
  FROM user_events
  WHERE medium IS NOT NULL
    AND medium NOT IN ('(data deleted)')   -- obfuscation artifact
    AND viewed = 1
  GROUP BY medium
)
SELECT medium, viewed, carted, ROUND(carted / viewed, 3) AS view_to_cart
FROM by_medium
WHERE viewed >= 500                        -- drop segments too small to be reliable
ORDER BY view_to_cart;