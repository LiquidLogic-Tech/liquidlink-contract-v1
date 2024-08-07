module liquidlink_dapp_score::dapp_score {

  // Importing Modules

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use sui::table_vec::{Self, TableVec};
    use std::string::{Self, String};
    use std::vector;
    use sui::transfer;
    use std::option::{Self, Option};
    use sui::event;
    use liquidlink_dapp_score::error::{
        not_authorized_error,
        duplicated_user_dapp_score_object_error,
        duplicated_error,
        not_exist_error,
        updater_expired_error,
        target_not_exist_error,
        score_under_zero_error,
        has_exist_error,
        wrong_version_error,
    };

    const REFERRAL_KEY: vector<u8> = b"referral";
    const PURE_INCREASE_KEY: vector<u8> = b"pure_increase";
    const PURE_DECREASE_KEY: vector<u8> = b"pure_decrease";
    const VERSION: u64 = 1;

  // Event Structs

    struct AddSuperAdminEvent has copy, drop {
        new_admin: address,
        by: address,
    }

    struct RemoveSuperAdminEvent has copy, drop {
        admin: address,
        by: address,
    }

    struct AddUpdaterEvent has copy, drop {
        object_id: ID,
        updater: address,
        by: address,
    }

    struct RemoveUpdaterEvent has copy, drop {
        object_id: ID,
        updater: address,
        by: address,
    }

    struct CreateDappConfigEvent has copy, drop {
        dapp: String,
        object_id: ID,
        display_name: String,
        data: String,
        image_url: String,
        by: address,
    }

    struct AddDappAdminEvent has copy, drop {
        dapp: String,
        admin: address,
        by: address,
    }

    struct RemoveDappAdminEvent has copy, drop {
        dapp: String,
        admin: address,
        by: address,
    }

    struct UpdateDappDisplayNameEvent has copy, drop {
        dapp: String,
        display_name: String,
        by: address,
    }

    struct UpdateDappDataEvent has copy, drop {
        dapp: String,
        data: String,
        by: address,
    }

    struct UpdateDappImageUrlEvent has copy, drop {
        dapp: String,
        image_url: String,
        by: address,
    }

    struct AddDappScoreTargetEvent has copy, drop {
        dapp: String,
        target: String,
        weight: u256,
        weight_is_negative: bool,
        weight_is_immutable: bool,
        data: String,
        by: address,
    }

    struct EditTargetWeightEvent has copy, drop {
        dapp: String,
        target: String,
        weight: u256,
        by: address,
    }

    struct EditTargetDataEvent has copy, drop {
        dapp: String,
        target: String,
        data: String,
        by: address,
    }

    struct EditTargetSignEvent has copy, drop {
        dapp: String,
        target: String,
        weight_is_negative: bool,
        by: address,
    }

    struct MakeTargetWeightImmutableEvent has copy, drop {
        dapp: String,
        target: String,
        by: address,
    }

    struct NewDappScoreObjectEvent has copy, drop {
        object_id: ID,
        user: address,
        dapp: String,
        referrer: Option<address>,
    }

    struct UpdateDappScoreObjectEvent has copy, drop {
        user: address,
        dapp: String,
        target: String,
        new_score: u256,
        score_change: u256,
        is_decrease: bool,
        is_by_admin: bool,
        is_by_admin_cap: bool,
    }

    struct UpdateRequestCreatedEvent has copy, drop {
        dapp_score_update_request_object_id: ID,
        user: address,
        dapp: String,
        referrer: Option<address>,
        updater: address,
    }

    struct UpdateRequestDeletedEvent has copy, drop {
        dapp_score_update_request_object_id: ID,
        user: address,
        dapp: String,
        updater: address,
    }

    struct UserReferralEvent has copy, drop {
        user: address,
        dapp: String,
        referrer: address,
    }

  // Object Structs
    
    struct DappScoreManager has key, store {
        id: UID,
        admins: vector<address>,
        creator: address,
        dapp_config_map: Table<String, ID>,
        updater_configs: vector<ID>,
        user_dapp_score_object_map: Table<address, DappScoreObjectMapWrapper>,
        dapp_user_score_object_map: Table<String, UserScoreObjectMapWrapper>,
        admin_dapp_map: Table<address, AdminDappMapWrapper>,
        version: u64,
    }

    struct AdminDappMapWrapper has store {
        dapps: vector<String>,
    }

    struct DappScoreObjectMapWrapper has store {
        dapp_score_objects_map: Table<String, ID>,
    }
    struct UserScoreObjectMapWrapper has store {
        user_score_objects_map: Table<address, ID>,
    }

    struct UpdaterConfig has key, store {
        id: UID,
        updater: address,
        valid: bool,
    }

    struct ScoreTableItem has store {
        score: u256,
    }

    struct TargetConfig has store {
        weight: u256,
        weight_is_negative: bool,
        weight_is_immutable: bool,
        data: String,
    }

    struct UserDappScore has key, store {
        id: UID,
        index: u64,
        user: address,
        dapp: String,
        score_table: Table<String, ScoreTableItem>,
        referrer: Option<address>,
    }

    struct DappConfig has key, store {
        id: UID,
        dapp: String,
        targets: TableVec<String>,
        targets_config: Table<String, TargetConfig>,
        display_name: String,
        data: String,
        image_url: String,
        admins: vector<address>,
    }

    struct DappScoreUpadteRequest has key, store {
        id: UID,
        user: address,
        referrer: Option<address>,
        dapp: String,
        proof: vector<u8>, // proof is useless on chain but is needed to proof the score at off-chain oracle backend.
    }

    struct DappAdminCap has store, drop {
        dapp: String,
        dappConfigId: ID,
    }

  // Constructor
    fun init (ctx: &mut TxContext) {
        let admins = vector::empty();
        vector::push_back(&mut admins, tx_context::sender(ctx));

        let dapp_score_manager = DappScoreManager{
            id: object::new(ctx),
            dapp_config_map: table::new(ctx),
            admins,
            creator: tx_context::sender(ctx),
            updater_configs: vector::empty(),
            user_dapp_score_object_map: table::new(ctx),
            dapp_user_score_object_map: table::new(ctx),
            admin_dapp_map: table::new(ctx),
            version: VERSION,
        };

        transfer::share_object(dapp_score_manager);
    }

  // Internal Functions

    fun internal_update_user_dapp_score_object (
        user_dapp_score: &mut UserDappScore,
        dapp: String,
        target: String,
        score_change: u256,
        is_decrease: bool,
        is_by_admin: bool,
        is_by_admin_cap: bool
    ) {
        assert!(
            user_dapp_score.dapp == dapp,
            not_authorized_error()
        );
        
        let new_score;
        if(!table::contains(&user_dapp_score.score_table, target)){
            assert!(!is_decrease, target_not_exist_error());
            table::add(&mut user_dapp_score.score_table, target, ScoreTableItem{ score: score_change });
            new_score = score_change;
        } else{
            let current_score = table::borrow_mut(&mut user_dapp_score.score_table, target);
            if(is_decrease){
                assert!(
                    current_score.score >= score_change,
                    score_under_zero_error()
                );
                new_score = current_score.score - score_change;
            } else {
                new_score = current_score.score + score_change;   
            };
            current_score.score = new_score;
        };
        event::emit(UpdateDappScoreObjectEvent {
            user: user_dapp_score.user,
            dapp: user_dapp_score.dapp,
            target,
            new_score,
            score_change,
            is_decrease,
            is_by_admin,
            is_by_admin_cap,
        });
    }

    fun check_dapp_score_manager_version (
        dapp_score_manager: & DappScoreManager,
    ) {
        assert!(
            dapp_score_manager.version == VERSION,
            wrong_version_error()
        );
    }

    fun internal_add_admin_dapp_map (
        dapp_score_manager: &mut DappScoreManager,
        admin: address,
        dapp: String,
    ) {
        if(table::contains(&dapp_score_manager.admin_dapp_map, admin)){
            let admin_dapp_map = table::borrow_mut(&mut dapp_score_manager.admin_dapp_map, admin);
            assert!(
                !vector::contains(&admin_dapp_map.dapps, &dapp),
                duplicated_error()
            );
            vector::push_back(&mut admin_dapp_map.dapps, dapp);
        } else {
            let dapps = vector::empty();
            vector::push_back(&mut dapps, dapp);
            let admin_dapp_map = AdminDappMapWrapper{ dapps };
            table::add(&mut dapp_score_manager.admin_dapp_map, admin, admin_dapp_map);
        };
    }

    fun internal_remove_admin_dapp_map (
        dapp_score_manager: &mut DappScoreManager,
        admin: address,
        dapp: String,
    ) {
        let admin_dapp_map = table::borrow_mut(&mut dapp_score_manager.admin_dapp_map, admin);
        let (dapp_exist, index) = vector::index_of(&admin_dapp_map.dapps, &dapp);
        assert!(
            dapp_exist,
            not_exist_error()
        );
        vector::swap_remove(&mut admin_dapp_map.dapps, index);
    }


    fun internal_add_dapp_score_target(
        dapp_config: &mut DappConfig,
        target: String,
        weight: u256,
        data: String,
        weight_is_negative: bool,
        weight_is_immutable: bool,
        ctx: &TxContext
    ) {
        table_vec::push_back(&mut dapp_config.targets, target);
        
        let targetConfig = TargetConfig{
            weight,
            data,
            weight_is_negative,
            weight_is_immutable,
        };
        table::add(&mut dapp_config.targets_config, target, targetConfig);

        event::emit(AddDappScoreTargetEvent{
            dapp: dapp_config.dapp,
            target,
            weight,
            weight_is_negative,
            weight_is_immutable,
            data,
            by: tx_context::sender(ctx),
        });
    }

    fun internal_create_dapp_config (
        dapp_score_manager: &mut DappScoreManager,
        dapp: String,
        display_name: String,
        data: String,
        image_url: String,
        ctx: &mut TxContext
    ): DappConfig {
        check_dapp_score_manager_version(dapp_score_manager);
        let admins = vector::empty();
        vector::push_back(&mut admins, tx_context::sender(ctx));
        internal_add_admin_dapp_map(dapp_score_manager, tx_context::sender(ctx), dapp);

        let dapp_config = DappConfig{
            id: object::new(ctx),
            dapp: dapp,
            targets: table_vec::empty(ctx),
            targets_config: table::new(ctx),
            display_name: display_name,
            data: data,
            image_url:  image_url,
            admins,
        };

        // init basic targets
        internal_add_dapp_score_target(&mut dapp_config, string::utf8(REFERRAL_KEY), 0, string::utf8(b""), false, false, ctx);
        internal_add_dapp_score_target(&mut dapp_config, string::utf8(PURE_INCREASE_KEY), 1, string::utf8(b""), false, true, ctx);
        internal_add_dapp_score_target(&mut dapp_config, string::utf8(PURE_DECREASE_KEY), 1, string::utf8(b""), true, true, ctx);

        assert!(
            !table::contains(&dapp_score_manager.dapp_config_map, dapp),
            duplicated_error()
        );
        table::add(&mut dapp_score_manager.dapp_config_map, dapp, object::id(&dapp_config));

        event::emit(CreateDappConfigEvent{
            dapp,
            object_id: object::id(&dapp_config),
            display_name,
            data,
            image_url,
            by: tx_context::sender(ctx),
        });

        event::emit(AddDappAdminEvent{
            dapp,
            admin: tx_context::sender(ctx),
            by: tx_context::sender(ctx),
        });

        dapp_config
    }

    fun internal_create_user_dapp_score_object (
        dapp_score_manager: &mut DappScoreManager,
        user: address,
        dapp: String,
        referrer: Option<address>,
        ctx: &mut TxContext
    ): UserDappScore {
        check_dapp_score_manager_version(dapp_score_manager);
        assert!(
            !is_user_dapp_score_object_exist(dapp_score_manager, user, dapp),
            duplicated_user_dapp_score_object_error()
        );

        let user_dapp_score = UserDappScore {
            id: object::new(ctx),
            index: table::length(&dapp_score_manager.user_dapp_score_object_map),
            user,
            dapp,
            score_table: table::new(ctx),
            referrer,
        };
        event::emit(NewDappScoreObjectEvent{
            object_id: object::id(&user_dapp_score),
            user: user_dapp_score.user,
            dapp: user_dapp_score.dapp,
            referrer: user_dapp_score.referrer,
        });
        
        if(!table::contains(&dapp_score_manager.user_dapp_score_object_map, user)){
            let dapp_score_objects_map = table::new(ctx);
            table::add(&mut dapp_score_objects_map, dapp, object::id(&user_dapp_score));

            let dapp_score_object_map_wrapper = DappScoreObjectMapWrapper{ dapp_score_objects_map };
            table::add(&mut dapp_score_manager.user_dapp_score_object_map, user, dapp_score_object_map_wrapper);
        } else {
            let dapp_score_object_map_wrapper = table::borrow_mut(&mut dapp_score_manager.user_dapp_score_object_map, user);
            table::add(&mut dapp_score_object_map_wrapper.dapp_score_objects_map, dapp, object::id(&user_dapp_score));
        };

        if(!table::contains(&dapp_score_manager.dapp_user_score_object_map, dapp)){
            let user_score_objects_map = table::new(ctx);
            table::add(&mut user_score_objects_map, user, object::id(&user_dapp_score));

            let user_score_object_map_wrapper = UserScoreObjectMapWrapper{ user_score_objects_map };
            table::add(&mut dapp_score_manager.dapp_user_score_object_map, dapp, user_score_object_map_wrapper);
        } else {
            let user_score_object_map_wrapper = table::borrow_mut(&mut dapp_score_manager.dapp_user_score_object_map, dapp);
            table::add(&mut user_score_object_map_wrapper.user_score_objects_map, user, object::id(&user_dapp_score));
        };

        user_dapp_score
    }

    fun add_referral_score(
        user: address,
        referrer_dapp_score: &mut UserDappScore,
        dapp: String,
    ){
        let referral_key = string::utf8(REFERRAL_KEY);
        internal_update_user_dapp_score_object(referrer_dapp_score, dapp, referral_key, 1, false, false, false);
        event::emit(UserReferralEvent{
            user,
            dapp,
            referrer: referrer_dapp_score.user,
        });
    }

    fun internal_create_dapp_score_update_request (
        updater_config: & UpdaterConfig,
        user: address,
        dapp: String,
        referrer: Option<address>,
        proof: vector<u8>,
        ctx: &mut TxContext
    ) {
        let dapp_score_update_request = DappScoreUpadteRequest {
            id: object::new(ctx),
            user,
            referrer,
            dapp,
            proof,
        };
        let dapp_score_update_request_object_id = object::id(&dapp_score_update_request);
        transfer::public_transfer(dapp_score_update_request, updater_config.updater);

        event::emit(UpdateRequestCreatedEvent{
            dapp_score_update_request_object_id,
            user,
            dapp,
            referrer,
            updater: updater_config.updater,
        });
    }

  // Super Admin Management

    public fun add_super_admin (
        dapp_score_manager: &mut DappScoreManager,
        new_admin: address,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_super_admin(dapp_score_manager, tx_context::sender(ctx));
        assert!(
            !vector::contains(&dapp_score_manager.admins, &new_admin),
            duplicated_error()
        );
        vector::push_back(&mut dapp_score_manager.admins, new_admin);
        event::emit(AddSuperAdminEvent{
            new_admin,
            by: tx_context::sender(ctx),
        });
    }

    public fun remove_super_admin (
        dapp_score_manager: &mut DappScoreManager,
        admin: address,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_super_admin(dapp_score_manager, tx_context::sender(ctx));
        let (admin_exist, index) = vector::index_of(&dapp_score_manager.admins, &admin);
        assert!(
            admin_exist && 
            vector::length(&dapp_score_manager.admins) > 1,
            not_authorized_error()
        );
        vector::swap_remove(&mut dapp_score_manager.admins, index);
        event::emit(RemoveSuperAdminEvent{
            admin,
            by: tx_context::sender(ctx),
        });
    }

    public fun add_updater (
        dapp_score_manager: &mut DappScoreManager,
        updater: address,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_super_admin(dapp_score_manager, tx_context::sender(ctx));
        let updater_config = UpdaterConfig{
            id: object::new(ctx),
            updater,
            valid: true,
        };
        vector::push_back(&mut dapp_score_manager.updater_configs, object::id(&updater_config));
        event::emit(AddUpdaterEvent{
            object_id: object::id(&updater_config),
            updater,
            by: tx_context::sender(ctx),
        });
        transfer::public_share_object(updater_config);
    }

    public fun change_updater (
        dapp_score_manager: & DappScoreManager,
        updater_config: &mut UpdaterConfig,
        new_updater: address,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_super_admin(dapp_score_manager, tx_context::sender(ctx));
        let original_updater = updater_config.updater;
        
        updater_config.updater = new_updater;
        event::emit(RemoveUpdaterEvent{
            object_id: object::id(updater_config),
            updater: original_updater,
            by: tx_context::sender(ctx),
        });
        event::emit(AddUpdaterEvent{
            object_id: object::id(updater_config),
            updater: new_updater,
            by: tx_context::sender(ctx),
        });
    }

    public fun remove_updater(
        dapp_score_manager: &mut DappScoreManager,
        updater_config: &mut UpdaterConfig,
        ctx: &mut TxContext
    ){
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_super_admin(dapp_score_manager, tx_context::sender(ctx));
        let (exist, index) = vector::index_of(&dapp_score_manager.updater_configs, &object::id(updater_config));
        assert!(exist, not_exist_error());
        vector::swap_remove(&mut dapp_score_manager.updater_configs, index);
        updater_config.valid = false;
        event::emit(RemoveUpdaterEvent{
            object_id: object::id(updater_config),
            updater: updater_config.updater,
            by: tx_context::sender(ctx),
        });
    }

  // Dapp Admin Management

    #[allow(lint(share_owned))]
    public fun create_dapp_config (
        dapp_score_manager: &mut DappScoreManager,
        dapp: String,
        display_name: String,
        data: String,
        image_url: String,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        let dapp_config = internal_create_dapp_config(dapp_score_manager, dapp, display_name, data, image_url, ctx);
        transfer::public_share_object(dapp_config);
    }

    public fun add_dapp_admin (
        dapp_score_manager: &mut DappScoreManager,
        dapp_config: &mut DappConfig,
        new_admin: address,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert!(
            !vector::contains(&dapp_config.admins, &new_admin),
            duplicated_error()
        );
        vector::push_back(&mut dapp_config.admins, new_admin);
        internal_add_admin_dapp_map(dapp_score_manager, new_admin, dapp_config.dapp);
        event::emit(AddDappAdminEvent{
            dapp: dapp_config.dapp,
            admin: new_admin,
            by: tx_context::sender(ctx),
        });
    }

    public fun remove_dapp_admin (
        dapp_score_manager: &mut DappScoreManager,
        dapp_config: &mut DappConfig,
        admin: address,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        let (admin_exist, index) = vector::index_of(&dapp_config.admins, &admin);
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert!(
            vector::length(&dapp_config.admins) > 1 &&
            admin_exist,
            not_authorized_error()
        );
        vector::swap_remove(&mut dapp_config.admins, index);
        internal_remove_admin_dapp_map(dapp_score_manager, admin, dapp_config.dapp);
        event::emit(RemoveDappAdminEvent{
            dapp: dapp_config.dapp,
            admin,
            by: tx_context::sender(ctx),
        });
    }

    public fun update_dapp_display_name(
        dapp_config: &mut DappConfig,
        display_name: String,
        ctx: &mut TxContext
    ) {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        dapp_config.display_name = display_name;
        event::emit(UpdateDappDisplayNameEvent{
            dapp: dapp_config.dapp,
            display_name,
            by: tx_context::sender(ctx),
        });
    }

    public fun update_dapp_data(
        dapp_config: &mut DappConfig,
        data: String,
        ctx: &mut TxContext
    ) {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        dapp_config.data = data;
        event::emit(UpdateDappDataEvent{
            dapp: dapp_config.dapp,
            data,
            by: tx_context::sender(ctx),
        });
    }

    public fun update_dapp_image_url(
        dapp_config: &mut DappConfig,
        image_url: String,
        ctx: &mut TxContext
    ) {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        dapp_config.image_url = image_url;
        event::emit(UpdateDappImageUrlEvent{
            dapp: dapp_config.dapp,
            image_url,
            by: tx_context::sender(ctx),
        });
    }

    public fun add_dapp_score_target(
        dapp_config: &mut DappConfig,
        target: String,
        weight: u256,
        data: String,
        weight_is_negative: bool,
        weight_is_immutable: bool,
        ctx: &mut TxContext
    ) {
        assert_target_name_is_not_reserved(&target);
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert_target_not_exist(dapp_config, target);
        
        internal_add_dapp_score_target(dapp_config, target, weight, data, weight_is_negative, weight_is_immutable, ctx);

        let referral_target = string::utf8(b"referral__");
        string::append(&mut referral_target, target);
        internal_add_dapp_score_target(dapp_config, referral_target, 0, string::utf8(b""), false, false, ctx);
    }

    fun weight_is_immutable(
        dapp_config: & DappConfig,
        target: String,
    ): bool {
        let targetConfig = table::borrow(&dapp_config.targets_config, target);
        targetConfig.weight_is_immutable
    }

    fun assert_weight_is_not_immutable(
        dapp_config: & DappConfig,
        target: String,
    ){
        assert!(
            !weight_is_immutable(dapp_config, target),
            not_authorized_error()
        );
    }
    
    public fun edit_dapp_score_target_weight(
        dapp_config: &mut DappConfig,
        target: String,
        weight: u256,
        ctx: &mut TxContext
    ) {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert_target_exist(dapp_config, target);
        assert_weight_is_not_immutable(dapp_config, target);
        let targetConfig = table::borrow_mut(&mut dapp_config.targets_config, target);
        targetConfig.weight = weight;

        event::emit(EditTargetWeightEvent{
            dapp: dapp_config.dapp,
            target,
            weight,
            by: tx_context::sender(ctx),
        });
    }

    public fun edit_dapp_score_target_data(
        dapp_config: &mut DappConfig,
        target: String,
        data: String,
        ctx: &mut TxContext
    ) {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert_target_exist(dapp_config, target);
        let targetConfig = table::borrow_mut(&mut dapp_config.targets_config, target);
        targetConfig.data = data;
        event::emit(EditTargetDataEvent{
            dapp: dapp_config.dapp,
            target,
            data,
            by: tx_context::sender(ctx),
        });
    }

    public fun edit_dapp_score_target_sign(
        dapp_config: &mut DappConfig,
        target: String,
        weight_is_negative: bool,
        ctx: &mut TxContext
    ) {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert_target_exist(dapp_config, target);
        assert_weight_is_not_immutable(dapp_config, target);
        let targetConfig = table::borrow_mut(&mut dapp_config.targets_config, target);
        targetConfig.weight_is_negative = weight_is_negative;

        event::emit(EditTargetSignEvent{
            dapp: dapp_config.dapp,
            target,
            weight_is_negative,
            by: tx_context::sender(ctx),
        });
    }

    public fun make_weight_immutable(
        dapp_config: &mut DappConfig,
        target: String,
        ctx: &mut TxContext
    ){
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert_target_exist(dapp_config, target);
        let targetConfig = table::borrow_mut(&mut dapp_config.targets_config, target);
        targetConfig.weight_is_immutable = true;
        event::emit(MakeTargetWeightImmutableEvent{
            dapp: dapp_config.dapp,
            target,
            by: tx_context::sender(ctx),
        });
    }

  // Dapp Admin Cap to update score by smart contract

    #[allow(lint(share_owned))]
    public fun create_dapp_config_and_get_admin_cap (
        dapp_score_manager: &mut DappScoreManager,
        dapp: String,
        display_name: String,
        data: String,
        image_url: String,
        ctx: &mut TxContext
    ): DappAdminCap {
        // check_dapp_score_manager_version(dapp_score_manager);
        let dapp_config = internal_create_dapp_config(dapp_score_manager, dapp, display_name, data, image_url, ctx);
        let dapp_admin_cap = create_dapp_admin_cap_by_admin(&dapp_config, ctx);
        transfer::public_share_object(dapp_config);
        dapp_admin_cap
    }

    public fun create_dapp_admin_cap_by_admin (
        dapp_config: & DappConfig,
        ctx: & TxContext
    ): DappAdminCap {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        let dapp_admin_cap = DappAdminCap{
            dapp: dapp_config.dapp,
            dappConfigId: object::id(dapp_config),
        };
        dapp_admin_cap
    }

    public fun create_user_dapp_score_object_by_admin_cap (
        admin_cap: & DappAdminCap,
        dapp_score_manager: &mut DappScoreManager,
        user: address,
        ctx: &mut TxContext
    ): UserDappScore {
        // check_dapp_score_manager_version(dapp_score_manager);
        internal_create_user_dapp_score_object(dapp_score_manager, user, admin_cap.dapp, option::none(), ctx)
    }

    public fun create_user_dapp_score_object_with_referrer_by_admin_cap (
        admin_cap: & DappAdminCap,
        dapp_score_manager: &mut DappScoreManager,
        user: address,
        referrer_dapp_score: &mut UserDappScore,
        ctx: &mut TxContext
    ): UserDappScore {
        // check_dapp_score_manager_version(dapp_score_manager);
        add_referral_score(user, referrer_dapp_score, admin_cap.dapp);
        internal_create_user_dapp_score_object(dapp_score_manager, user, admin_cap.dapp, option::some(referrer_dapp_score.user), ctx)
    }

    public fun increase_user_dapp_score_object_by_admin_cap(
        admin_cap: & DappAdminCap,
        user_dapp_score: &mut UserDappScore,
        target: String,
        score_increase: u256,
    ) {
        internal_update_user_dapp_score_object(user_dapp_score, admin_cap.dapp, target, score_increase, false, false, true);
    }

    public fun decrease_user_dapp_score_object_by_admin_cap(
        admin_cap: & DappAdminCap,
        user_dapp_score: &mut UserDappScore,
        target: String,
        score_decrease: u256,
    ) {
        internal_update_user_dapp_score_object(user_dapp_score, admin_cap.dapp, target, score_decrease, true, false, true);
    }

  // Dapp Admin Management For User Score

    public fun create_user_dapp_score_object_by_admin (
        dapp_score_manager: &mut DappScoreManager,
        dapp_config: & DappConfig,
        user: address,
        ctx: &mut TxContext
    ): UserDappScore {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        internal_create_user_dapp_score_object(dapp_score_manager, user, dapp_config.dapp, option::none(), ctx)
    }


    public fun update_user_dapp_score_object_by_admin (
        dapp_score_manager: &DappScoreManager,
        dapp_config: & DappConfig,
        user_dapp_score: &mut UserDappScore,
        target: String,
        score_change: u256,
        is_decrease: bool,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert_target_exist(dapp_config, target);
        internal_update_user_dapp_score_object(user_dapp_score, dapp_config.dapp, target, score_change, is_decrease, true, false);
    }

    public fun reset_user_dapp_score_object_by_admin (
        dapp_score_manager: &DappScoreManager,
        dapp_config: & DappConfig,
        user_dapp_score: &mut UserDappScore,
        target: String,
        new_score: u256,
        ctx: &mut TxContext
    ) {
        check_dapp_score_manager_version(dapp_score_manager);
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        assert_target_exist(dapp_config, target);
        let current_score = table::borrow_mut(&mut user_dapp_score.score_table, target);
        let is_decrease = current_score.score > new_score;
        let score_change;
        if(is_decrease){
            score_change = current_score.score - new_score;
        } else {
            score_change = new_score - current_score.score;
        };
        internal_update_user_dapp_score_object(user_dapp_score, dapp_config.dapp, target, score_change, is_decrease, true, false);
    }

    public fun create_dapp_score_update_request_for_user_by_admin (
        dapp_config: & DappConfig,
        updater_config: & UpdaterConfig,
        user: address,
        referrer: Option<address>,
        proof: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert_is_dapp_admin(dapp_config, tx_context::sender(ctx));
        internal_create_dapp_score_update_request(updater_config, user, dapp_config.dapp, referrer, proof, ctx);
    }

  // Client
    
    public fun create_dapp_score_update_request (
        updater_config: & UpdaterConfig,
        dapp: String,
        referrer: Option<address>,
        proof: vector<u8>,
        ctx: &mut TxContext
    ){
        assert!(updater_config.valid, updater_expired_error());
        let user = tx_context::sender(ctx);
        internal_create_dapp_score_update_request(updater_config, user, dapp, referrer, proof, ctx);
    }

  // Dapp Score Updater

    public fun create_referrer_dapp_score_object_by_updater (
        updater_config: & UpdaterConfig,
        dapp_score_manager: &mut DappScoreManager,
        dapp_score_update_request: & DappScoreUpadteRequest,
        ctx: &mut TxContext
    ): UserDappScore {
        assert_valid_updater(updater_config, tx_context::sender(ctx));
        assert!(dapp_score_update_request.referrer != option::none(), not_authorized_error());

        internal_create_user_dapp_score_object(
            dapp_score_manager, 
            *option::borrow(&dapp_score_update_request.referrer),
            dapp_score_update_request.dapp,
            option::none(),
            ctx
        )
    }

    public fun create_user_dapp_score_object_by_updater (
        updater_config: & UpdaterConfig,
        dapp_score_manager: &mut DappScoreManager,
        dapp_score_update_request: & DappScoreUpadteRequest,
        ctx: &mut TxContext
    ): UserDappScore {
        assert_valid_updater(updater_config, tx_context::sender(ctx));
        
        assert!(
            option::some(dapp_score_update_request.user) == dapp_score_update_request.referrer ||
            dapp_score_update_request.referrer == option::none(), 
            not_authorized_error()
        );
        
        internal_create_user_dapp_score_object(
            dapp_score_manager, 
            dapp_score_update_request.user, 
            dapp_score_update_request.dapp, 
            dapp_score_update_request.referrer, 
            ctx
        )
    }

    #[allow(lint(share_owned))]
    public fun transfer_user_dapp_score_object_to_public_share (
        user_dapp_score: UserDappScore,
    ) {
        transfer::public_share_object(user_dapp_score);
    }

    public fun create_user_dapp_score_object_with_referrer_by_updater (
        updater_config: & UpdaterConfig,
        dapp_score_manager: &mut DappScoreManager,
        dapp_score_update_request: & DappScoreUpadteRequest,
        referrer_dapp_score: &mut UserDappScore,
        ctx: &mut TxContext
    ): UserDappScore {
        assert_valid_updater(updater_config, tx_context::sender(ctx));
        assert!(
            dapp_score_update_request.referrer == option::some(referrer_dapp_score.user),
            not_authorized_error()
        );

        add_referral_score(
            dapp_score_update_request.user,
            referrer_dapp_score, 
            dapp_score_update_request.dapp
        );
    
        internal_create_user_dapp_score_object(
            dapp_score_manager, 
            dapp_score_update_request.user, 
            dapp_score_update_request.dapp, 
            dapp_score_update_request.referrer, 
            ctx
        )
    }

    fun check_valid_increase_user_dapp_score_with_referrer_by_updater(
        updater_config: & UpdaterConfig,
        user_dapp_score: & UserDappScore,
        referrer_dapp_score: & UserDappScore,
        dapp_score_update_request: & DappScoreUpadteRequest,
        ctx: & TxContext
    ) {
        assert_valid_updater(updater_config, tx_context::sender(ctx));
        assert!(
            dapp_score_update_request.referrer == option::some(referrer_dapp_score.user) &&
            user_dapp_score.user != referrer_dapp_score.user, 
            not_authorized_error()
        );
        assert!(
            user_dapp_score.user == dapp_score_update_request.user,
            not_authorized_error()
        );
    }

    public fun batch_increase_user_dapp_score_with_referrer_by_updater(
        updater_config: & UpdaterConfig,
        user_dapp_score: &mut UserDappScore,
        referrer_dapp_score: &mut UserDappScore,
        dapp_score_update_request: & DappScoreUpadteRequest,
        targets: vector<String>,
        referral_targets: vector<String>,
        score_increases: vector<u256>,
        ctx: &mut TxContext
    ) {
        check_valid_increase_user_dapp_score_with_referrer_by_updater(
            updater_config, 
            user_dapp_score, 
            referrer_dapp_score, 
            dapp_score_update_request, 
            ctx
        );
        let index = 0;
        loop {
            if(index >= vector::length(&targets)){
                break
            };
            let target = *vector::borrow(&targets, index);
            let score_increase = *vector::borrow(&score_increases, index);
            internal_update_user_dapp_score_object(user_dapp_score, dapp_score_update_request.dapp, target, score_increase, false, false, false);

            // let referral_target = string::utf8(b"referral__");
            // string::append(&mut referral_target, target);
            let referral_target = *vector::borrow(&referral_targets, index);
            assert!(
                string::sub_string(&referral_target, 0, 10) == string::utf8(b"referral__") &&
                string::sub_string(&referral_target, 10, string::length(&referral_target)) == target,
                not_authorized_error()
            );
            internal_update_user_dapp_score_object(referrer_dapp_score, dapp_score_update_request.dapp, referral_target, score_increase, false, false, false);
            index = index + 1;
        };
    }

    public fun increase_user_dapp_score_with_referrer_by_updater(
        updater_config: & UpdaterConfig,
        user_dapp_score: &mut UserDappScore,
        referrer_dapp_score: &mut UserDappScore,
        dapp_score_update_request: & DappScoreUpadteRequest,
        target: String,
        referral_target: String,
        score_increase: u256,
        ctx: &mut TxContext
    ) {
        check_valid_increase_user_dapp_score_with_referrer_by_updater(
            updater_config, 
            user_dapp_score, 
            referrer_dapp_score, 
            dapp_score_update_request, 
            ctx
        );
        internal_update_user_dapp_score_object(user_dapp_score, dapp_score_update_request.dapp, target, score_increase, false, false, false);

        // let referral_target = string::utf8(b"referral__");
        // string::append(&mut referral_target, target);

        // just check if referral_target is valid by first part and last part is equal to referral__ and target
        assert!(
            string::sub_string(&referral_target, 0, 10) == string::utf8(b"referral__") &&
            string::sub_string(&referral_target, 10, string::length(&referral_target)) == target,
            not_authorized_error()
        );
        internal_update_user_dapp_score_object(referrer_dapp_score, dapp_score_update_request.dapp, referral_target, score_increase, false, false, false);
    }

    fun check_valid_increase_user_dapp_score_by_updater(
        updater_config: & UpdaterConfig,
        user_dapp_score: & UserDappScore,
        dapp_score_update_request: & DappScoreUpadteRequest,
        ctx: & TxContext
    ) {
        assert!(
            dapp_score_update_request.referrer == option::some(user_dapp_score.user) ||
            dapp_score_update_request.referrer == option::none(),
            not_authorized_error()
        );
        assert_valid_updater(updater_config, tx_context::sender(ctx));
        assert!(
            user_dapp_score.user == dapp_score_update_request.user,
            not_authorized_error()
        );
    }

    public fun batch_increase_user_dapp_score_by_updater(
        updater_config: & UpdaterConfig,
        user_dapp_score: &mut UserDappScore,
        dapp_score_update_request: & DappScoreUpadteRequest,
        targets: vector<String>,
        score_increases: vector<u256>,
        ctx: &mut TxContext
    ) {
        check_valid_increase_user_dapp_score_by_updater(
            updater_config, 
            user_dapp_score, 
            dapp_score_update_request, 
            ctx
        );
        let index = 0;
        loop {
            if(index >= vector::length(&targets)){
                break
            };
            let target = *vector::borrow(&targets, index);
            let score_increase = *vector::borrow(&score_increases, index);
            internal_update_user_dapp_score_object(user_dapp_score, dapp_score_update_request.dapp, target, score_increase, false, false, false);
            index = index + 1;
        };
    }

    public fun increase_user_dapp_score_by_updater (
        updater_config: & UpdaterConfig,
        user_dapp_score: &mut UserDappScore,
        dapp_score_update_request: & DappScoreUpadteRequest,
        target: String,
        score_increase: u256,
        ctx: &mut TxContext
    ) {
        check_valid_increase_user_dapp_score_by_updater(
            updater_config, 
            user_dapp_score, 
            dapp_score_update_request, 
            ctx
        );
        internal_update_user_dapp_score_object(user_dapp_score, dapp_score_update_request.dapp, target, score_increase, false, false, false);
    }

    public fun delete_dapp_score_update_request_by_updater (
        updater_config: & UpdaterConfig,
        dapp_score_update_request: DappScoreUpadteRequest,
        ctx: &mut TxContext
    ) {
        assert_valid_updater(updater_config, tx_context::sender(ctx));
        
        let dapp_score_update_request_object_id = object::id(&dapp_score_update_request);

        let DappScoreUpadteRequest{
            id,
            user,
            referrer: _,
            dapp,
            proof: _,
        } = dapp_score_update_request;

        event::emit(UpdateRequestDeletedEvent{
            dapp_score_update_request_object_id,
            user,
            dapp,
            updater: updater_config.updater,
        });

        object::delete(id);
    }

  // Getter functions

    public fun is_super_admin (
        dapp_score_manager: &DappScoreManager,
        user: &address
    ): bool {
        vector::contains(&dapp_score_manager.admins, user)
    }

    public fun get_score(
        user_dapp_score: &UserDappScore,
        target: String,
    ): u256 {
        if(!table::contains(&user_dapp_score.score_table, target)){
            return 0
        };
        let current_score = table::borrow(&user_dapp_score.score_table, target);
        current_score.score
    }

    public fun get_user_dapp_score_index(
        user_dapp_score: & UserDappScore,
    ): u64 {
        user_dapp_score.index
    }

    public fun get_user(
        user_dapp_score: &UserDappScore,
    ): address {
        user_dapp_score.user
    }
    
    public fun get_dapp(
        user_dapp_score: &UserDappScore,
    ): String {
        user_dapp_score.dapp
    }

    public fun get_referrer(
        user_dapp_score: &UserDappScore,
    ): Option<address> {
        user_dapp_score.referrer
    }

    public fun borrow_user_dapp_score_table(
        user_dapp_score: & UserDappScore,
    ): &Table<String, ScoreTableItem> {
        &user_dapp_score.score_table
    }

    public fun get_dapp_display_name(
        dapp_config: &DappConfig,
    ): String {
        dapp_config.display_name
    }

    public fun get_dapp_data(
        dapp_config: &DappConfig,
    ): String {
        dapp_config.data
    }

    public fun get_dapp_image_url(
        dapp_config: &DappConfig,
    ): String {
        dapp_config.image_url
    }

    public fun get_target_weight(
        dapp_config: &DappConfig,
        target: String,
    ): u256 {
        if(!target_exist(dapp_config, target)){
            return 0
        };
        let target_config = table::borrow(&dapp_config.targets_config, target);
        target_config.weight
    }

    public fun get_dapp_admins(
        dapp_config: &DappConfig,
    ): vector<address> {
        dapp_config.admins
    }

    public fun borrow_dapp_targets(
        dapp_config: &DappConfig,
    ): &TableVec<String> {
        &dapp_config.targets
    }

    public fun borrow_dapp_targets_config(
        dapp_config: &DappConfig,
    ): &Table<String, TargetConfig> {
        &dapp_config.targets_config
    }

    public fun is_dapp_admin(
        dapp_config: &DappConfig,
        user: address
    ): bool {
        vector::contains(&dapp_config.admins, &user)
    }

    public fun is_updater(
        updater_config: & UpdaterConfig,
        user: address
    ): bool {
        updater_config.updater == user
    }

    public fun assert_valid_updater (
        updater_config: & UpdaterConfig,
        user: address,
    ){
        assert!(updater_config.valid, updater_expired_error());
        assert!(
            is_updater(updater_config, user),
            not_authorized_error()
        );
    }
    
    public fun assert_target_name_is_not_reserved(
        target: &String,
    ){
        // should not target.startsWith("referral__")
        // we can only use string::substring, need to check length first
        assert!(
            string::length(target) < 9 || string::sub_string(target, 0, 10) != string::utf8(b"referral__"),
            not_authorized_error()
        );
    }

    public fun assert_is_dapp_admin(
        dapp_config: &DappConfig,
        admin_address: address
    ){
        assert!(
            is_dapp_admin(dapp_config, admin_address),
            not_authorized_error()
        );
    }

    public fun assert_is_super_admin(
        dapp_score_manager: &DappScoreManager,
        user: address
    ){
        assert!(
            is_super_admin(dapp_score_manager, &user),
            not_authorized_error()
        );
    }

    public fun target_exist(
        dapp_config: & DappConfig,
        target: String
    ): bool {
        table::contains(&dapp_config.targets_config, target)
    }

    public fun assert_target_exist(
        dapp_config: & DappConfig,
        target: String
    ){
        assert!(
            target_exist(dapp_config, target),
            target_not_exist_error()
        );
    }

    public fun assert_target_not_exist(
        dapp_config: & DappConfig,
        target: String
    ){
        assert!(
            !target_exist(dapp_config, target),
            duplicated_error()
        );
    }

  // Getter functions for user_dapp_score_object_map, dapp_user_score_object_map
    
    public fun get_user_dapp_score_object_id(
        dapp_score_manager: & DappScoreManager,
        user: address,
        dapp: String
    ): ID {
        let user_dapp_score_object_map_wrapper = table::borrow(&dapp_score_manager.user_dapp_score_object_map, user);
        let user_dapp_score_object_id = table::borrow(&user_dapp_score_object_map_wrapper.dapp_score_objects_map, dapp);
        *user_dapp_score_object_id
    }

    public fun is_user_dapp_score_object_exist(
        dapp_score_manager: & DappScoreManager,
        user: address,
        dapp: String
    ): bool {
        if(!table::contains(&dapp_score_manager.user_dapp_score_object_map, user)){
            return false
        };
        let user_dapp_score_object_map_wrapper = table::borrow(&dapp_score_manager.user_dapp_score_object_map, user);
        
        table::contains(&user_dapp_score_object_map_wrapper.dapp_score_objects_map, dapp)
    }

    public fun assert_user_dapp_score_object_exist(
        dapp_score_manager: & DappScoreManager,
        user: address,
        dapp: String
    ){
        assert!(
            is_user_dapp_score_object_exist(dapp_score_manager, user, dapp),
            not_exist_error()
        );
    }

    public fun assert_user_dapp_score_object_not_exist(
        dapp_score_manager: & DappScoreManager,
        user: address,
        dapp: String
    ){
        assert!(
            !is_user_dapp_score_object_exist(dapp_score_manager, user, dapp),
            has_exist_error()
        );
    }

    public fun borrow_user_dapp_score_objects_by_user(
        dapp_score_manager: & DappScoreManager,
        user: address
    ): &Table<String, ID> {
        let user_dapp_score_object_map_wrapper = table::borrow(&dapp_score_manager.user_dapp_score_object_map, user);
        &user_dapp_score_object_map_wrapper.dapp_score_objects_map
    }

    public fun borrow_dapp_user_score_objects_table(
        dapp_score_manager: & DappScoreManager,
        dapp: String
    ): &Table<address, ID> {
        let user_score_object_map_wrapper = table::borrow(&dapp_score_manager.dapp_user_score_object_map, dapp);
        &user_score_object_map_wrapper.user_score_objects_map
    }

  // score function
    // calcluate total score of user at the dapp with weight, iterate through the targets

    fun internal_calculate_user_total_score(
        dapp_config: & DappConfig,
        user_dapp_score: & UserDappScore,
    ): (u256, u256) {
        let positive_score = 0;
        let negative_score = 0;
        let targets_length = table_vec::length(&dapp_config.targets);
        let index = 0;
        loop {
            if(index >= targets_length){
                break
            };
            
            let target = table_vec::borrow(&dapp_config.targets, index);
            
            let target_config = table::borrow(&dapp_config.targets_config, *target);
            
            if(target_config.weight_is_negative){
                negative_score = negative_score + get_score(user_dapp_score, *target) * target_config.weight;
            } else {
                positive_score = positive_score + get_score(user_dapp_score, *target) * target_config.weight;
            };
            index = index + 1;
        };
        (positive_score, negative_score)
    }
    public fun calculate_user_total_score(
        dapp_config: & DappConfig,
        user_dapp_score: & UserDappScore,
    ): u256 {
        let (positive_score, negative_score) = internal_calculate_user_total_score(dapp_config, user_dapp_score);
        if(negative_score > positive_score){
            return 0
        };
        positive_score - negative_score
    }

    public fun calculate_user_total_score_negative_sign(
        dapp_config: & DappConfig,
        user_dapp_score: & UserDappScore,
    ): u256 {
        let (positive_score, negative_score) = internal_calculate_user_total_score(dapp_config, user_dapp_score);
        if(negative_score > positive_score){
            return negative_score - positive_score
        };
        0
    }
    
  // Test
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}


