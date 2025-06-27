import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import EventAddService "services/event/create";
import EventReadService "services/event/read";
import EventUpdateService "services/event/update";
import EventAttendeeAddService "services/eventAttendee/addAttendee";
import EventAttendeeGetService "services/eventAttendee/getAttendee";
import EventSchemaService "services/schema";
import ArgumentTypes "types/argumentTypes";
import SharedConstants "../shared/constants";
import SharedInterfaces "../shared/interfaces";
import SharedTypes "../shared/types";

shared ({ caller = initializer }) actor class EventCanister() = this {

  stable var databases = Map.new<Text, Database.Database>();
  stable let d3 = D3.D3();

  private let canistergeekMonitor = Canistergeek.Monitor();
  private let canistergeekLogger = Canistergeek.Logger();
  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  public func generateSchema() : async Text {
    let _schemaResponse = await EventSchemaService.generateEventSchema(databases);
    return "Schema created successfully";
  };

  public func get_trusted_origins() : async [Text] {
    return SharedConstants.whiteListedCanisters;
  };

  public shared (msg) func createEventAndRegisterWithKonecta(
    userCanisterId : Text,
    payload : ArgumentTypes.CreateEventAndKonectaPayload,
  ) : async Result.Result<ArgumentTypes.CreateEventAndKonectaResponse, Text> {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    canistergeekMonitor.collectMetrics();
    await EventAddService.createEventAndRegister(
      msg.caller,
      userCanisterId,
      payload,
      databases,
      d3,
      canistergeekLogger,
    );
  };

  public shared (msg) func cancelEvent(userPrincipal : Principal, eventId : Text) : async Result.Result<Text, Text> {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.cancelEvent(userPrincipal, eventId, databases, canistergeekLogger);
  };

  public shared (msg) func addEventAttendee(payload : SharedTypes.EventAttendeeRequestPayload) : async Result.Result<Text, Text> {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    await EventAttendeeAddService.addEventAttendee(payload, databases, canistergeekLogger);
  };

  public query func checkIfAttendeeExistsForEvent(userPrincipal : Principal, eventId : Text) : async Bool {
    return EventAttendeeGetService.checkIfAttendeeExistsForEvent(userPrincipal, eventId, databases);
  };

  public composite query func getAttendeesByActionWithUserDetails(eventId : Text, action : SharedTypes.EventAttendeeActions) : async Result.Result<[SharedTypes.UserResponsePayload], [Text]> {
    let response = EventAttendeeGetService.getAttendeesIdsByAction(eventId, action, databases);

    switch (response) {
      case (#ok(userIds)) {
        if (Array.size(userIds) == 0) {
          return #ok([]);
        };

        let indexActor = actor (SharedConstants.IndexCanister) : SharedInterfaces.IndexActor;
        let usersDataResponse = await indexActor.getUsersDataByPrincipal(userIds);

        var userPayloadsBuffer = Buffer.Buffer<SharedTypes.UserResponsePayload>(usersDataResponse.size());

        for ((_, userDataOpt) in usersDataResponse.vals()) {
          switch (userDataOpt) {
            case (?userData) {
              userPayloadsBuffer.add(userData);
            };
            case (null) {};
          };
        };

        return #ok(Buffer.toArray(userPayloadsBuffer));
      };
      case (#err(err)) {
        return #err(err);
      };
    };
  };

  private func getSingleEventDetails(eventId : Text) : async (Text, ?SharedTypes.EventDetailsPayload) {
    let eventDataResult = await EventReadService.eventDetailsWithUserData(eventId, databases);

    let eventDataOpt : ?SharedTypes.EventDetailsPayload = switch (eventDataResult) {
      case (#ok(data)) ?data;
      case (#err(_)) null;
    };

    return (eventId, eventDataOpt);
  };

  // 2. The main public function now just orchestrates the parallel calls.
  public shared (msg) func getMultipleEventsDetailsWithUserData(eventIds : [Text]) : async [(Text, ?SharedTypes.EventDetailsPayload)] {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };

    // Use a Buffer to collect the promises
    var promisesBuffer = Buffer.Buffer<async (Text, ?SharedTypes.EventDetailsPayload)>(eventIds.size());

    for (eventId in eventIds.vals()) {
      // Call the simple helper function. The compiler knows its return type.
      promisesBuffer.add(getSingleEventDetails(eventId));
    };

    let promises = Buffer.toArray(promisesBuffer);

    // Await all promises in parallel and collect results
    var resultsBuffer = Buffer.Buffer<(Text, ?SharedTypes.EventDetailsPayload)>(promises.size());
    for (p in promises.vals()) {
      resultsBuffer.add(await p);
    };

    return Buffer.toArray(resultsBuffer);
  };

  public query func getEventsForAttendee(userPrincipal : Text) : async Result.Result<[Text], [Text]> {
    EventAttendeeGetService.getEventsForAttendee(Principal.fromText(userPrincipal), databases);
  };

  public query func getEventTableMetadata() : async Database.GetTableMetadataOutputType {
    EventReadService.eventTableMetadata(databases);
  };

  public query (msg) func getEventDetailsByUserPrincipal() : async Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    EventReadService.getEventDetailsByUserPrincipal(msg.caller, databases);
  };

  public query func getEventDetailsByUserId(userPrincipal : Text) : async Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    EventReadService.getEventDetailsByUserId(userPrincipal, databases);
  };

  public shared func getEventDetailsWithUserData(eventId : Text) : async SharedTypes.EventDetailsPayload {
    let result = await EventReadService.eventDetailsWithUserData(eventId, databases);

    switch (result) {
      case (#ok(payload)) {
        return payload;
      };
      case (#err(errorMessages)) {
        var combinedError = "";
        if (Array.size(errorMessages) > 0) {
          combinedError := errorMessages[0];
        };

        throw Error.reject("Failed to get event details for eventId '" # eventId # "': " # combinedError);
      };
    };
  };

  public shared (msg) func updateEvent(userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventRequestPayload) : async Result.Result<Text, Text> {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.updateEvent(msg.caller, userCanisterId, eventId, payload, databases, d3, canistergeekLogger);
  };

  public shared (msg) func updateEventUsingUserPrincipal(userPrincipal : Principal, userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventRequestPayload) : async Result.Result<Text, Text> {
    if (Principal.isAnonymous(msg.caller)) {
      throw Error.reject("Anonymous callers are not allowed to perform this action.");
    };
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.updateEvent(userPrincipal, userCanisterId, eventId, payload, databases, d3, canistergeekLogger);
  };

  public query func getFile(fileId : Text) : async D3.GetFileOutputType {
    EventReadService.getFile(fileId, d3);
  };

  public query func http_request(httpRequest : D3.HttpRequest) : async D3.HttpResponse {
    D3.getFileHTTP({ d3; httpRequest; httpStreamingCallbackActor = this });
  };

  public query func http_request_streaming_callback(streamingCallbackToken : D3.StreamingCallbackToken) : async D3.StreamingCallbackHttpResponse {
    D3.httpStreamingCallback({ d3; streamingCallbackToken });
  };

  system func preupgrade() {
    _canistergeekMonitorUD := ?canistergeekMonitor.preupgrade();
    _canistergeekLoggerUD := ?canistergeekLogger.preupgrade();
  };

  system func postupgrade() {
    canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
    _canistergeekMonitorUD := null;

    canistergeekLogger.postupgrade(_canistergeekLoggerUD);
    _canistergeekLoggerUD := null;

    //Optional: override default number of log messages to your value
    canistergeekLogger.setMaxMessagesCount(3000);
  };

  public query func getCanistergeekInformation(request : Canistergeek.GetInformationRequest) : async Canistergeek.GetInformationResponse {

    Canistergeek.getInformation(?canistergeekMonitor, ?canistergeekLogger, request);
  };

  public shared func updateCanistergeekInformation(request : Canistergeek.UpdateInformationRequest) : async () {

    canistergeekMonitor.updateInformation(request);
  };

  // system func preupgrade() {
  //   EventService.generateEventSchema(databases);
  // };
};
