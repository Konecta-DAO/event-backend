import Database "mo:alfangodb/AlfangoDB";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import SharedTypes "../../shared/types";

module {

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
    userData : SharedTypes.UserResponsePayload;
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

  public type EventRequestPayload = {
    user_id : ?Text;
    event_id : Text;
    event_type : EventType;
    status : SharedTypes.EventStatus;
    categories : [Text];
    consultations : ?[Text];
    expertise : ?Text;
    price_token : ?Token;
    token_amount : ?Float;
    interests : ?[Text];
    metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type AppliedServiceRequestsPayload = {
    event_id : Text;
    applied_user_id : Principal;
    action : SharedTypes.EventAttendeeActions;
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
    userData : SharedTypes.UserResponsePayload;
    note : Text;
    location : Text;
  };

  public type ProposalResponsePayload = {
    event_id : Text;
    event_name : Text;
    event_description : Text;
    userData : SharedTypes.UserResponsePayload;
    note : Text;
    location : Text;
    action : Text;
    updated_at : Nat;
  };
};
