module ExpertFeedbackTable {
  public let ExpertFeedbackTableAttributes = [
    {
      name = "event_id";
      dataType = #text;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "remitter_feedback_missing";
      dataType = #bool;
      unique = false;
      required = true;
      defaultValue = #default;
    },
    {
      name = "user_feedback_id";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "agreeWithUserFeedback";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "user_id";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
    {
      name = "transfer_or_refund";
      dataType = #text;
      unique = false;
      required = false;
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
      name = "event_recording_link";
      dataType = #text;
      unique = false;
      required = false;
      defaultValue = #default;
    },
  ];

  public let ExpertFeedbackTableIndexes = [
    { name = "event_id_index"; attributeNames = ["event_id"]; unique = false },
    {
      name = "user_feedback_id_index";
      attributeNames = ["user_feedback_id"];
      unique = false;
    },
  ];
};
