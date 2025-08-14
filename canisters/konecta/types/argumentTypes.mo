import Database "mo:alfangodb/AlfangoDB";
import Bool "mo:base/Bool";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";

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

  public type EventResponsePayload = {
    konecta_event_id : Text;
    user_id : Text;
    event_id : Text;
    event_name : Text;
    event_description : Text;
    subaccount_id_hex : Text;
    event_type : Text;
    status : Text;
    start_date : Nat;
    end_date : Nat;
    categories : [Text];
    consultations : [Text];
    expertise : Text;
    price_token : Text;
    token_amount : Float;
    interests : [Text];
    showcase_link : Text;
    participation_type : Text;
    recording_visibility : Text;
    is_recording_available : Bool;
    subaccount_id_index : Nat;
    metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
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

  public type EventCanisterRequestPayload = {
    user_id : Principal;
    coverphoto : Text;
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat;
    end_date : Nat;
    language : Text;
    status : EventStatus;
    metadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type PaginatedProposalResponsePayload = {
    items : [ProposalResponsePayload];
    offset : Nat;
    limit : Nat;
    scannedItemCount : Int;
    nonScannedItemCount : Int;
    totalRecords : Nat;
  };

  public type PaginatedProposalCompositeQueryPayload = {
    items : [ProposalCompositeQueryPayload];
    offset : Nat;
    limit : Nat;
    scannedItemCount : Int;
    nonScannedItemCount : Int;
    totalRecords : Nat;
  };

  public type PaginatedTransactionResponsePayload = {
    items : [TransactionResponsePayload];
    offset : Nat;
    limit : Nat;
    scannedItemCount : Int;
    nonScannedItemCount : Int;
    totalRecords : Nat;
  };

  public type PaginatedTransactionWithUserDataResponse = {
    items : [TransactionWithUserDataResponse];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor; // <-- MODIFIED
  };

  public type EventWithUserDataTupleArray = [(Text, EventProtocolCanisterPayload)];

  public type FeedRequestPayload = {
    currentTimestamp : Nat;
    timezone : ?Text;
    categories : [Text];
    offset : Nat;
    limit : Nat;
    searchValue : ?Text;
    recordingType : [Bool];
  };

  public type FeedResponsePayload = {
    event_id : Text;
    user_id : Text;
    subaccount_id_hex : Text;
    coverphoto : Text;
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat;
    end_date : Nat;
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
    showcase_link : Text;
    participation_type : Text;
    recording_visibility : Text;
    is_recording_available : Bool;
    subaccount_id_index : Nat;
    eventMetadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
    konectaMetadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
  };

  public type PaginatedEventResponsePayload = {
    items : [EventResponsePayload];
    offset : Nat;
    limit : Nat;
    scannedItemCount : Int;
    nonScannedItemCount : Int;
    totalRecords : Nat;
  };

  public type FeedResponsePayloadWithoutUser = {
    event_id : Text;
    user_id : Text;
    subaccount_id_hex : Text;
    coverphoto : Text;
    name : Text;
    description : Text;
    location : Text;
    start_date : Nat;
    end_date : Nat;
    language : Text;
    status : Text;
    konecta_event_id : Text;
    event_type : Text;
    categories : [Text];
    consultations : [Text];
    expertise : Text;
    price_token : Text;
    token_amount : Float;
    interests : [Text];
    showcase_link : Text;
    participation_type : Text;
    recording_visibility : Text;
    is_recording_available : Bool;
    subaccount_id_index : Nat;
    eventMetadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
    konectaMetadata : [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];
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

  public type PaginatedEventWithUserDataTupleArray = {
    items : EventWithUserDataTupleArray;
    offset : Nat;
    limit : Nat;
    scannedItemCount : Int;
    nonScannedItemCount : Int;
    totalRecords : Nat;
  };

  public type EventCanisterResponseWithoutUser = {
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

  public type CalendarRequestPayload = {
    name : Text;
    description : Text;
  };

  public type RemoveCalendarEvent = {
    event_id : Text;
  };

  public type CalendarAndEventMetadataResponse = {
    calendar_id : Text;
    eventMetadata_id : Text;
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
  };

  public type WithdrawAttendeeRequestPayload = {
    event_id : Text;
    invitee_user_id : Principal;
    action : EventAttendeeActions;
    timestamp : Nat;
    event_type : Text;
    event_status : Text;
  };

  public type AppliedServiceRequestsPayload = {
    event_id : Text;
    applied_user_id : Principal;
    action : EventAttendeeActions;
    timestamp : Nat;
    event_status : Text;
  };

  public type ApplyToServiceRequestPayload = {
    event_id : Text;
    note : Text;
    location : Text;
  };

  public type AppplicantIdsResponsePayload = {
    id : Text;
    applied_user_id : Text;
    note : Text;
    location : Text;
    action : Text;
    timestamp : Nat;
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

  public type ProposalCompositeQueryPayload = {
    event_id : Text;
    konectaEventData : EventResponsePayload;
    note : Text;
    location : Text;
    action : Text;
    updated_at : Nat;
  };

  public type TransferRequestPayload = {
    eventId : Text;
    priceToken : Token;
    amount : Nat;
    fee : ?Nat;
    memo : ?Blob;
  };

  public type TransferredToType = {
    #EventSubaccount;
    #CreatorUser;
    #AcceptedUser;
    #KonectaAccount;
    #CancellationRefund;
    #AutomaticRefundByJob;
    #RefundByExpert;
  };

  public type TransactionRequestPayload = {
    event_id : Text;
    transferred_to_type : TransferredToType;
    remitter_user_id : Text;
    beneficiary_user_id : Text;
    source_account_id_hex : Text;
    destination_account_id_hex : Text;
    block_index : Nat;
    amount : Nat;
    fee : Nat;
    narration : Text;
    memo : ?Blob;
    created_at_time : Nat64;
  };

  public type TransactionUser = {
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
  };

  public type TransactionResponsePayload = {
    transaction_id : Text;
    event_id : Text;
    transferred_to_type : Text;
    remitter_user_id : Text;
    beneficiary_user_id : Text;
    source_account_id_hex : Text;
    destination_account_id_hex : Text;
    block_index : Nat;
    amount : Nat;
    fee : Nat;
    narration : Text;
    memo : Blob;
    created_at_time : Nat64;
  };

  public type TransactionWithUserDataResponse = {
    transaction_id : Text;
    event_id : Text;
    transferred_to_type : Text;
    remitter_user_id : Text;
    beneficiary_user_id : Text;
    source_account_id_hex : Text;
    destination_account_id_hex : Text;
    block_index : Nat;
    amount : Nat;
    fee : Nat;
    narration : Text;
    memo : Blob;
    created_at_time : Nat64;
    eventData : FeedResponsePayloadWithoutUser;
    beneficiary_user_data : ?TransactionUser;
    url : Text;
  };

  public type Timestamp = Nat64;
  public type LedgerIcrc1TransferError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #BadBurn : { min_burn_amount : Nat };
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #CreatedInFuture : { ledger_time : Timestamp };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
    #AddTxHistoryError : { message : Text };
    #FetchEventDetailsError : { message : Text };
    #FetchTxHistoryError : { message : Text };
    #GetAcceptedUserError : { message : Text };
    #FreeEventError : { message : Text };
    #SendEmailError : { message : Text };
  };

  public type LedgerIcrc2TransferError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #InsufficientAllowance : { allowance : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
    #AddTxHistoryError : { message : Text };
    #FetchEventDetailsError : { message : Text };
    #FetchTxHistoryError : { message : Text };
    #CreateEventMetadataError : { message : Text };
  };

  public type EmailVariableType = {
    #Single : (Text, Text);
    #Nested : (Text, [[(Text, Text)]]);
  };

  public type SendNotificationArgs = {
    email : Text;
    templateName : Text;
    sender : Text;
    subject : Text;
    variables : [EmailVariableType];
  };

  public type MailgunResponse = {
    id : ?Text;
    message : Text;
  };

  public type UserActionEmailPayload = {
    to_user_timezone : Text;
    to_email : Text;
    event_id : Text;
    event_location : Text;
    event_date : Text;
    event_name : Text;
    from_firstname : Text;
    from_lastname : Text;
    to_firstname : Text;
    to_lastname : Text;
    is_attendee : Text;
    is_request : Text;
    is_offer : Text;
    is_request_creator : Text;
    is_paid_event : Bool;
  };

  public type UserActionTablePayload = {
    event_id : Text;
    from_user_id : Text;
    to_user_id : Text;
    action : Text;
    from : Text;
    to : Text;
    timestamp : Nat;
    template_name : Text;
  };

  public type UserFeedbackRequestPayload = {
    event_id : Text;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
    timezone : Text;
    successful : FeedbackActions;
    reason : ?Text;
    rating : ?Nat;
    recording_link : ?Text;
  };

  public type CreateUserFeedbackResponsePayload = {
    feedbackId : Text;
    konectaEventData : EventResponsePayload;
  };

  public type EventCompletionResponsePayload = {
    id : Text;
    event_id : Text;
    user_id : Text;
    user_type : Text;
    recipient_type : Text;
    notification_type : Text;
    template_name : Text;
    from : Text;
    to : Text;
    message_id : Text;
    idempotency_key : Text;
  };

  public type FeedbackActions = {
    #Yes;
    #No;
  };

  public type UserFeedbackResponsePayload = {
    id : Text;
    event_id : Text;
    user_id : Text;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
    timezone : Text;
    user_type : Text;
    successful : Text;
    reason : Text;
    rating : Nat;
    recording_link : Text;
  };

  public type ForwardToExpertRequestPayload = {
    event_id : Text;
    user_feedback_id : Text;
  };

  public let FeedbackEmailKeys = [
    "user_feedback_id",
    "username",
    "reason",
    "rating",
  ];

  public type GenericObject = {
    key : Text;
    value : ?Text;
  };

  public type FeedbackEmail = {
    user_feedback_id : Text;
    username : Text;
    reason : ?Text;
    rating : ?Nat;
  };

  public type MissingFeedbackEmail = {
    user_id : Text;
    firstname : Text;
    lastname : Text;
    username : Text;
    email : Text;
  };

  public type ForwardMultipleToExpert = {
    event_id : Text;
    beneficiary_feedback_id : Text;
    userFeedbackArr : [FeedbackEmail];
    userFeedbackEmailArr : [[(Text, Text)]];
  };

  public type ForwardMissingFeedbackToExpert = {
    event_id : Text;
    missingFeedbackUserArr : [MissingFeedbackEmail];
    missingFeedbackUserEmailArr : [[(Text, Text)]];
  };

  public type ForwardToExpertResponsePayload = {
    id : Text;
    event_id : Text;
    from : Text;
    to : Text;
    user_feedback_id : Text;
    template_name : Text;
    message_id : Text;
    idempotency_key : Text;
  };

  public type MoneyTransferActions = {
    #TransferToBeneficiary;
    #RefundToRemitter;
  };

  public type ExpertFeedbackRequestPayload = {
    event_id : Text;
    remitter_feedback_missing : Bool;
    user_feedback_id : ?Text;
    agreeWithUserFeedback : ?FeedbackActions;
    user_id : ?Text;
    transfer_or_refund : ?MoneyTransferActions;
    event_recording_link : ?Text;
    reason : ?Text;
  };

  public type ExpertFeedbackResponsePayload = {
    event_id : Text;
    remitter_feedback_missing : Bool;
    user_feedback_id : Text;
    user_feedback : ?UserFeedbackResponsePayload;
    agreeWithUserFeedback : Text;
    user_id : Text;
    transfer_or_refund : Text;
    event_recording_link : Text;
    reason : Text;
  };

  public type ExpertFeedbackForMissingRemitterFeedback = {
    event_id : Text;
    user_id : Text;
    transferOrRefund : MoneyTransferActions;
    reason : ?Text;
  };

  public type ExpertResolutionEmailRequest = {
    event_id : Text;
    remitter_user_id_of_refundee : Text;
    user_feedback : UserFeedbackResponsePayload;
    creator_feedback : UserFeedbackResponsePayload;
    expert_feedback_id : Text;
    remitter_feedback_missing : Bool;
    transaction_id : ?Text;
  };

  public type ExpertResolutionEmailResponse = {
    event_id : Text;
    user_feedback_id : Text;
    expert_feedback_id : Text;
    from : Text;
    to : Text;
    template_name : Text;
    message_id : Text;
    transaction_id : Text;
    idempotency_key : Text;
  };

  public type MissingFeedbackEvent = {
    event_id : Text;
    start_date : Nat;
    end_date : Nat;
    name : Text;
  };

  public type EmailResponse = {
    message_id : Text;
    idempotency_key : Text;
  };

  public type UserActionEmailResponse = {
    event_id : Text;
    from_user_id : Text;
    to_user_id : Text;
    action : Text;
    from : Text;
    to : Text;
    template_name : Text;
    message_id : Text;
    idempotency_key : Text;
    timestamp : Nat;
  };

  public type SearchFilterExpression = {
    attributeName : Text;
    filterExpressionCondition : Database.FilterExpressionConditionType;
  };

  public type UserMoneyTransferEmailPayload = {
    user_feedback : UserFeedbackResponsePayload;
    creator_feedback : UserFeedbackResponsePayload;
    expert_feedback_id : Text;
    remitter_feedback_missing : Bool;
  };

  public type PaginatedAppplicantIdsResponsePayload = {
    items : [ApplicationDataWithEventDetails];
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

  public type ApplicantDetailsPayload = {
    userData : UserResponsePayload;
    applicationMetadata : ?[(Text, Database.StringAttributeDataValue)];
    applicationStatus : Text;
    applicationTimestamp : Nat;
  };

  public type PaginatedApplicationStatusOfMyCreatedEvents = {
    items : [ApplicationStatusOfMyCreatedEvents];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor; // <-- MODIFIED
  };

  public type ApplicationStatusOfMyCreatedEvents = {
    event_id : Text;
    event_name : Text;
    event_description : Text;
    applied_users_details : [ApplicantDetailsPayload];
  };

  public type ApplicationDataWithEventDetails = {
    event_id : Text;
    konecta_event_data : EventResponsePayload;
    applied_user_data : [AppplicantIdsResponsePayload];
  };

  public type EventApplicationStatus = {
    event_id : Text;
    applied_users : [EventApplicationStatusWithCanister];
  };

  public type EventApplicationStatusWithCanister = {
    applied_user_id : Text;
    action : Text;
    user_canister_id : Text;
  };

  public type CanisterMapPayload = {
    principal_id : Text;
    canister_id : Text;
  };

  public type CheckEventExistsPayload = {
    event_type : EventType;
    start_date : Nat;
    end_date : Nat;
  };

  public type PaginatedFeedResponsePayload = {
    items : [FeedResponsePayload];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor;
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

  public type PaginatedEventWithUserDataPayload = {
    items : [EventWithUserDataPayload];
    totalRecords : Nat;
    hasMore : Bool;
    nextCursor : ?SearchTypes.PaginatedScanCursor;
  };

};
