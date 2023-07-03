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
  var messages : [Principal, [Message]] = [];

  // Declare a mapping of user principal to their account
  var accounts : [Principal, Account] = [];

  // Function to create an account by linking the caller's wallet
  public func createAccount() : async () {
    let callerPrincipal = caller;
    
    // Check if the caller already has an account
    if let _ = accounts[callerPrincipal] {
      // Account already exists, do nothing
      return ();
    }
    
    // Create a new account with a zero balance
    let newAccount : Account = {
      principal = callerPrincipal;
      balance = 0;
    };
    
    // Set the new account in the accounts mapping
    accounts[callerPrincipal] := newAccount;
  }

  // Function to send a message to a recipient
  public func sendMessage(recipient: Principal, content: Text) : async () {
    let sender = caller;
    let timestamp = Prim.toTimestamp(Prim.now());
    
    // Create a new message object
    let newMessage : Message = {
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

  // Function to retrieve messages for the caller
  public query func getMessages() : async [Message] {
    let callerPrincipal = caller;
    return messages[callerPrincipal] ?? [];
  }

  // Function to delete messages for the caller
  public func deleteMessages() : async () {
    let callerPrincipal = caller;
    messages[callerPrincipal] := [];
  }
}

// Generate a unique canister ID for the messagingPlatform
public func generateCanisterId() : Principal {
  let id = Hash.sha224(Principal.fromActor(messagingPlatform));
  return Principal.fromSha224(id);
}
