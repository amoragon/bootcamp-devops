FROM maven:3-openjdk-8 as builder
WORKDIR /opt/spring-app
COPY ./spring-app ./
RUN mvn package

FROM openjdk:8-jre-alpine
EXPOSE 8080
COPY --from=builder /opt/spring-app/target/spring-app-0.1.0.jar /opt
WORKDIR /opt
CMD ["java", "-jar", "spring-app-0.1.0.jar"]
