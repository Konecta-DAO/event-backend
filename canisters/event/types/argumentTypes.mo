import Database "mo:alfangodb/AlfangoDB";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Map "mo:map/Map";

module {

  public type EventStatus = {
    #Created;
    #Canceled;
  };

  public type EventResponsePayload = {
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
  };

  public type EventWithUserDataPayload = {
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

  public type EventRequestPayload = {
    user_id : ?Principal;
    coverphoto : ?{
      fileDataObject : Blob;
      fileName : Text;
      fileType : Text;
    };
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat; // unix time in nanoseconds
    end_date : Nat; // unix time in nanoseconds
    language : ?Text;
    status : EventStatus;
    metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type EventMetadataPayload = {
    event_id : Text;
    name : Text;
    start_date : Nat;
    end_date : Nat;
    calendar_id : Text;
    status : EventStatus;
    created_by : Principal;
  };

  public type CalendarRequestPayload = {
    name : Text;
    description : Text;
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

};
