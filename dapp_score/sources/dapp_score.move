module liquidlink_dapp_score::dapp_score {

  // Importing Modules

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use std::string::{String};
    use std::vector;
    use sui::transfer;
    use sui::event;
    use std::option::{Self, Option};
    use liquidlink_dapp_score::error::{
        not_authorized_error,
        // duplicated_user_dapp_score_object_error,
        duplicated_error,
        // not_exist_error,
        // updater_expired_error,
        // target_not_exist_error,
        // score_under_zero_error,
        // has_exist_error,
        // wrong_version_error,
    };

    const VERSION: u64 = 1;

  // Event Structs

    struct AddAdminEvent has copy, drop {
        new_admin: address,
        by: address,
    }

    struct RemoveAdminEvent has copy, drop {
        admin: address,
        by: address,
    }

    struct ChangeUpdaterEvent has copy, drop {
        new_updater: address,
        by: address,
    }

    struct CreateDappEvent has copy, drop {
        dapp_index: u64,
        name: String,
        data: String,
        image_url: String,
        by: address,
    }

    struct AddDappAdminEvent has copy, drop {
        dapp_index: u64,
        admin: address,
        by: address,
    }

    struct RemoveDappAdminEvent has copy, drop {
        dapp_index: u64,
        admin: address,
        by: address,
    }

    struct UpdateDappNameEvent has copy, drop {
        dapp_index: u64,
        old_name: String,
        name: String,
        by: address,
    }

    struct UpdateDappDataEvent has copy, drop {
        dapp_index: u64,
        old_data: String,
        data: String,
        by: address,
    }

    struct UpdateDappImageUrlEvent has copy, drop {
        dapp_index: u64,
        old_image_url: String,
        image_url: String,
        by: address,
    }

    struct UpdateUserOffchainScoreByUpdater has copy, drop {
        dapp_index: u64,
        user: address,
        old_score: u64,
        new_score: u64,
        score_change: u64,
        is_negative: bool,
        by: address,
    }

    struct IncreaseUserScoreByAdminEvent has copy, drop {
        dapp_index: u64,
        user: address,
        old_score: u64,
        new_score: u64,
        score_increase: u64,
        by: address,
    }

    struct DecreaseUserScoreByAdminEvent has copy, drop {
        dapp_index: u64,
        user: address,
        old_score: u64,
        new_score: u64,
        score_decrease: u64,
        by: address,
    }

    struct IncreaseScoreByAdminCapEvent has copy, drop {
        dapp_index: u64,
        user: address,
        old_score: u64,
        new_score: u64,
        score_increase: u64,
        by: address,
    }

    struct DecreaseScoreByAdminCapEvent has copy, drop {
        dapp_index: u64,
        user: address,
        old_score: u64,
        new_score: u64,
        score_decrease: u64,
        by: address,
    }

    struct UserDappScoreChangedEvent has copy, drop {
        user: address,
        dapp_index: u64,
        offchain_score: u64,
        addition_by_admin: u64,
        deduction_by_admin: u64,
        addition_by_admin_cap: u64,
        deduction_by_admin_cap: u64,
    }

    struct CreateDappScoreUpdateRequestEvent has copy, drop {
        id: ID,
        updater: address,
        dapp_index: u64,
        user: address,
        referrer: Option<address>,
        proof: vector<u8>,
    }

    struct DeleteDappScoreUpdateRequestEvent has copy, drop {
        id: ID,
        user: address,
        dapp_index: u64,
        by: address,
    }



  // Object Structs

    struct DappScoreManager has key, store {
        id: UID,
        admins: vector<address>,
        creator: address,
        dapps: Table<u64, Dapp>,
        users: Table<address, User>,
        next_dapp_index: u64,
        updater: address,
        version: u64,
    }

    struct Dapp has store {
        index: u64,
        name: String,
        admins: vector<address>,
        users: Table<address, DappUser>,
        data: String,
        image_url: String,
    }

    struct DappUser has store {
        offchain_score: u64,
        addition_by_admin_cap: u64,
        deduction_by_admin_cap: u64,
        addition_by_admin: u64,
        deduction_by_admin: u64,
        referrer: Option<address>,
    }

    struct User has store {
        dapp_indexes: vector<u64>,
        admin_dapp_indexes: vector<u64>,
    }

    struct DappAdminCap has store, drop {
        dapp_index: u64,
    }

  // Constructor

    fun init (ctx: &mut TxContext) {

        let dapp_score_manager = DappScoreManager {
            id: object::new(ctx),
            admins: vector::empty(),
            creator: tx_context::sender(ctx),
            dapps: table::new(ctx),
            users: table::new(ctx),
            next_dapp_index: 0,
            updater: @0xd71bceb881f839dd871b6d655ceec19a3332f6b30535ccd5a53bbb2c907f9003,
            version: VERSION,
        };

        internal_add_super_admin(
          &mut dapp_score_manager, 
          tx_context::sender(ctx), 
          ctx
        );

        transfer::share_object(dapp_score_manager);
    }

  // Admin Management

    fun check_is_super_admin(
        dapp_score_manager: &DappScoreManager, 
        ctx: &TxContext
    ) {
        assert!(
            vector::contains(&dapp_score_manager.admins, &tx_context::sender(ctx))
            || dapp_score_manager.creator == tx_context::sender(ctx),
            not_authorized_error()
        );
    }

    fun internal_add_super_admin(
        dapp_score_manager: &mut DappScoreManager, 
        new_admin: address, 
        ctx: &TxContext
    ) {
        check_is_super_admin(dapp_score_manager, ctx);
        vector::push_back(&mut dapp_score_manager.admins, new_admin);
        event::emit(AddAdminEvent {
            new_admin,
            by: tx_context::sender(ctx),
        });
    }

    fun internal_remove_super_admin(
        dapp_score_manager: &mut DappScoreManager, 
        admin: address, 
        ctx: &TxContext
    ) {
        check_is_super_admin(dapp_score_manager, ctx);
        let (_, idx) = vector::index_of(&dapp_score_manager.admins, &admin);
        vector::remove(&mut dapp_score_manager.admins, idx);
        assert!(
            vector::length(&dapp_score_manager.admins) > 0,
            not_authorized_error()
        );
        event::emit(RemoveAdminEvent {
            admin,
            by: tx_context::sender(ctx),
        });
    }

    public fun add_super_admin(
        dapp_score_manager: &mut DappScoreManager,
        new_admin: address,
        ctx: & TxContext
    ) {
        internal_add_super_admin(dapp_score_manager, new_admin, ctx);
    }

    public fun remove_super_admin(
        dapp_score_manager: &mut DappScoreManager,
        admin: address,
        ctx: & TxContext
    ) {
        internal_remove_super_admin(dapp_score_manager, admin, ctx);
    }
  
  // Updater mangement

    public fun check_is_updater(
        dapp_score_manager: &DappScoreManager, 
        ctx: &TxContext
    ) {
        assert!(
            dapp_score_manager.updater == tx_context::sender(ctx),
            not_authorized_error()
        );
    }

    public fun change_updater(
        dapp_score_manager: &mut DappScoreManager,
        new_updater: address,
        ctx: &TxContext
    ) {
        check_is_super_admin(dapp_score_manager, ctx);
        dapp_score_manager.updater = new_updater;
        event::emit(ChangeUpdaterEvent {
            new_updater,
            by: tx_context::sender(ctx),
        });
    }

  // Update user score

    fun internal_create_dapp_user_score_profile(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        user: address,
        referrer: Option<address>,
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        let dapp_user = DappUser {
            offchain_score: 0,
            addition_by_admin_cap: 0,
            deduction_by_admin_cap: 0,
            addition_by_admin: 0,
            deduction_by_admin: 0,
            referrer: referrer,
        };
        table::add(&mut dapp.users, user, dapp_user);

        if(table::contains(&dapp_score_manager.users, user)) {
            let user_obj = table::borrow_mut(&mut dapp_score_manager.users, user);
            vector::push_back(&mut user_obj.dapp_indexes, dapp.index);
        } else {
            let dapp_indexes = vector::empty();
            vector::push_back(&mut dapp_indexes, dapp.index);
            let user_obj = User {
                dapp_indexes,
                admin_dapp_indexes: vector::empty(),
            };
            table::add(&mut dapp_score_manager.users, user, user_obj);
        }
    }

    public fun update_user_offchain_score(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        user: address,
        referrer: Option<address>,
        new_score: u64,
        ctx: &TxContext
    ) {
        check_is_updater(dapp_score_manager, ctx);
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        if(!table::contains(&dapp.users, user)) {
            internal_create_dapp_user_score_profile(dapp_score_manager, dapp_index, user, referrer);
            dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        };
        let dapp_user = table::borrow_mut(&mut dapp.users, user);
        let score_change;
        let is_negative = false;
        if(new_score < dapp_user.offchain_score) {
            score_change = dapp_user.offchain_score - new_score;
            is_negative = true;
        } else {
            score_change = new_score - dapp_user.offchain_score;
        };
        let old_score = dapp_user.offchain_score;
        dapp_user.offchain_score = new_score;

        event::emit(UpdateUserOffchainScoreByUpdater{
            dapp_index,
            user,
            new_score,
            old_score,
            score_change,
            is_negative,
            by: tx_context::sender(ctx),
        });
        
        emit_user_dapp_score_change_event(user, dapp_index, dapp_user);
    }

  // Create Dapp
    
    public fun check_is_dapp_admin(
        dapp: &Dapp,
        ctx: &TxContext
    ) {
        assert!(
            vector::contains(&dapp.admins, &tx_context::sender(ctx)) ||
            vector::length(&dapp.admins) == 0,
            not_authorized_error()
        );
    }
    
    fun internal_add_dapp_admin(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        new_admin: address,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        check_is_dapp_admin(dapp, ctx);
        if(!table::contains(&dapp_score_manager.users, new_admin)) {
            let user = User {
                dapp_indexes: vector::empty(),
                admin_dapp_indexes: vector::empty(),
            };
            table::add(&mut dapp_score_manager.users, new_admin, user);
        };
        let user = table::borrow_mut(&mut dapp_score_manager.users, new_admin);
        assert!(
            !vector::contains(&dapp.admins, &new_admin),
            duplicated_error()
        );
        vector::push_back(&mut user.admin_dapp_indexes, dapp.index);
        vector::push_back(&mut dapp.admins, new_admin);
        event::emit(AddDappAdminEvent {
            dapp_index: dapp.index,
            admin: new_admin,
            by: tx_context::sender(ctx),
        });
    }

    fun internal_remove_dapp_admin(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        admin: address,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        let user = table::borrow_mut(&mut dapp_score_manager.users, admin);
        check_is_dapp_admin(dapp, ctx);
        let (dapp_admin_contain, dapp_admin_index) = vector::index_of(&dapp.admins, &admin);
        let (user_admin_contain, user_admin_index) = vector::index_of(&user.admin_dapp_indexes, &dapp.index);
        assert!(dapp_admin_contain && user_admin_contain, not_authorized_error());
        vector::remove(&mut dapp.admins, dapp_admin_index);
        assert!(
            vector::length(&dapp.admins) > 0,
            not_authorized_error()
        );
        vector::remove(&mut user.admin_dapp_indexes, user_admin_index);
        event::emit(RemoveDappAdminEvent {
            dapp_index: dapp.index,
            admin,
            by: tx_context::sender(ctx),
        });
    }

    public fun create_dapp(
        dapp_score_manager: &mut DappScoreManager,
        name: String,
        data: String,
        image_url: String,
        ctx: &mut TxContext
    ) {
        let dapp = Dapp {
            index: dapp_score_manager.next_dapp_index,
            name,
            admins: vector::empty(),
            users: table::new(ctx),
            data,
            image_url,
        };
        dapp_score_manager.next_dapp_index = dapp_score_manager.next_dapp_index + 1;
        
        event::emit(CreateDappEvent {
            dapp_index: dapp.index,
            name,
            data,
            image_url,
            by: tx_context::sender(ctx),
        });
        let dapp_index = dapp.index;
        table::add(&mut dapp_score_manager.dapps, dapp.index, dapp);
        
        internal_add_dapp_admin(dapp_score_manager, dapp_index, tx_context::sender(ctx), ctx);
    }

    public fun add_dapp_admin(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        new_admin: address,
        ctx: &TxContext
    ) {
        internal_add_dapp_admin(dapp_score_manager, dapp_index, new_admin, ctx);
    }

    public fun remove_dapp_admin(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        admin: address,
        ctx: &TxContext
    ) {
        internal_remove_dapp_admin(dapp_score_manager, dapp_index, admin, ctx);
    }

    public fun update_dapp_name(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        name: String,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        check_is_dapp_admin(dapp, ctx);
        event::emit(UpdateDappNameEvent {
            dapp_index,
            old_name: dapp.name,
            name,
            by: tx_context::sender(ctx),
        });
        dapp.name = name;
    }

    public fun update_dapp_data(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        data: String,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        check_is_dapp_admin(dapp, ctx);
        event::emit(UpdateDappDataEvent {
            dapp_index,
            old_data: dapp.data,
            data,
            by: tx_context::sender(ctx),
        });
        dapp.data = data;
    }

    public fun update_dapp_image_url(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        image_url: String,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        check_is_dapp_admin(dapp, ctx);
        event::emit(UpdateDappImageUrlEvent {
            dapp_index,
            old_image_url: dapp.image_url,
            image_url,
            by: tx_context::sender(ctx),
        });
        dapp.image_url = image_url;
    }

    public fun increase_user_score_by_admin(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        user: address,
        score_increase: u64,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        check_is_dapp_admin(dapp, ctx);
        if(!table::contains(&dapp.users, user)) {
            internal_create_dapp_user_score_profile(dapp_score_manager, dapp_index, user, option::none());
            dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        };
        let dapp_user = table::borrow_mut(&mut dapp.users, user);
        let old_score = dapp_user.addition_by_admin;
        dapp_user.addition_by_admin = dapp_user.addition_by_admin + score_increase;
        event::emit(IncreaseUserScoreByAdminEvent {
            dapp_index,
            user,
            old_score,
            new_score: dapp_user.addition_by_admin,
            score_increase,
            by: tx_context::sender(ctx),
        });
        emit_user_dapp_score_change_event(user, dapp_index, dapp_user);
    }

    public fun decrease_user_score_by_admin(
        dapp_score_manager: &mut DappScoreManager,
        dapp_index: u64,
        user: address,
        score_decrease: u64,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        check_is_dapp_admin(dapp, ctx);
        if(!table::contains(&dapp.users, user)) {
            internal_create_dapp_user_score_profile(dapp_score_manager, dapp_index, user, option::none());
            dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_index);
        };
        let dapp_user = table::borrow_mut(&mut dapp.users, user);
        let old_score = dapp_user.deduction_by_admin;
        dapp_user.deduction_by_admin = dapp_user.deduction_by_admin + score_decrease;
        event::emit(DecreaseUserScoreByAdminEvent {
            dapp_index,
            user,
            old_score,
            new_score: dapp_user.deduction_by_admin,
            score_decrease,
            by: tx_context::sender(ctx),
        });
        emit_user_dapp_score_change_event(user, dapp_index, dapp_user);
    }

  // smart contract addition and deduction score

    public fun get_admin_cap (
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
        ctx: &TxContext
    ): DappAdminCap {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        check_is_dapp_admin(dapp, ctx);

        let dapp_admin_cap = DappAdminCap {
            dapp_index,
        };
        return dapp_admin_cap
    }

    public fun increase_score_by_admin_cap(
        dapp_score_manager: &mut DappScoreManager,
        dapp_admin_cap: DappAdminCap,
        user: address,
        referrer: Option<address>,
        score_increase: u64,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_admin_cap.dapp_index);
        if(!table::contains(&dapp.users, user)) {
            internal_create_dapp_user_score_profile(dapp_score_manager, dapp_admin_cap.dapp_index, user, referrer);
            dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_admin_cap.dapp_index);
        };
        let dapp_user = table::borrow_mut(&mut dapp.users, user);
        let old_score = dapp_user.addition_by_admin_cap;
        dapp_user.addition_by_admin_cap = dapp_user.addition_by_admin_cap + score_increase;
        event::emit(IncreaseScoreByAdminCapEvent {
            dapp_index: dapp_admin_cap.dapp_index,
            user,
            old_score,
            new_score: dapp_user.addition_by_admin_cap,
            score_increase,
            by: tx_context::sender(ctx),
        });
        
        emit_user_dapp_score_change_event(user, dapp_admin_cap.dapp_index, dapp_user);
    }

    public fun decrease_score_by_admin_cap(
        dapp_score_manager: &mut DappScoreManager,
        dapp_admin_cap: DappAdminCap,
        user: address,
        referrer: Option<address>,
        score_decrease: u64,
        ctx: &TxContext
    ) {
        let dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_admin_cap.dapp_index);
        if(!table::contains(&dapp.users, user)) {
            internal_create_dapp_user_score_profile(dapp_score_manager, dapp_admin_cap.dapp_index, user, referrer);
            dapp = table::borrow_mut(&mut dapp_score_manager.dapps, dapp_admin_cap.dapp_index);
        };
        let dapp_user = table::borrow_mut(&mut dapp.users, user);
        let old_score = dapp_user.deduction_by_admin_cap;
        dapp_user.deduction_by_admin_cap = dapp_user.deduction_by_admin_cap + score_decrease;
        event::emit(DecreaseScoreByAdminCapEvent {
            dapp_index: dapp_admin_cap.dapp_index,
            user,
            old_score,
            new_score: dapp_user.deduction_by_admin_cap,
            score_decrease,
            by: tx_context::sender(ctx),
        });
        emit_user_dapp_score_change_event(user, dapp_admin_cap.dapp_index, dapp_user);
    }

    fun emit_user_dapp_score_change_event(
        user: address,
        dapp_index: u64,
        dapp_user: &DappUser,
    ) {
        event::emit(UserDappScoreChangedEvent {
            user,
            dapp_index,
            offchain_score: dapp_user.offchain_score,
            addition_by_admin: dapp_user.addition_by_admin,
            deduction_by_admin: dapp_user.deduction_by_admin,
            addition_by_admin_cap: dapp_user.addition_by_admin_cap,
            deduction_by_admin_cap: dapp_user.deduction_by_admin_cap,
        });
    }

  // Getter Functions

    public fun get_dapp_admins(
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
    ): vector<address> {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        return dapp.admins
    }

    public fun get_dapp_name(
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
    ): String {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        return dapp.name
    }

    public fun get_dapp_data(
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
    ): String {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        return dapp.data
    }

    public fun get_dapp_image_url(
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
    ): String {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        return dapp.image_url
    }

    public fun get_user_score(
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
        user: address,
    ): u64 {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        let dapp_user = table::borrow(&dapp.users, user);
        return internal_get_user_score(dapp_user)
    }

    fun internal_get_user_score(
        dapp_user: &DappUser,
    ): u64 {
        if(dapp_user.deduction_by_admin + dapp_user.deduction_by_admin_cap > dapp_user.offchain_score + dapp_user.addition_by_admin + dapp_user.addition_by_admin_cap) {
            return 0
        };
        return dapp_user.offchain_score
            + dapp_user.addition_by_admin
            + dapp_user.addition_by_admin_cap
            - dapp_user.deduction_by_admin
            - dapp_user.deduction_by_admin_cap
    }

    public fun get_user_score_detail(
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
        user: address,
    ): (u64, u64, u64, u64, u64) {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        let dapp_user = table::borrow(&dapp.users, user);
        return (
            dapp_user.offchain_score,
            dapp_user.addition_by_admin,
            dapp_user.addition_by_admin_cap,
            dapp_user.deduction_by_admin,
            dapp_user.deduction_by_admin_cap
        )
    }

    public fun get_user_referrer(
        dapp_score_manager: &DappScoreManager,
        dapp_index: u64,
        user: address,
    ): Option<address> {
        let dapp = table::borrow(&dapp_score_manager.dapps, dapp_index);
        let dapp_user = table::borrow(&dapp.users, user);
        return dapp_user.referrer
    }

    public fun get_user_dapps(
        dapp_score_manager: &DappScoreManager,
        user: address,
    ): vector<u64> {
        let user_obj = table::borrow(&dapp_score_manager.users, user);
        return user_obj.dapp_indexes
    }

  // Dapp Score Update Request

    struct DappScoreUpadteRequest has key, store {
        id: UID,
        user: address,
        referrer: Option<address>,
        dapp_index: u64,
        proof: vector<u8>, // proof is useless on chain but is needed to proof the score at off-chain oracle backend.
    }

    public fun create_dapp_score_update_request(
        updater: address,
        dapp_index: u64,
        referrer: Option<address>,
        proof: vector<u8>,
        ctx: &mut TxContext
    ) {
        let dapp_score_update_request = DappScoreUpadteRequest {
            id: object::new(ctx),
            user: tx_context::sender(ctx),
            referrer,
            dapp_index,
            proof,
        };
        event::emit(CreateDappScoreUpdateRequestEvent {
            id: object::uid_to_inner(&dapp_score_update_request.id),
            updater,
            dapp_index,
            user: dapp_score_update_request.user,
            referrer,
            proof,
        });
        transfer::transfer(dapp_score_update_request, updater);
    }

    public fun delete_dapp_score_update_request(
        dapp_score_manager: &DappScoreManager,
        dapp_score_update_request: DappScoreUpadteRequest,
        ctx: &TxContext
    ) {
        check_is_updater(dapp_score_manager, ctx);
        let DappScoreUpadteRequest{
            id,
            user,
            referrer: _,
            dapp_index,
            proof: _,
        } = dapp_score_update_request;
        event::emit(DeleteDappScoreUpdateRequestEvent {
            id: object::uid_to_inner(&id),
            user,
            dapp_index,
            by: tx_context::sender(ctx),
        });
        object::delete(id);
    }

  // Test
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}

