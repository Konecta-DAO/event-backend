import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SharedInterfaces "../../../shared/interfaces";
import SharedConstants "../../../shared/constants";
import SharedTypes "../../../shared/types";
import Constants "../../utils/constants";
import HelperService "../../../shared/common_utils/helper";
import CommonService "../common";
import { checkIfEventExists } "./read";

module {

  public func createEvent(
    userPrincipal : Principal,
    userCanisterId : Text,
    payload : SharedTypes.KonectaEventCreationPayload, // MODIFIED: Payload is now the shared type
    databases : Map.Map<Text, Database.Database>,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Text {

    var response = "";

    // check if event exists or not using the event_id passed from the Event canister
    let eventExists = checkIfEventExists(payload.event_id, databases);
    canistergeekLogger.logMessage("Konecta Event exists check --->" # debug_show (eventExists));

    if (not eventExists) {
      // The logic here is mostly the same, but it now reads from the `SharedTypes.KonectaEventCreationPayload`
      let eventType = CommonService.getEventType(payload.event_type, Constants.EventType.Request);

      var metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)] = [];
      switch (payload.metadata) {
        case (?meta) metadata := meta;
        case null metadata := [];
      };

      let eventStatus = CommonService.getEventStatus(payload.status, SharedTypes.EventStatus.Created);

      // `payload.categories` is a required `[Text]` field in the new type
      let categoriesArray = HelperService.getStringAttributeDataValueArray(payload.categories);

      let consultations : [Text] = HelperService.initializeTextArrayField(payload.consultations, []);
      let consultationsArray = HelperService.getStringAttributeDataValueArray(consultations);

      let interests : [Text] = HelperService.initializeTextArrayField(payload.interests, []);
      let interestsArray = HelperService.getStringAttributeDataValueArray(interests);

      let expertise : Text = HelperService.initializeTextField(payload.expertise, "");
      let tokenAmount : Float = HelperService.initializeFloatField(payload.token_amount, 0.00);

      var priceToken = Constants.TokenType.ICP; // Default value
      ignore do ? {
        switch (payload.price_token!) {
          case (#CKBTC) priceToken := Constants.TokenType.CKBTC;
          case (#ICP) priceToken := Constants.TokenType.ICP;
          case (#FREE) priceToken := Constants.TokenType.FREE;
        };
      };

      let userId = HelperService.initializeTextField(payload.user_id, Principal.toText(userPrincipal));

      let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
        ("user_id", #text(userId)),
        ("event_id", #text(payload.event_id)), // Use the event_id from the payload
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
      canistergeekLogger.logMessage("Konecta Attribute data values --->" # debug_show (attributeDataValues));

      let item = await Database.createItem({
        createItemInput = {
          databaseName = SharedConstants.KonectA;
          tableName = Constants.KonectAEventTable;
          attributeDataValues = attributeDataValues;
        };
        alfangoDB = { databases };
      });
      canistergeekLogger.logMessage("Konecta Event create response --->" # debug_show (item));

      switch (item) {
        case (#err(msg)) {
          response := HelperService.textArrayToString(msg);
          canistergeekLogger.logMessage("Error response --->" # debug_show (item));
        };
        case (#ok(result)) {
          let userCanister = actor (userCanisterId) : SharedInterfaces.UserActor;
          let calendarId = await userCanister.getCalendarId(payload.event_id);
          let eventMetadataId = await userCanister.getEventMetadataId(payload.event_id, calendarId);
          canistergeekLogger.logMessage("Found Event metadata id in user canister --->" # debug_show (eventMetadataId));

          let eventObject : SharedTypes.UpdateEventMetadataPayload = {
            event_id = payload.event_id;
            status = ?payload.status;
            categories = ?payload.categories;
            interests = payload.interests;
          };
          canistergeekLogger.logMessage("Event object to update user canister --->" # debug_show (eventObject));

          let eventMetadataResponse = await userCanister.updateEventMetaData(eventMetadataId, eventObject);
          canistergeekLogger.logMessage("User canister metadata update response --->" # debug_show (eventMetadataResponse));
          response := result.id;
        };
      };

      return response;
    } else {
      return "Event already exists in Konecta canister";
    };
  };

};
