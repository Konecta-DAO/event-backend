import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import SharedConstants "../../../shared/constants";
import SharedTypes "../../../shared/types";
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
        databaseName = SharedConstants.KonectA;
        tableName = Constants.EventTable;
        filterExpressions = [
          {
            attributeName = "user_id";
            filterExpressionCondition = #EQ(#principal(userPrincipal));
          },
          {
            attributeName = "status";
            filterExpressionCondition = #NEQ(#text(SharedTypes.EventStatus.Canceled));
          },
        ];
      };
      alfangoDB = { databases };
    });

    return CommonService.transformGetAllEventsResponse(eventResponse);
  };

  public func eventDetailsWithUserData(eventId : Text, databases : Map.Map<Text, Database.Database>) : async Result.Result<SharedTypes.EventDetailsPayload, [Text]> {
    let eventResponse = Database.getItemById({
      getItemByIdInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.EventTable;
        id = eventId;
      };
      alfangoDB = { databases };
    });

    return await CommonService.transformGetEventResponseAsync(eventResponse);
  };

  public func eventTableMetadata(databases : Map.Map<Text, Database.Database>) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = SharedConstants.KonectA;
        tableName = Constants.EventTable;
      };
      alfangoDB = { databases };
    });
  };

  public func getFile(fileId : Text, d3 : D3.D3) : D3.GetFileOutputType {
    CommonService.getFile(fileId, d3);
  };
};
