module EventTable {

  public let EventTableAttributes = [
    // Core Event Information
    {
      name = "user_id";
      dataType = #principal;
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
      name = "coverphoto";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "language";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },

    // Konecta-specific fields
    {
      name = "event_type";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "participation_type";
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
      name = "showcase_link";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "recording_visibility";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "is_recording_available";
      dataType = #bool;
      unique = false;
      required = false;
      defaultValue = #default;
    },

    // Subaccount and Metadata
    {
      name = "subaccount_id_hex";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "subaccount_id_index";
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

  public let EventTableIndexes = [
    {
      name = "user_id_index";
      attributeNames = ["user_id"];
      unique = false;
    },
    {
      name = "start_date_index";
      attributeNames = ["start_date"];
      unique = false;
    },
    {
      name = "status_index";
      attributeNames = ["status"];
      unique = false;
    },
    {
      name = "event_type_index";
      attributeNames = ["event_type"];
      unique = false;
    },
  ];
};
