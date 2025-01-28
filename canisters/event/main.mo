import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import EventCommonService "services/common";
import EventAddService "services/event/create";
import EventReadService "services/event/read";
import EventUpdateService "services/event/update";
import EventAttendeeAddService "services/eventAttendee/addAttendee";
import EventAttendeeGetService "services/eventAttendee/getAttendee";
import EventSchemaService "services/schema";
import ArgumentTypes "types/argumentTypes";
import EventConstants "utils/constants";

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
    return EventConstants.whiteListedCanisters;
  };

  public shared (msg) func createEvent(userCanisterId : Text, payload : ArgumentTypes.EventRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();
    await EventAddService.createEvent(msg.caller, userCanisterId, payload, databases, d3, canistergeekLogger);
  };

  public shared func cancelEvent(userPrincipal : Principal, eventId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.cancelEvent(userPrincipal, eventId, databases, canistergeekLogger);
  };

  public shared func addEventAttendee(payload : ArgumentTypes.EventAttendeeRequestPayload) : async Result.Result<Text, Text> {
    await EventAttendeeAddService.addEventAttendee(payload, databases, canistergeekLogger);
  };

  public query func checkIfAttendeeExistsForEvent(userPrincipal : Principal, eventId : Text) : async Bool {
    return EventAttendeeGetService.checkIfAttendeeExistsForEvent(userPrincipal, eventId, databases);
  };

  public composite query func getAttendeesByActionWithUserDetails(eventId : Text, action : ArgumentTypes.EventAttendeeActions) : async Result.Result<[ArgumentTypes.UserResponsePayload], [Text]> {
    let response = EventAttendeeGetService.getAttendeesIdsByAction(eventId, action, databases);
    let userBuffer = Buffer.Buffer<ArgumentTypes.UserResponsePayload>(0);

    switch (response) {
      case (#ok(userIds)) {
        for (userId in userIds.vals()) {
          let user = await getUserDetailsByCompositeQuery(userId);
          userBuffer.add(user);
        };
        #ok(Buffer.toArray(userBuffer));
      };

      case (#err(err)) {
        return #err(err);
      };
    };
  };

  public query func getEventsForAttendee(userPrincipal : Text) : async Result.Result<[Text], [Text]> {
    EventAttendeeGetService.getEventsForAttendee(Principal.fromText(userPrincipal), databases);
  };

  public query func getAttendeesIdsByAction(eventId : Text, action : ArgumentTypes.EventAttendeeActions) : async Result.Result<[Text], [Text]> {
    EventAttendeeGetService.getAttendeesIdsByAction(eventId, action, databases);
  };

  public query func getEventTableMetadata() : async Database.GetTableMetadataOutputType {
    EventReadService.eventTableMetadata(databases);
  };

  public query (msg) func getEventDetailsByUserPrincipal() : async Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    EventReadService.getEventDetailsByUserPrincipal(msg.caller, databases);
  };

  public query func getEventDetailsByUserId(userPrincipal : Text) : async Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    EventReadService.getEventDetailsByUserId(userPrincipal, databases);
  };

  public query func getEventDetailsByEventId(eventId : Text) : async Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    EventReadService.eventDataById(eventId, databases);
  };

  public shared func getEventDetailsWithUserData(eventId : Text) : async ArgumentTypes.EventWithUserDataPayload {
    await EventReadService.eventDetailsWithUserData(eventId, databases);
  };

  public shared (msg) func updateEvent(userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventRequestPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.updateEvent(msg.caller, userCanisterId, eventId, payload, databases, d3, canistergeekLogger);
  };

  public shared (msg) func updateEventUsingUserPrincipal(userPrincipal : Principal, userCanisterId : Text, eventId : Text, payload : ArgumentTypes.EventRequestPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventUpdateService.updateEvent(userPrincipal, userCanisterId, eventId, payload, databases, d3, canistergeekLogger);
  };

  public query func getFile(fileId : Text) : async D3.GetFileOutputType {
    EventReadService.getFile(fileId, d3);
  };

  public composite query func getUserDetailsByCompositeQuery(userId : Text) : async ArgumentTypes.UserResponsePayload {
    let indexActor = actor (EventConstants.IndexCanister) : EventCommonService.IndexActor;
    let userCanisterId = await indexActor.getUserCanisterByUserPrincipal(userId);

    let userCanisterActor = actor (userCanisterId) : EventCommonService.UserCanisterType;
    await userCanisterActor.getUserForEventCanister(userId);
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
  /* Validate and reject anonymous calls*/
  // system func inspect({ caller : Principal }) : Bool {
  //   not (Principal.isAnonymous(caller));
  // };

  // system func preupgrade() {
  //   EventService.generateEventSchema(databases);
  // };
};
