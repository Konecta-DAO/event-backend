import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";

import CommonService "../../services/common";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";

module {

  public func getEventDetailsByUserPrincipal(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    return getEventDataByPrincipalId(userPrincipal, databases);
  };

  public func getEventDetailsByUserId(userPrincipal : Text, databases : Map.Map<Text, Database.Database>) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    return getEventDataByPrincipalId(Principal.fromText(userPrincipal), databases);
  };

  private func getEventDataByPrincipalId(userPrincipal : Principal, databases : Map.Map<Text, Database.Database>) : Result.Result<[ArgumentTypes.EventResponsePayload], [Text]> {
    let eventResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        filterExpressions = [
          {
            attributeName = "user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(Constants.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    return CommonService.transformGetAllEventsResponse(eventResponse);
  };

  public func eventDataById(eventId : Text, databases : Map.Map<Text, Database.Database>) : Result.Result<ArgumentTypes.EventResponsePayload, [Text]> {
    let eventResponse = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        id = eventId;
      };
      alfangoDB = { databases };
    });

    return CommonService.transformGetEventResponse(eventResponse);
  };

  public func eventDetailsWithUserData(eventId : Text, databases : Map.Map<Text, Database.Database>) : async ArgumentTypes.EventWithUserDataPayload {
    let eventResponse = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        id = eventId;
      };
      alfangoDB = { databases };
    });

    let eventData = await CommonService.transformGetEventResponseAsync(eventResponse);

    switch (eventData) {
      case (#ok(eventData)) {
        return eventData;
      };
      case (#err(err)) {
        return CommonService.initialEventObjectWithUserData;
      };
    };
  };

  public func eventTableMetadata(databases : Map.Map<Text, Database.Database>) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        metadata = {
          databaseName = Constants.KonectA;
          tableName = Constants.EventTable;
        };
        tableName = Constants.EventTable;
      };
      alfangoDB = { databases };
    });
  };

  public func getFile(fileId : Text, d3 : D3.D3) : D3.GetFileOutputType {
    CommonService.getFile(fileId, d3);
  };
};
