import Database "mo:alfangodb/AlfangoDB";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {

  public type EventStatus = {
    #Draft;
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

  public type ParticipationType = {
    #PersonToPerson;
    #PersonToMultiplePersons;
  };

  public type RecordingVisibility = {
    #Public;
    #Private;
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

    event_type : Text;
    participation_type : Text;
    categories : [Text];
    consultations : [Text];
    expertise : Text;
    price_token : Text;
    token_amount : Float;
    interests : [Text];
    showcase_link : Text;
    recording_visibility : Text;
    is_recording_available : Bool;
    subaccount_id_hex : Text;
    subaccount_id_index : Nat;
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
    event_type : Text;
    participation_type : Text;
    categories : [Text];
    consultations : [Text];
    expertise : Text;
    price_token : Text;
    token_amount : Float;
    interests : [Text];
    showcase_link : Text;
    recording_visibility : Text;
    is_recording_available : Bool;
    subaccount_id_hex : Text;
    subaccount_id_index : Nat;

    userData : UserResponsePayload;
  };

  public type EventRequestPayload = {
    // Core Event Fields
    user_id : ?Principal;
    coverphoto : ?{ fileDataObject : Blob; fileName : Text; fileType : Text };
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat;
    end_date : Nat;
    language : ?Text;
    status : EventStatus;
    metadata : ?[(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];

    // Konecta-specific Fields
    event_type : EventType;
    participation_type : ?ParticipationType;
    categories : [Text];
    consultations : ?[Text];
    expertise : ?Text;
    price_token : ?Token;
    token_amount : ?Float;
    interests : ?[Text];
    showcase_link : ?Text;
    recording_visibility : ?RecordingVisibility;
    is_recording_available : ?Bool;

    // Subaccount Fields
    subaccount_id_hex : Text;
    subaccount_id_index : Nat;
  };

  public type EventMetadataPayload = {
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
    event_id : Text;
    name : ?Text;
    start_date : ?Nat;
    end_date : ?Nat;
    calendar_id : ?Text;
    status : EventStatus;
    created_by : ?Principal;
  };

  public type CalendarRequestPayload = {
    name : Text;
    description : Text;
  };

  public type UserResponsePayload = {
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

  public type EventAttendeeActions = {
    #Applied;
    #Invited;
    #Accepted;
    #Joined;
    #Declined;
    #Withdrawn;
  };

  public type EventAttendeeRequestPayload = {
    event_id : Text;
    invitee_user_id : Principal;
    action : EventAttendeeActions;
    timestamp : Nat;
    event_status : Text;
    event_type : Text;
    participation_type : Text;
    metadata : ?[(Text, Database.StringAttributeDataValue)];
  };

  public type WithdrawAttendeeRequestPayload = {
    event_id : Text;
    invitee_user_id : Principal;
    action : EventAttendeeActions;
    timestamp : Nat;
    event_type : Text;
    event_status : Text;
  };

  public type EventWithUserDataTupleArray = [(Text, EventWithUserDataPayload)];

  public type PaginatedEventIds = {
    ids : [Text];
    offset : Nat;
    limit : Nat;
    scannedItemCount : Int;
    nonScannedItemCount : Int;
    totalRecords : Nat;
  };

  public type PaginatedEventResponsePayload = {
    items : EventWithUserDataTupleArray;
    offset : Nat;
    limit : Nat;
    scannedItemCount : Int;
    nonScannedItemCount : Int;
    totalRecords : Nat;
  };

  public type EventAttendeeResponsePayload = {
    id : Text;
    event_id : Text;
    invitee_user_id : Text;
    action : Text;
    timestamp : Nat;
    event_status : Text;
    metadata : ?[(Text, Database.StringAttributeDataValue)];
  };

  public type PaginatedEventAttendeeResponse = {
    items : [EventAttendeeResponsePayload];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor;
  };

  public type PaginatedProposalsResponse = {
    items : [ProposalResponsePayload];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor;
  };

  public type ProposalResponsePayload = {
    eventData : EventWithUserDataPayload;
    proposalMetadata : ?[(Text, Database.StringAttributeDataValue)];
  };

  public type CanisterMapPayload = {
    principal_id : Text;
    canister_id : Text;
  };

  public type AttendeeEventMetadataRequestPayload = {
    calendar_id : ?Text;
    event_id : Text;
    name : ?Text;
    start_date : ?Nat;
    end_date : ?Nat;
    status : EventStatus;
    created_by : ?Principal;
  };

  public type UpdateMultipleEventsPayload = {
    eventId : Text;
    payload : EventRequestPayload;
  };

  public type UpdateMultipleEventsResponse = {
    successful : [Text];
    failed : [(Text, Text)];
  };

  public type PaginatedEventIdsWithCursor = {
    ids : [Text];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor;
  };

  public type PaginatedEventWithUserDataPayload = {
    items : [EventWithUserDataPayload];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor;
  };
};
