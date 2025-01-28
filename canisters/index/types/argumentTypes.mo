import Principal "mo:base/Principal";

module {

  public type UserMapPayload = {
    principal_id : Principal;
    canister_id : Principal;
    username : Text;
  };

  public type UpdateUserRequestPayload = {
    principal_id : Text;
    canister_id : Text;
    username : Text;
  };

  public type SignupResponsePayload = {
    userId : Int;
    message : Text;
  };

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
