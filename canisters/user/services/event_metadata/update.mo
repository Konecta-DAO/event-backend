import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import Constants "../../utils/constants";
import CommonService "../common";
import HelperService "../../../shared/common_utils/helper";
import { getEventMetadataById } "./read";
import SharedConstants "../../../shared/constants";
import SharedTypes "../../../shared/types";

module {
  public func updateEventMetaData(
    _userPrincipal : Principal,
    eventMetadataId : Text,
    eventMetadataPayload : SharedTypes.UpdateEventMetadataPayload,
    databases : Map.Map<Text, Database.Database>,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Text {
    var response = "";

    let eventMetadataData = getEventMetadataById(eventMetadataId, databases);

    switch (eventMetadataData) {
      case (#err(errorMessage)) {
        return "Failed to find event metadata to update: " # HelperService.textArrayToString(errorMessage);
      };

      case (#ok(oldValues)) {
        var finalStatusText = oldValues.status;
        switch (eventMetadataPayload.status) {
          case (?newStatusVariant) {
            finalStatusText := CommonService.getEventStatus(newStatusVariant, oldValues.status);
          };
          case null{};
        };

        let finalInterests = HelperService.initializeTextArrayField(eventMetadataPayload.interests, oldValues.interests);
        let interestArray = HelperService.getStringAttributeDataValueArray(finalInterests);

        let finalCategories = HelperService.initializeTextArrayField(eventMetadataPayload.categories, oldValues.categories);
        let categoriesArray = HelperService.getStringAttributeDataValueArray(finalCategories);

        let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
          ("calendar_id", #text(oldValues.calendar_id)),
          ("event_id", #text(oldValues.event_id)),
          ("name", #text(oldValues.name)),
          ("start_date", #nat(oldValues.start_date)),
          ("end_date", #nat(oldValues.end_date)),
          ("created_by", #principal(Principal.fromText(oldValues.created_by))),
          ("status", #text(finalStatusText)),
          ("categories", #list(categoriesArray)),
          ("interests", #list(interestArray)),
        ];
        canistergeekLogger.logMessage("Attribute data values FOR UPDATE --->" # debug_show (attributeDataValues));

        let item = Database.updateItem({
          updateItemInput = {
            databaseName = SharedConstants.KonectA;
            tableName = Constants.EventMetadataTable;
            id = eventMetadataId;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = { databases };
        });
        canistergeekLogger.logMessage("Update Event metadata response --->" # debug_show (item));

        switch (item) {
          case (#err(_msg)) {
            response := "Failed to update event metadata";
          };
          case (#ok(result)) {
            response := "Updated event metadata with id: " # result.id;
          };
        };
      };
    };

    return response;
  };
};
