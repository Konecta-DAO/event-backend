module {
  public let KonectA = "KonectA";
  public let KonectAEventTable = "KonectAEventTable";
  public let RequestAppliedTable = "RequestAppliedTable";
  public let AnonymousPrincipal = "2vxsx-fae";
  public let EventStatus = {
    Created = "Created";
    Canceled = "Canceled";
  };
  public let EventStatusVariant = {
    Created = #Created;
    Canceled = #Canceled;
  };
  public let EventType = {
    Request = "Request";
    Offer = "Offer";
  };
  public let TokenType = {
    CKBTC = "CKBTC";
    ICP = "ICP";
    FREE = "FREE";
  };
  public let EventAttendeeStatus = {
    Applied = "Applied";
    Invited = "Invited";
    Accepted = "Accepted";
    Joined = "Joined";
    Declined = "Declined";
  };
  public let EventAttendeeStatusVariant = {
    Applied = #Applied;
    Invited = #Invited;
    Accepted = #Accepted;
    Joined = #Joined;
    Declined = #Declined;
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
    "https://hst3y-eqaaa-aaaai-qpdyq-cai.icp0.io", // KonectA Frontend Canister
    "https://ryjl3-tyaaa-aaaaa-aaaba-cai",
    "https://mxzaz-hqaaa-aaaar-qaada-cai",
    "https://zfcdd-tqaaa-aaaaq-aaaga-cai",
    "https://2ouva-viaaa-aaaaq-aaamq-cai",
  ];
  public let IndexCanister = "xnp5v-5aaaa-aaaap-qccda-cai";
  public let EventCanister = "xemwj-liaaa-aaaap-qcccq-cai";
  public let KonectaCanister = "yg2ow-xiaaa-aaaap-qceza-cai";
};
