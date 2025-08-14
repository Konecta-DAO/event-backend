import Database "mo:alfangodb/AlfangoDB";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";

import CommonService "../../services/common";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import Helper "../../utils/helper";

module {

  type MetadataForMap = [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];

  public func createEvent(
    userPrincipal : Principal,
    userCanisterId : Text,
    payload : ArgumentTypes.EventRequestPayload,
    alfangoDB : Database.AlfangoDB,
    d3 : D3.D3,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Text {
    var response = "";

    var language = "";
    switch (payload.language) {
      case null language := Constants.DefaultLanguage;
      case (?lang) language := lang;
    };

    var coverPhotoUrl = "";
    switch (payload.coverphoto) {
      case (?coverPhotoData) {
        let coverPhotoOutput = await D3.storeFile({
          d3 = d3;
          storeFileInput = {
            fileDataObject = coverPhotoData.fileDataObject;
            fileName = coverPhotoData.fileName;
            fileType = coverPhotoData.fileType;
          };
        });

        switch (coverPhotoOutput) {
          case (file) {
            coverPhotoUrl := file.fileId;
          };
        };
      };
      case (null) {};
    };

    let status = CommonService.getEventStatus(payload.status, Constants.EventStatus.Draft);

    let metadata_for_map : MetadataForMap = switch (payload.metadata) {
      case (?meta) meta;
      case null [];
    };

    let userId = Helper.initializePrincipalField(payload.user_id, userPrincipal);

    let eventType = Helper.getEventType(payload.event_type, Constants.EventType.Request);

    var participationType = "";
    if (eventType == Constants.EventType.Request) {
      participationType := Helper.getParticipationType(payload.participation_type, Constants.ParticipationType.PersonToPerson);
    } else {
      participationType := Helper.getParticipationType(payload.participation_type, Constants.ParticipationType.PersonToMultiplePersons);
    };

    let categoriesArray = Helper.getStringAttributeDataValueArray(payload.categories);

    let consultations : [Text] = Helper.initializeTextArrayField(payload.consultations, []);
    let consultationsArray = Helper.getStringAttributeDataValueArray(consultations);

    let interests : [Text] = Helper.initializeTextArrayField(payload.interests, []);
    let interestsArray = Helper.getStringAttributeDataValueArray(interests);

    let expertise : Text = Helper.initializeTextField(payload.expertise, "");
    let tokenAmount : Float = Helper.initializeFloatField(payload.token_amount, 0.0);
    let priceToken = Helper.getPriceToken(payload.price_token, Constants.TokenType.ICP);
    let showcaseLink = Helper.initializeTextField(payload.showcase_link, "");
    let recordingVisibility = Helper.getRecordingVisibilty(payload.recording_visibility, "");
    let isRecordingAvailable = Helper.initializeBoolField(payload.is_recording_available, false);

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
      ("metadata", #map(metadata_for_map)),

      ("event_type", #text(eventType)),
      ("participation_type", #text(participationType)),
      ("categories", #list(categoriesArray)),
      ("consultations", #list(consultationsArray)),
      ("expertise", #text(expertise)),
      ("price_token", #text(priceToken)),
      ("token_amount", #float(tokenAmount)),
      ("interests", #list(interestsArray)),
      ("showcase_link", #text(showcaseLink)),
      ("recording_visibility", #text(recordingVisibility)),
      ("is_recording_available", #bool(isRecordingAvailable)),
      ("subaccount_id_hex", #text(payload.subaccount_id_hex)),
      ("subaccount_id_index", #nat(payload.subaccount_id_index)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = await Database.createItem({
      createItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Event create response --->" # debug_show (item));

    switch (item) {
      case (#err(msg)) {
        response := "Failed to create event:" # msg[0];
      };
      case (#ok(result)) {
        let userCanister = actor (userCanisterId) : CommonService.UserCanisterType;

        // 1. Get or create the user's calendar ID.
        var calendarId = await userCanister.getCalendarId();

        let calendarObject = {
          name = payload.name;
          description = payload.description;
        };

        if (Text.size(calendarId) == 0) {
          calendarId := await userCanister.upsertCalendarData(calendarId, calendarObject);
        };

        // 2. Construct the payload for the user canister.
        let eventObject : ArgumentTypes.EventMetadataPayload = {
          event_id = result.id;
          name = payload.name;
          start_date = payload.start_date;
          end_date = payload.end_date;
          calendar_id = calendarId;
          status = payload.status;
          created_by = userPrincipal;
          categories = payload.categories;
          interests = interests;
        };

        // 3. Call the user canister to create the calendar entry.
        ignore await userCanister.createEventMetaData(eventObject);

        // 4. Return the new event ID as the successful response.
        response := result.id;
      };
    };

    return response;
  };
};
