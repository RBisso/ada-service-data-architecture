-- ============================================================================
-- MovieFlix Data Warehouse - Star Schema
-- ============================================================================
-- Layer 2: Data Warehouse (processed data)
-- Tables are recreated by the ETL script (load_dw.py) before each load.
-- ============================================================================

DROP TABLE IF EXISTS fact_ratings CASCADE;
DROP TABLE IF EXISTS movie_genres CASCADE;
DROP TABLE IF EXISTS dim_genres CASCADE;
DROP TABLE IF EXISTS dim_movies CASCADE;
DROP TABLE IF EXISTS dim_users CASCADE;

-- Dimension: Movies
CREATE TABLE dim_movies (
    movie_id     INT PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    release_year INT,
    genres       VARCHAR(200) NOT NULL
);

-- Dimension: Users
CREATE TABLE dim_users (
    user_id    INT PRIMARY KEY,
    gender     CHAR(1),
    age        INT,
    occupation VARCHAR(100),
    country    VARCHAR(100)
);

-- Dimension: Genres (normalized from the pipe-delimited string in movies.csv)
CREATE TABLE dim_genres (
    genre_id SERIAL PRIMARY KEY,
    genre    VARCHAR(50) NOT NULL UNIQUE
);

-- Bridge table: Movies <-> Genres (many-to-many)
CREATE TABLE movie_genres (
    movie_id INT NOT NULL REFERENCES dim_movies (movie_id),
    genre_id INT NOT NULL REFERENCES dim_genres (genre_id),
    PRIMARY KEY (movie_id, genre_id)
);

-- Fact: Ratings
CREATE TABLE fact_ratings (
    rating_id SERIAL PRIMARY KEY,
    user_id    INT NOT NULL REFERENCES dim_users (user_id),
    movie_id   INT NOT NULL REFERENCES dim_movies (movie_id),
    rating     NUMERIC(3, 1) NOT NULL,
    rated_at   TIMESTAMP NOT NULL
);
