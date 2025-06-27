import SharedTypes "../../shared/types";
import SharedServices "../../shared/services";
import SharedInterfaces "../../shared/interfaces";
import Canistergeek "mo:canistergeek/canistergeek";

module {
    public func cancelEventForUser(userId : Text, eventId : Text, eventObject : SharedTypes.UpdateEventMetadataPayload, canistergeekLogger : Canistergeek.Logger) : async () {
        try {
            let userCanisterId = await SharedServices.getUserCanisterId(userId);
            if (userCanisterId != "") {
                let userCanister = actor (userCanisterId) : SharedInterfaces.UserActor;
                let calendarId = await userCanister.getCalendarId(eventId);
                let eventMetadataId = await userCanister.getEventMetadataId(eventId, calendarId);

                ignore await userCanister.updateEventMetaData(eventMetadataId, eventObject);
            };
        } catch (_e) {
            canistergeekLogger.logMessage("Failed to cancel event for user " # userId);
        };
    };
};
