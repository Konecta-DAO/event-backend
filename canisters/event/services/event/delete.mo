import Database "mo:alfangodb/AlfangoDB";
import Result "mo:base/Result";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import SharedInterfaces "../../../shared/interfaces";
import SharedConstants "../../../shared/constants";
import Constants "../../utils/constants";
import ArgumentTypes "../../types/argumentTypes";
import { getTupleValueAsText } "../../../shared/common_utils/helper";

module {

    public func deleteEventById(
        eventData : ArgumentTypes.CreateEventSuccess,
        userCanisterId : Text,
        databases : Map.Map<Text, Database.Database>,
        d3 : D3.D3,
        canistergeekLogger : Canistergeek.Logger,
    ) : async Result.Result<(), Text> {

        try {
            let userCanister = actor (userCanisterId) : SharedInterfaces.UserActor;

            await userCanister.deleteEventMetaData(eventData.eventMetadataId);
            canistergeekLogger.logMessage("Rollback: Deleted Event Metadata " # eventData.eventMetadataId);

            await userCanister.deleteCalendarData(eventData.calendarId);
            canistergeekLogger.logMessage("Rollback: Deleted Calendar Data " # eventData.calendarId);

        } catch (e) {
            let errorMsg = "Rollback: FAILED to delete data from User canister.";
            canistergeekLogger.logMessage("CRITICAL: " # errorMsg);
            return #err(errorMsg);
        };

        let coverPhotoUrl = getTupleValueAsText(eventData.attributes, "coverphoto");
        if (coverPhotoUrl != "") {
            ignore await D3.updateOperation({
                d3 = d3;
                updateOperationInput = #DeleteFile({ fileId = coverPhotoUrl });
            });
            canistergeekLogger.logMessage("Rollback: Deleted cover photo " # coverPhotoUrl);
        };

        let deleteResult = Database.deleteItem({
            deleteItemInput = {
                databaseName = SharedConstants.KonectA;
                tableName = Constants.EventTable;
                id = eventData.id;
            };
            alfangoDB = { databases };
        });

        switch (deleteResult) {
            case (#ok) {
                canistergeekLogger.logMessage("Rollback: Deleted event record " # eventData.id);
                return #ok;
            };
            case (#err(msg)) {
                let errorMsg = "Rollback: FAILED to delete event record from DB. Error: " # msg[0];
                canistergeekLogger.logMessage("CRITICAL: " # errorMsg);
                return #err(errorMsg);
            };
        };
    };
};
