-- Viewing the dataset 
SELECT *
FROM workspace.default.sales
LIMIT 50;

-- Count total vs distinct rows
SELECT 
  COUNT(*) AS total_rows,
  COUNT(DISTINCT *) AS distinct_rows,
  COUNT(*) - COUNT(DISTINCT *) AS duplicate_count
FROM workspace.default.sales;

-- Find duplicate rows with their counts
SELECT *, COUNT(*) AS occurrence_count
FROM workspace.default.sales
GROUP BY ALL
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;    -- No duplicates found

-- Daily price per unit, % gross profit, % GP per unit

SELECT
    `Date`,
    `Sales`,
    `Cost Of Sales`,
    `Quantity Sold`,
    ROUND(`Sales` / `Quantity Sold`, 2)                              AS daily_price_per_unit,
    ROUND((`Sales` - `Cost Of Sales`) / `Sales` * 100, 2)             AS daily_gross_profit_pct,
    ROUND((`Sales` - `Cost Of Sales`) / `Quantity Sold`, 2)           AS daily_gp_per_unit_rand,
    ROUND(((`Sales` - `Cost Of Sales`) / `Quantity Sold`)
          / (`Sales` / `Quantity Sold`) * 100, 2)                     AS daily_gp_per_unit_pct
FROM workspace.default.sales
ORDER BY `Date`;

-- Average unit sales price of the product (whole period)

SELECT
    ROUND(AVG(`Sales` / `Quantity Sold`), 2)        AS avg_daily_unit_price,
    ROUND(SUM(`Sales`) / SUM(`Quantity Sold`), 2)    AS volume_weighted_avg_unit_price
FROM workspace.default.sales;

-- Price Elasticity of Demand across 3 promotional periods
-- Promo periods identified via a 30-day centered rolling average
-- of daily unit price; a period is flagged as "on promotion" when
-- daily price sits materially (>6%) below its local rolling baseline
-- for several consecutive days.
-- Elasticity = %Change in Quantity Demanded / %Change in Price
-- Baseline = the immediately preceding non-promo window of equal length
-- ============================================================

WITH promo_period_1 AS (          -- 2016-01-22 to 2016-02-08 (18 days)
    SELECT 'Promo 1 (22 Jan - 08 Feb 2016)' AS period,
           AVG(`Sales` / `Quantity Sold`) AS avg_price,
           AVG(`Quantity Sold`)           AS avg_qty
    FROM workspace.default.sales
    WHERE `Date` BETWEEN '2016-01-22' AND '2016-02-08'
),
baseline_1 AS (                   -- preceding 18 days: 2016-01-04 to 2016-01-21
    SELECT AVG(`Sales` / `Quantity Sold`) AS avg_price,
           AVG(`Quantity Sold`)           AS avg_qty
    FROM workspace.default.sales
    WHERE `Date` BETWEEN '2016-01-04' AND '2016-01-21'
),
promo_period_2 AS (                -- 2015-09-23 to 2015-10-06 (14 days)
    SELECT 'Promo 2 (23 Sep - 06 Oct 2015)' AS period,
           AVG(`Sales` / `Quantity Sold`) AS avg_price,
           AVG(`Quantity Sold`)           AS avg_qty
    FROM workspace.default.sales
    WHERE `Date` BETWEEN '2015-09-23' AND '2015-10-06'
),
baseline_2 AS (                    -- preceding 14 days: 2015-09-09 to 2015-09-22
    SELECT AVG(`Sales` / `Quantity Sold`) AS avg_price,
           AVG(`Quantity Sold`)           AS avg_qty
    FROM workspace.default.sales
    WHERE `Date` BETWEEN '2015-09-09' AND '2015-09-22'
),
promo_period_3 AS (                 -- 2016-06-27 to 2016-07-06 (10 days)
    SELECT 'Promo 3 (27 Jun - 06 Jul 2016)' AS period,
           AVG(`Sales` / `Quantity Sold`) AS avg_price,
           AVG(`Quantity Sold`)           AS avg_qty
    FROM workspace.default.sales
    WHERE `Date` BETWEEN '2016-06-27' AND '2016-07-06'
),
baseline_3 AS (                     -- preceding 10 days: 2016-06-17 to 2016-06-26
    SELECT AVG(`Sales` / `Quantity Sold`) AS avg_price,
           AVG(`Quantity Sold`)           AS avg_qty
    FROM workspace.default.sales
    WHERE `Date` BETWEEN '2016-06-17' AND '2016-06-26'
)
SELECT p.period,
       ROUND(b.avg_price, 2)  AS baseline_price,
       ROUND(p.avg_price, 2)  AS promo_price,
       ROUND((p.avg_price - b.avg_price)/b.avg_price*100, 2)  AS pct_change_price,
       ROUND(b.avg_qty, 0)    AS baseline_qty,
       ROUND(p.avg_qty, 0)    AS promo_qty,
       ROUND((p.avg_qty - b.avg_qty)/b.avg_qty*100, 2)        AS pct_change_qty,
       ROUND(((p.avg_qty - b.avg_qty)/b.avg_qty) /
             ((p.avg_price - b.avg_price)/b.avg_price), 2)     AS price_elasticity_of_demand
