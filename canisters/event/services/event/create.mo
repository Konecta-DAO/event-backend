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

    // 1. language fallback
    var language = "";
    switch (payload.eventPayload.language) {
      case (null) language := Constants.DefaultLanguage;
      case (?lang) language := lang;
    };

    // 2. upload cover photo
    var coverPhotoUrl = "";
    ignore do ? {
      let coverPhotoOutput = await D3.updateOperation({
        d3 = d3;
        updateOperationInput = #StoreFile({
          fileDataObject = payload.eventPayload.coverphoto!.fileDataObject;
          fileName = payload.eventPayload.coverphoto!.fileName;
          fileType = payload.eventPayload.coverphoto!.fileType;
        });
      });
      switch (coverPhotoOutput) {
        case (#StoreFileOutput(file)) coverPhotoUrl := file.fileId;
        case (#StoreFileChunkOutput(_)) {};
        case (#StoreFileMetadataOutput(_)) {};
        case (#CleanupAbandonedUploadsOutput(_)) {};
        case (#DeleteFileOutput(_)) {};
      };
    };

    // 3. compute status & metadata
    let status = CommonService.getEventStatus(
      payload.eventPayload.status,
      SharedTypes.EventStatus.Created,
    );

    var metadata : [(
      Text,
      Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue,
    )] = [];
    switch (payload.eventPayload.metadata) {
      case (?meta) metadata := meta;
      case null metadata := [];
    };

    // 4. build attributeDataValues
    let userId = initializePrincipalField(
      payload.eventPayload.user_id,
      userPrincipal,
    );
    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("user_id", #principal(userId)),
      ("name", #text(payload.eventPayload.name)),
      ("description", #text(payload.eventPayload.description)),
      ("location", #text(payload.eventPayload.location)),
      ("start_date", #nat(payload.eventPayload.start_date)),
      ("end_date", #nat(payload.eventPayload.end_date)),
      ("status", #text(status)),
      ("coverphoto", #text(coverPhotoUrl)),
      ("language", #text(language)),
      ("metadata", #map(metadata)),
    ];
    canistergeekLogger.logMessage(
      "Attribute data values --->" # debug_show (attributeDataValues)
    );

    // 5. persist base event
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
        // 6. upsert calendar & metadata on user canister
        let userCanister = actor (userCanisterId) : SharedInterfaces.UserActor;
        let calendarObject = {
          name = getTupleValueAsText(attributeDataValues, "name");
          description = getTupleValueAsText(attributeDataValues, "description");
        };
        let calendarId = await userCanister.upsertCalendarData(
          Principal.toText(userPrincipal),
          "",
          calendarObject,
        );

        let eventObject = {
          event_id = result.id;
          name = getTupleValueAsText(attributeDataValues, "name");
          start_date = textToNat(getTupleValueAsText(attributeDataValues, "start_date"));
          end_date = textToNat(getTupleValueAsText(attributeDataValues, "end_date"));
          status = payload.eventPayload.status;
          calendar_id = calendarId;
          created_by = userPrincipal;
          categories = null;
          interests = null;
        };
        let eventMetadataResult = await userCanister.createEventMetaData(eventObject);
        let eventMetadataId = switch (eventMetadataResult) {
          case (#ok(id)) id;
          case (#err(m)) return #err("Failed to create user event metadata: " # m);
        };

        // assemble the eventData for Konecta
        let eventData = {
          id = result.id;
          attributes = attributeDataValues;
          calendarId = calendarId;
          eventMetadataId = eventMetadataId;
        };

        let konectaPayload = payload.konectaPayload;
        let konectaCanister = actor (SharedConstants.KonectaCanister) : SharedInterfaces.KonectaActor;

        let konectaCreationPayload : SharedTypes.KonectaEventCreationPayload = {
          user_id = ?Principal.toText(userPrincipal);
          event_id = eventData.id;
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
          await konectaCanister.createKonectaEvent(
            userCanisterId,
            konectaCreationPayload,
          );
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
            case (#err(m)) canistergeekLogger.logMessage("CRITICAL: Rollback FAILED for event: " # eventData.id # ". Error: " # m);
          };
          return #err(errorMsg);
        };
        canistergeekLogger.logMessage("Konecta registration response --->" # debug_show (konectaEventId));

        return #ok({
          eventId = eventData.id;
          konectaEventId = konectaEventId;
        });
      };
    };
  };
};
