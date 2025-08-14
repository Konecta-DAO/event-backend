module UserFeedbackTable {
  public let UserFeedbackTableAttributes = [
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
      name = "firstname";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "lastname";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "username";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "email";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "timezone";
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
      name = "successful";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "reason";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "recording_link";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "rating";
      dataType = #nat;
      unique = false;
      required = false;
      defaultValue = #default;
    },
  ];

  public let UserFeedbackTableIndexes = [
    { name = "event_id_index"; attributeNames = ["event_id"]; unique = false },
    { name = "user_id_index"; attributeNames = ["user_id"]; unique = false },
    { name = "username_index"; attributeNames = ["username"]; unique = false },
    { name = "email_index"; attributeNames = ["email"]; unique = false },
    { name = "user_type_index"; attributeNames = ["user_type"]; unique = false },
    {
      name = "successful_index";
      attributeNames = ["successful"];
      unique = false;
    },
    { name = "rating_index"; attributeNames = ["rating"]; unique = false },
  ];
};
