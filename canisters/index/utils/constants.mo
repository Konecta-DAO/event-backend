module {
  public let DefaultCycles = 1_500_000_000_000;
  public let AnonymousPrincipal = "2vxsx-fae";
  /**
   * @desc List of whitelisted canisters that are allowed to access this IndexCanister.
   */
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
  public let IcpLedgerCanister = "ryjl3-tyaaa-aaaaa-aaaba-cai";
  public let VerifyIcpAmount = 1_000_000;
  public let KonectaCanister = "eyark-fqaaa-aaaag-qm7oa-cai";

  public let IndexDBName = "IndexDB";
  public let UserDataTable = "UserData";
  public let UserSubaccountTable = "UserSubaccount";
  public let TransactionTable = "Transaction";
};
