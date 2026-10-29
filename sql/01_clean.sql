-- =====================================================================
-- 01_clean.sql  |  Zomato restaurants: profiling and cleaning
-- Dialect: SQLite 3.25+  (also runs in DB Browser for SQLite)
-- Input : zomato_raw (Kaggle CSV as-is, every column TEXT)
-- Output: restaurants (India only), restaurant_cuisines, data_quality_log
-- =====================================================================

DROP TABLE IF EXISTS data_quality_log;
CREATE TABLE data_quality_log (check_name TEXT, rows_affected INTEGER, action TEXT);

INSERT INTO data_quality_log
SELECT 'Raw rows loaded (15 countries)', COUNT(*), 'none' FROM zomato_raw;

INSERT INTO data_quality_log
SELECT 'Restaurants outside India (country code <> 1)', COUNT(*), 'excluded: different currencies and tiny samples'
FROM zomato_raw WHERE CountryCode <> '1';

INSERT INTO data_quality_log
SELECT 'Duplicate restaurant id', COUNT(*) - COUNT(DISTINCT RestaurantID), 'none needed'
FROM zomato_raw;

-- Unrated restaurants are stored as rating 1.0 with 0 to 3 votes. Left in,
-- they would count as the worst-rated restaurants in the country.
INSERT INTO data_quality_log
SELECT 'Rating 1.0 with fewer than 4 votes (placeholder for "not rated")', COUNT(*), 'rating set to NULL'
FROM zomato_raw
WHERE CountryCode = '1' AND CAST(Rating AS REAL) = 1.0 AND CAST(Votes AS INTEGER) < 4;

INSERT INTO data_quality_log
SELECT 'Cost for two recorded as 0', COUNT(*), 'cost set to NULL'
FROM zomato_raw WHERE CountryCode = '1' AND CAST(Average_Cost_for_two AS INTEGER) = 0;

DROP TABLE IF EXISTS restaurants;
CREATE TABLE restaurants AS
SELECT
    CAST(RestaurantID AS INTEGER)                            AS restaurant_id,
    TRIM(RestaurantName)                                     AS restaurant_name,
    TRIM(City)                                               AS city,
    CASE WHEN City IN ('New Delhi', 'Gurgaon', 'Noida', 'Faridabad', 'Ghaziabad')
         THEN 'Delhi NCR' ELSE 'Other cities' END            AS region,
    TRIM(REPLACE(REPLACE(Locality, '|  ', ', '), '| ', ', ')) AS locality,
    REPLACE(Cuisines, '|', ',')                              AS cuisines,
    Has_Table_booking                                        AS has_table_booking,
    Has_Online_delivery                                      AS has_online_delivery,
    CAST(Price_range AS INTEGER)                             AS price_range,
    CAST(Votes AS INTEGER)                                   AS votes,
    NULLIF(CAST(Average_Cost_for_two AS INTEGER), 0)         AS cost_for_two,
    CASE WHEN CAST(Rating AS REAL) = 1.0 AND CAST(Votes AS INTEGER) < 4 THEN NULL
         ELSE CAST(Rating AS REAL) END                       AS rating
FROM zomato_raw
WHERE CountryCode = '1';

-- Zomato's own rating labels
ALTER TABLE restaurants ADD COLUMN rating_label TEXT;
UPDATE restaurants
SET rating_label = CASE
    WHEN rating IS NULL THEN 'Not rated'
    WHEN rating < 2.5   THEN 'Poor'
    WHEN rating < 3.5   THEN 'Average'
    WHEN rating < 4.0   THEN 'Good'
    WHEN rating < 4.5   THEN 'Very good'
    ELSE 'Excellent' END;

INSERT INTO data_quality_log
SELECT 'Clean Indian restaurants', COUNT(*), 'final table' FROM restaurants;

-- One row per restaurant per cuisine ('North Indian, Mughlai' -> 2 rows)
DROP TABLE IF EXISTS restaurant_cuisines;
CREATE TABLE restaurant_cuisines AS
WITH RECURSIVE tags(restaurant_id, tag, rest) AS (
    SELECT restaurant_id, '', cuisines || ','
    FROM restaurants
    WHERE cuisines IS NOT NULL
    UNION ALL
    SELECT restaurant_id,
           TRIM(SUBSTR(rest, 1, INSTR(rest, ',') - 1)),
           SUBSTR(rest, INSTR(rest, ',') + 1)
    FROM tags
    WHERE rest <> ''
)
SELECT DISTINCT restaurant_id, tag AS cuisine
FROM tags
WHERE tag <> '';
