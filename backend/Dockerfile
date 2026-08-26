FROM eclipse-temurin:25-jdk AS build
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* && \
    mkdir -p lib && \
    curl -L -o lib/postgresql.jar \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar

COPY src ./src

RUN mkdir -p out && \
    find src/main/java -name "*.java" > sources.txt && \
    javac -cp "lib/postgresql.jar" -d out @sources.txt && \
    cp -R src/main/resources/. out/

FROM eclipse-temurin:25-jre-noble
WORKDIR /app
COPY --from=build /app/lib/postgresql.jar lib/
COPY --from=build /app/out .

ENV DB_HOST=db_oltp
ENV DB_PORT=5432
ENV DB_USER=app_user
ENV DB_PASSWORD=app_pass
ENV DB_NAME=products_db
ENV PORT=8080

EXPOSE 8080

CMD ["java", "-cp", ".:lib/postgresql.jar", "com.products.App"]
