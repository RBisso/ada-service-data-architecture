package com.products;

import com.products.handler.ProductHandler;
import com.products.repository.ProductRepository;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class App {
    public static void main(String[] args) throws Exception {
        int maxRetries = 10;
        for (int i = 1; i <= maxRetries; i++) {
            try {
                System.out.println("Connecting to database (attempt " + i + "/" + maxRetries + ")...");
                ProductRepository.init();
                break;
            } catch (Exception e) {
                if (i == maxRetries) {
                    System.err.println("Failed to connect to database after " + maxRetries + " attempts");
                    throw e;
                }
                Thread.sleep(2000);
            }
        }

        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/api/products", new ProductHandler());
        server.createContext("/health", exchange -> {
            String response = "{\"status\":\"ok\"}";
            byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, bytes.length);
            try (var os = exchange.getResponseBody()) {
                os.write(bytes);
            }
        });
        server.start();
        System.out.println("Server started on port " + port);
    }
}
