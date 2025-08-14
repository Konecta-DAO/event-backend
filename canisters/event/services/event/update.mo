import Database "mo:alfangodb/AlfangoDB";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Canistergeek "mo:canistergeek/canistergeek";
import D3 "mo:d3storage/D3";
import Map "mo:map/Map";
import HashMap "mo:base/HashMap";
import CommonService "../../services/common";
import AddAttendeeService "../../services/eventAttendee/addAttendee";
import UpdateAttendeeService "../../services/eventAttendee/updateAttendee";
import {
  getAllAttendeesIds;
  getAttendeesIdsByActionArray;
  getAttendeesIdsByAction;
} "../../services/eventAttendee/getAttendee";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import Helper "../../utils/helper";
import {
  getTupleValueAsText;
  initializePrincipalField;
  textArrayToString;
  textToNat;
} "../../utils/helper";
import { eventDataById } "./read";

module {
  type MetadataForMap = [(Text, Database.NumericAttributeDataValue or Database.StringAttributeDataValue or Database.ListAttributeDataValue)];

  public func updateEvent(
    userPrincipal : Principal,
    userCanisterId : Text,
    eventId : Text,
    payload : ArgumentTypes.EventRequestPayload,
    alfangoDB : Database.AlfangoDB,
    d3 : D3.D3,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    let eventData = eventDataById(eventId, alfangoDB);
    var oldValues : ArgumentTypes.EventResponsePayload = CommonService.initialEventObjectWithUserData;
    switch (eventData) {
      case (#ok(event)) {
        oldValues := event;
      };
      case (#err(errorMessage)) {
        return #err("Failed to find event to update: " # Helper.textArrayToString(errorMessage));
      };
    };

    var coverPhotoUrl = oldValues.coverphoto;
    ignore do ? {

      let coverPhotoOutput = await D3.storeFile({
        d3 = d3;
        storeFileInput = {
          fileDataObject = payload.coverphoto!.fileDataObject;
          fileName = payload.coverphoto!.fileName;
          fileType = payload.coverphoto!.fileType;
        };
      });

      switch (coverPhotoOutput) {
        case (file) {
          coverPhotoUrl := file.fileId;
        };
      };
    };

    let language = Helper.initializeTextField(payload.language, oldValues.language);

    let metadata_for_map : MetadataForMap = switch (payload.metadata) {
      case (?meta) meta;
      case null oldValues.metadata;
    };

    let status = CommonService.getEventStatus(payload.status, oldValues.status);
    let userId = Helper.initializePrincipalField(payload.user_id, Principal.fromText(oldValues.user_id));
    let eventType = Helper.getEventType(payload.event_type, oldValues.event_type);
    let participationType = Helper.getParticipationType(payload.participation_type, oldValues.participation_type);
    let categoriesArray = Helper.getStringAttributeDataValueArray(payload.categories);
    let consultations = Helper.initializeTextArrayField(payload.consultations, oldValues.consultations);
    let consultationsArray = Helper.getStringAttributeDataValueArray(consultations);
    let expertise = Helper.initializeTextField(payload.expertise, oldValues.expertise);
    let priceToken = Helper.getPriceToken(payload.price_token, oldValues.price_token);
    let tokenAmount = Helper.initializeFloatField(payload.token_amount, oldValues.token_amount);
    let interests = Helper.initializeTextArrayField(payload.interests, oldValues.interests);
    let interestsArray = Helper.getStringAttributeDataValueArray(interests);
    let showcaseLink = Helper.initializeTextField(payload.showcase_link, oldValues.showcase_link);
    let recordingVisibility = Helper.getRecordingVisibilty(payload.recording_visibility, oldValues.recording_visibility);
    let isRecordingAvailable = Helper.initializeBoolField(payload.is_recording_available, oldValues.is_recording_available);

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("user_id", #principal(userId)),
      ("name", #text(payload.name)),
      ("description", #text(payload.description)),
      ("location", #text(payload.location)),
      ("start_date", #nat(payload.start_date)),
      ("end_date", #nat(payload.end_date)),
      ("status", #text(status)),
      ("coverphoto", #text(coverPhotoUrl)),
      ("language", #text(language)),
      ("metadata", #map(metadata_for_map)),
      ("event_type", #text(eventType)),
      ("participation_type", #text(participationType)),
      ("categories", #list(categoriesArray)),
      ("consultations", #list(consultationsArray)),
      ("expertise", #text(expertise)),
      ("price_token", #text(priceToken)),
      ("token_amount", #float(tokenAmount)),
      ("interests", #list(interestsArray)),
      ("showcase_link", #text(showcaseLink)),
      ("recording_visibility", #text(recordingVisibility)),
      ("is_recording_available", #bool(isRecordingAvailable)),
      ("subaccount_id_hex", #text(payload.subaccount_id_hex)),
      ("subaccount_id_index", #nat(payload.subaccount_id_index)),
    ];
    canistergeekLogger.logMessage("Attribute data values --->" # debug_show (attributeDataValues));

    let item = Database.updateItem({
      updateItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.EventTable;
        id = eventId;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = alfangoDB;
    });
    canistergeekLogger.logMessage("Event update response --->" # debug_show (item));

    switch (item) {
      case (#err(msg)) {
        #err("Failed to update event: " # Helper.textArrayToString(msg));
      };
      case (#ok(result)) {

        let userCanister = actor (userCanisterId) : CommonService.UserCanisterType;

        // Update creator's calendar
        var calendarId = await userCanister.getCalendarId();
        if (Text.size(calendarId) == 0) {
          calendarId := await userCanister.upsertCalendarData(calendarId, { name = payload.name; description = payload.description });
        };
        let eventMetadataId = await userCanister.getEventMetadataId(eventId, calendarId);
        let eventObject : ArgumentTypes.UpdateEventMetadataPayload = {
          event_id = result.id;
          name = ?payload.name;
          start_date = ?payload.start_date;
          end_date = ?payload.end_date;
          status = payload.status;
          calendar_id = ?calendarId;
          created_by = ?userPrincipal;
        };
        ignore await userCanister.updateEventMetaData(eventMetadataId, eventObject);

        // If dates changed, notify attendees to update their calendars
        if ((oldValues.start_date != payload.start_date) or (oldValues.end_date != payload.end_date)) {
          let attendeeIdResponse = getAttendeesIdsByActionArray(eventId, [#Joined, #Accepted], alfangoDB);

          switch (attendeeIdResponse) {
            case (#ok(attendeeIds)) {
              let indexCanister = actor (Constants.IndexCanister) : CommonService.IndexActor;
              let userCanisterData = await indexCanister.getUserCanistersByPrincipal(attendeeIds);

              let updateFutures = Buffer.Buffer<async Result.Result<Text, Text>>(userCanisterData.size());
              for (canisterData in userCanisterData.vals()) {
                let userCanisterActor = actor (canisterData.canister_id) : CommonService.UserCanisterType;
                let attendeeEventMetadataPayload : ArgumentTypes.AttendeeEventMetadataRequestPayload = {
                  event_id = eventId;
                  start_date = ?payload.start_date;
                  end_date = ?payload.end_date;
                  status = payload.status;
                  calendar_id = null;
                  name = null;
                  created_by = null;
                };
                updateFutures.add(userCanisterActor.updateEventMetadataForAttendee({ eventId; eventMetadataPayload = attendeeEventMetadataPayload }));
              };

              // Collect results (optional, can be fire-and-forget)
              for (future in updateFutures.vals()) {
                ignore await future;
              };
            };
            case (#err(error)) {
              canistergeekLogger.logMessage("Failed to get attendees for updating event metadata --> " # debug_show (error));
            };
          };
        };

        #ok(result.id);
      };

    };

  };

  private func updateAttendeeCalendarOnCancel(
    canisterData : ArgumentTypes.CanisterMapPayload,
    eventId : Text,
    eventData : ArgumentTypes.EventResponsePayload,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {
    let userId = canisterData.principal_id;
    let userCanisterId = canisterData.canister_id;
    let userCanister = actor (userCanisterId) : CommonService.UserCanisterType;

    let calendarId = await userCanister.getCalendarId();
    let eventMetadataId = await userCanister.getEventMetadataId(eventId, calendarId);

    let eventObject : ArgumentTypes.UpdateEventMetadataPayload = {
      event_id = eventId;
      name = ?eventData.name;
      start_date = ?eventData.start_date;
      end_date = ?eventData.end_date;
      calendar_id = ?calendarId;
      status = Constants.EventStatusVariant.Canceled;
      created_by = ?Principal.fromText(userId);
    };
    await userCanister.updateEventMetaData(eventMetadataId, eventObject);
  };

  public func cancelEvent(
    userPrincipal : Principal,
    eventId : Text,
    eventType : Text,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<[Text], Text> {

    let eventDataResult = eventDataById(eventId, alfangoDB);
    canistergeekLogger.logMessage("Event Data --->" # debug_show (eventDataResult));

    switch (eventDataResult) {
      case (#err(err)) { return #err(Helper.textArrayToString(err)) };
      case (#ok(eventData)) {
        // Mark event as Cancelled in the single source of truth
        ignore Database.updateItem({
          updateItemInput = {
            databaseName = Constants.KonectA;
            tableName = Constants.EventTable;
            id = eventId;
            attributeDataValues = [("status", #text(Constants.EventStatus.Canceled))];
          };
          alfangoDB;
        });

        // Build unique list of principals to notify (creator + attendees)
        let seen = HashMap.HashMap<Text, ()>(8, Text.equal, Text.hash);
        let userIdsBuf = Buffer.Buffer<Text>(8);
        func addUnique(id : Text) : () {
          if (seen.replace(id, ()) == null) { userIdsBuf.add(id) };
        };

        addUnique(Principal.toText(userPrincipal));

        var attendeeIdsForReturn : [Text] = [];
        if (eventType == Constants.EventType.Offer) {
          let attendeeIdsRes = getAllAttendeesIds(eventId, alfangoDB);
          switch (attendeeIdsRes) {
            case (#err(e)) { return #err(Helper.textArrayToString(e)) };
            case (#ok(attendees)) {
              let tmpAttBuf = Buffer.Buffer<Text>(attendees.size());
              for (att in attendees.vals()) {
                addUnique(att.invitee_user_id);
                tmpAttBuf.add(att.invitee_user_id);
                ignore AddAttendeeService.updateEventAttendee(
                  {
                    id = att.id;
                    event_id = eventId;
                    invitee_user_id = att.invitee_user_id;
                    action = att.action;
                    timestamp = Int.abs(Time.now());
                    event_status = Constants.EventStatus.Canceled;
                    metadata = att.metadata;
                  },
                  alfangoDB,
                  canistergeekLogger,
                );
              };
              attendeeIdsForReturn := Buffer.toArray(tmpAttBuf);
            };
          };
        };

        // Batch resolve canister IDs and dispatch calendar updates
        let userIdArray = Buffer.toArray(userIdsBuf);
        let indexActor = actor (Constants.IndexCanister) : CommonService.IndexActor;
        let userCanisterData = await indexActor.getUserCanistersByPrincipal(userIdArray);

        let futs = Buffer.Buffer<async Result.Result<Text, Text>>(userCanisterData.size());
        for (cData in userCanisterData.vals()) {
          futs.add(updateAttendeeCalendarOnCancel(cData, eventId, eventData, canistergeekLogger));
        };

        // Collect results
        for (f in futs.vals()) {
          ignore await f;
        };

        if (eventType == Constants.EventType.Offer) {
          #ok(attendeeIdsForReturn);
        } else {
          #ok([]);
        };
      };
    };
  };

  public func acceptApplication(
    creatorPrincipal : Principal,
    eventId : Text,
    acceptedUserId : Principal,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {

    // 1. Authorize the caller
    let eventDataResult = eventDataById(eventId, alfangoDB);
    switch (eventDataResult) {
      case (#err(e)) { return #err("Event not found: " # textArrayToString(e)) };
      case (#ok(event)) {
        if (Principal.fromText(event.user_id) != creatorPrincipal) {
          return #err("Unauthorized: Only the event creator can accept applications.");
        };
      };
    };

    // 2. Get all current applicants for the event
    let applicantsResult = getAttendeesIdsByAction(eventId, #Applied, alfangoDB);
    let applicantPrincipals = switch (applicantsResult) {
      case (#err(e)) {
        return #err("Could not fetch applicants: " # textArrayToString(e));
      };
      case (#ok(ids)) {
        if (ids.size() == 0) {
          return #err("No pending applications found for this event.");
        };
        ids;
      };
    };

    // 3. Loop through applicants and update their status atomically within this canister
    var foundApplicant = false;
    let updateFutures = Buffer.Buffer<async Result.Result<Text, Text>>(applicantPrincipals.size());

    for (applicantIdText in applicantPrincipals.vals()) {
      let applicantPrincipal = Principal.fromText(applicantIdText);
      let newAction = if (applicantPrincipal == acceptedUserId) {
        foundApplicant := true;
        #Accepted;
      } else {
        #Declined;
      };

      // Add the future to the buffer to be executed concurrently
      updateFutures.add(
        UpdateAttendeeService.updateEventAttendeeStatus(
          eventId,
          applicantPrincipal,
          #Applied, // currentAction
          newAction,
          alfangoDB,
        )
      );
    };

    if (not foundApplicant) {
      return #err("The specified applicant was not found in the pending applications list.");
    };

    // 4. Await all the concurrent updates
    var errors = Buffer.Buffer<Text>(0);
    for (future in updateFutures.vals()) {
      let result = await future;
      switch (result) {
        case (#err(e)) { errors.add(e) };
        case (#ok(_)) {};
      };
    };

    if (errors.size() > 0) {
      return #err("One or more applicant statuses failed to update: " # textArrayToString(errors.toArray()));
    };

    return #ok("Application processed successfully.");
  };

  public func declineApplication(
    creatorPrincipal : Principal,
    eventId : Text,
    declinedUserId : Principal,
    alfangoDB : Database.AlfangoDB,
    canistergeekLogger : Canistergeek.Logger,
  ) : async Result.Result<Text, Text> {
    // 1. Authorize the caller (ensure they are the event creator)
    let eventDataResult = eventDataById(eventId, alfangoDB);
    switch (eventDataResult) {
      case (#err(e)) { return #err("Event not found: " # textArrayToString(e)) };
      case (#ok(event)) {
        if (Principal.fromText(event.user_id) != creatorPrincipal) {
          return #err("Unauthorized: Only the event creator can decline applications.");
        };
      };
    };

    // 2. Directly call the status update service for the specific user
    canistergeekLogger.logMessage("Declining application for user " # Principal.toText(declinedUserId));

    let updateResult = await UpdateAttendeeService.updateEventAttendeeStatus(
      eventId,
      declinedUserId,
      #Applied, // The user's current status
      #Declined, // The new status
      alfangoDB,
    );

    // 3. Return the result
    switch (updateResult) {
      case (#ok(recordId)) {
        return #ok("Application from user " # Principal.toText(declinedUserId) # " has been declined.");
      };
      case (#err(e)) {
        return #err("Failed to decline application: " # e);
      };
    };
  };

  public func updateMultipleEvents(
    userPrincipal : Principal,
    userCanisterId : Text,
    updates : [ArgumentTypes.UpdateMultipleEventsPayload],
    alfangoDB : Database.AlfangoDB,
    d3 : D3.D3,
    canistergeekLogger : Canistergeek.Logger,
  ) : async ArgumentTypes.UpdateMultipleEventsResponse {

    // 1. Dispatch (Fan-Out): Start all async update calls concurrently.
    // We store the pending `async` calls (futures) in a buffer.
    let updateFutures = Buffer.Buffer<async Result.Result<Text, Text>>(updates.size());
    for (updateRequest in updates.vals()) {
      // Reuse the existing single update logic for each event.
      updateFutures.add(
        updateEvent(
          userPrincipal,
          userCanisterId,
          updateRequest.eventId,
          updateRequest.payload,
          alfangoDB,
          d3,
          canistergeekLogger,
        )
      );
    };

    // 2. Collect (Fan-In): Await all the results and categorize them.
    let successfulUpdates = Buffer.Buffer<Text>(updates.size());
    let failedUpdates = Buffer.Buffer<(Text, Text)>(0);

    for (i in updates.keys()) {
      let eventId = updates[i].eventId;
      let result = await updateFutures.get(i);
      switch (result) {
        case (#ok(updatedEventId)) {
          successfulUpdates.add(updatedEventId);
        };
        case (#err(errorMessage)) {
          failedUpdates.add((eventId, errorMessage));
        };
      };
    };

    // 3. Return a structured response with both successes and failures.
    return {
      successful = Buffer.toArray(successfulUpdates);
      failed = Buffer.toArray(failedUpdates);
    };
  };
};
