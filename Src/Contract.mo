import Prim "mo:prim";
import Candid "mo:candid";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Hash "ic:canister/hash";

// Define a message struct to store message details
type Message = {
  sender: Principal;
  recipient: Principal;
  content: Text;
  timestamp: Time;
};

// Define an account struct to store user account details
type Account = {
  principal: Principal;
  balance: Nat;
};

// Define the messaging platform canister
actor messagingPlatform {

  // Declare a mapping of recipient to messages
  var messages: [Principal, [Message]] = [];

  // Declare a mapping of user principal to their account
  var accounts: [Principal, Account] = [];

  /**
   * Creates a user account by linking the caller's wallet.
   * If the caller already has an account, no action is taken.
   * @returns () - Empty tuple.
   */
  public func createAccount(): async () {
    let callerPrincipal = caller;

    // Check if the caller already has an account
    if let _ = accounts[callerPrincipal] {
      // Account already exists, do nothing
      return ();
    }

    // Create a new account with a zero balance
    let newAccount: Account = {
      principal = callerPrincipal;
      balance = 0;
    };

    // Set the new account in the accounts mapping
    accounts[callerPrincipal] := newAccount;
  }

  /**
   * Sends a message to a recipient.
   * @param recipient - The principal of the message recipient.
   * @param content - The content of the message.
   * @returns () - Empty tuple.
   */
  public func sendMessage(recipient: Principal, content: Text): async () {
    let sender = caller;
    let timestamp = Prim.toTimestamp(Prim.now());

    // Create a new message object
    let newMessage: Message = {
      sender = sender;
      recipient = recipient;
      content = content;
      timestamp = timestamp;
    };

    // Append the message to the recipient's message list
    if let existingMessages = messages[recipient] {
      messages[recipient] := Array.append(existingMessages, [newMessage]);
    } else {
      messages[recipient] := [newMessage];
    }

    // Update the sender's account balance by adding an incentive
    let senderAccount = accounts[sender];
    if let account = senderAccount {
      accounts[sender] := { account with balance = account.balance + 1 };
    }
  }

  /**
   * Retrieves all messages for the caller.
   * @returns [Message] - List of messages for the caller.
   */
  public query func getMessages(): async [Message] {
    let callerPrincipal = caller;
    return messages[callerPrincipal] ?? [];
  }

  /**
   * Deletes all messages for the caller.
   * @returns () - Empty tuple.
   */
  public func deleteMessages(): async () {
    let callerPrincipal = caller;
    messages[callerPrincipal] := [];
  }

  /**
   * Deletes specific messages for the caller.
   * @param messageIndexes - The indexes of the messages to delete.
   * @returns () - Empty tuple.
   */
  public func deleteSpecificMessages(messageIndexes: [Nat]): async () {
    let callerPrincipal = caller;
    let existingMessages = messages[callerPrincipal] ?? [];

    // Filter and remove the specified messages
    let remainingMessages = Array.filter(
      existingMessages,
      (_, index) => !(Array.contains(messageIndexes, index))
    );

    messages[callerPrincipal] := remainingMessages;
  }

  /**
   * Searches for messages based on specified criteria.
   * @param criteria - The search criteria object.
   * @returns [Message] - List of messages matching the search criteria.
   */
  public query func searchMessages(criteria: { sender: ?Principal; recipient: ?Principal; content: ?Text }): async [Message] {
    let callerPrincipal = caller;
    let existingMessages = messages[callerPrincipal] ?? [];

    // Apply the search criteria
    let filteredMessages = Array.filter(existingMessages, message => {
      if (criteria.sender != null && criteria.sender != message.sender) {
        return false;
      }

      if (criteria.recipient != null && criteria.recipient != message.recipient) {
        return false;
      }

      if (criteria.content != null && !Text.contains(message.content, criteria.content)) {
        return false;
      }

      return true;
    });

    return filteredMessages;
  }

  /**
   * Transfers a specified amount of the caller's account balance to another user's account.
   * @param recipient - The principal of the recipient's account.
   * @param amount - The amount to transfer.
   * @returns () - Empty tuple.
   */
  public func transferBalance(recipient: Principal, amount: Nat): async () {
    let sender = caller;
    let senderAccount = accounts[sender];

    if let senderAccount = senderAccount {
      if (senderAccount.balance >= amount) {
        // Deduct the transferred amount from the sender's account balance
        accounts[sender] := { senderAccount with balance = senderAccount.balance - amount };

        // Add the transferred amount to the recipient's account balance
        let recipientAccount = accounts[recipient];

        if let recipientAccount = recipientAccount {
          accounts[recipient] := { recipientAccount with balance = recipientAccount.balance + amount };
        } else {
          let newAccount: Account = { principal = recipient; balance = amount };
          accounts[recipient] := newAccount;
        }
      }
    }
  }
}

// Generate a unique canister ID for the messagingPlatform
public func generateCanisterId(): Principal {
  let id = Hash.sha224(Principal.fromActor(messagingPlatform));
  return Principal.fromSha224(id);
}
