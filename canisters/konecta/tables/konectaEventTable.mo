module KonectaEventTable {

  public let KonectaEventTableAttributes = [
    {
      name = "user_id";
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
      name = "status";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "event_type";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "categories";
      dataType = #list;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "consultations";
      dataType = #list;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "expertise";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "price_token";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "token_amount";
      dataType = #float;
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
      name = "metadata";
      dataType = #map;
      unique = false;
      required = false;
      defaultValue = #default;
    },
  ];

  public let KonectaEventTableIndexes = [
    {
      name = "event_id_index";
      nonUnique = false;
      attributeName = "event_id";
    },
  ];

};
