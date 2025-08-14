module ResolutionResponseEmailTable {
  public let ResolutionResponseEmailTableAttributes = [
    {
      name = "event_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "user_feedback_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "expert_feedback_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "from";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "to";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "template_name";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "message_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "idempotency_key";
      dataType = #text;
      unique = true;
      required = true;
      defaultValue = #default;
    },
    {
      name = "transaction_id";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
  ];

  public let ResolutionResponseEmailTableIndexes = [
    { name = "event_id_index"; attributeNames = ["event_id"]; unique = false },
    {
      name = "user_feedback_id_index";
      attributeNames = ["user_feedback_id"];
      unique = false;
    },
    {
      name = "expert_feedback_id_index";
      attributeNames = ["expert_feedback_id"];
      unique = false;
    },
    { name = "from_index"; attributeNames = ["from"]; unique = false },
    { name = "to_index"; attributeNames = ["to"]; unique = false },
    {
      name = "message_id_index";
      attributeNames = ["message_id"];
      unique = false;
    },
    {
      name = "transaction_id_index";
      attributeNames = ["transaction_id"];
      unique = false;
    },
  ];
};
