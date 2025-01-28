module EventTable {

  public let EventTableAttributes = [
    {
      name = "user_id";
      dataType = #principal;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "coverphoto";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "name";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "description";
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
      name = "start_date";
      dataType = #nat; // unix time in nanoseconds
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "end_date";
      dataType = #nat; // unix time in nanoseconds
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "language";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "status";
      dataType = #text;
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

  public let EventTableIndexes = [
    {
      name = "user_id_index";
      nonUnique = false;
      attributeName = "user_id";
    },
  ];

};
