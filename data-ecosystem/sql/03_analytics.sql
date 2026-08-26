-- ============================================================================
-- MovieFlix Analytics - Business Queries
-- ============================================================================
-- Direct analytical queries over the Data Warehouse / Data Marts.
-- Executed by the ETL script (load_dw.py), which prints the results.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 1: What are the 5 most popular movies (highest number of ratings)?
-- ----------------------------------------------------------------------------
SELECT
    m.title,
    COUNT(r.rating_id) AS num_ratings
FROM fact_ratings r
JOIN dim_movies m ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title
ORDER BY num_ratings DESC, m.title
LIMIT 5;

-- ----------------------------------------------------------------------------
-- Query 2: Which genre has the highest average rating?
-- ----------------------------------------------------------------------------
SELECT
    g.genre,
    ROUND(AVG(r.rating), 2) AS avg_rating,
    COUNT(r.rating_id)      AS num_ratings
FROM fact_ratings r
JOIN movie_genres mg ON r.movie_id = mg.movie_id
JOIN dim_genres  g  ON mg.genre_id = g.genre_id
GROUP BY g.genre
ORDER BY avg_rating DESC, num_ratings DESC, g.genre
LIMIT 1;

-- ----------------------------------------------------------------------------
-- Query 3: Which country watches/rates the most movies?
-- ----------------------------------------------------------------------------
SELECT
    u.country,
    COUNT(r.rating_id) AS num_ratings
FROM fact_ratings r
JOIN dim_users u ON r.user_id = u.user_id
GROUP BY u.country
ORDER BY num_ratings DESC, u.country
LIMIT 1;
