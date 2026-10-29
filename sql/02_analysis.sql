-- =====================================================================
-- 02_analysis.sql  |  Zomato India: price, quality and delivery
-- Dialect: SQLite 3.25+. Run 01_clean.sql first.
-- Ratings exclude unrated restaurants (rating IS NULL) throughout.
-- =====================================================================


-- @name: overview
-- @section: At a glance
-- @title: Headline numbers (India)
-- @chart: kpi money=median_cost_for_two
-- @insight: 8,652 Indian restaurants, 92% of them in Delhi NCR. A quarter have no rating yet, and the rated ones average 3.35 out of 5.
WITH ordered AS (
    SELECT cost_for_two,
           ROW_NUMBER() OVER (ORDER BY cost_for_two) AS rn,
           COUNT(*) OVER ()                          AS n
    FROM restaurants WHERE cost_for_two IS NOT NULL
)
SELECT COUNT(*)                                                             AS restaurants,
       ROUND(100.0 * SUM(region = 'Delhi NCR') / COUNT(*), 1)               AS delhi_ncr_pct,
       ROUND(100.0 * COUNT(rating) / COUNT(*), 1)                           AS rated_pct,
       ROUND(AVG(rating), 2)                                                AS avg_rating,
       (SELECT cost_for_two FROM ordered WHERE rn = (n + 1) / 2)            AS median_cost_for_two,
       ROUND(100.0 * SUM(has_online_delivery = 'Yes') / COUNT(*), 1)        AS online_delivery_pct
FROM restaurants;


-- @name: city_coverage
-- @section: Coverage
-- @title: Restaurants by city (top 10)
-- @chart: hbar x=city y=restaurants
-- @insight: This is a Delhi NCR dataset: New Delhi alone has 5,473 restaurants. Every other city has 20 to 21, so city-level comparisons outside NCR are not meaningful.
SELECT city, region, COUNT(*) AS restaurants
FROM restaurants
GROUP BY city
ORDER BY restaurants DESC
LIMIT 10;


-- @name: region_bias
-- @section: Coverage
-- @title: Delhi NCR vs the other 38 cities
-- @chart: table money=avg_cost_for_two
-- @insight: The 705 restaurants outside NCR are all rated, average 488 votes and score 3.94, against 3.28 in NCR. They look like a sample of each city's best-known places, which is why NCR-only analysis follows.
SELECT region,
       COUNT(DISTINCT city)                        AS cities,
       COUNT(*)                                    AS restaurants,
       ROUND(100.0 * COUNT(rating) / COUNT(*), 1)  AS rated_pct,
       ROUND(AVG(rating), 2)                       AS avg_rating,
       ROUND(AVG(votes), 0)                        AS avg_votes,
       ROUND(AVG(cost_for_two), 0)                 AS avg_cost_for_two
FROM restaurants
GROUP BY region;


-- @name: rating_labels
-- @section: Coverage
-- @title: Restaurants by Zomato rating label
-- @chart: bar x=rating_label y=restaurants
-- @insight: More than half of rated restaurants (56%) score 'Average' (2.5 to 3.4). Only 1.3% of all restaurants reach 'Excellent' (4.5+).
SELECT rating_label,
       COUNT(*)                                            AS restaurants,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS share_pct
FROM restaurants
GROUP BY rating_label
ORDER BY CASE rating_label WHEN 'Not rated' THEN 0 WHEN 'Poor' THEN 1 WHEN 'Average' THEN 2
                           WHEN 'Good' THEN 3 WHEN 'Very good' THEN 4 ELSE 5 END;


-- @name: top_localities
-- @section: Delhi NCR neighbourhoods
-- @title: Most restaurant-dense localities in Delhi NCR
-- @chart: hbar x=locality y=restaurants
-- @insight: Connaught Place is the densest locality (122 restaurants) and also rates well (3.78). Dense residential areas such as Shahdara and Mayur Vihar Phase 1 rate about 3.0.
SELECT locality || ', ' || city   AS locality,
       COUNT(*)                   AS restaurants,
       ROUND(AVG(rating), 2)      AS avg_rating
FROM restaurants
WHERE region = 'Delhi NCR'
GROUP BY locality, city
ORDER BY restaurants DESC
LIMIT 12;


