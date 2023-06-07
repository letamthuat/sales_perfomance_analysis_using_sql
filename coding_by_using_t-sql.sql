-- DỮ LIỆU SỬ DỤNG

SELECT * FROM dim_scenario

SELECT * FROM dim_payment_channel

SELECT * FROM dim_platform

SELECT * FROM dim_status

SELECT * FROM fact_transaction_2019

SELECT * FROM fact_transaction_2020

-- PHÂN LOẠI KHÁCH HÀNG

-- 1.Tính các giá trị recency, frequency, monetary

WITH fact_table AS (
   SELECT customer_id, transaction_id, transaction_time, charged_amount
       , CONVERT (varchar, transaction_time, 112) AS day_formated
   FROM fact_transaction_2019 AS fact_19
   JOIN dim_scenario AS scena ON fact_19.scenario_id = scena.scenario_id
   WHERE category = 'Billing' AND status_id = 1
   UNION
   SELECT customer_id, transaction_id, transaction_time, charged_amount
       , CONVERT (varchar, transaction_time, 112) AS day_formated
   FROM fact_transaction_2020 AS fact_20
   JOIN dim_scenario AS scena ON fact_20.scenario_id = scena.scenario_id
   WHERE category = 'Billing' AND status_id = 1
)
SELECT customer_id
   , DATEDIFF (day, MAX ( transaction_time ), '2020-12-31')  AS recency
   , COUNT ( DISTINCT day_formated) AS frequency
   , SUM (charged_amount *1.0) AS monetary
FROM fact_table
GROUP BY customer_id

-- 2.R-tier, f-tier, m-tier

WITH fact_table AS (
   SELECT customer_id, transaction_id, transaction_time, charged_amount
       , CONVERT (varchar, transaction_time, 112) AS day_formated
   FROM fact_transaction_2019 AS fact_19
   JOIN dim_scenario AS scena ON fact_19.scenario_id = scena.scenario_id
   WHERE category = 'Billing' AND status_id = 1
   UNION
   SELECT customer_id, transaction_id, transaction_time, charged_amount
       , CONVERT (varchar, transaction_time, 112) AS day_formated
   FROM fact_transaction_2020 AS fact_20
   JOIN dim_scenario AS scena ON fact_20.scenario_id = scena.scenario_id
   WHERE category = 'Billing' AND status_id = 1
)
, rfm_table AS (
SELECT customer_id
   , DATEDIFF (day, MAX ( transaction_time ), '2020-12-31')  AS recency
   , COUNT ( DISTINCT day_formated) AS frequency
   , SUM (charged_amount * 1.0) AS monetary
FROM fact_table
GROUP BY customer_id
)
, rfm_rank_table AS (
    SELECT *
        , PERCENT_RANK () OVER (ORDER BY recency ASC) AS recency_rank
        , PERCENT_RANK () OVER (ORDER BY frequency DESC) AS frequency_rank
        , PERCENT_RANK () OVER (ORDER BY monetary DESC) AS monetary_rank
    FROM rfm_table
)
SELECT customer_id
    , CASE WHEN recency_rank BETWEEN 0 AND 0.25 THEN 1 
        WHEN recency_rank BETWEEN 0.25 AND 0.5 THEN 2
        WHEN recency_rank BETWEEN 0.5 AND 0.75 THEN 3
        ELSE 4 END AS r_tier 
    , CASE WHEN frequency_rank BETWEEN 0 AND 0.25 THEN 1 
        WHEN frequency_rank BETWEEN 0.25 AND 0.5 THEN 2
        WHEN frequency_rank BETWEEN 0.5 AND 0.75 THEN 3
        ELSE 4 END AS f_tier 
    , CASE WHEN monetary_rank BETWEEN 0 AND 0.25 THEN 1 
        WHEN monetary_rank BETWEEN 0.25 AND 0.5 THEN 2
        WHEN monetary_rank BETWEEN 0.5 AND 0.75 THEN 3
        ELSE 4 END AS m_tier 
FROM rfm_rank_table

