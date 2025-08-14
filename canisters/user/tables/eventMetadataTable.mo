module EventMetadataTable {
  public let EventMetadataTableAttributes = [
    {
      name = "calendar_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "event_id";
      dataType = #text;
      unique = false;
      required = true;
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
      name = "categories";
      dataType = #list;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "interests";
      dataType = #list;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "start_date";
      dataType = #nat;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "end_date";
      dataType = #nat;
      unique = false;
      required = true;
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
      name = "created_by";
      dataType = #principal;
      unique = false;
      required = true;
      defaultValue = #default;
    },
  ];

  public let EventMetadataTableIndexes = [
    {
      name = "event_id_index";
      attributeNames = ["event_id"];
      unique = false;
    }
  ];
};
