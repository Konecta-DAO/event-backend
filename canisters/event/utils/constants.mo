module {
  public let KonectA = "KonectA";
  public let EventTable = "Event";
  public let EventAttendeeTable = "EventAttendeeTable";
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
  public let ParticipationType = {
    PersonToPerson = "PersonToPerson";
    PersonToMultiplePersons = "PersonToMultiplePersons";
  };
  public let DefaultLanguage = "English";
  public let EventAttendeeStatus = {
    Applied = "Applied";
    Invited = "Invited";
    Accepted = "Accepted";
    Joined = "Joined";
    Declined = "Declined";
    Withdrawn = "Withdrawn";
  };
  public let TokenType = {
    CKBTC = "CKBTC";
    ICP = "ICP";
    FREE = "FREE";
  };
  public let RecordingVisibility = {
    Public = "Public";
    Private = "Private";
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
};
