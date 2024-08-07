module liquidlink_transfer::transfer {

  // Importing Modules

    use sui::tx_context::{Self, TxContext};
    use std::string::{String};
    use sui::transfer;
    use sui::event;
    use sui::coin::{Self, Coin};

  // Event Structs

    struct TransferCoinEvent<phantom T> has copy, drop {
        sender: address,
        receiver: address,
        amount: u64,
        note: String,
    }

    struct TransferObjectEvent<phantom T: key + store> has copy, drop {
        sender: address,
        receiver: address,
        note: String,
    }

  // Public Functions
    
    public fun transfer_coin<T>(
        coin: Coin<T>,
        receiver: address,
        note: String,
        ctx: &mut TxContext,
    ) {
        let amount = coin::value(&coin);
        transfer::public_transfer(coin, receiver);
        event::emit( 
          TransferCoinEvent<T>{
            sender: tx_context::sender(ctx),
            receiver,
            amount,
            note,
          } 
        );
    }

    public fun transfer_object<T: key + store>(
        object: T,
        receiver: address,
        note: String,
        ctx: &mut TxContext,
    ) {
        transfer::public_transfer(object, receiver);
        event::emit(TransferObjectEvent<T>{
            sender: tx_context::sender(ctx),
            receiver,
            note,
        });
    }
}

