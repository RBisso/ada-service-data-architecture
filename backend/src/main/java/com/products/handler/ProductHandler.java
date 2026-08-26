package com.products.handler;

import com.products.model.Product;
import com.products.repository.ProductRepository;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ProductHandler implements HttpHandler {

    private static final Pattern PRODUCTS_ID = Pattern.compile("^/api/products/(\\d+)$");
    private static final Pattern PRODUCTS = Pattern.compile("^/api/products$");

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();

        try {
            switch (method) {
                case "GET" -> handleGet(exchange, path);
                case "POST" -> handlePost(exchange);
                case "PUT" -> handlePut(exchange, path);
                case "DELETE" -> handleDelete(exchange, path);
                default -> sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            }
        } catch (Exception e) {
            sendResponse(exchange, 500, "{\"error\":\"Internal server error\"}");
        }
    }

    private void handleGet(HttpExchange exchange, String path) throws Exception {
        Matcher idMatcher = PRODUCTS_ID.matcher(path);
        if (idMatcher.matches()) {
            int id = Integer.parseInt(idMatcher.group(1));
            Optional<Product> product = ProductRepository.findById(id);
            if (product.isPresent()) {
                sendResponse(exchange, 200, product.get().toJson());
            } else {
                sendResponse(exchange, 404, "{\"error\":\"Product not found\"}");
            }
        } else if (PRODUCTS.matcher(path).matches()) {
            List<Product> products = ProductRepository.findAll();
            StringBuilder sb = new StringBuilder("[");
            for (int i = 0; i < products.size(); i++) {
                if (i > 0) sb.append(",");
                sb.append(products.get(i).toJson());
            }
            sb.append("]");
            sendResponse(exchange, 200, sb.toString());
        } else {
            sendResponse(exchange, 404, "{\"error\":\"Not found\"}");
        }
    }

    private void handlePost(HttpExchange exchange) throws Exception {
        String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        String name = extractName(body);
        if (name == null || name.isBlank()) {
            sendResponse(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }
        Product product = ProductRepository.save(name);
        sendResponse(exchange, 201, product.toJson());
    }

    private void handlePut(HttpExchange exchange, String path) throws Exception {
        Matcher matcher = PRODUCTS_ID.matcher(path);
        if (!matcher.matches()) {
            sendResponse(exchange, 400, "{\"error\":\"Invalid path\"}");
            return;
        }
        int id = Integer.parseInt(matcher.group(1));
        String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        String name = extractName(body);
        if (name == null || name.isBlank()) {
            sendResponse(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }
        Optional<Product> updated = ProductRepository.update(id, name);
        if (updated.isPresent()) {
            sendResponse(exchange, 200, updated.get().toJson());
        } else {
            sendResponse(exchange, 404, "{\"error\":\"Product not found\"}");
        }
    }

    private void handleDelete(HttpExchange exchange, String path) throws Exception {
        Matcher matcher = PRODUCTS_ID.matcher(path);
        if (!matcher.matches()) {
            sendResponse(exchange, 400, "{\"error\":\"Invalid path\"}");
            return;
        }
        int id = Integer.parseInt(matcher.group(1));
        boolean deleted = ProductRepository.delete(id);
        if (deleted) {
            sendResponse(exchange, 204, "");
        } else {
            sendResponse(exchange, 404, "{\"error\":\"Product not found\"}");
        }
    }

    private String extractName(String json) {
        int idx = json.indexOf("\"name\"");
        if (idx == -1) return null;
        int colonIdx = json.indexOf(':', idx);
        int quoteStart = json.indexOf('"', colonIdx + 1);
        int quoteEnd = json.indexOf('"', quoteStart + 1);
        if (quoteStart == -1 || quoteEnd == -1) return null;
        return json.substring(quoteStart + 1, quoteEnd);
    }

    private void sendResponse(HttpExchange exchange, int statusCode, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
}
