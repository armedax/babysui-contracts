module airdrop::core {
  use std::vector;
  use std::hash;
  
  use sui::object::{Self, UID};
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use sui::clock::{Self, Clock};
  use sui::vec_map::{Self, VecMap};
  use sui::bcs;

  use babysui::babysui::{BABYSUI};

  use movemate::merkle_proof;

  const THIRTY_DAYS_IN_MS: u64 = 2592000000;

  const ERROR_INVALID_PROOF: u64 = 0;
  const ERROR_ALL_CLAIMED: u64 = 1;
  const ERROR_NOT_STARTED: u64 = 2;
  const ERROR_NO_ROOT: u64 = 3;
  const ERROR_EXCEED_CLAIMABLE: u64 = 4;

  struct AirdropAdminCap has key {
    id: UID
  }

  struct Account has store {
    claimed: bool
  }

  struct AirdropStorage has key { 
    id: UID,
    balance: Balance<BABYSUI>,
    root: vector<u8>,
    start_time: u64,
    accounts: VecMap<address, Account>,
    amount_per_user: u64
  }

  fun init(ctx: &mut TxContext) {
    transfer::transfer(
      AirdropAdminCap {
        id: object::new(ctx)
      },
      tx_context::sender(ctx)
    );

    transfer::share_object(
      AirdropStorage {
        id: object::new(ctx),
        balance: balance::zero<BABYSUI>(),
        root: vector::empty(),
        start_time: 0,
        accounts: vec_map::empty(),
        amount_per_user: 0
      }
    );
  }

  public fun get_airdrop(
    storage: &mut AirdropStorage, 
    proof: vector<vector<u8>>, 
    amount: u64, 
    ctx: &mut TxContext
  ): Coin<BABYSUI> {
    assert!(storage.start_time != 0, ERROR_NOT_STARTED);
    assert!(storage.amount_per_user >= amount, ERROR_EXCEED_CLAIMABLE);
    assert!(!vector::is_empty(&storage.root), ERROR_NO_ROOT);

    let sender = tx_context::sender(ctx);
    let payload = bcs::to_bytes(&sender);

    vector::append(&mut payload, bcs::to_bytes(&amount));

    let leaf = hash::sha3_256(payload);
    assert!(merkle_proof::verify(&proof, storage.root, leaf), ERROR_INVALID_PROOF);

    let account = get_mut_account(storage, sender);
    assert!(!account.claimed, ERROR_ALL_CLAIMED);
    account.claimed = true;
    assert!(account.claimed, ERROR_ALL_CLAIMED);

    coin::take(&mut storage.balance, amount_to_send, ctx)
  }

  entry fun airdrop(
    storage: &mut AirdropStorage, 
    proof: vector<vector<u8>>, 
    amount: u64, 
    ctx: &mut TxContext
  ) {
    transfer::public_transfer(
      get_airdrop(
        storage,
        proof,
        amount,
        ctx
      ),
      tx_context::sender(ctx));
  }

  fun get_mut_account(storage: &mut AirdropStorage, sender: address): &mut Account {
    if (!vec_map::contains(&storage.accounts, &sender)) {
      vec_map::insert(&mut storage.accounts, sender, Account { claimed: false });
    };

    vec_map::get_mut(&mut storage.accounts, &sender)
  }

  entry public fun start(
    _: &AirdropAdminCap, 
    storage: &mut AirdropStorage, 
    root: vector<u8>, 
    coin_babysui: Coin<BABYSUI>, 
    start_time: u64, 
    amount_per_user: u64
  ) {
    storage.root = root;
    balance::join(&mut storage.balance, coin::into_balance(coin_babysui));
    storage.start_time = start_time;
    storage.amount_per_user = amount_per_user;
  }

  public fun has_claimed(storage: &AirdropStorage, user: address): bool {
    if (!vec_map::contains(&storage.accounts, &user)) return false;
    let account = vec_map::get(&storage.accounts, &user);
    account.claimed
  }

  public fun read_airdrop_storage(storage: &AirdropStorage): (u64, vector<u8>, u64, u64) {
    (balance::value(&storage.balance), storage.root, storage.start_time, storage.amount_per_user)
  }
}