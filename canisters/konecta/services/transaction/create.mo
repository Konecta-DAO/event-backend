import Database "mo:alfangodb/AlfangoDB";
import Map "mo:map/Map";

import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import CommonService "../shared/common";

module {
  public func createTransaction(payload : ArgumentTypes.TransactionRequestPayload, alfangoDB : Database.AlfangoDB) : async Database.CreateItemOutputType {

    let transferType = CommonService.getTransferType(payload.transferred_to_type, Constants.TransferredToType.EventSubaccount);

    let attributeDataValues : [(Text, Database.AttributeDataValue)] = [
      ("event_id", #text(payload.event_id)),
      ("remitter_user_id", #text(payload.remitter_user_id)),
      ("transferred_to_type", #text(transferType)),
      ("beneficiary_user_id", #text(payload.beneficiary_user_id)),
      ("source_account_id_hex", #text(payload.source_account_id_hex)),
      ("destination_account_id_hex", #text(payload.destination_account_id_hex)),
      ("block_index", #nat(payload.block_index)),
      ("amount", #nat(payload.amount)),
      ("fee", #nat(payload.fee)),
      ("narration", #text(payload.narration)),
      ("created_at_time", #nat64(payload.created_at_time)),
    ];

    // Create a new transaction entry in the database
    let transactionResponse = await Database.createItem({
      createItemInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        attributeDataValues = attributeDataValues;
      };
      alfangoDB = alfangoDB;
    });

    return transactionResponse;
  };
};
