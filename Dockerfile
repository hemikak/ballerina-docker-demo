FROM openjdk:8-jre-alpine

WORKDIR /home/

COPY covid19_data_api.jar .
COPY data-sources.json .

EXPOSE 9090

CMD java -jar covid19_data_api.jar