-- ============================================================================
-- MovieFlix Data Marts - Business Views
-- ============================================================================
-- Layer 3: Data Marts (SQL views over the Data Warehouse).
-- Recreated by the ETL script after each data load.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View 1: Top 10 highest-rated movies by genre
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_top10_movies_by_genre AS
WITH movie_ratings AS (
    SELECT
        m.movie_id,
        m.title,
        m.release_year,
        g.genre,
        ROUND(AVG(r.rating), 2) AS avg_rating,
        COUNT(r.rating_id)      AS rating_count
    FROM fact_ratings r
    JOIN dim_movies  m  ON r.movie_id = m.movie_id
    JOIN movie_genres mg ON m.movie_id = mg.movie_id
    JOIN dim_genres  g  ON mg.genre_id = g.genre_id
    GROUP BY m.movie_id, m.title, m.release_year, g.genre
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY genre
            ORDER BY avg_rating DESC, rating_count DESC, movie_id
        ) AS rn
    FROM movie_ratings
)
SELECT genre, title, release_year, avg_rating, rating_count
FROM ranked
WHERE rn <= 10
ORDER BY genre, rn;

-- ----------------------------------------------------------------------------
-- View 2: Average rating by user age group
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_avg_rating_by_age_group AS
WITH rated AS (
    SELECT
        CASE
            WHEN u.age < 18            THEN 'Under 18'
            WHEN u.age BETWEEN 18 AND 24 THEN '18-24'
            WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
            WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
            WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
            ELSE '55+'
        END AS age_group,
        r.rating
    FROM fact_ratings r
    JOIN dim_users u ON r.user_id = u.user_id
)
SELECT
    age_group,
    ROUND(AVG(rating), 2) AS avg_rating,
    COUNT(*)              AS rating_count
FROM rated
GROUP BY age_group
ORDER BY age_group;

-- ----------------------------------------------------------------------------
-- View 3: Number of ratings by country
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_ratings_by_country AS
SELECT
    u.country,
    COUNT(r.rating_id) AS rating_count
FROM fact_ratings r
JOIN dim_users u ON r.user_id = u.user_id
GROUP BY u.country
ORDER BY rating_count DESC, u.country;
