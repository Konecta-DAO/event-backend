import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import UserFeedbackService "../../email/user_feedback/read";
import TransformService "../../shared/transform";

module {
  public func expertFeedbackTableMetadata(alfangoDB : Database.AlfangoDB) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.ExpertFeedbackTable;
      };
      alfangoDB = alfangoDB;
    });
  };

  public func getListOfExpertFeedbacks(
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : Result.Result<[ArgumentTypes.ExpertFeedbackResponsePayload], [Text]> {
    let response = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.ExpertFeedbackTable;
        filter = #AND([]);
      };
      alfangoDB = alfangoDB;
    });

    TransformService.transformGetAllExpertFeedbacksResponse(response, UserFeedbackService.getUserFeedback, alfangoDB, canistergeekLogger);
  };
};