FROM promo_period_1 p, baseline_1 b
UNION ALL
SELECT p.period,
       ROUND(b.avg_price, 2), ROUND(p.avg_price, 2),
       ROUND((p.avg_price - b.avg_price)/b.avg_price*100, 2),
       ROUND(b.avg_qty, 0), ROUND(p.avg_qty, 0),
       ROUND((p.avg_qty - b.avg_qty)/b.avg_qty*100, 2),
       ROUND(((p.avg_qty - b.avg_qty)/b.avg_qty) /
             ((p.avg_price - b.avg_price)/b.avg_price), 2)
FROM promo_period_2 p, baseline_2 b
UNION ALL
SELECT p.period,
       ROUND(b.avg_price, 2), ROUND(p.avg_price, 2),
       ROUND((p.avg_price - b.avg_price)/b.avg_price*100, 2),
       ROUND(b.avg_qty, 0), ROUND(p.avg_qty, 0),
       ROUND((p.avg_qty - b.avg_qty)/b.avg_qty*100, 2),
       ROUND(((p.avg_qty - b.avg_qty)/b.avg_qty) /
             ((p.avg_price - b.avg_price)/b.avg_price), 2)
FROM promo_period_3 p, baseline_3 b;

-- Day-of-week seasonality (avg sales, qty, price)

SELECT
    CASE DAYOFWEEK(`Date`)
        WHEN 1 THEN 'Sunday' WHEN 2 THEN 'Monday' WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday' WHEN 5 THEN 'Thursday' WHEN 6 THEN 'Friday'
        ELSE 'Saturday' END                          AS day_of_week,
    DAYOFWEEK(`Date`)                                 AS dow_sort,
    ROUND(AVG(`Sales`), 0)                            AS avg_daily_sales,
    ROUND(AVG(`Quantity Sold`), 0)                    AS avg_daily_qty,
    ROUND(AVG(`Sales` / `Quantity Sold`), 2)          AS avg_unit_price
FROM workspace.default.sales
GROUP BY day_of_week, dow_sort
ORDER BY dow_sort;


-- Monthly sales trend

SELECT
    DATE_FORMAT(`Date`, 'yyyy-MM')                       AS year_month,
    ROUND(SUM(`Sales`), 0)                               AS total_sales,
    ROUND(SUM(`Sales` - `Cost Of Sales`), 0)             AS total_gross_profit,
    ROUND(SUM(`Sales` - `Cost Of Sales`) / SUM(`Sales`) * 100, 2) AS gp_pct,
    SUM(`Quantity Sold`)                                 AS total_qty
FROM workspace.default.sales
GROUP BY year_month
ORDER BY year_month;

-- METRIC 6c: Annual summary (YoY view)

SELECT
    YEAR(`Date`)                                         AS year,
    ROUND(SUM(`Sales`), 0)                               AS total_sales,
    ROUND(SUM(`Sales` - `Cost Of Sales`), 0)             AS total_gross_profit,
    ROUND(SUM(`Sales` - `Cost Of Sales`) / SUM(`Sales`) * 100, 2) AS gp_pct,
    SUM(`Quantity Sold`)                                 AS total_qty,
    ROUND(AVG(`Sales` / `Quantity Sold`), 2)             AS avg_unit_price,
    COUNT(*)                                             AS trading_days
FROM workspace.default.sales
GROUP BY year
ORDER BY year;

-- Overall KPI summary

SELECT
    ROUND(SUM(`Sales`), 0)                                        AS total_sales_rand,
    ROUND(SUM(`Cost Of Sales`), 0)                                 AS total_cost_of_sales_rand,
    ROUND(SUM(`Sales` - `Cost Of Sales`), 0)                       AS total_gross_profit_rand,
    ROUND(SUM(`Sales` - `Cost Of Sales`) / SUM(`Sales`) * 100, 2)  AS overall_gp_pct,
    SUM(`Quantity Sold`)                                           AS total_units_sold,
    ROUND(AVG(`Sales` / `Quantity Sold`), 2)                       AS avg_unit_price,
    COUNT(*)                                                       AS total_trading_days,
    MIN(`Date`)                                                    AS first_date,
    MAX(`Date`)                                                    AS last_date
FROM workspace.default.sales;
