import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Time "mo:base/Time";

import CommonService "../../services/common";
import GetAttendeeService "./getAttendee";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import Helper "../../utils/helper";

module {
  /**
  * @desc Updates the status (action) of a specific event attendee. For example, from #Applied to #Accepted.
  * @param eventId The ID of the event.
  * @param inviteeUserId The Principal of the user whose status is being changed.
  * @param currentAction The user's current status, used to find the correct record.
  * @param newAction The new status to set for the user.
  * @param alfangoDB The database instance.
  * @returns The ID of the updated record on success, or an error message on failure.
  */
  public func updateEventAttendeeStatus(
    eventId : Text,
    inviteeUserId : Principal,
    currentAction : ArgumentTypes.EventAttendeeActions,
    newAction : ArgumentTypes.EventAttendeeActions,
    alfangoDB : Database.AlfangoDB,
  ) : async Result.Result<Text, Text> {
    // 1. Find the specific record ID for the user with their current status.
    let attendeeRecordId = GetAttendeeService.getAttendeeRecordId(inviteeUserId, eventId, currentAction, alfangoDB);

    // 2. Handle the case where the record is not found.
    switch (attendeeRecordId) {
      case (null) {
        return #err("Could not find an attendee with the specified current status to update.");
      };
      case (?recordId) {
        // 3. If found, prepare and execute the update.
        let newActionType = CommonService.getActionType(newAction);
        let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
          // Only update the fields that are changing.
          ("action", #text(newActionType)),
          ("timestamp", #nat(Int.abs(Time.now()))),
        ];

        // 4. Perform the database update.
        let item = Database.updateItem({
          updateItemInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.EventAttendeeTable;
            id = recordId;
            attributeDataValues = attributeDataValues;
          };
          alfangoDB = alfangoDB;
        });

        // 5. Return the result of the update operation.
        switch (item) {
          case (#err(msg)) #err(Helper.textArrayToString(msg));
          case (#ok(result)) #ok(result.id);
        };
      };
    };
  };
};
