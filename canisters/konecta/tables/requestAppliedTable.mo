module RequestAppliedTable {
  public let RequestAppliedTableAttributes = [
    {
      name = "event_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "applied_user_id";
      dataType = #principal;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "note";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "location";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "action";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "timestamp";
      dataType = #nat;
      unique = false;
      required = true;
      defaultValue = #default;
    },
  ];

  public let RequestAppliedTableIndexes = [
    {
      name = "event_id_index";
      nonUnique = false;
      attributeName = "event_id";
    },
    {
      name = "applied_user_id_index";
      nonUnique = false;
      attributeName = "applied_user_id";
    },
  ];
};
