import ArgumentTypes "../types/argumentTypes";

module {

  public type UserCanisterType = actor {
    getUserDetailsByUsername : shared query (username : Text) -> async ?ArgumentTypes.UserPayload;
    upsertUserPublic : (pid : Text, payload : ArgumentTypes.UserRequestPayload) -> async Text;
  };

};
