module TransactionTable {
  public let TransactionTableAttributes = [
    {
      name = "event_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "transferred_to_type";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "remitter_user_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "beneficiary_user_id";
      dataType = #text;
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
      name = "event_id_index";
      attributeNames = ["event_id"];
      unique = false;
    },
    {
      name = "transferred_to_type_index";
      attributeNames = ["transferred_to_type"];
      unique = false;
    },
    {
      name = "remitter_user_id_index";
      attributeNames = ["remitter_user_id"];
      unique = false;
    },
    {
      name = "beneficiary_user_id_index";
      attributeNames = ["beneficiary_user_id"];
      unique = false;
    },
    {
      name = "source_account_id_hex_index";
      attributeNames = ["source_account_id_hex"];
      unique = false;
    },
    {
      name = "destination_account_id_hex_index";
      attributeNames = ["destination_account_id_hex"];
      unique = false;
    },
  ];
};
