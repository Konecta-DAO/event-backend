import Database "mo:alfangodb/AlfangoDB";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Map "mo:map/Map";
import SearchTypes "mo:alfangodb/AlfangoDB/types/search";
import TransformService "../../services/shared/transform";
import ArgumentTypes "../../types/argumentTypes";
import Constants "../../utils/constants";
import HelperService "../../utils/helper";
import OutputTypes "mo:alfangodb/AlfangoDB/types/output";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";

module {

  public func getAllTransactionsForEventByType(eventId : Text, transferType : Text, alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.TransactionResponsePayload], Text> {
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
      #expression({
        attributeNames = "transferred_to_type";
        filterExpressionCondition = #EQ(#text(transferType));
      }),
    ]);

    let items = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = filter;
      };
      alfangoDB = alfangoDB;
    });

    switch (items) {
      case (#ok(_eventData)) {
        return TransformService.transformTransactionResponse(items);
      };
      case (#err(error)) #err(HelperService.textArrayToString(error));
    };
  };

  public func getTransactionsForEventByType(
    eventId : Text,
    transferType : Text,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<ArgumentTypes.PaginatedTransactionResponsePayload, Text> {

    let filterExpressions : [SearchTypes.FilterExpressionType] = [
      {
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      },
      {
        attributeNames = "transferred_to_type";
        filterExpressionCondition = #EQ(#text(transferType));
      },
    ];

    let queryFilters = Array.map<SearchTypes.FilterExpressionType, SearchTypes.QueryFilter>(
      filterExpressions,
      func(expr) { #expression(expr) },
    );
    let filter : SearchTypes.QueryFilter = #AND(queryFilters);

    // Only get total records on the first page load
    let totalRecords = if (cursor == null) {
      TransformService.getTotalRecords(
        Constants.TransactionTable,
        filterExpressions,
        alfangoDB,
      );
    } else {
      0; // Don't recalculate on subsequent pages
    };

    let items = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = filter;
        limit = limit;
        cursor = cursor;
      };
      alfangoDB = alfangoDB;
    });

    return TransformService.transformPaginatedTransactionResponse(totalRecords, items);
  };

  public func getAllTransactions(alfangoDB : Database.AlfangoDB) : Result.Result<[ArgumentTypes.TransactionResponsePayload], Text> {
    let transactionsResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = #AND([]);
      };
      alfangoDB = alfangoDB;
    });

    return TransformService.transformTransactionResponse(transactionsResponse);
  };

  public func getAllPaginatedTransactions(
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<ArgumentTypes.PaginatedTransactionResponsePayload, Text> {

    let filterExpressions : [SearchTypes.FilterExpressionType] = [];

    // Only get the total record count on the first page load
    let totalRecords = if (cursor == null) {
      TransformService.getTotalRecords(
        Constants.TransactionTable,
        filterExpressions,
        alfangoDB,
      );
    } else {
      0; // Don't recalculate on subsequent pages
    };

    // Use the scalable paginatedScan with the provided cursor
    let transactionsResponse = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = #AND([]);
        limit = limit;
        cursor = cursor;
      };
      alfangoDB = alfangoDB;
    });

    return TransformService.transformPaginatedTransactionResponse(totalRecords, transactionsResponse);
  };

  public func getTransactionsForUser(
    userPrincipal : Principal,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<ArgumentTypes.PaginatedTransactionResponsePayload, Text> {

    let filter : SearchTypes.QueryFilter = #OR([
      #expression({
        attributeNames = "remitter_user_id";
        filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
      }),
      #expression({
        attributeNames = "beneficiary_user_id";
        filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
      }),
    ]);

    // Only get the total record count on the first page load
    let totalRecords = if (cursor == null) {
      let filterExpressions : [SearchTypes.FilterExpressionType] = [
        {
          attributeNames = "remitter_user_id";
          filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
        },
      ];
      TransformService.getTotalRecords(
        Constants.TransactionTable,
        filterExpressions,
        alfangoDB,
      );
    } else {
      0; // Don't recalculate on subsequent pages
    };

    let items = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = filter;
        limit = limit;
        cursor = cursor;
      };
      alfangoDB = alfangoDB;
    });

    return TransformService.transformPaginatedTransactionResponse(totalRecords, items);
  };

  public func getTransactionsForUserByType(
    userPrincipal : Principal,
    transferType : Text,
    limit : Nat,
    cursor : ?SearchTypes.PaginatedScanCursor,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<ArgumentTypes.PaginatedTransactionResponsePayload, Text> {

    // A combined filter to find transactions of a specific type
    // where the user is EITHER the remitter OR the beneficiary.
    let filter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "transferred_to_type";
        filterExpressionCondition = #EQ(#text(transferType));
      }),
      #OR([
        #expression({
          attributeNames = "remitter_user_id";
          filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
        }),
        #expression({
          attributeNames = "beneficiary_user_id";
          filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
        }),
      ]),
    ]);

    // Only get the total record count on the first page load
    let totalRecords = if (cursor == null) {
      let filterExpressions : [SearchTypes.FilterExpressionType] = [
        {
          attributeNames = "transferred_to_type";
          filterExpressionCondition = #EQ(#text(transferType));
        },
        // This is a simplified filter for counting. The actual filter is more complex.
        {
          attributeNames = "remitter_user_id";
          filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
        },
      ];
      TransformService.getTotalRecords(
        Constants.TransactionTable,
        filterExpressions,
        alfangoDB,
      );
    } else {
      0; // Don't recalculate on subsequent pages
    };

    let items = Database.paginatedScan({
      paginatedScanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = filter;
        limit = limit;
        cursor = cursor; // Pass the cursor
      };
      alfangoDB = alfangoDB;
    });

    // We can now directly use the paginated response
    return TransformService.transformPaginatedTransactionResponse(totalRecords, items);
  };

  public func getTransactionsForUserForEvent(
    userPrincipal : Principal,
    eventId : Text,
    offset : Nat,
    limit : Nat,
    alfangoDB : Database.AlfangoDB,
  ) : Result.Result<ArgumentTypes.PaginatedTransactionResponsePayload, Text> {

    let transactionBuffer = Buffer.Buffer<OutputTypes.ItemOutputType>(0);
    let errorBuffer = Buffer.Buffer<Text>(0);

    // 1. Scan for transactions where the user is the REMITTER for the specific event
    let remitterFilter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "remitter_user_id";
        filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
      }),
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
    ]);

    let remitterTransactionsResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = remitterFilter;
      };
      alfangoDB = alfangoDB;
    });

    switch (remitterTransactionsResponse) {
      case (#ok(remitterTransactions)) {
        transactionBuffer.append(Buffer.fromArray(remitterTransactions));
      };
      case (#err(error)) {
        errorBuffer.add(HelperService.textArrayToString(error));
      };
    };

    // 2. Scan for transactions where the user is the BENEFICIARY for the specific event
    let beneficiaryFilter : SearchTypes.QueryFilter = #AND([
      #expression({
        attributeNames = "beneficiary_user_id";
        filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
      }),
      #expression({
        attributeNames = "event_id";
        filterExpressionCondition = #EQ(#text(eventId));
      }),
    ]);

    let beneficiaryTransactionsResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = beneficiaryFilter;
      };
      alfangoDB = alfangoDB;
    });

    switch (beneficiaryTransactionsResponse) {
      case (#ok(beneficiaryTransactions)) {
        transactionBuffer.append(Buffer.fromArray(beneficiaryTransactions));
      };
      case (#err(error)) {
        errorBuffer.add(HelperService.textArrayToString(error));
      };
    };

    // 3. Check for any errors during the scan operations
    if (errorBuffer.size() > 0) {
      return #err(HelperService.textArrayToString(Buffer.toArray(errorBuffer)));
    };

    // 4. Combine all results, then sort and paginate the combined list
    let allTransactions = Buffer.toArray(transactionBuffer);

    let compareTransactions = func(a : OutputTypes.ItemOutputType, b : OutputTypes.ItemOutputType) : Order.Order {
      let timeA = HelperService.textToNat(HelperService.getTupleValueAsText(a.item, "created_at_time"));
      let timeB = HelperService.textToNat(HelperService.getTupleValueAsText(b.item, "created_at_time"));
      // Sort descending (newest first)
      return Nat.compare(timeB, timeA);
    };

    let sortedTransactions = Array.sort<OutputTypes.ItemOutputType>(allTransactions, compareTransactions);

    let totalRecords = sortedTransactions.size();
    let end = Nat.min(offset + limit, totalRecords);

    let paginatedItems : [OutputTypes.ItemOutputType] = if (offset >= totalRecords) {
      [];
    } else {
      Iter.toArray(Array.slice(sortedTransactions, offset, end));
    };

    // Create a paginated result object to pass to the transformation function
    let paginatedResponse = {
      items = paginatedItems;
      limit = limit;
      hasMore = end < totalRecords;
      nextCursor = null;
    };

    // 5. Transform the final paginated list into the required response payload
    return TransformService.transformPaginatedTransactionResponse(totalRecords, #ok(paginatedResponse));
  };

  public func getRemitterTransactionsForUserForEvent(userPrincipal : Principal, eventId : Text, alfangoDB : Database.AlfangoDB) : Result.Result<ArgumentTypes.TransactionResponsePayload, Text> {
    let remitterTransactionsResponse = Database.scan({
      scanInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        filter = #AND([
          #expression({
            attributeNames = "remitter_user_id";
            filterExpressionCondition = #EQ(#text(Principal.toText(userPrincipal)));
          }),
          #expression({
            attributeNames = "event_id";
            filterExpressionCondition = #EQ(#text(eventId));
          }),
        ]);
      };
      alfangoDB = alfangoDB;
    });

    let remitterTransactions = TransformService.transformTransactionResponse(remitterTransactionsResponse);
    switch (remitterTransactions) {
      case (#ok(remitterTransactions)) {
        if (remitterTransactions.size() == 0) {
          return #err("Transaction not found");
        };
        return #ok(remitterTransactions[0]);
      };
      case (#err(error)) {
        return #err(error);
      };
    };
  };

  public func getTransactionById(transactionId : Text, alfangoDB : Database.AlfangoDB) : Result.Result<ArgumentTypes.TransactionResponsePayload, Text> {
    let transactionResponse = Database.getItemById({
      getItemByIdInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
        id = transactionId;
      };
      alfangoDB = alfangoDB;
    });

    return TransformService.transformGetTransactionResponse(transactionResponse);
  };

  public func transactionTableMetadata(alfangoDB : Database.AlfangoDB) : Database.GetTableMetadataOutputType {
    Database.getTableMetadata({
      getTableMetadataInput = {
        databaseName = Constants.KonectA;
        tableName = Constants.TransactionTable;
      };
      alfangoDB = alfangoDB;
    });
  };
};
