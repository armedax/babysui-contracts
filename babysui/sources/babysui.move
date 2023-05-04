module babysui::babysui {
  use std::option;

  use sui::object::{Self, UID};
  use sui::tx_context::{TxContext};
  use sui::balance::{Self, Supply};
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::url;
  use sui::tx_context;

  const BABYSUI_TOTAL_SUPPLY: u64 = 600000000000000000;

  // Errors
  const ERROR_NO_ZERO_ADDRESS: u64 = 2;

  struct BABYSUI has drop {}

  struct BABYSUIStorage has key {
    id: UID,
    supply: Supply<BABYSUI>
  }

  fun init(witness: BABYSUI, ctx: &mut TxContext) {
      let (treasury, metadata) = coin::create_currency<BABYSUI>(
            witness, 
            9,
            b"BABYSUI",
            b"Babysui",
            b"The Biggest Meme Token on SUI Chain",
            option::some(url::new_unsafe_from_bytes(b"<Token logo goes here>")),
            ctx
        );

      let supply = coin::treasury_into_supply(treasury);

      transfer::public_transfer(
        coin::from_balance(
          balance::increase_supply(&mut supply, BABYSUI_TOTAL_SUPPLY), ctx
        ),
        tx_context::sender(ctx)
      );

      transfer::share_object(
        BABYSUIStorage {
          id: object::new(ctx),
          supply
        }
      );

      transfer::public_freeze_object(metadata);
  }

  /**
  * @dev A utility function to transfer BABYSUI to a {recipient}
  * @param c The Coin<BABYSUI> to transfer
  * @param recipient The recipient of the Coin<BABYSUI>
  */
  public entry fun transfer(c: Coin<BABYSUI>, recipient: address) {
    transfer::public_transfer(c, recipient);
  }

  /**
  * @dev It returns the total supply of the Coin<X>
  * @param storage The {BABYSUIStorage} shared object
  * @return the total supply in u64
  */
  public fun total_supply(storage: &BABYSUIStorage): u64 {
    balance::supply_value(&storage.supply)
  }


  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(BABYSUI {}, ctx);
  }
}