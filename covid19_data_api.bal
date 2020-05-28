import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/docker;

http:Client covid19APIClient = new("https://covidapi.info/api/v1");

@docker:Config {
    name: "covid-api"
}
@docker:CopyFiles {
    files: [{
        sourceFile: "data-sources.json",
        target: "data-sources.json"
    }]
}
@http:ServiceConfig {
    basePath: "/covid19"
}
service covid19RecoveriesService on new http:Listener(9090) {
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/recoveries"
    }
    resource function getRecoveries(http:Caller caller, http:Request request) {
        http:Response|error responseOrError = covid19APIClient->get("/global");

        if (responseOrError is error) {
            json errorJson = { message: "error occurred retrieving data" };
            error? clientError = caller->internalServerError(errorJson);
            if (clientError is error) {
                log:printError("unable to communicate to client", clientError);
            }
            return;
        }

        http:Response response = <http:Response>responseOrError;
        // Get the JSON payload
        json|error covidJsonOrError = response.getJsonPayload();
        
        if (covidJsonOrError is error) {
            json errorJson = { message: "error occurred retrieving data" };
            error? clientError = caller->internalServerError(errorJson);
            log:printError("backend response does not contain a json");
            if (clientError is error) {
                log:printError("unable to communicate to client", clientError);
            }
            return;
        }

        json covidJson = <json>covidJsonOrError;

        if (response.statusCode != 200) {
            json errorJson = { message: "error occurred retrieving data" };
            error? clientError = caller->internalServerError(errorJson);
            log:printError("error recieved from backend API: " + covidJson.toJsonString());
            if (clientError is error) {
                log:printError("unable to communicate to client", clientError);
            }
            return;
        }

        // Get the number of recoveries
        json|error recoveriesJsonOrError = covidJson.result.recovered;

        if (recoveriesJsonOrError is error) {
            json errorJson = { message: "error occurred retrieving data" };
            error? clientError = caller->internalServerError(errorJson);
            log:printError("json received from backend is invalid: " + covidJson.toJsonString());
            if (clientError is error) {
                log:printError("unable to communicate to client", clientError);
            }
            return;
        }

        // Create a new JSON
        json responseJson = { recoveries: <@untainted>recoveriesJsonOrError.toString() };

        // Respond back to the client.
        error? clientError = caller->ok(responseJson);
        if (clientError is error) {
            log:printError("unable to communicate to client", clientError);
        }
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/sources"
    }
    resource function getDataSource(http:Caller caller, http:Request request) returns error? {
        io:ReadableByteChannel|error dataSourceByteChannelOrError = <@untainted>io:openReadableFile("data-sources.json");

        if (dataSourceByteChannelOrError is error) {
            json errorJson = { message: "error occurred retrieving data" };
            error? clientError = caller->internalServerError(errorJson);
            log:printError("unable to read data-sources.json", dataSourceByteChannelOrError);
            if (clientError is error) {
                log:printError("unable to communicate to client", clientError);
            }
            return;
        }

        io:ReadableByteChannel dataSourceByteChannel = <io:ReadableByteChannel>dataSourceByteChannelOrError;

        io:ReadableCharacterChannel dataSourceChannel = new(dataSourceByteChannel, "UTF8");

        // Read JSON from data-sources.json file
        json dataSourceJson = <@untainted>checkpanic dataSourceChannel.readJson();
        check dataSourceChannel.close();

        // Respond back to the client.
        error? clientError = caller->ok(dataSourceJson);
        if (clientError is error) {
            log:printError("unable to communicate to client", clientError);
        }
    }
}
