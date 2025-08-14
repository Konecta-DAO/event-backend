import Principal "mo:base/Principal";
import Database "mo:alfangodb/AlfangoDB";
import Text "mo:base/Text";
import Nat "mo:base/Nat";

module {

  public type EventStatus = {
    #Draft;
    #Created;
    #Canceled;
  };

  public type UserPayload = {
    principal_id : Principal;
    canister_id : Principal;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
    bio : Text;
    categories : [Text];
    profilepic : Text;
    coverphoto : Text;
    introduction_video_link : Text;
    country : Text;
    timezone : Text;
  };

  public type UserRequestPayload = {
    principal_id : ?Text;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
    bio : ?Text;
    categories : ?[Text];
    profilepic : ?Text;
    coverphoto : ?Text;
    introduction_video_link : ?Text;
    country : Text;
    timezone : Text;
  };

  public type CreateEventMetadataPayload = {
    event_id : Text;
    name : Text;
    start_date : Nat;
    end_date : Nat;
    calendar_id : Text;
    status : EventStatus;
    created_by : Principal;
    categories : [Text];
    interests : [Text];
  };

  public type UpdateEventMetadataPayload = {
    calendar_id : ?Text;
    event_id : Text; // Required to find the correct record
    name : ?Text;
    start_date : ?Nat;
    end_date : ?Nat;
    status : EventStatus; // Status is required for an update
    created_by : ?Principal;
  };

  // This is the payload for when an attendee's calendar needs to be updated.
  // Subset of the UpdateEventMetadataPayload.
  public type AttendeeEventMetadataRequestPayload = {
    calendar_id : ?Text;
    event_id : Text;
    name : ?Text;
    start_date : ?Nat;
    end_date : ?Nat;
    status : EventStatus;
    created_by : ?Principal;
  };

  public type EventMetadataResponsePayload = {
    event_metadata_id : Text;
    calendar_id : Text;
    event_id : Text;
    name : Text;
    categories : [Text];
    interests : [Text];
    start_date : Nat;
    end_date : Nat;
    status : Text;
    created_by : Text;
  };

  public type CalendarRequestPayload = {
    name : Text;
    description : Text;
  };

  public type EventUserResponsePayload = {
    principal_id : Text;
    canister_id : Text;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
    bio : Text;
    categories : [Text];
    profilepic : Text;
    coverphoto : Text;
    introduction_video_link : Text;
    country : Text;
    timezone : Text;
  };
};
