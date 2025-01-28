import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CommonService "../../services/common";
import ArgumentTypes "../../types/argumentTypes";
import EventConstants "../../utils/constants";
import HelperService "../../utils/helper";
import GetAttendeeService "../eventAttendee/getAttendee";

module {
  public func addEventAttendee(payload : ArgumentTypes.EventAttendeeRequestPayload, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Result.Result<Text, Text> {

    if (GetAttendeeService.checkIfAttendeeExistsForEvent(payload.invitee_user_id, payload.event_id, databases)) {
      #err("User already exists in the event attendee list.");
    } else {
      // Create initial data values buffer
      let actionType = CommonService.getActionType(payload.action);

      let initialDataValues = Buffer.fromArray<(Text, Database.AttributeDataValue)>([]);
      let dataValuesToBeAppended = Buffer.Buffer<(Text, Database.AttributeDataValue)>(0);

      // Add data values to the buffer
      dataValuesToBeAppended.add("event_id", #text(payload.event_id));
      dataValuesToBeAppended.add("invitee_user_id", #principal(payload.invitee_user_id));
      dataValuesToBeAppended.add("action", #text(actionType));
      dataValuesToBeAppended.add("timestamp", #nat(payload.timestamp));

      // Append the data values buffer to the initial data values buffer
      initialDataValues.append(dataValuesToBeAppended);
      let dataValuesArray = Buffer.toArray(initialDataValues);
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (dataValuesArray));

      // Create an item in the Event Attendee Table in the database
      let item = await Database.createItem({
        createItemInput = {
          databaseName = EventConstants.KonectA;
          tableName = EventConstants.EventAttendeeTable;
          attributeDataValues = dataValuesArray;
        };
        alfangoDB = { databases };
      });

      switch (item) {
        case (#err(msg)) {
          // If there was an error creating the item, set the response accordingly
          #err(HelperService.textArrayToString(msg));
        };
        case (#ok(result)) {
          // If the item was created successfully, set the response to the item ID
          #ok(result.id);
        };
      };

    };
  };
};
