FROM openjdk:8-jre-alpine

WORKDIR /swagger-petstore

COPY target/lib/jetty-runner.jar /swagger-petstore/jetty-runner.jar
COPY target/*.war /swagger-petstore/server.war
COPY src/main/resources/openapi.yaml /swagger-petstore/openapi.yaml
COPY inflector.yaml /swagger-petstore/
COPY appd-javaagent /opt/appdynamics/

EXPOSE 8080

ENV JAVA_OPTS -javaagent:/opt/appdynamics/javaagent.jar

CMD ["java", "${JAVA_OPTS}", "-jar", "-DswaggerUrl=openapi.yaml", "/swagger-petstore/jetty-runner.jar", "--log", "/var/log/yyyy_mm_dd-requests.log", "/swagger-petstore/server.war"]
