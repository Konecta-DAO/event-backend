import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import CalendarTable "../../tables/calendarTable";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import { getTupleValueAsText } "../../utils/helper";
import UserReadService "../user/read";

module {
  public func upsertCalendarData(
    userPrincipal : Text,
    calendarId : Text,
    calendarPayload : ArgumentTypes.CalendarRequestPayload,
    userDataMap : Map.Map<Principal, ArgumentTypes.UserPayload>,
    databases : Map.Map<Text, Database.Database>,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Text {
    var response = "";

    var calendarExists = false;

    if (Text.size(calendarId) > 0) {
      calendarExists := true;
    };

    let initialDataValues = Buffer.fromArray<(Text, Database.AttributeDataValue)>([]);
    let dataValuesToBeAppended = Buffer.Buffer<(Text, Database.AttributeDataValue)>(0);

    ignore do ? {

      let userData = UserReadService.getUserDataByPrincipalId(Principal.fromText(userPrincipal), userDataMap);
      canistergeekLogger.logMessage("User data --->" # debug_show (userData));

      dataValuesToBeAppended.add("name", #text("default"));
      dataValuesToBeAppended.add("description", #text("default"));
      dataValuesToBeAppended.add("timezone", #text(userData!.timezone));
    };

    initialDataValues.append(dataValuesToBeAppended);
    let dataValuesArray = Buffer.toArray(initialDataValues);
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (dataValuesArray));

    if (calendarExists) {
      let item = Database.updateItem({
        updateItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.CalendarTable;
          id = calendarId;
          attributeDataValues = dataValuesArray;
        };
        alfangoDB = { databases };
      });
      canistergeekLogger.logMessage("Calendar response --->" # debug_show (item));

      switch (item) {
        case (#err(msg)) {
          response := "Failed to update calendar data";
        };
        case (#ok(result)) {
          response := result.id;
        };

      };
    } else {
      let item = await Database.createItem({
        createItemInput = {
          databaseName = Constants.KonectA;
          tableName = Constants.CalendarTable;
          attributeDataValues = dataValuesArray;
        };
        alfangoDB = { databases };
      });
      canistergeekLogger.logMessage("Calendar response --->" # debug_show (item));

      switch (item) {
        case (#err(msg)) {
          response := "Failed to save calendar data";
        };
        case (#ok(result)) {
          response := result.id;
        };

      };

    };

    return response;
  };
};
