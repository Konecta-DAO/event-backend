import ArgumentTypes "../types/argumentTypes";

module {

  public type UserCanisterType = actor {
    getUser : shared query () -> async ?ArgumentTypes.UserPayload;
    upsertUser : shared (payload : ArgumentTypes.UserRequestPayload) -> async Text;
  };

};