-- @name: best_localities
-- @section: Delhi NCR neighbourhoods
-- @title: Best-rated NCR localities vs the NCR average (20+ rated restaurants)
-- @chart: hbar x=locality y=rating_vs_ncr_avg
-- @insight: The best-rated localities are destination districts: Gurgaon's Sector 29 and Cyber Hub, Hauz Khas Village and Khan Market. These four average ₹1,250 or more for two.
SELECT locality || ', ' || city   AS locality,
       COUNT(rating)              AS rated_restaurants,
       ROUND(AVG(rating), 2)      AS avg_rating,
       ROUND(AVG(rating) - (SELECT AVG(rating) FROM restaurants WHERE region = 'Delhi NCR'), 2) AS rating_vs_ncr_avg,
       ROUND(AVG(cost_for_two), 0) AS avg_cost_for_two
FROM restaurants
WHERE region = 'Delhi NCR'
GROUP BY locality, city
HAVING COUNT(rating) >= 20
ORDER BY avg_rating DESC
LIMIT 12;


-- @name: top_cuisines
-- @section: Cuisines
-- @title: Most common cuisines (a restaurant counts once per cuisine)
-- @chart: hbar x=cuisine y=restaurants
-- @insight: North Indian is on 46% of menus and Chinese on 31%. Fast food comes third at 23%.
SELECT cuisine,
       COUNT(*)                                                         AS restaurants,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM restaurants), 1)  AS share_of_restaurants_pct
FROM restaurant_cuisines
GROUP BY cuisine
ORDER BY restaurants DESC
LIMIT 12;


-- @name: cuisine_rating_gap
-- @section: Cuisines
-- @title: Rating above or below the India average, by cuisine (100+ rated restaurants)
-- @chart: hbar x=cuisine y=rating_gap
-- @insight: European, Asian and Mexican restaurants rate about half a point above average. The most common cuisines, North Indian, Chinese and Mughlai, sit just below it, and mithai shops rate lowest.
WITH national AS (SELECT AVG(rating) AS avg_rating FROM restaurants)
SELECT rc.cuisine,
       COUNT(r.rating)                                AS rated_restaurants,
       ROUND(AVG(r.rating), 2)                        AS avg_rating,
       ROUND(AVG(r.rating) - national.avg_rating, 2)  AS rating_gap
FROM restaurant_cuisines rc
JOIN restaurants r ON r.restaurant_id = rc.restaurant_id
CROSS JOIN national
GROUP BY rc.cuisine
HAVING COUNT(r.rating) >= 100
ORDER BY rating_gap DESC;


-- @name: price_tiers
-- @section: Price and quality
-- @title: Price tiers: size, cost and rating
-- @chart: table money=avg_cost_for_two
-- @insight: Half of all restaurants are in the cheapest tier (₹285 for two on average). The top tier costs nine times as much and draws over ten times the votes per restaurant.
SELECT price_range                                   AS price_tier,
       COUNT(*)                                      AS restaurants,
       ROUND(AVG(cost_for_two), 0)                   AS avg_cost_for_two,
       ROUND(AVG(rating), 2)                         AS avg_rating,
       ROUND(AVG(votes), 0)                          AS avg_votes,
       ROUND(100.0 * SUM(has_online_delivery = 'Yes') / COUNT(*), 1) AS online_delivery_pct,
       ROUND(100.0 * SUM(has_table_booking = 'Yes') / COUNT(*), 1)   AS table_booking_pct
FROM restaurants
GROUP BY price_range
ORDER BY price_range;


-- @name: price_rating_gap
-- @section: Price and quality
-- @title: Rating above or below average, by price tier (1 = cheapest)
-- @chart: bar x=price_tier y=rating_gap
-- @insight: Ratings rise with price: tier 3 and 4 restaurants rate about 0.35 above average, tier 1 sits 0.16 below.
WITH national AS (SELECT AVG(rating) AS avg_rating FROM restaurants)
SELECT 'Tier ' || price_range                         AS price_tier,
       ROUND(AVG(rating), 2)                          AS avg_rating,
       ROUND(AVG(rating) - national.avg_rating, 2)    AS rating_gap
FROM restaurants CROSS JOIN national
GROUP BY price_range
ORDER BY price_range;


-- @name: delivery_by_tier
-- @section: Price and quality
-- @title: Online delivery and table booking adoption by price tier
-- @chart: bar x=price_tier y=online_delivery_pct,table_booking_pct
-- @insight: Online delivery peaks in the mid-price tier 2 (45%), while table booking is a premium feature: 56% of tier 3 and 65% of tier 4 restaurants offer it, and no tier 1 restaurant does.
SELECT 'Tier ' || price_range                                         AS price_tier,
       ROUND(100.0 * SUM(has_online_delivery = 'Yes') / COUNT(*), 1)  AS online_delivery_pct,
       ROUND(100.0 * SUM(has_table_booking = 'Yes') / COUNT(*), 1)    AS table_booking_pct
