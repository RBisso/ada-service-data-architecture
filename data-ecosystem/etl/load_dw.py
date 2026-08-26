#!/usr/bin/env python3
"""MovieFlix ETL: loads the Data Lake (CSV) into the Data Warehouse (PostgreSQL).

Flow:
    1. Connect to the Data Warehouse (db_dw) with retry/backoff.
    2. Recreate the star schema (01_dw_schema.sql).
    3. Load dim_movies, dim_genres, movie_genres, dim_users and fact_ratings
       from the raw CSVs in the Data Lake.
    4. Create the Data Mart views (02_datamarts.sql).
    5. Run the analytical queries (03_analytics.sql) and print the results.
"""

import csv
import os
import re
import sys
import time
from datetime import datetime

import psycopg2

DB_HOST = os.environ.get("DB_HOST", "db_dw")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_USER = os.environ.get("DB_USER", "dw_user")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "dw_pass")
DB_NAME = os.environ.get("DB_NAME", "movieflix_dw")

DATALAKE_DIR = os.environ.get("DATALAKE_DIR", "/datalake")
SQL_DIR = os.environ.get("SQL_DIR", "/sql")

SCHEMA_SQL = os.path.join(SQL_DIR, "01_dw_schema.sql")
DATAMARTS_SQL = os.path.join(SQL_DIR, "02_datamarts.sql")
ANALYTICS_SQL = os.path.join(SQL_DIR, "03_analytics.sql")

MOVIES_CSV = os.path.join(DATALAKE_DIR, "movies.csv")
USERS_CSV = os.path.join(DATALAKE_DIR, "users.csv")
RATINGS_CSV = os.path.join(DATALAKE_DIR, "ratings.csv")

TITLE_YEAR_RE = re.compile(r"\((\d{4})\)\s*$")


def connect_with_retry(max_attempts=30, delay=2):
    for attempt in range(1, max_attempts + 1):
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                user=DB_USER,
                password=DB_PASSWORD,
                dbname=DB_NAME,
            )
            print(f"[etl] Connected to Data Warehouse at {DB_HOST}:{DB_PORT}")
            return conn
        except psycopg2.OperationalError as exc:
            print(
                f"[etl] Waiting for Data Warehouse (attempt {attempt}/{max_attempts}): {exc}"
            )
            time.sleep(delay)
    raise RuntimeError("Could not connect to the Data Warehouse.")


def split_sql(sql_text):
    """Split a SQL file into individual statements, ignoring `--` comments."""
    cleaned_lines = [line.split("--", 1)[0] for line in sql_text.splitlines()]
    text = "\n".join(cleaned_lines)
    return [stmt.strip() for stmt in text.split(";") if stmt.strip()]


def run_sql_file(cursor, path):
    with open(path, encoding="utf-8") as fh:
        statements = split_sql(fh.read())
    for stmt in statements:
        cursor.execute(stmt)
    print(f"[etl] Executed {path} ({len(statements)} statement(s))")


def load_movies(cursor, path):
    genres = {}
    movie_rows = []

    with open(path, encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            movie_id = int(row["movieId"])
            title = row["title"]
            genres_str = row["genres"]

            match = TITLE_YEAR_RE.search(title)
            release_year = int(match.group(1)) if match else None
            if match:
                title = title[: match.start()].strip()

            movie_rows.append((movie_id, title, release_year, genres_str))

            for genre in genres_str.split("|"):
                genre = genre.strip()
                if genre and genre not in genres:
                    genres[genre] = None

    cursor.executemany(
        "INSERT INTO dim_movies (movie_id, title, release_year, genres) "
        "VALUES (%s, %s, %s, %s)",
        movie_rows,
    )

    for genre in genres:
        cursor.execute(
            "INSERT INTO dim_genres (genre) VALUES (%s) RETURNING genre_id", (genre,)
        )
        genres[genre] = cursor.fetchone()[0]

    bridge_rows = []
    for movie_id, _, _, genres_str in movie_rows:
        for genre in genres_str.split("|"):
            genre = genre.strip()
            if genre:
                bridge_rows.append((movie_id, genres[genre]))
    cursor.executemany(
        "INSERT INTO movie_genres (movie_id, genre_id) VALUES (%s, %s)", bridge_rows
    )

    print(
        f"[etl] Loaded dim_movies: {len(movie_rows)} row(s), "
        f"dim_genres: {len(genres)} row(s), "
        f"movie_genres: {len(bridge_rows)} row(s)"
    )


def load_users(cursor, path):
    rows = []
    with open(path, encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            rows.append(
                (
                    int(row["userId"]),
                    row["gender"],
                    int(row["age"]),
                    row["occupation"],
                    row["country"],
                )
            )
    cursor.executemany(
        "INSERT INTO dim_users (user_id, gender, age, occupation, country) "
        "VALUES (%s, %s, %s, %s, %s)",
        rows,
    )
    print(f"[etl] Loaded dim_users: {len(rows)} row(s)")


def load_ratings(cursor, path):
    rows = []
    with open(path, encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            rated_at = datetime.fromtimestamp(int(row["timestamp"]))
            rows.append(
                (
                    int(row["userId"]),
                    int(row["movieId"]),
                    float(row["rating"]),
                    rated_at,
                )
            )
    cursor.executemany(
        "INSERT INTO fact_ratings (user_id, movie_id, rating, rated_at) "
        "VALUES (%s, %s, %s, %s)",
        rows,
    )
    print(f"[etl] Loaded fact_ratings: {len(rows)} row(s)")


def run_analytics(cursor, path):
    with open(path, encoding="utf-8") as fh:
        statements = split_sql(fh.read())

    for stmt in statements:
        if not stmt.upper().startswith("SELECT"):
            cursor.execute(stmt)
            continue

        cursor.execute(stmt)
        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()
        print("\n" + "=" * 60)
        print(" | ".join(columns))
        print("-" * 60)
        for row in rows:
            print(" | ".join(str(value) for value in row))
        print("=" * 60)


def main():
    print("[etl] Starting MovieFlix ETL...")
    conn = connect_with_retry()
    try:
        with conn.cursor() as cursor:
            run_sql_file(cursor, SCHEMA_SQL)
            load_movies(cursor, MOVIES_CSV)
            load_users(cursor, USERS_CSV)
            load_ratings(cursor, RATINGS_CSV)
            run_sql_file(cursor, DATAMARTS_SQL)
            conn.commit()
            run_analytics(cursor, ANALYTICS_SQL)
            conn.commit()
        print("[etl] ETL completed successfully.")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[etl] ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
