import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import CommonService "../../services/common";
import DeleteService "./delete";
import SharedInterfaces "../../../shared/interfaces";
import SharedConstants "../../../shared/constants";
import SharedTypes "../../../shared/types";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import { getTupleValueAsText; initializePrincipalField; textToNat } "../../../shared/common_utils/helper";

module {

  public func createEventAndRegister(
    userPrincipal : Principal,
    userCanisterId : Text,
    payload : ArgumentTypes.CreateEventAndKonectaPayload,
    databases : Map.Map<Text, Database.Database>,
    d3 : D3.D3,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<ArgumentTypes.CreateEventAndKonectaResponse, Text> {

    let eventCreationResult = await createEvent(
      userPrincipal,
      userCanisterId,
      payload.eventPayload,
      databases,
      d3,
      canistergeekLogger,
    );

    switch (eventCreationResult) {
      case (#err(errorMsg)) {
        return #err(errorMsg);
      };

      case (#ok(eventData)) {
        let eventId = eventData.id;

        let konectaPayload = payload.konectaPayload;
        let konectaCanister = actor (SharedConstants.KonectaCanister) : SharedInterfaces.KonectaActor;

        let konectaCreationPayload : SharedTypes.KonectaEventCreationPayload = {
          user_id = ?Principal.toText(userPrincipal);
          event_id = eventId;
          event_type = konectaPayload.event_type;
          status = payload.eventPayload.status;
          categories = konectaPayload.categories;
          consultations = konectaPayload.consultations;
          expertise = konectaPayload.expertise;
          price_token = konectaPayload.price_token;
          token_amount = konectaPayload.token_amount;
          interests = konectaPayload.interests;
          metadata = konectaPayload.metadata;
        };

        let konectaEventId = try {
          await konectaCanister.createKonectaEvent(userCanisterId, konectaCreationPayload);
        } catch (_e) {
          let errorMsg = "Base event created, but failed to register with Konecta. Attempting to roll back.";
          canistergeekLogger.logMessage(errorMsg);

          let rollbackResult = await DeleteService.deleteEventById(
            eventData,
            userCanisterId,
            databases,
            d3,
            canistergeekLogger,
          );

          switch (rollbackResult) {
            case (#ok) canistergeekLogger.logMessage("Rollback successful for event: " # eventData.id);
            case (#err(msg)) canistergeekLogger.logMessage("CRITICAL: Rollback FAILED for event: " # eventData.id # ". Error: " # msg);
          };

          return #err(errorMsg);
        };
        canistergeekLogger.logMessage("Konecta registration response --->" # debug_show (konectaEventId));

        return #ok({
          eventId = eventId;
          konectaEventId = konectaEventId;
        });
      };
    };
  };

  public func createEvent(
    userPrincipal : Principal,
    userCanisterId : Text,
    payload : ArgumentTypes.EventRequestPayload,
    databases : Map.Map<Text, Database.Database>,
    d3 : D3.D3,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<ArgumentTypes.CreateEventSuccess, Text> {

    var language = "";

    switch (payload.language) {
      case null language := Constants.DefaultLanguage;
      case (?lang) language := lang;
    };

    var coverPhotoUrl = "";
    ignore do ? {

      let coverPhotoOutput = await D3.updateOperation({
        d3 = d3;
        updateOperationInput = #StoreFile({
          fileDataObject = payload.coverphoto!.fileDataObject;
          fileName = payload.coverphoto!.fileName;
          fileType = payload.coverphoto!.fileType;
        });
      });

      switch (coverPhotoOutput) {
        case (#StoreFileOutput(file)) {
          coverPhotoUrl := file.fileId;
        };
        case (#StoreFileChunkOutput(_)) {};
        case (#StoreFileMetadataOutput(_)) {};
      };
    };

    let status = CommonService.getEventStatus(payload.status, SharedTypes.EventStatus.Created);

    var metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = [];
    switch (payload.metadata) {
      case (?meta) metadata := meta;
      case null metadata := [];
    };

    let userId = initializePrincipalField(payload.user_id, userPrincipal);

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("user_id", #principal(userId)),
      ("name", #text(payload.name)),
      ("description", #text(payload.description)),
      ("location", #text(payload.location)),
      ("start_date", #nat(payload.start_date)),
      ("end_date", #nat(payload.end_date)),
      ("status", #text(status)),
      ("coverphoto", #text(coverPhotoUrl)),
      ("language", #text(language)),
      ("metadata", #map(metadata)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = await Database.createItem({
      createItemInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.EventTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = { databases };
    });
    canistergeekLogger.logMessage("Event create response --->" # debug_show (item));

    switch (item) {
      case (#err(msg)) {
        return #err("Failed to create event: " # msg[0]);
      };
      case (#ok(result)) {

        let userCanister = actor (userCanisterId) : SharedInterfaces.UserActor;

        let calendarObject = {
          name = getTupleValueAsText(attributeDataValues, "name");
          description = getTupleValueAsText(attributeDataValues, "description");
        };

        let calendarId = await userCanister.upsertCalendarData(Principal.toText(userPrincipal), "", calendarObject);

        let eventObject = {
          event_id = result.id;
          name = getTupleValueAsText(attributeDataValues, "name");
          start_date = textToNat(getTupleValueAsText(attributeDataValues, "start_date"));
          end_date = textToNat(getTupleValueAsText(attributeDataValues, "end_date"));
          status = payload.status;
          calendar_id = calendarId;
          created_by = userPrincipal;
          categories = null;
          interests = null;
        };
        let eventMetadataResult = await userCanister.createEventMetaData(eventObject);

        let eventMetadataId = switch (eventMetadataResult) {
          case (#ok(id)) id;
          case (#err(msg)) {
            return #err("Failed to create user event metadata: " # msg);
          };
        };

        return #ok({
          id = result.id;
          attributes = attributeDataValues;
          calendarId = calendarId;
          eventMetadataId = eventMetadataId;
        });
      };
    };
  };
};
