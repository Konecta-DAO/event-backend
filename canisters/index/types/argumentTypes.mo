import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Result "mo:base/Result";

module {

  public type CanisterMapPayload = {
    principal_id : Text;
    canister_id : Text;
  };

  public type UserMapPayload = {
    principal_id : Principal;
    canister_id : Principal;
    username : Text;
  };

  public type UserDataMapPayload = {
    principal_id : Principal;
    canister_id : Principal;
    username : Text;
    userData : UserPayload;
  };

  public type SubaccountMapPayload = {
    principal_id : Principal;
    subaccount_id_hex : Text;
    subaccount_ledger_identifier : Text;
    subaccount_index : Nat;
  };

  public type UpdateUserRequestPayload = {
    principal_id : Text;
    canister_id : Text;
    username : Text;
  };

  public type UserPayload = {
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
    introduction_video_link : Text;
    country : Text;
    timezone : Text;
  };

  public type UserAccountInfoPayload = {
    canister_id : Text;
    subaccount_id_hex : Text;
    subaccount_ledger_identifier : Text;
  };

  public type Timestamp = Nat64;

  public type TransactionResponsePayload = {
    principal_id : Principal;
    subaccount_index : Nat;
    source_account_id_hex : Text;
    destination_account_id_hex : Text;
    block_index : Nat;
    amount : Nat;
    fee : Nat;
    narration : Text;
    memo : ?Blob;
    created_at_time : Nat64;
  };

  public type RegistrationCheckSuccess = {
    message : Text;
    canister_id : Principal;
    subaccount_id_hex : ?Text;
    subaccount_ledger_identifier : ?Text;
  };

  public type RegistrationCheckError = {
    message : Text;
    canister_id : ?Principal;
    subaccount_id_hex : ?Text;
    subaccount_ledger_identifier : ?Text;
  };

  public type RegistrationCheckResult = Result.Result<RegistrationCheckSuccess, RegistrationCheckError>;
};
