import Principal "mo:base/Principal";
import Result "mo:base/Result";
import SharedTypes "./types";

module {
    // The single source of truth for the Index canister's public API
    public type IndexActor = actor {
        getUserCanisterByUserPrincipal : shared query (principal : Text) -> async Text;
        getUsersDataByPrincipal : composite query (userIds : [Text]) -> async [(Text, ?SharedTypes.UserResponsePayload)];
    };

    // The single source of truth for the Event canister's public API
    public type EventActor = actor {
        addEventAttendee : (payload : SharedTypes.EventAttendeeRequestPayload) -> async Result.Result<Text, Text>;
        cancelEvent : (userPrincipal : Principal, eventId : Text) -> async Result.Result<Text, Text>;
        checkIfAttendeeExistsForEvent : shared query (userPrincipal : Principal, eventId : Text) -> async Bool;
        getEventsForAttendee : shared query (userPrincipal : Text) -> async Result.Result<[Text], [Text]>;
        updateEventUsingUserPrincipal : (userPrincipal : Principal, userCanisterId : Text, eventId : Text, payload : SharedTypes.EventCanisterRequestPayload) -> async Result.Result<Text, Text>;
        getEventDetailsWithUserData : (eventId : Text) -> async SharedTypes.EventDetailsPayload;
        getMultipleEventsDetailsWithUserData : shared (eventIds : [Text]) -> async [(Text, ?SharedTypes.EventDetailsPayload)];
    };

    // The single source of truth for the User canister's public API
    public type UserActor = actor {
        createEventMetaData : (metadata : SharedTypes.CreateEventMetadataRequestPayload) -> async Result.Result<Text, Text>;
        updateEventMetaData : (eventMetadataId : Text, metadata : SharedTypes.UpdateEventMetadataPayload) -> async Text;
        upsertCalendarData : (userPrincipal : Text, calendarId : Text, calendarData : SharedTypes.CalendarRequestPayload) -> async Text;
        getCalendarId : (eventId : Text) -> async Text;
        getEventMetadataId : (eventId : Text, calendarId : Text) -> async Text;
        getUserForEventCanister : shared query (userPrincipal : Text) -> async SharedTypes.UserResponsePayload;
        deleteEventMetaData : (eventMetadataId : Text) -> async ();
        deleteCalendarData : (calendarId : Text) -> async ();
    };

    // The single source of truth for the Konecta canister's public API
    public type KonectaActor = actor {
        createKonectaEvent : (userCanisterId : Text, payload : SharedTypes.KonectaEventCreationPayload) -> async Text;
    };
};
