import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import ArgumentTypes "../../../types/argumentTypes";
import Constants "../../../utils/constants";
import TransformService "../../shared/transform";

module {
    public func getListOfUserActionEmails(
        alfangoDB : Database.AlfangoDB,
        _canistergeekLogger : Canistergeek.Logger,
    ) : Result.Result<[ArgumentTypes.UserActionEmailResponse], [Text]> {
        let item = Database.scan({
            scanInput = {
                databaseName = Constants.KonectA;
                tableName = Constants.UserActionEmailTable;
                filter = #AND([]);
            };
            alfangoDB = alfangoDB;
        });

        TransformService.transformGetAllUserActionEmails(item);
    };
};