-- 3.Phân loại tệp khách hàng
WITH fact_table AS (
   SELECT customer_id, transaction_id, transaction_time, charged_amount
       , CONVERT (varchar, transaction_time, 112) AS day_formated
   FROM fact_transaction_2019 AS fact_19
   JOIN dim_scenario AS scena ON fact_19.scenario_id = scena.scenario_id
   WHERE category = 'Billing' AND status_id = 1
   UNION
   SELECT customer_id, transaction_id, transaction_time, charged_amount
       , CONVERT (varchar, transaction_time, 112) AS day_formated
   FROM fact_transaction_2020 AS fact_20
   JOIN dim_scenario AS scena ON fact_20.scenario_id = scena.scenario_id
   WHERE category = 'Billing' AND status_id = 1
)
, rfm_table AS (
SELECT customer_id
   , DATEDIFF (day, MAX ( transaction_time ), '2020-12-31')  AS recency
   , COUNT ( DISTINCT day_formated) AS frequency
   , SUM (charged_amount * 1.0) AS monetary
FROM fact_table
GROUP BY customer_id
)
, rfm_rank_table AS (
    SELECT *
        , PERCENT_RANK () OVER (ORDER BY recency ASC) AS recency_rank
        , PERCENT_RANK () OVER (ORDER BY frequency DESC) AS frequency_rank
        , PERCENT_RANK () OVER (ORDER BY monetary DESC) AS monetary_rank
    FROM rfm_table
)
, rfm_tier AS (
    SELECT customer_id
        , CASE WHEN recency_rank BETWEEN 0 AND 0.25 THEN 1 
            WHEN recency_rank BETWEEN 0.25 AND 0.5 THEN 2
            WHEN recency_rank BETWEEN 0.5 AND 0.75 THEN 3
            ELSE 4 END AS r_tier 
        , CASE WHEN frequency_rank BETWEEN 0 AND 0.25 THEN 1 
            WHEN frequency_rank BETWEEN 0.25 AND 0.5 THEN 2
            WHEN frequency_rank BETWEEN 0.5 AND 0.75 THEN 3
            ELSE 4 END AS f_tier 
        , CASE WHEN monetary_rank BETWEEN 0 AND 0.25 THEN 1 
            WHEN monetary_rank BETWEEN 0.25 AND 0.5 THEN 2
            WHEN monetary_rank BETWEEN 0.5 AND 0.75 THEN 3
            ELSE 4 END AS m_tier 
    FROM rfm_rank_table
)
SELECT *
    , CASE WHEN r_tier = 1 AND f_tier = 1 AND m_tier = 1 THEN 'Best customers'
        WHEN r_tier IN ('3', '4') AND f_tier IN ('3', '4') THEN 'Lost Bad customers'
        WHEN r_tier IN ('3', '4') AND f_tier = 2 THEN 'Lost customer'
        WHEN r_tier = 2 AND f_tier = 1 THEN 'Alomost lost'
        WHEN r_tier = 1 AND f_tier = 1 AND m_tier IN ('2', '3', '4') THEN 'Loyal customers'
        WHEN r_tier IN ('1', '2') AND f_tier IN ('1', '2', '3') AND m_tier = 1 THEN 'Big Spender'
        WHEN r_tier IN ('1', '2') AND f_tier = 4 THEN 'New customers'
        WHEN r_tier IN ('3', '4') AND f_tier = 1 THEN 'Hibernating'
        WHEN r_tier IN ('1', '2') AND f_tier IN ('2', '3') AND m_tier IN ('2', '3', '4') THEN 'Big Spender'
        END AS segment 
FROM rfm_tier

-- COHORT ANALYS

WITH table_first_month AS (
   SELECT customer_id, transaction_id, transaction_time
       ,  MIN ( MONTH (transaction_time)) OVER ( PARTITION BY customer_id ) AS first_month
       ,  MONTH (transaction_time) - MIN ( MONTH (transaction_time)) OVER ( PARTITION BY customer_id ) AS subsequent_month
   FROM fact_transaction_2019 fact_19
   JOIN dim_scenario sce ON fact_19.scenario_id = sce.scenario_id
   WHERE sub_category = 'Telco Card' AND status_id = 1
)
, table_sub_month AS (
   SELECT first_month AS acquisition_month
       , subsequent_month
       , COUNT (DISTINCT customer_id) AS number_retained_customers
   FROM table_first_month
   GROUP BY first_month, subsequent_month
   -- ORDER BY first_month, subsequent_month
)
, table_retention AS (
   SELECT *
       , FIRST_VALUE ( number_retained_customers ) OVER ( PARTITION BY acquisition_month ORDER BY subsequent_month ASC ) AS original_customers
       , number_retained_customers * 1.0 /
           FIRST_VALUE ( number_retained_customers ) OVER ( PARTITION BY acquisition_month ORDER BY subsequent_month ASC ) AS pct
   FROM table_sub_month
)
SELECT acquisition_month
   , original_customers
   , "0", "1", "2", "3", "4", "5", "6","7", "8", "9", "10", "11"
FROM ( SELECT acquisition_month, subsequent_month, original_customers, pct
       FROM table_retention) AS source_table
PIVOT (
   MAX (pct)
   FOR subsequent_month IN ( "0", "1", "2", "3", "4", "5", "6",  "7", "8", "9", "10", "11" )
) AS pivot_logic
ORDER BY acquisition_month

