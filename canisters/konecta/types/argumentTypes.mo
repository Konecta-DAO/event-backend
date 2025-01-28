import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Map "mo:map/Map";

module {

  public type EventStatus = {
    #Created;
    #Canceled;
  };

  public type EventType = {
    #Request;
    #Offer;
  };

  public type Token = {
    #CKBTC;
    #ICP;
    #FREE;
  };

  public type EventResponsePayload = {
    konecta_event_id : Text;
    user_id : Text;
    event_id : Text;
    event_type : Text;
    status : Text;
    categories : [Text];
    consultations : [Text];
    expertise : Text;
    price_token : Text;
    token_amount : Float;
    interests : [Text];
    metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type FeedResponsePayload = {
    event_id : Text;
    user_id : Text;
    coverphoto : Text;
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat; // unix time in nanoseconds
    end_date : Nat; // unix time in nanoseconds
    language : Text;
    status : Text;
    userData : UserResponsePayload;
    konecta_event_id : Text;
    event_type : Text;
    categories : [Text];
    consultations : [Text];
    expertise : Text;
    price_token : Text;
    token_amount : Float;
    interests : [Text];
    eventMetadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
    konectaMetadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

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
    profilepic : Text;
    coverphoto : Text;
    country : Text;
    timezone : Text;
  };

  public type EventRequestPayload = {
    user_id : ?Text;
    event_id : Text;
    event_type : EventType;
    status : EventStatus;
    categories : [Text];
    consultations : ?[Text];
    expertise : ?Text;
    price_token : ?Token;
    token_amount : ?Float;
    interests : ?[Text];
    metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type EventCanisterRequestPayload = {
    user_id : Principal;
    coverphoto : Text;
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat; // unix time in nanoseconds
    end_date : Nat; // unix time in nanoseconds
    language : Text;
    status : EventStatus;
    metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type UpdateEventMetadataPayload = {
    event_id : Text;
    status : EventStatus;
    categories : [Text];
    interests : [Text];
  };

  public type CreateEventMetadataRequestPayload = {
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

  public type EventProtocolCanisterPayload = {
    event_id : Text;
    user_id : Text;
    coverphoto : Text;
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat; // unix time in nanoseconds
    end_date : Nat; // unix time in nanoseconds
    language : Text;
    status : Text;
    metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
    userData : UserResponsePayload;
  };

  public type CalendarRequestPayload = {
    name : Text;
    description : Text;
  };

  public type EventAttendeeActions = {
    #Applied;
    #Invited;
    #Accepted;
    #Joined;
    #Declined;
  };

  public type EventAttendeeRequestPayload = {
    event_id : Text;
    invitee_user_id : Principal;
    action : EventAttendeeActions;
    timestamp : Nat;
  };

  public type AppliedServiceRequestsPayload = {
    event_id : Text;
    applied_user_id : Principal;
    action : EventAttendeeActions;
    timestamp : Nat;
  };

  public type ApplyToServiceRequestPayload = {
    event_id : Text;
    note : Text;
    location : Text;
  };

  public type AppplicantIdsResponsePayload = {
    applied_user_id : Text;
    note : Text;
    location : Text;
  };
  public type ApplicantsWithUserDataPayload = {
    userData : UserResponsePayload;
    note : Text;
    location : Text;
  };

  public type ProposalResponsePayload = {
    event_id : Text;
    event_name : Text;
    event_description : Text;
    userData : UserResponsePayload;
    note : Text;
    location : Text;
    action : Text;
    updated_at : Nat;
  };
};
