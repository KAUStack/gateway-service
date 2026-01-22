# Multi-stage Dockerfile for local development
# Stage 1: Build
FROM eclipse-temurin:25-jdk-alpine AS build

WORKDIR /app

# Copy Maven wrapper and pom.xml first for better caching
COPY .mvn .mvn
COPY mvnw pom.xml ./

# Download dependencies (cached if pom.xml doesn't change)
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN ./mvnw clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:25-jre-alpine

WORKDIR /app

# Create a non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Install curl for health checks
RUN apk add --no-cache curl

# Copy the built JAR from build stage
COPY --from=build /app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

USER appuser

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
