module {
  public let TransactionTableAttributes = [
    {
      name = "principal_id";
      dataType = #principal;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "subaccount_index";
      dataType = #nat;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "source_account_id_hex";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "destination_account_id_hex";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "block_index";
      dataType = #nat;
      unique = true;
      required = true;
      defaultValue = #default;
    },
    {
      name = "amount";
      dataType = #nat;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "fee";
      dataType = #nat;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "narration";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "memo";
      dataType = #blob;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "created_at_time";
      dataType = #nat64;
      unique = false;
      required = true;
      defaultValue = #default;
    },
  ];

  public let TransactionTableIndexes = [
    {
      name = "principal_id_index";
      attributeNames = ["principal_id"];
      unique = false;
    },
    {
      name = "block_index_index";
      attributeNames = ["block_index"];
      unique = true;
    },
  ];
};
