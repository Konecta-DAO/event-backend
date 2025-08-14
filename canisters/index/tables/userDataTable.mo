module {
  public let UserDataTableAttributes = [
    {
      name = "principal_id";
      dataType = #principal;
      unique = true;
      required = true;
      defaultValue = #default;
    },
    {
      name = "canister_id";
      dataType = #principal;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "username";
      dataType = #text;
      unique = true;
      required = true;
      defaultValue = #default;
    },
  ];

  public let UserDataTableIndexes = [
    {
      name = "principal_id_index";
      attributeNames = ["principal_id"];
      unique = true;
    },
    { name = "username_index"; attributeNames = ["username"]; unique = true },
  ];
};
