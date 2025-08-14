import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Map "mo:map/Map";

import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import TransformService "../../shared/transform";

module {

  public func getListOfEventCompletionEmails(alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.EventCompletionResponsePayload], [Text]> {

    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventCompletionNotificationTable;
        filter = #AND([]);
      };
      alfangoDB = alfangoDB;
    });

    switch (items) {
      case (#ok(_eventData)) {
        return TransformService.transformGetAllEventCompletionMailResponse(items);
      };
      case (#err(error)) {
        return #err(error);
      };
    };
  };

  public func eventCompletionNotificationTableMetadata(alfangoDB : Database.AlfangoDB) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventCompletionNotificationTable;
      };
      alfangoDB = alfangoDB;
    });
  };
};