FROM restaurants
GROUP BY price_range
ORDER BY price_range;


-- @name: delivery_effect
-- @section: Price and quality
-- @title: Does online delivery go with better ratings? (compared within each price tier)
-- @chart: bar x=price_tier y=with_delivery,without_delivery
-- @insight: Within the same price tier, offering online delivery makes almost no difference to ratings (within 0.1 points in tiers 1 to 3).
SELECT 'Tier ' || price_range                                            AS price_tier,
       ROUND(AVG(CASE WHEN has_online_delivery = 'Yes' THEN rating END), 2) AS with_delivery,
       ROUND(AVG(CASE WHEN has_online_delivery = 'No'  THEN rating END), 2) AS without_delivery
FROM restaurants
GROUP BY price_range
ORDER BY price_range;


-- @name: votes_vs_rating
-- @section: Price and quality
-- @title: Average rating by number of votes
-- @chart: bar x=vote_band y=avg_rating
-- @insight: Ratings climb steadily with engagement: restaurants with 1,000+ votes average 4.11, against 3.10 for those under 50.
SELECT CASE
           WHEN votes < 50   THEN 'Under 50'
           WHEN votes < 200  THEN '50-199'
           WHEN votes < 500  THEN '200-499'
           WHEN votes < 1000 THEN '500-999'
           ELSE '1,000+'
       END                    AS vote_band,
       COUNT(*)               AS restaurants,
       ROUND(AVG(rating), 2)  AS avg_rating
FROM restaurants
WHERE rating IS NOT NULL
GROUP BY vote_band
ORDER BY MIN(votes);


-- @name: best_value
-- @section: Best value
-- @title: Best value restaurants in Delhi NCR: weighted rating, cost for two ₹500 or less
-- @chart: table money=cost_for_two
-- @insight: Ranked on a weighted rating that discounts low vote counts, Delhi NCR's best value spots at ₹500 or less for two are dessert and South Indian institutions, led by Naturals Ice Cream, Saravana Bhavan and Wenger's in Connaught Place.
-- Weighted rating pulls restaurants with few votes toward the average:
--   WR = v/(v+m) * R + m/(v+m) * C,  m = 200 votes, C = average rating
WITH params AS (
    SELECT AVG(rating) AS c, 200.0 AS m FROM restaurants WHERE rating IS NOT NULL
),
scored AS (
    SELECT r.restaurant_name, r.locality, r.cuisines, r.cost_for_two, r.rating, r.votes,
           (r.votes / (r.votes + p.m)) * r.rating + (p.m / (r.votes + p.m)) * p.c AS weighted_rating
    FROM restaurants r CROSS JOIN params p
    WHERE r.rating IS NOT NULL AND r.region = 'Delhi NCR' AND r.cost_for_two <= 500
)
SELECT RANK() OVER (ORDER BY weighted_rating DESC) AS rank,
       restaurant_name, locality, cuisines, cost_for_two, rating, votes,
       ROUND(weighted_rating, 2) AS weighted_rating
FROM scored
ORDER BY weighted_rating DESC
LIMIT 15;


-- @name: chains
-- @section: Best value
-- @title: Largest chains in India by outlets listed
-- @chart: hbar x=brand y=outlets
-- @insight: The biggest chains rate below average: Cafe Coffee Day and Subway score 3.0 and Domino's 2.93. Barbeque Nation is the exception at 4.35.
SELECT MAX(restaurant_name)      AS brand,
       COUNT(*)                  AS outlets,
       ROUND(AVG(rating), 2)     AS avg_rating,
       ROUND(AVG(cost_for_two), 0) AS avg_cost_for_two
FROM restaurants
GROUP BY LOWER(restaurant_name)
ORDER BY outlets DESC
LIMIT 12;


-- @name: data_quality
-- @section: Data quality
-- @title: What the cleaning step found and fixed
-- @chart: table
-- @insight: The biggest fix is the 2,139 unrated restaurants stored as a 1.0 rating. Left in, they would drag the India average from 3.35 down to about 2.77 and make cheap, new restaurants look like the worst in the country.
SELECT check_name, rows_affected, action
FROM data_quality_log;
