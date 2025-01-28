import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import List "mo:base/List";
import Prelude "mo:base/Prelude";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import KonectaEventTable "../../tables/konectaEventTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import CommonService "../common";
import { checkIfEventExists } "./read";

module {

  public func createEvent(userPrincipal : Principal, userCanisterId : Text, payload : ArgumentTypes.EventRequestPayload, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {

    var response = "";

    // check if event exists or not
    let eventExists = checkIfEventExists(payload.event_id, databases);
    canistergeekLogger.logMessage("Event exists --->" # debug_show (eventExists));

    if (not eventExists) {
      let eventType = CommonService.getEventType(payload.event_type, Constants.EventType.Request);

      var metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = [];
      switch (payload.metadata) {
        case (?meta) metadata := meta;
        case null metadata := [];
      };

      let eventStatus = CommonService.getEventStatus(payload.status, Constants.EventStatus.Created);

      let categoriesArray = HelperService.getStringAttributeDataValueArray(payload.categories);

      let consultations : [Text] = HelperService.initializeTextArrayField(payload.consultations, []);
      let consultationsArray = HelperService.getStringAttributeDataValueArray(consultations);

      let interests : [Text] = HelperService.initializeTextArrayField(payload.interests, []);
      let interestsArray = HelperService.getStringAttributeDataValueArray(interests);

      let expertise : Text = HelperService.initializeTextField(payload.expertise, "");
      let tokenAmount : Float = HelperService.initializeFloatField(payload.token_amount, 0.00);

      var priceToken = Constants.TokenType.ICP;
      ignore do ? {
        switch (payload.price_token) {
          case (? #CKBTC) priceToken := Constants.TokenType.CKBTC;
          case (? #ICP) priceToken := Constants.TokenType.ICP;
          case (? #FREE) priceToken := Constants.TokenType.FREE;
          case null priceToken := null!;
        };
      };

      let userId = HelperService.initializeTextField(payload.user_id, Principal.toText(userPrincipal));

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

      let item = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.KonectAEventTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = { databases };
      });
      canistergeekLogger.logMessage("Event create response --->" # debug_show (item));

      switch (item) {
        case (#err(msg)) {
          response := HelperService.textArrayToString(msg);
          canistergeekLogger.logMessage("Error response --->" # debug_show (item));
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
    } else {
      return "Event already exists";
    };
  };

};
