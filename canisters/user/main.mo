import Database "mo:alfangodb/AlfangoDB";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import Cygnus "library/Cygnus";
import CalendarReadService "services/calendar/read";
import CalendarSchemaService "services/calendar/schema";
import CalendarUpsertService "services/calendar/upsert";
import CommonService "services/common";
import EventMetadataCreateService "services/event_metadata/create";
import EventMetadataReadService "services/event_metadata/read";
import EventMetadataSchemaService "services/event_metadata/schema";
import EventMetadataUpdateService "services/event_metadata/update";
import Account "services/icPCH/Account";
import icPCHUtils "services/icPCH/Utils";
import FileUploadService "services/user/fileupload";
import UserReadService "services/user/read";
import UserUpsertService "services/user/upsert";
import ArgumentTypes "types/argumentTypes";
import UserConstants "utils/constants";

shared ({ caller = initializer }) actor class UserCanister() = this {

  stable var userDataMap = Map.new<Principal, ArgumentTypes.UserPayload>();

  stable var databases = Map.new<Text, Database.Database>();

  stable let d3 = D3.D3();

  private let canistergeekMonitor = Canistergeek.Monitor();
  private let canistergeekLogger = Canistergeek.Logger();
  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  public query func get_trusted_origins() : async [Text] {
    return UserConstants.whiteListedCanisters;
  };

  public query func getCurrentCanisterPrincipal() : async Text {
    return Principal.toText(Principal.fromActor(this));
  };

  public query (msg) func getAccountIdentifier() : async Text {
    icPCHUtils.blobToHex(Account.accountIdentifier(msg.caller, Account.defaultSubaccount()));
  };

  public shared (msg) func upsertUser(payload : ArgumentTypes.UserRequestPayload) : async Text {
    await UserUpsertService.upsertUser(msg.caller, userDataMap, payload, Principal.fromActor(this));
  };

  public shared func updateUserRecord(principal : Text, values : ArgumentTypes.UpdateUserRecordPayload) : async Text {
    return await UserUpsertService.updateUserRecord(Principal.fromText(principal), values, userDataMap);
  };

  public query (msg) func getUser() : async ?ArgumentTypes.UserPayload {
    UserReadService.getUserDataByPrincipalId(msg.caller, userDataMap);
  };

  public query func getUserByPrincipalId(userPrincipal : Text) : async ?ArgumentTypes.UserPayload {
    UserReadService.getUserByUserId(userPrincipal, userDataMap);
  };

  public query func getUserDetailsByUsername(username : Text) : async ?ArgumentTypes.UserPayload {
    UserReadService.getUserByUsername(username, userDataMap);
  };

  public query func getUserForEventCanister(userPrincipal : Text) : async ArgumentTypes.EventUserResponsePayload {
    UserReadService.getUserForEventCanister(userPrincipal, userDataMap);
  };

  public func generateSchema() : async Text {
    let _database = await CommonService.createProjectDatabase(databases);
    let _table = await createUserTables();

    return "Schema created successfully";
  };

  private func createUserTables() : async Text {
    try {
      let _calendarTableResponse = await createCalendarTable();
      let _eventMetadataTableResponse = await createEventMetadataTable();
      return "Tables created successfully";
    } catch (e : Error) {
      return "Failed to create tables";
    };
  };

  private func createCalendarTable() : async Text {
    await CalendarSchemaService.createCalendarTable(databases);
  };

  public shared func upsertCalendarData(userPrincipal : Text, calendarId : Text, calendarPayload : ArgumentTypes.CalendarRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();
    await CalendarUpsertService.upsertCalendarData(userPrincipal, calendarId, calendarPayload, userDataMap, databases, canistergeekLogger);
  };

  public query func getCalendarId(eventId : Text) : async Text {
    CalendarReadService.getCalendarId(eventId, databases);
  };

  private func createEventMetadataTable() : async Text {
    let response = await EventMetadataSchemaService.createEventMetadataTable(databases);
    return response;
  };

  public shared func createEventMetaData(eventMetadataPayload : ArgumentTypes.EventMetadataRequestPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventMetadataCreateService.createEventMetaData(eventMetadataPayload, databases, canistergeekLogger);
  };

  public shared (msg) func updateEventMetaData(eventMetadataId : Text, eventMetadataPayload : ArgumentTypes.EventMetadataRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();
    await EventMetadataUpdateService.updateEventMetaData(msg.caller, eventMetadataId, eventMetadataPayload, databases, canistergeekLogger);
  };

  public query func getEventMetadataId(eventId : Text, calendarId : Text) : async Text {
    EventMetadataReadService.getEventMetadataId(eventId, calendarId, databases);
  };

  public query func getEventMetadataById(eventMetadataId : Text) : async Result.Result<ArgumentTypes.EventMetadataResponsePayload, [Text]> {
    EventMetadataReadService.getEventMetadataById(eventMetadataId, databases);
  };

  public query func getAllEventsMetadata() : async Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    EventMetadataReadService.getAllEventsMetadata(databases);
  };

  public query func getAllEventsMetadataForUser() : async Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    EventMetadataReadService.getAllEventsMetadataForUser(databases);
  };

  public query func getEventMetaDataFromStartToEndDate(startDate : Nat, endDate : Nat, categories : [Text]) : async Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    EventMetadataReadService.getEventMetaDataFromStartToEndDate(startDate, endDate, categories, databases);
  };

  public shared func upsertUserPublic(pid : Text, payload : ArgumentTypes.UserRequestPayload) : async Text {
    await UserUpsertService.upsertUser(Principal.fromText(pid), userDataMap, payload, Principal.fromActor(this));
  };

  public shared func saveFile(file : D3.StoreFileInputType) : async Text {
    await FileUploadService.saveFile(file, d3);
  };

  public query func getUserPublic(pid : Text) : async ?ArgumentTypes.UserPayload {
    UserReadService.getUserDataByPrincipalId(Principal.fromText(pid), userDataMap);
  };

  public query func getFile(fileId : Text) : async D3.GetFileOutputType {
    UserReadService.getFile(fileId, d3);
  };

  public query func http_request(httpRequest : D3.HttpRequest) : async D3.HttpResponse {
    D3.getFileHTTP({ d3; httpRequest; httpStreamingCallbackActor = this });
  };

  public query func http_request_streaming_callback(streamingCallbackToken : D3.StreamingCallbackToken) : async D3.StreamingCallbackHttpResponse {
    D3.httpStreamingCallback({ d3; streamingCallbackToken });
  };

  public query func getUserEventMetadataTableMetadata() : async Database.GetTableMetadataOutputType {
    EventMetadataReadService.getUserEventMetadataTableMetadata(databases);
  };

  public query func getCalendarTableMetadata() : async Database.GetTableMetadataOutputType {
    CalendarReadService.getCalendarTableMetadata(databases);
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

  public shared (msg) func fetchCanisterStatus(auxPrincipalId : ?Principal) : async Cygnus.CanisterStatus {
    let cygnusClass = Cygnus.Cygnus();
    //  cygnusClass.validateUser(msg.caller, auxPrincipalId);
    await cygnusClass.getStatus(Principal.fromActor(this));
  };

  public shared (msg) func approveCycleWithdrawal(withdrawAmount : Nat) : async () {
    let cygnusClass = Cygnus.Cygnus();
    cygnusClass.validateUser(msg.caller, null);
    let sendablelimit : Nat = Cycles.balance();
    let sendableCycles = if (withdrawAmount <= sendablelimit) withdrawAmount else sendablelimit;
    Cycles.add(sendableCycles);
    await cygnusClass.CygnusCanitser.acceptWithdrwalCyclesFromOtherCanitsers();
  };

  /* Validate and reject anonymous calls*/
  // system func inspect({ caller : Principal }) : Bool {
  //   not (Principal.isAnonymous(caller));
  // };

};
