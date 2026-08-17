package com.products.config;

public class Config {
    public static final String DB_HOST = System.getenv("DB_HOST");
    public static final String DB_PORT = System.getenv("DB_PORT");
    public static final String DB_USER = System.getenv("DB_USER");
    public static final String DB_PASSWORD = System.getenv("DB_PASSWORD");
    public static final String DB_NAME = System.getenv("DB_NAME");

    public static String getJdbcUrl() {
        return String.format("jdbc:postgresql://%s:%s/%s", DB_HOST, DB_PORT, DB_NAME);
    }
}
