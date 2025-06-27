import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";
import SharedConstants "../../../shared/constants";
import SharedTypes "../../../shared/types";
import FeedRequestsReadService "../../services/feed_requests/read";
import ArgumentTypes "../../types/argumentTypes";
import EventConstants "../../utils/constants";

module {
  public func applyToServiceRequest(userPrincipal : Principal, payload : ArgumentTypes.ApplyToServiceRequestPayload, databases : Map.Map<Text, Database.Database>, canistergeekLogger : Canistergeek.Logger) : async Text {

    if (FeedRequestsReadService.checkIfRequestAppliedForEvent(userPrincipal, payload.event_id, databases)) {
      return "You have already applied to this event";
    } else {
      var response = "";
      // Create initial data values buffer

      let initialDataValues = Buffer.fromArray<(Text, Database.AttributeDataValue)>([]);
      let dataValuesToBeAppended = Buffer.Buffer<(Text, Database.AttributeDataValue)>(0);

      // Add data values to the buffer
      dataValuesToBeAppended.add("event_id", #text(payload.event_id));
      dataValuesToBeAppended.add("applied_user_id", #principal(userPrincipal));
      dataValuesToBeAppended.add("note", #text(payload.note));
      dataValuesToBeAppended.add("location", #text(payload.location));
      dataValuesToBeAppended.add("action", #text(SharedTypes.EventAttendeeStatus.Applied));
      dataValuesToBeAppended.add("timestamp", #nat(Int.abs(Time.now())));

      // Append the data values buffer to the initial data values buffer
      initialDataValues.append(dataValuesToBeAppended);
      let dataValuesArray = Buffer.toArray(initialDataValues);
      canistergeekLogger.logMessage("Attribute data values --->" # debug_show (dataValuesArray));

      // Create an item in the Event Attendee Table in the database
      let item = await Database.createItem({
        createItemInput = {
          databaseName = SharedConstants.KonectA;
          tableName = EventConstants.RequestAppliedTable;
          attributeDataValues = dataValuesArray;
        };
        alfangoDB = { databases };
      });

      switch (item) {
        case (#err(_msg)) {
          // If there was an error creating the item, set the response accordingly
          response := "Failed to apply to the event. Please try again later";
        };
        case (#ok(result)) {
          // If the item was created successfully, set the response to the item ID
          response := result.id;
        };
      };

      return response;
    };

  };
};
