package com.products.handler;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Set;

public class StaticResourceHandler implements HttpHandler {
    private final Set<String> allowedPaths;
    private final String resourcePath;
    private final String contentType;

    public StaticResourceHandler(Set<String> allowedPaths, String resourcePath, String contentType) {
        this.allowedPaths = Set.copyOf(allowedPaths);
        this.resourcePath = resourcePath;
        this.contentType = contentType;
    }

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            send(exchange, 405, "Method not allowed".getBytes());
            return;
        }

        String requestPath = exchange.getRequestURI().getPath();
        if (!allowedPaths.contains(requestPath)) {
            send(exchange, 404, "Not found".getBytes());
            return;
        }

        try (InputStream inputStream = getClass().getResourceAsStream(resourcePath)) {
            if (inputStream == null) {
                send(exchange, 404, "Not found".getBytes());
                return;
            }

            byte[] body = inputStream.readAllBytes();
            exchange.getResponseHeaders().set("Content-Type", contentType);
            send(exchange, 200, body);
        }
    }

    private void send(HttpExchange exchange, int statusCode, byte[] body) throws IOException {
        exchange.sendResponseHeaders(statusCode, body.length);
        try (OutputStream outputStream = exchange.getResponseBody()) {
            outputStream.write(body);
        }
    }
}
