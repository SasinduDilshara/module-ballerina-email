// Copyright (c) 2020 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerina/task;

# Represents a service listener that monitors the email server location.
public class ImapListener {

    private ImapListenerConfig config;
    private task:Scheduler? appointment = ();

    # Gets invoked during the `email:ImapListener` initialization.
    #
    # + ListenerConfig - Configurations for Email endpoint
    # + return - () or else error upon failure to initialize the listener
    public isolated function init(ImapListenerConfig listenerConfig) returns Error? {
        self.config = listenerConfig;
        ImapConfig imapConfig = {
             port: listenerConfig.port,
             security: listenerConfig.security
        };
        SecureSocket? secureSocketParam = listenerConfig?.secureSocket;
        if (!(secureSocketParam is ())) {
            imapConfig.secureSocket = secureSocketParam;
        }
        return externalInit(self, self.config, imapConfig, "IMAP");
    }

    # Starts the `email:ImapListener`.
    # ```ballerina
    # email:Error? result = emailListener.start();
    # ```
    #
    # + return - () or else error upon failure to start the listener
    public isolated function 'start() returns @tainted error? {
        return self.internalStart();
    }

    # Stops the `email:ImapListener`.
    # ```ballerina
    # email:Error? result = emailListener.__stop();
    # ```
    #
    # + return - () or else error upon failure to stop the listener
    public isolated function __stop() returns error? {
        check self.stop();
    }

    # Binds a service to the `email:ImapListener`.
    # ```ballerina
    # email:Error? result = emailListener.attach(helloService, hello);
    # ```
    #
    # + s - Type descriptor of the service
    # + name - Name of the service
    # + return - `()` or else a `email:Error` upon failure to register the listener
    public isolated function attach(service object {} s, string[]|string? name = ()) returns error? {
        if(name is string?) {
            return self.register(s, name);
        }
    }

    # Stops consuming messages and detaches the service from the `email:ImapListener`.
    # ```ballerina
    # email:Error? result = emailListener.detach(helloService);
    # ```
    #
    # + s - Type descriptor of the service
    # + return - `()` or else a `email:Error` upon failure to detach the service
    public isolated function detach(service object {} s) returns error? {

    }

    # Stops the `email:ImapListener` forcefully.
    # ```ballerina
    # email:Error? result = emailListener.immediateStop();
    # ```
    #
    # + return - `()` or else a `email:Error` upon failure to stop the listener
    public isolated function immediateStop() returns error? {
        check self.stop();
    }

    # Stops the `email:ImapListener` gracefully.
    # ```ballerina
    # email:Error? result = emailListener.gracefulStop();
    # ```
    #
    # + return - () or else error upon failure to stop the listener
    public isolated function gracefulStop() returns error? {
        check self.stop();
    }

    isolated function internalStart() returns @tainted error? {
        var scheduler = self.config.cronExpression;
        if (scheduler is string) {
            task:AppointmentConfiguration config = {cronExpression: scheduler};
            self.appointment = check new(config);
        } else {
            task:TimerConfiguration config = {intervalInMillis: self.config.pollingIntervalInMillis, initialDelayInMillis: 100};
            self.appointment = check new (config);
        }
        var appointment = self.appointment;
        if (appointment is task:Scheduler) {
            check appointment.attach(imapAppointmentService, self);
            check appointment.start();
        }
        //log:print("User " + self.config.username.to + " is listening to remote server at " + self.config.host + "...");
    }

    isolated function stop() returns error? {
        var appointment = self.appointment;
        if (appointment is task:Scheduler) {
            check appointment.stop();
        }
        log:print("Stopped listening to remote server at " + self.config.host);
    }

    isolated function poll() returns error? {
        return poll(self);
    }

    # Registers for the Email service.
    # ```ballerina
    # emailListener.register(helloService, hello);
    # ```
    #
    # + emailService - Type descriptor of the service
    # + name - Service name
    public isolated function register(service object {} emailService, string? name) {
        register(self, emailService);
    }
}

final service isolated object{} imapAppointmentService = service object {
    remote isolated function onTrigger(ImapListener l) {
        var result = l.poll();
        if (result is error) {
            log:printError("Error while executing poll function", err = result);
        }
    }
};

# Configuration for Email listener endpoint.
#
# + host - Email server host
# + username - Email server access username
# + password - Email server access password
# + pollingIntervalInMillis - Periodic time interval to check new update
# + port - Port number of the IMAP server
# + security - Type of security channel
# + cronExpression - Cron expression to check new update
# + secureSocket - Secure socket configuration
public type ImapListenerConfig record {|
    string host;
    string username;
    string password;
    int pollingIntervalInMillis = 60000;
    int port = 993;
    Security security = SSL;
    string? cronExpression = ();
    SecureSocket secureSocket?;
|};
