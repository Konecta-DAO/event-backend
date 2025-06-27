import Principal "mo:base/Principal";
import SharedTypes "../../shared/types";

module {

  public type UserPayload = {
    id : Text;
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
    country : Text;
    timezone : Text;
  };

  public type UserRequestPayload = {
    id : ?Text;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
    bio : ?Text;
    categories : ?[Text];
    profilepic : ?Text;
    coverphoto : ?Text;
    country : Text;
    timezone : Text;
  };

  public type UpdateUserRecordPayload = {
    id : ?Text;
    principal_id : Text;
    canister_id : Text;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
    bio : ?Text;
    categories : ?[Text];
    profilepic : ?Text;
    coverphoto : ?Text;
    country : Text;
    timezone : Text;
  };

  public type EventMetadataRequestPayload = {
    calendar_id : ?Text;
    event_id : Text;
    name : ?Text;
    categories : ?[Text];
    interests : ?[Text];
    start_date : ?Nat;
    end_date : ?Nat;
    status : SharedTypes.EventStatus;
    created_by : ?Principal;
  };

  public type EventMetadataResponsePayload = {
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

  public type CalendarResponsesPayload = {
    name : Text;
    description : Text;
    timezone : Text;
  };

  public type EventUserResponsePayload = {
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
};
