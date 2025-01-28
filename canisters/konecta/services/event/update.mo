import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import List "mo:base/List";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import KonectaEventTable "../../tables/konectaEventTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import CommonService "../common";
import { getEventData } "./read";

module {
  public func updateEvent(userPrincipal : Principal, userCanisterId : Text, payload : ArgumentTypes.EventRequestPayload, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {
    var response = "";

    let eventData = getEventData(payload.event_id, databases);
    var oldValues : ArgumentTypes.EventResponsePayload = {
      konecta_event_id = "";
      user_id = "";
      event_id = "";
      event_type = "";
      status = "";
      categories = [];
      consultations = [];
      expertise = "";
      price_token = "";
      token_amount = 0.0;
      interests = [];
      metadata = [];
    };

    switch (eventData) {
      case (#ok(event)) {
        oldValues := event;
      };
      case (#err(errorMessage)) ();
    };
    let konectaEventId = oldValues.konecta_event_id;

    let eventType = CommonService.getEventType(payload.event_type, oldValues.event_type);

    let eventStatus = CommonService.getEventStatus(payload.status, oldValues.status);

    let categoriesArray = HelperService.getStringAttributeDataValueArray(payload.categories);

    let oldConsultationsArray : [Text] = oldValues.consultations;
    let consultations : [Text] = HelperService.initializeTextArrayField(payload.consultations, oldConsultationsArray);
    let consultationsArray = HelperService.getStringAttributeDataValueArray(consultations);

    let oldInterestsArray : [Text] = oldValues.interests;
    let interests : [Text] = HelperService.initializeTextArrayField(payload.interests, oldInterestsArray);
    let interestsArray = HelperService.getStringAttributeDataValueArray(interests);

    let expertise : Text = HelperService.initializeTextField(payload.expertise, oldValues.expertise);

    let tokenAmountInFloat = oldValues.token_amount;
    let tokenAmount : Float = HelperService.initializeFloatField(payload.token_amount, tokenAmountInFloat);

    var priceToken = oldValues.price_token;
    switch (payload.price_token) {
      case (? #CKBTC) priceToken := Constants.TokenType.CKBTC;
      case (? #ICP) priceToken := Constants.TokenType.ICP;
      case (? #FREE) priceToken := Constants.TokenType.FREE;
      case null priceToken := oldValues.price_token;
    };

    let oldMetadataArray : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = oldValues.metadata;
    var metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = oldMetadataArray;
    switch (payload.metadata) {
      case (?meta) metadata := meta;
      case null metadata := oldMetadataArray;
    };

    let userId = HelperService.initializeTextField(payload.user_id, oldValues.user_id);

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("user_id", #text(userId)),
      ("event_id", #text(payload.event_id)),
      ("event_type", #text(eventType)),
      ("status", #text(eventStatus)),
      ("categories", #list(categoriesArray)),
      ("consultations", #list(consultationsArray)),
      ("expertise", #text(expertise)),
      ("price_token", #text(priceToken)),
      ("token_amount", #float(tokenAmount)),
      ("interests", #list(interestsArray)),
      ("metadata", #map(metadata)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = Database.updateItem({
      updateItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.KonectAEventTable;
        attributeDataValues = attributeDataValues;
        id = konectaEventId;
      };
      alfangoDB = { databases };
    });
    canistergeekLogger.logMessage("Event update response --->" # debug_show (item));

    switch (item) {
      case (#err(msg)) {
        response := "Failed to update event";
      };
      case (#ok(result)) {

        let userCanister = actor (userCanisterId) : CommonService.UserCanisterType;
        let calendarId = await userCanister.getCalendarId(payload.event_id);
        let eventMetadataId = await userCanister.getEventMetadataId(payload.event_id, calendarId);
        canistergeekLogger.logMessage("Event metadata id --->" # debug_show (eventMetadataId));

        let eventObject = {
          event_id = payload.event_id;
          status = payload.status;
          categories = payload.categories;
          interests = interests;
        };
        canistergeekLogger.logMessage("Event object --->" # debug_show (eventObject));

        let eventMetadataResponse = await userCanister.updateEventMetaData(eventMetadataId, eventObject);
        canistergeekLogger.logMessage("Event metadata response --->" # debug_show (eventMetadataResponse));
        response := result.id;
      };

    };

    return response;
  };

  public func cancelKonectaEvent(
    userPrincipal : Principal,
    eventId : Text,
    databases : Map.Map<Text, Database.Database>,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {
    let eventData = getEventData(eventId, databases);
    canistergeekLogger.logMessage("Event data cancel event --->" # debug_show (eventData));

    switch (eventData) {
      case (#ok(eventData)) {

        let categoriesArray = HelperService.getStringAttributeDataValueArray(eventData.categories);
        let consultationsArray = HelperService.getStringAttributeDataValueArray(eventData.consultations);
        let interestsArray = HelperService.getStringAttributeDataValueArray(eventData.interests);

        let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
          ("user_id", #text(eventData.user_id)),
          ("event_id", #text(eventData.event_id)),
          ("event_type", #text(eventData.event_type)),
          ("status", #text(Constants.EventStatus.Canceled)),
          ("categories", #list(categoriesArray)),
          ("consultations", #list(consultationsArray)),
          ("expertise", #text(eventData.expertise)),
          ("price_token", #text(eventData.price_token)),
          ("token_amount", #float(eventData.token_amount)),
          ("interests", #list(interestsArray)),
          ("metadata", #map(eventData.metadata)),
        ];
        canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

        let konectaEventId = eventData.konecta_event_id;

        let item = Database.updateItem({
          updateItemInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.KonectAEventTable;
            id = konectaEventId;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = { databases };
        });
        canistergeekLogger.logMessage("Cancel event response --->" # debug_show (item));

        switch (item) {
          case (#ok(itemData)) {

            let eventCanisterActor = actor (Constants.EventCanister) : CommonService.EventCanisterType;
            let cancelEventResponse = await eventCanisterActor.cancelEvent(userPrincipal, eventId);

            switch (cancelEventResponse) {
              case (#ok(response)) {
                #ok("Event canceled successfully");
              };

              case (#err(error)) {
                #err(error);
              };
            };
          };
          case (#err(error)) {
            #err(HelperService.textArrayToString(error));
          };
        };
      };
      case (#err(error)) #err(HelperService.textArrayToString(error));
    };

  };
};
