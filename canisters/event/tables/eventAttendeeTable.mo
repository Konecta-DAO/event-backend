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
      name = "event_status";
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
    {
      name = "metadata";
      dataType = #map;
      unique = false;
      required = false;
      defaultValue = #default;
    },
  ];

  public let EventAttendeeTableIndexes = [
    {
      name = "event_id_index";
      attributeNames = ["event_id"];
      unique = false;
    },
    {
      name = "invitee_user_id_index";
      attributeNames = ["invitee_user_id"];
      unique = false;
    },
    {
      name = "event_status_index";
      attributeNames = ["event_status"];
      unique = false;
    },
  ];
};
