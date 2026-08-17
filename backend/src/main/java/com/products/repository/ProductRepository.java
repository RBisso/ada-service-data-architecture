package com.products.repository;

import com.products.config.Config;
import com.products.model.Product;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class ProductRepository {

    public static void init() throws SQLException {
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS products (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(50) NOT NULL
                )
            """);
        }
    }

    private static Connection getConnection() throws SQLException {
        return DriverManager.getConnection(Config.getJdbcUrl(), Config.DB_USER, Config.DB_PASSWORD);
    }

    public static List<Product> findAll() throws SQLException {
        List<Product> products = new ArrayList<>();
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT id, name FROM products")) {
            while (rs.next()) {
                products.add(new Product(rs.getInt("id"), rs.getString("name")));
            }
        }
        return products;
    }

    public static Optional<Product> findById(int id) throws SQLException {
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT id, name FROM products WHERE id = ?")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(new Product(rs.getInt("id"), rs.getString("name")));
                }
            }
        }
        return Optional.empty();
    }

    public static Product save(String name) throws SQLException {
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement("INSERT INTO products (name) VALUES (?) RETURNING id")) {
            ps.setString(1, name);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return new Product(rs.getInt("id"), name);
            }
        }
    }

    public static Optional<Product> update(int id, String name) throws SQLException {
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement("UPDATE products SET name = ? WHERE id = ? RETURNING id")) {
            ps.setString(1, name);
            ps.setInt(2, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(new Product(id, name));
                }
            }
        }
        return Optional.empty();
    }

    public static boolean delete(int id) throws SQLException {
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM products WHERE id = ?")) {
            ps.setInt(1, id);
            return ps.executeUpdate() > 0;
        }
    }
}
