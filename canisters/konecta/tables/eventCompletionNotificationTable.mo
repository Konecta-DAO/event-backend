module EventCompletionNotificationTable {
  public let EventCompletionNotificationTableAttributes = [
    {
      name = "event_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "user_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "user_type";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "recipient_type";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "notification_type";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "template_name";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "from";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "to";
      dataType = #text;
      unique = false;
      required = false;
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
  ];

  public let EventCompletionNotificationTableIndexes = [
    { name = "event_id_index"; attributeNames = ["event_id"]; unique = false },
    { name = "user_id_index"; attributeNames = ["user_id"]; unique = false },
    { name = "user_type_index"; attributeNames = ["user_type"]; unique = false },
    {
      name = "recipient_type_index";
      attributeNames = ["recipient_type"];
      unique = false;
    },
    {
      name = "notification_type_index";
      attributeNames = ["notification_type"];
      unique = false;
    },
    { name = "from_index"; attributeNames = ["from"]; unique = false },
    { name = "to_index"; attributeNames = ["to"]; unique = false },
    {
      name = "message_id_index";
      attributeNames = ["message_id"];
      unique = false;
    },
  ];
};
