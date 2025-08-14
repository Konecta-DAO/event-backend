import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import Map "mo:map/Map";

import SharedService "../../services/shared/shared";
import ArgumentTypes "../../types/argumentTypes";
import KonectaConstants "../../utils/constants";
import HelperService "../../utils/helper";
import CommonService "../../services/shared/common";

module {
  public func acceptUserApplication(
    creatorPrincipal : Principal, // The event creator, who is calling this function
    userIdOfApplicant : Text,
    eventId : Text,
    _alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    let eventCanisterActor = actor (KonectaConstants.EventCanister) : SharedService.EventCanisterType;
    let applicantPrincipal = Principal.fromText(userIdOfApplicant);

    // 1. Atomically update attendee statuses in the Event canister (the SSoT).
    // This will set the applicant to #Accepted and other applicants to #Declined.
    let processResult = await eventCanisterActor.acceptApplication(eventId, applicantPrincipal);
    switch (processResult) {
      case (#err(e)) {
        canistergeekLogger.logMessage("Failed to process application in Event canister: " # e);
        return #err("Failed to accept application: " # e);
      };
      case (#ok(_)) {
        // Proceed with orchestration
      };
    };

    // 2. Get fresh event details to use for calendar and event status updates.
    let eventData = await eventCanisterActor.getEventDetailsWithUserDataAsync(eventId);
    if (Text.size(eventData.event_id) == 0) {
      // This is unlikely if the previous step succeeded, but it's a good safeguard.
      return #err("Could not find event details after accepting the application. The event may have been deleted.");
    };

    // 3. Add the event to the *accepted applicant's* calendar.
    try {
      let applicantCanisterId = await SharedService.getUserCanisterId(Principal.toText(applicantPrincipal));
      if (Text.size(applicantCanisterId) == 0) {
        return #err("Could not find the applicant's user canister to update their calendar.");
      };

      let userCanister = actor (applicantCanisterId) : SharedService.UserCanisterType;

      var calendarId = await userCanister.getCalendarId(Principal.toText(applicantPrincipal));
      if (Text.size(calendarId) == 0) {
        // If the user doesn't have a calendar, create one.
        calendarId := await userCanister.upsertCalendarData(
          calendarId,
          { name = "Default Calendar"; description = "" },
        );
      };

      let eventMetadataPayload : ArgumentTypes.CreateEventMetadataRequestPayload = {
        event_id = eventData.event_id;
        name = eventData.name;
        start_date = eventData.start_date;
        end_date = eventData.end_date;
        calendar_id = calendarId;
        status = KonectaConstants.EventStatusVariant.Created; // The event is now officially on
        created_by = creatorPrincipal;
        categories = eventData.categories;
        interests = eventData.interests;
      };
      let calendarResponse = await userCanister.createEventMetaData(eventMetadataPayload);
      switch (calendarResponse) {
        case (#ok(_)) { /* Calendar updated successfully */ };
        case (#err(e)) {
          canistergeekLogger.logMessage("Failed to update applicant's calendar: " # e);
          return #err("Application accepted, but failed to update applicant's calendar. Error: " # e);
        };
      };
    } catch (e) {
      canistergeekLogger.logMessage("Unexpected error updating calendar: " # Error.message(e));
      return #err("An unexpected error occurred while updating the applicant's calendar.");
    };

    // 4. Update the main event's status to "Created".
    let updatePayload : ArgumentTypes.EventRequestPayload = {
      name = eventData.name;
      description = eventData.description;
      location = eventData.location;
      start_date = eventData.start_date;
      end_date = eventData.end_date;
      status = KonectaConstants.EventStatusVariant.Created; // This is the key change
      user_id = ?Principal.fromText(eventData.user_id);
      coverphoto = null; // No need to re-upload the photo
      language = ?eventData.language;
      metadata = ?eventData.metadata;
      event_type = CommonService.getEventTypeVariant(eventData.event_type, #Request);
      participation_type = ?CommonService.getParticipationTypeVariant(eventData.participation_type, #PersonToPerson);
      categories = eventData.categories;
      consultations = ?eventData.consultations;
      expertise = ?eventData.expertise;
      price_token = ?CommonService.getPriceTokenVariant(eventData.price_token, #ICP);
      token_amount = ?eventData.token_amount;
      interests = ?eventData.interests;
      showcase_link = ?eventData.showcase_link;
      recording_visibility = ?CommonService.getRecordingVisibiltyVariant(eventData.recording_visibility, #Private);
      is_recording_available = ?eventData.is_recording_available;
      subaccount_id_hex = eventData.subaccount_id_hex;
      subaccount_id_index = eventData.subaccount_id_index;
    };

    let creatorCanisterId = await SharedService.getUserCanisterId(Principal.toText(creatorPrincipal));
    let updateEventResponse = await eventCanisterActor.updateEvent(creatorCanisterId, eventId, updatePayload);

    switch (updateEventResponse) {
      case (#ok(_)) {
        return #ok("Application accepted successfully and event is now confirmed.");
      };
      case (#err(e)) {
        return #err("Application accepted, but failed to update the main event status. Error: " # e);
      };
    };
  };
};
