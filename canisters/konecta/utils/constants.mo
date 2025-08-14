module {
  public let KonectA = "KonectA";
  public let TransactionTable = "TransactionTable";
  public let EventCompletionNotificationTable = "EventCompletionNotificationTable";
  public let UserFeedbackTable = "UserFeedbackTable";
  public let ExpertEmailTable = "ExpertEmailTable";
  public let ExpertFeedbackTable = "ExpertFeedbackTable";
  public let ResolutionResponseEmailTable = "ResolutionResponseEmailTable";
  public let UserActionEmailTable = "UserActionEmailTable";
  public let MissingFeedbackEmailTable = "MissingFeedbackEmailTable";
  public let AnonymousPrincipal = "2vxsx-fae";
  public let ICDashboard = "https://dashboard.internetcomputer.org/transaction/";
  public let EventStatus = {
    Draft = "Draft";
    Created = "Created";
    Canceled = "Canceled";
  };
  public let EventStatusVariant = {
    Draft = #Draft;
    Created = #Created;
    Canceled = #Canceled;
  };
  public let EventType = {
    Request = "Request";
    Offer = "Offer";
  };
  public let EventTypeVariant = {
    Request = #Request;
    Offer = #Offer;
  };

  public let ParticipationTypeVariant = {
    PersonToPerson = #PersonToPerson;
    PersonToMultiplePersons = #PersonToMultiplePersons;
  };

  public let RecordingVisibility = {
    Public = "Public";
    Private = "Private";
  };
  public let RecordingVisibilityVariant = {
    Public = #Public;
    Private = #Private;
  };

  public let TokenType = {
    CKBTC = "CKBTC";
    ICP = "ICP";
    FREE = "FREE";
  };
  public let TokenTypeVariant = {
    CKBTC = #CKBTC;
    ICP = #ICP;
    FREE = #FREE;
  };
  public let EventAttendeeStatus = {
    Applied = "Applied";
    Invited = "Invited";
    Accepted = "Accepted";
    Joined = "Joined";
    Declined = "Declined";
    Withdrawn = "Withdrawn";
  };
  public let EventAttendeeStatusVariant = {
    Applied = #Applied;
    Invited = #Invited;
    Accepted = #Accepted;
    Joined = #Joined;
    Declined = #Declined;
    Withdrawn = #Withdrawn;
  };
  public let FeedbackStatus = {
    Yes = "Yes";
    No = "No";
  };
  public let FeedbackStatusVariant = {
    Yes = #Yes;
    No = #No;
  };
  public let MoneyTransferActionsVariant = {
    TransferToBeneficiary = #TransferToBeneficiary;
    RefundToRemitter = #RefundToRemitter;
  };
  public let MoneyTransferActions = {
    TransferToBeneficiary = "TransferToBeneficiary";
    RefundToRemitter = "RefundToRemitter";
  };
  public let whiteListedCanisters = [
    "https://playground-dev.nfid.one",
    "https://wzkxy-vyaaa-aaaaj-qab3q-cai.ic0.app",
    "https://hvn26-aiaaa-aaaak-aaa2a-cai.ic0.app",
    "nfid.one",
    "https://gzqxf-kqaaa-aaaak-qakba-cai",
    "http://localhost:3000", // React Localhost
    "http://localhost:3000/", // React Localhost
    "http://localhost:4200", // Angular Localhost
    "https://wfguo-oiaaa-aaaag-qngma-cai.icp0.io", // KonectA Frontend Canister
    "https://ryjl3-tyaaa-aaaaa-aaaba-cai",
    "https://mxzaz-hqaaa-aaaar-qaada-cai",
    "https://zfcdd-tqaaa-aaaaq-aaaga-cai",
    "https://2ouva-viaaa-aaaaq-aaamq-cai",
    "https://wfguo-oiaaa-aaaag-qngma-cai.icp0.io/",
  ];
  public let IndexCanister = "yak2b-tqaaa-aaaag-qnhmq-cai";
  public let EventCanister = "yhl4v-6iaaa-aaaag-qnhma-cai";
  public let KonectaCanister = "eyark-fqaaa-aaaag-qm7oa-cai";
  public let IcpLedgerCanister = "ryjl3-tyaaa-aaaaa-aaaba-cai";
  public let CkbtcLedgerCanister = "mxzaz-hqaaa-aaaar-qaada-cai";
  public let TransferredToType = {
    EventSubaccount = "EventSubaccount";
    CreatorUser = "CreatorUser";
    AcceptedUser = "AcceptedUser";
    KonectaAccount = "KonectaAccount";
    CancellationRefund = "CancellationRefund";
    AutomaticRefundByJob = "AutomaticRefundByJob";
    RefundByExpert = "RefundByExpert";
  };
  public let TransferredToTypeVariant = {
    EventSubaccount = #EventSubaccount;
    CreatorUser = #CreatorUser;
    AcceptedUser = #AcceptedUser;
    KonectaAccount = #KonectaAccount;
    CancellationRefund = #CancellationRefund;
    AutomaticRefundByJob = #AutomaticRefundByJob;
    RefundByExpert = #RefundByExpert;
  };
  public let KonectAEmail = "Konecta Admin <noreply@konecta.com>";
  public let ExpertEmail = "nshahdev1@gmail.com";
  public let EmailType = {
    EventRequestAccepted = "EventRequestAccepted";
    EventCanceled = "EventCanceled";
  };
  public let EmailTemplates = {
    EventCompletionTemplate = "eventcompletion";
    ForwardIssueToExpertTemplate = "forwardissuetoexpert";
    ForwardRatingToExpertTemplate = "forwardratingtoexpert";
    ForwardMultipleIssueToExpertTemplate = "forwardmultipleissuestoexpert";
    ForwardMultipleRatingToExpertTemplate = "forwardmultipleratingstoexpert";
    ForwardFeedbackConflictToExpertTemplate = "feedbackconflicttemplate";
    ResolutionRefundTemplate = "resolutionrefundtemplate";
    EventRecordingTemplate = "eventrecordingtemplate";
    CancelEventByCreatorORAcceptee = "canceleventbycreatororacceptee";
    CancelEventByAttendee = "canceleventbyattendee";
    CancelEventbyApplicant = "canceleventbyapplicant";
    ForwardMissingFeedbackUserlistToExpert = "forwardmissingfeedbackuserlisttoexpert";
    NewApplicationForServiceRequest = "newapplicationforservicerequest";
  };
  public let EventCompletionEmailUserType = {
    RequestCreator = "RequestCreator";
    Attendee = "Attendee";
    OfferCreator = "OfferCreator";
    Acceptee = "Acceptee";
  };
  public let PaymentUserType = {
    Remitter = "Remitter";
    Beneficiary = "Beneficiary";
  };
  public let NotificationType = {
    Email = "Email";
    InApp = "InApp";
  };
};
