import SharedConstants "./constants";
import SharedInterfaces "./interfaces";
import SharedTypes "./types";

module {
    public func getUserDetails(userId : Text) : async SharedTypes.UserResponsePayload {
        let indexActor = actor (SharedConstants.IndexCanister) : SharedInterfaces.IndexActor;
        let userCanisterId = await indexActor.getUserCanisterByUserPrincipal(userId);

        if (userCanisterId == "") {
            // A more robust solution would return a Result type.
        };

        let userCanisterActor = actor (userCanisterId) : SharedInterfaces.UserActor;
        let userData = await userCanisterActor.getUserForEventCanister(userId);

        return userData;
    };

    public func getUserCanisterId(userId : Text) : async Text {
        let indexActor = actor (SharedConstants.IndexCanister) : SharedInterfaces.IndexActor;
        let userCanisterId = await indexActor.getUserCanisterByUserPrincipal(userId);
        return userCanisterId;
    };
};
