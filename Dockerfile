FROM openjdk:8

WORKDIR /home/

COPY data-sources.json .
COPY covid19_data_api.jar .

EXPOSE 9090

CMD java -jar covid19_data_api.jar