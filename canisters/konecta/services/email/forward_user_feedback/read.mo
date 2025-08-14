import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Map "mo:map/Map";

import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import TransformService "../../shared/transform";

module {

  public func getListOfExpertForwardedEmails(alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.ForwardToExpertResponsePayload], [Text]> {
    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.ExpertEmailTable;
        filter = #AND([]);
      };
      alfangoDB = alfangoDB;
    });

    switch (items) {
      case (#ok(_eventData)) {
        return TransformService.transformGetAllExpertForwardedMailResponse(items);
      };
      case (#err(error)) {
        return #err(error);
      };
    };
  };

  public func expertEmailTableMetadata(alfangoDB : Database.AlfangoDB) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.ExpertEmailTable;
      };
      alfangoDB = alfangoDB;
    });
  };
};
