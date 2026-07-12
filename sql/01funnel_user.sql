WITH user_events AS (
  SELECT
    user_pseudo_id,
    MAX(IF(event_name = 'view_item',         1, 0)) AS viewed,
    MAX(IF(event_name = 'add_to_cart',       1, 0)) AS carted,
    MAX(IF(event_name = 'begin_checkout',    1, 0)) AS checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS shipping,
    MAX(IF(event_name = 'add_payment_info',  1, 0)) AS payment,
    MAX(IF(event_name = 'purchase',          1, 0)) AS purchased
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
)
SELECT
  SUM(viewed)    AS s1_viewed,
  SUM(carted)    AS s2_carted,
  SUM(checkout)  AS s3_checkout,
  SUM(shipping)  AS s4_shipping,
  SUM(payment)   AS s5_payment,
  SUM(purchased) AS s6_purchased,
  ROUND(SUM(carted)    / SUM(viewed),   3) AS view_to_cart,
  ROUND(SUM(checkout)  / SUM(carted),   3) AS cart_to_checkout,
  ROUND(SUM(shipping)  / SUM(checkout), 3) AS checkout_to_shipping,
  ROUND(SUM(payment)   / SUM(shipping), 3) AS shipping_to_payment,
  ROUND(SUM(purchased) / SUM(payment),  3) AS payment_to_purchase
FROM user_events;