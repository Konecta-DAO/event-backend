module EventAttendeeTable {
  public let EventAttendeeTableAttributes = [
    {
      name = "event_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "invitee_user_id";
      dataType = #principal;
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

  public let EventAttendeeTableIndexes = [
    {
      name = "event_id_index";
      nonUnique = false;
      attributeName = "event_id";
    },
  ];
};
