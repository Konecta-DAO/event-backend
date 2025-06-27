import Database "mo:alfangodb/AlfangoDB";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import SharedTypes "../../shared/types";
import KonectaTypes "../../konecta/types/argumentTypes";
module {

 public type CreateEventSuccess = {
    id : Text;
    attributes : [(Text, Database.AttributeDataValue)];
    calendarId: Text;
    eventMetadataId: Text;
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
    status : SharedTypes.EventStatus;
    metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type EventMetadataPayload = {
    event_id : Text;
    name : Text;
    start_date : Nat;
    end_date : Nat;
    calendar_id : Text;
    status : SharedTypes.EventStatus;
    created_by : Principal;
  };

  /**
    * The Konecta-specific data needed for the combined creation call.
    * Note it does NOT include event_id or status, as those are generated
    * during the base event creation.
    */
  public type KonectaDataForCombinedCreate = {
    event_type : KonectaTypes.EventType; // Re-use the variant from Konecta's types
    categories : [Text];
    consultations : ?[Text];
    expertise : ?Text;
    price_token : ?KonectaTypes.Token; // Re-use the variant from Konecta's types
    token_amount : ?Float;
    interests : ?[Text];
    metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  /**
    * The single payload from the frontend for the new combined function.
    */
  public type CreateEventAndKonectaPayload = {
    eventPayload : EventRequestPayload;
    konectaPayload : KonectaDataForCombinedCreate;
  };

  /**
    * The successful response type for the new combined function.
    */
  public type CreateEventAndKonectaResponse = {
    eventId : Text;
    konectaEventId : Text;
  };
};
