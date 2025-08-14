module {
  public let UserSubaccountTableAttributes = [
    {
      name = "principal_id";
      dataType = #principal;
      unique = true;
      required = true;
      defaultValue = #default;
    },
    {
      name = "subaccount_id_hex";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "subaccount_ledger_identifier";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "subaccount_index";
      dataType = #nat;
      unique = true;
      required = true;
      defaultValue = #default;
    },
  ];

  public let UserSubaccountTableIndexes = [
    {
      name = "principal_id_index";
      attributeNames = ["principal_id"];
      unique = true;
    },
    {
      name = "subaccount_index_index";
      attributeNames = ["subaccount_index"];
      unique = true;
    },
  ];
};
