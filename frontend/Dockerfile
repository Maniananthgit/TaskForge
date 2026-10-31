# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.35.3 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --no-tree-shake-icons

# Stage 2: Serve with High-Performance Nginx Alpine
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

# Nginx configuration for Single Page Applications (GoRouter support)
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
    error_page 500 502 503 504 /50x.html; \
    location = /50x.html { \
        root /usr/share/nginx/html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
