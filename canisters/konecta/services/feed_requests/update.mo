import Database "mo:alfangodb/AlfangoDB";
import Result "mo:base/Result";
import Map "mo:map/Map";
import SharedConstants "../../../shared/constants";
import CommonService "../../services/common";
import ArgumentTypes "../../types/argumentTypes";
import EventConstants "../../utils/constants";
import HelperService "../../../shared/common_utils/helper";

module {
  public func updateAppliedRequestAction(requestId : Text, requestObject : ArgumentTypes.AppliedServiceRequestsPayload, databases : Map.Map<Text, Database.Database>) : Result.Result<Text, Text> {

    let actionType = CommonService.getActionType(requestObject.action);

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(requestObject.event_id)),
      ("applied_user_id", #principal(requestObject.applied_user_id)),
      ("action", #text(actionType)),
      ("timestamp", #nat(requestObject.timestamp)),
    ];

    let item = Database.updateItem({
      updateItemInput = {
        databaseName = SharedConstants.KonectA;
        tableName = EventConstants.RequestAppliedTable;
        id = requestId;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = { databases };
    });

    switch (item) {
      case (#err(error)) {
        #err(HelperService.textArrayToString(error));
      };
      case (#ok(result)) {
        #ok(result.id);
      };
    };
  };
};
