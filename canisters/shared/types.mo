/**
 * @file This module serves as the single source of truth for all data types
 * that are shared or passed between the canisters in the project (Index, User, Event, Konecta).
 * Centralizing types here prevents duplication and ensures consistency.
 */
import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

module {

    // =================================================================
    // ==                     SHARED VARIANT TYPES                    ==
    // =================================================================

    /**
    * Represents the status of a base Event or a Konecta Event.
    * Used by: Event, Konecta, User.
    */
    public type EventStatus = {
        #Created;
        #Canceled;
    };

    public let EventStatus = {
        Created = "Created";
        Canceled = "Canceled";
    };
    public let EventStatusVariant = {
        Created = #Created;
        Canceled = #Canceled;
    };

    /**
    * Represents the different actions or statuses an attendee can have for an event.
    * Used by: Event, Konecta.
    */
    public type EventAttendeeActions = {
        #Applied;
        #Invited;
        #Accepted;
        #Joined;
        #Declined;
    };

    public let EventAttendeeStatus = {
        Applied = "Applied";
        Invited = "Invited";
        Accepted = "Accepted";
        Joined = "Joined";
        Declined = "Declined";
    };

    // =================================================================
    // ==                 CANONICAL DATA STRUCTURES                   ==
    // =================================================================

    /**
    * The canonical public-facing user data structure.
    * This type is returned by the User canister and consumed by the Event and Konecta canisters.
    * It should contain the full, formatted URLs for images.
    */
    public type UserResponsePayload = {
        id : Text;
        principal_id : Text;
        canister_id : Text;
        firstname : Text;
        lastname : Text;
        username : Text;
        email : Text;
        bio : Text;
        categories : [Text];
        profilepic : Text; // The full URL, e.g., "https://<canister_id>.raw.icp0.io/..."
        coverphoto : Text; // The full URL
        country : Text;
        timezone : Text;
    };

    /**
    * A comprehensive event object that includes the creator's user data.
    * This is the primary event detail structure returned by the Event canister
    * and consumed by the Konecta canister.
    * Replaces `EventWithUserDataPayload` (from event canister) and `EventProtocolCanisterPayload` (from konecta canister).
    */
    public type EventDetailsPayload = {
        event_id : Text;
        user_id : Text;
        coverphoto : Text;
        name : Text;
        description : Text;
        location : Text;
        start_date : Nat;
        end_date : Nat;
        language : Text;
        status : Text;
        metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
        userData : UserResponsePayload;
    };

    // =================================================================
    // ==               INTER-CANISTER REQUEST PAYLOADS               ==
    // =================================================================

    /**
    * Payload for adding an attendee to an event's attendee list.
    * Used by: Konecta (caller) -> Event (receiver).
    */
    public type EventAttendeeRequestPayload = {
        event_id : Text;
        invitee_user_id : Principal;
        action : EventAttendeeActions;
        timestamp : Nat;
    };

    /**
    * NEW: Payload for creating a Konecta event. This is a shared type
    * to be used by any canister that needs to create a Konecta event.
    * Mirrors the type in konecta/types/argumentTypes.mo but is now shared.
    */
    public type KonectaEventCreationPayload = {
        user_id : ?Text;
        event_id : Text; // The ID of the base event, provided by the caller (Event canister)
        event_type : { #Request; #Offer };
        status : EventStatus;
        categories : [Text];
        consultations : ?[Text];
        expertise : ?Text;
        price_token : ?{ #CKBTC; #ICP; #FREE };
        token_amount : ?Float;
        interests : ?[Text];
        metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
    };

    /**
    * Payload for creating or updating calendar data within a User canister.
    * Used by: Event (caller) -> User (receiver)
    * Used by: Konecta (caller) -> User (receiver)
    */
    public type CalendarRequestPayload = {
        name : Text;
        description : Text;
    };

    /**
    * Payload for creating event-related metadata within a User canister.
    * This is sent when a new event/konect is created.
    * We merge the two slightly different definitions from the user and konecta canisters into one optional payload.
    * Used by: Event (caller) -> User (receiver), Konecta (caller) -> User (receiver).
    */
    public type CreateEventMetadataRequestPayload = {
        event_id : Text;
        name : Text;
        start_date : Nat;
        end_date : Nat;
        calendar_id : Text;
        status : EventStatus;
        created_by : Principal;
        // Fields specific to Konecta, optional for base Event
        categories : ?[Text];
        interests : ?[Text];
    };

    /**
    * Payload for updating event-related metadata in the User canister.
    * Used by: Konecta (caller) -> User (receiver).
    */
    public type UpdateEventMetadataPayload = {
        event_id : Text;
        status : ?EventStatus;
        categories : ?[Text];
        interests : ?[Text];
    };

    /**
    * Payload sent from the Konecta canister to the Event canister to update
    * the base event data after an application has been accepted.
    */
    public type EventCanisterRequestPayload = {
        user_id : ?Principal;
        coverphoto : Text;
        name : Text;
        description : Text;
        location : Text;
        start_date : Nat;
        end_date : Nat;
        language : ?Text;
        status : EventStatus;
        metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
    };
};
