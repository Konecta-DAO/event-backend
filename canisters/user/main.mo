import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Map "mo:map/Map";
import Debug "mo:base/Debug";

// Third-party library imports
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Cygnus "library/Cygnus";
import Cycles "mo:base/ExperimentalCycles";

// Local canister service imports
import CalendarReadService "services/calendar/read";
import EventMetadataCreateService "services/event_metadata/create";
import EventMetadataReadService "services/event_metadata/read";
import EventMetadataUpdateService "services/event_metadata/update";
import FileUploadService "services/user/fileupload";
import SchemaService "services/user/schema";
import CommonService "services/common";

// Type imports
import ArgumentTypes "types/argumentTypes";
import UserConstants "utils/constants";

shared ({ caller = initializer }) actor class UserCanister() = this {

  // --- Stable State ---
  stable var profile : ?ArgumentTypes.UserPayload = null;
  stable var alfangoDB : Database.AlfangoDB = {
    databases = Map.new<Text, Database.Database>();
    STABLE_MEMORY_LIMIT = 3_221_225_472;
    var totalStableBytes = 0;
  };
  stable let d3 = D3.D3();
  private let canistergeekMonitor = Canistergeek.Monitor();
  private let canistergeekLogger = Canistergeek.Logger();
  stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
  stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;

  // --- Profile Management ---
  public shared (msg) func upsertUser(payload : ArgumentTypes.UserRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();
    let caller = msg.caller;

    if (profile == null) {
      profile := ?{
        principal_id = caller;
        canister_id = Principal.fromActor(this);
        firstname = payload.firstname;
        lastname = payload.lastname;
        username = payload.username;
        email = payload.email;
        bio = Option.get(payload.bio, "");
        categories = Option.get(payload.categories, []);
        profilepic = Option.get(payload.profilepic, "");
        coverphoto = Option.get(payload.coverphoto, "");
        introduction_video_link = Option.get(payload.introduction_video_link, "");
        country = payload.country;
        timezone = payload.timezone;
      };
      return "User profile created successfully.";
    } else {
      switch (profile) {
        case (?currentProfile) {
          let indexCanisterPrincipal = Principal.fromText(UserConstants.IndexCanister);

          if (currentProfile.principal_id != caller and caller != indexCanisterPrincipal) {
            return "Error: Caller is not authorized to update this profile.";
          };

          let newUsername = if (caller == indexCanisterPrincipal) {
            payload.username;
          } else {
            currentProfile.username;
          };

          profile := ?{
            principal_id = currentProfile.principal_id;
            canister_id = currentProfile.canister_id;
            username = newUsername;
            firstname = payload.firstname;
            lastname = payload.lastname;
            email = payload.email;
            bio = Option.get(payload.bio, currentProfile.bio);
            categories = Option.get(payload.categories, currentProfile.categories);
            profilepic = Option.get(payload.profilepic, currentProfile.profilepic);
            coverphoto = Option.get(payload.coverphoto, currentProfile.coverphoto);
            introduction_video_link = Option.get(payload.introduction_video_link, currentProfile.introduction_video_link);
            country = payload.country;
            timezone = payload.timezone;
          };
          return "User profile updated successfully.";
        };
        case (null) {
          // This case is logically impossible due to the `if (profile == null)` check above.
          // Trapping is the safest action.
          Debug.trap("Unreachable state in upsertUser");
        };
      };
    };
  };

  public query func getUser() : async ?ArgumentTypes.UserPayload {
    return profile;
  };

  public query func getUserForEventCanister(userPrincipal : Text) : async ArgumentTypes.EventUserResponsePayload {
    switch (profile) {
      case (?p) {
        if (Principal.toText(p.principal_id) != userPrincipal) {
          return CommonService.initialUserObject;
        };

        return {
          principal_id = Principal.toText(p.principal_id);
          canister_id = Principal.toText(p.canister_id);
          firstname = p.firstname;
          lastname = p.lastname;
          username = p.username;
          email = p.email;
          bio = p.bio;
          categories = p.categories;
          profilepic = p.profilepic;
          coverphoto = p.coverphoto;
          introduction_video_link = p.introduction_video_link;
          country = p.country;
          timezone = p.timezone;
        };
      };
      case (null) {
        return CommonService.initialUserObject;
      };
    };
  };

  // --- Schema and Initialization ---

  public func generateSchema() : async Text {
    canistergeekMonitor.collectMetrics();
    let _schemaResponse = SchemaService.generateSchema(alfangoDB, canistergeekLogger);
    return "Schema created successfully";
  };

  // --- Calendar and Event Metadata Management ---

  public shared (msg) func upsertCalendarData(calendarId : Text, calendarPayload : ArgumentTypes.CalendarRequestPayload) : async Text {
    canistergeekMonitor.collectMetrics();

    switch (profile) {
      case (?userProfile) {
        if (userProfile.principal_id != msg.caller) {
          return "Error: Caller is not authorized to perform this action.";
        };

        let calendarExists = Text.size(calendarId) > 0;
        let dataValues : [(Text, Database.AttributeDataValue)] = [
          ("name", #text(calendarPayload.name)),
          ("description", #text(calendarPayload.description)),
          ("timezone", #text(userProfile.timezone)),
        ];
        canistergeekLogger.logMessage("Attribute data values for calendar --->" # debug_show (dataValues));

        if (calendarExists) {
          let item = Database.updateItem({
            updateItemInput = {
              databaseName = UserConstants.KonectA;
              tableName = UserConstants.CalendarTable;
              id = calendarId;
              attributeDataValues = dataValues;
            };
            alfangoDB = alfangoDB;
          });
          canistergeekLogger.logMessage("Calendar update response --->" # debug_show (item));

          switch (item) {
            case (#ok(result)) { return result.id };
            case (#err(_)) { return "Failed to update calendar data" };
          };

        } else {
          let item = await Database.createItem({
            createItemInput = {
              databaseName = UserConstants.KonectA;
              tableName = UserConstants.CalendarTable;
              attributeDataValues = dataValues;
            };
            alfangoDB = alfangoDB;
          });
          canistergeekLogger.logMessage("Calendar create response --->" # debug_show (item));

          switch (item) {
            case (#ok(result)) { return result.id };
            case (#err(_)) { return "Failed to save calendar data" };
          };
        };
      };
      case (null) {
        return "Error: User profile must be created before a calendar can be managed.";
      };
    };
  };

  public query func getCalendarId() : async Text {
    CalendarReadService.getCalendarId(alfangoDB);
  };

  public shared func createEventMetaData(eventMetadataPayload : ArgumentTypes.CreateEventMetadataPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    await EventMetadataCreateService.createEventMetaData(eventMetadataPayload, alfangoDB, canistergeekLogger);
  };

  public shared func updateEventMetaData(eventMetadataId : Text, eventMetadataPayload : ArgumentTypes.UpdateEventMetadataPayload) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    EventMetadataUpdateService.updateEventMetaData(eventMetadataId, eventMetadataPayload, alfangoDB, canistergeekLogger);
  };

  public shared func updateEventMetadataForAttendee({
    eventId : Text;
    eventMetadataPayload : ArgumentTypes.AttendeeEventMetadataRequestPayload;
  }) : async Result.Result<Text, Text> {
    return EventMetadataUpdateService.updateEventMetadataForAttendee({
      eventId;
      eventMetadataPayload;
      alfangoDB;
      canistergeekLogger;
    });
  };

  public query func getEventMetadataId(eventId : Text, calendarId : Text) : async Text {
    EventMetadataReadService.getEventMetadataId(eventId, calendarId, alfangoDB);
  };

  public query func getEventMetadataById(eventMetadataId : Text) : async Result.Result<ArgumentTypes.EventMetadataResponsePayload, [Text]> {
    EventMetadataReadService.getEventMetadataById(eventMetadataId, alfangoDB);
  };

  public query func getAllEventsMetadata() : async Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    EventMetadataReadService.getAllEventsMetadata(alfangoDB);
  };

  public query func getEventMetaDataFromStartToEndDate(startDate : Nat, endDate : Nat, categories : [Text]) : async Result.Result<[ArgumentTypes.EventMetadataResponsePayload], [Text]> {
    EventMetadataReadService.getEventMetaDataFromStartToEndDate(startDate, endDate, categories, alfangoDB);
  };

  public shared func removeCalendarEvent(eventMetadataId : Text) : async Result.Result<Text, Text> {
    canistergeekMonitor.collectMetrics();
    EventMetadataUpdateService.removeCalendarEvent(eventMetadataId, alfangoDB, canistergeekLogger);
  };

  // --- File Management ---
  public shared func saveFile(file : D3.StoreFileInputType) : async Text {
    await FileUploadService.saveFile(file, d3);
  };

  public query func getFile(fileId : Text) : async D3.GetFileOutputType {
    CommonService.getFile(fileId, d3);
  };

  public query func http_request(httpRequest : D3.HttpRequest) : async D3.HttpResponse {
    D3.getFileHTTP({ d3; httpRequest; httpStreamingCallbackActor = this });
  };

  public query func http_request_streaming_callback(streamingCallbackToken : D3.StreamingCallbackToken) : async D3.StreamingCallbackHttpResponse {
    D3.httpStreamingCallback({ d3; streamingCallbackToken });
  };

  // --- Canister Administration & Monitoring ---
  public query func get_trusted_origins() : async [Text] {
    return UserConstants.whiteListedCanisters;
  };

  public shared query func icrc28_trusted_origins() : async {
    trusted_origins : [Text];
  } {
    return { trusted_origins = UserConstants.whiteListedCanisters };
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
    canistergeekLogger.setMaxMessagesCount(3000);
  };

  public query func getCanistergeekInformation(request : Canistergeek.GetInformationRequest) : async Canistergeek.GetInformationResponse {
    Canistergeek.getInformation(?canistergeekMonitor, ?canistergeekLogger, request);
  };

  public shared func updateCanistergeekInformation(request : Canistergeek.UpdateInformationRequest) : async () {
    canistergeekMonitor.updateInformation(request);
  };

  public shared (msg) func fetchCanisterStatus(_auxPrincipalId : ?Principal) : async Cygnus.CanisterStatus {
    let cygnusClass = Cygnus.Cygnus();
    await cygnusClass.getStatus(Principal.fromActor(this));
  };

  public shared (msg) func approveCycleWithdrawal(withdrawAmount : Nat) : async () {
    let cygnusClass = Cygnus.Cygnus();
    cygnusClass.validateUser(msg.caller, null);
    let sendablelimit : Nat = Cycles.balance();
    let sendableCycles = if (withdrawAmount <= sendablelimit) withdrawAmount else sendablelimit;
    Cycles.add<system>(sendableCycles);
    await cygnusClass.CygnusCanitser.acceptWithdrwalCyclesFromOtherCanitsers();
  };

  public shared (_msg) func updateOperation({
    updateOpsInput : Database.UpdateOpsInputType;
  }) : async Database.UpdateOpsOutputType {
    return await Database.updateOperation({
      updateOpsInput;
      alfangoDB = alfangoDB;
    });
  };

  public query (_msg) func queryOperation({
    queryOpsInput : Database.QueryOpsInputType;
  }) : async Database.QueryOpsOutputType {
    return Database.queryOperation({ queryOpsInput; alfangoDB = alfangoDB });
  };

  /* Validate and reject anonymous calls*/
  // system func inspect({ caller : Principal }) : Bool {
  //   not (Principal.isAnonymous(caller));
  // };
};
