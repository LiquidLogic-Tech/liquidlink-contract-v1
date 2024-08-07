

#[test_only]
module liquidlink_dapp_score::test_dapp_score {
    use sui::test_scenario::{Self as ts};
    use std::vector::{Self};
    use std::option::{Self};
    use sui::object::{Self};
    use std::string::{utf8};
    use sui::table;

    use liquidlink_dapp_score::dapp_score::{
        Self, 
        DappScoreManager, 
        DappConfig, 
        UserDappScore, 
        UpdaterConfig, 
        DappScoreUpadteRequest,
    };
    use liquidlink_dapp_score::error::{
        ErrorNotAuthorized, 
        ErrorDuplicated,
        ErrorDuplicatedUserDappScoreObject,
    };

    #[test]
    fun test_dapp_score_set_and_update() {
        // Setup test scenario
        let admin = @0x1;
        let updater = @0x2;
        let dapp_admin = @0x3;
        let userA = @0x4;
        let userB = @0x5;
        let userC = @0x6;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Add updater by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_updater(&mut dapp_score_manager, updater, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a target by dapp_admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // check the referrer target is created, too
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let targets_config = dapp_score::borrow_dapp_targets_config(&dapp_config);
            assert!(table::contains(targets_config, utf8(b"referral__target")), 0);
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Create a new Dapp score object for user by dapp_admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);

            let user_dapp_score = dapp_score::create_user_dapp_score_object_by_admin(
                &mut dapp_score_manager, 
                &dapp_config, 
                userA, 
                ts::ctx(scenario)
            );
            dapp_score::update_user_dapp_score_object_by_admin(
                &dapp_score_manager,
                &dapp_config,
                &mut user_dapp_score,
                utf8(b"target"),
                100,
                false,
                ts::ctx(scenario)
            );

            dapp_score::transfer_user_dapp_score_object_to_public_share(user_dapp_score);

            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
            ts::return_shared(updater_config);
        };

        // get user dapp score and assert the score
        ts::next_tx(scenario, dapp_admin);
        {
            let user_dapp_score = ts::take_shared<UserDappScore>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let score = dapp_score::get_score(&user_dapp_score, utf8(b"target"));
            let user = dapp_score::get_user(&user_dapp_score);
            assert!(score == 100, 0);
            assert!(user == userA, 0);

            let referrer = dapp_score::get_referrer(&user_dapp_score);
            assert!(referrer == option::none(), 0);

            let index = dapp_score::get_user_dapp_score_index(&user_dapp_score);
            assert!(index == 0, 0);

            // calculate total score
            let total_score = dapp_score::calculate_user_total_score(&dapp_config, &user_dapp_score);
            assert!(total_score == 100 * 100, 0);

            ts::return_shared(user_dapp_score);
            ts::return_shared(dapp_config);
        };

        // userB create a update request that referrer is userA
        ts::next_tx(scenario, userB);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                &updater_config,
                utf8(b"MyDapp"),
                option::some(userA),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // updater update the score for userB at target for 150 score
        ts::next_tx(scenario, updater);
        let userB_dapp_score_id;
        {
            let dapp_score_update_request = ts::take_from_address<DappScoreUpadteRequest>(scenario, updater);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let referrer_dapp_score = ts::take_shared<UserDappScore>(scenario);
            let user_dapp_score = dapp_score::create_user_dapp_score_object_with_referrer_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                &dapp_score_update_request,
                &mut referrer_dapp_score,
                ts::ctx(scenario)
            );
            let index = dapp_score::get_user_dapp_score_index(&user_dapp_score);
            assert!(index == 1, 0);
            dapp_score::increase_user_dapp_score_with_referrer_by_updater(
                &updater_config,
                &mut user_dapp_score,
                &mut referrer_dapp_score,
                &dapp_score_update_request,
                utf8(b"target"),
                utf8(b"referral__target"),
                150,
                ts::ctx(scenario)
            );
            userB_dapp_score_id = object::id(&user_dapp_score);
            dapp_score::transfer_user_dapp_score_object_to_public_share(user_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(referrer_dapp_score);
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };

        // userB check he have 150 score
        ts::next_tx(scenario, userB);
        {
            let userB_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userB_dapp_score_id);
            let score = dapp_score::get_score(
                &userB_dapp_score, 
                utf8(b"target")
            );
            assert!(score == 150, 0);
            
            let referrer = dapp_score::get_referrer(&userB_dapp_score);
            assert!(referrer == option::some(userA), 0);

            ts::return_shared(userB_dapp_score);
        };

        // userC create a update request that don't have referrer
        ts::next_tx(scenario, userC);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                &updater_config,
                utf8(b"MyDapp"),
                option::none(),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // updater update the score for userC at target for 200 score
        ts::next_tx(scenario, updater);
        let userC_dapp_score_id;
        {
            let dapp_score_update_request = ts::take_from_address<DappScoreUpadteRequest>(scenario, updater);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let user_dapp_score = dapp_score::create_user_dapp_score_object_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                &dapp_score_update_request,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_by_updater(
                &updater_config,
                &mut user_dapp_score,
                &dapp_score_update_request,
                utf8(b"target"),
                200,
                ts::ctx(scenario)
            );
            userC_dapp_score_id = object::id(&user_dapp_score);
            dapp_score::transfer_user_dapp_score_object_to_public_share(user_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };

        // userC check he have 200 score
        ts::next_tx(scenario, userC);
        {
            let userC_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userC_dapp_score_id);
            let score = dapp_score::get_score(&userC_dapp_score, utf8(b"target"));
            assert!(score == 200, 0);
            let referrer = dapp_score::get_referrer(&userC_dapp_score);
            assert!(referrer == option::none(), 0);
            ts::return_shared(userC_dapp_score);
        };

        // reset_user_dapp_score_object_by_admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let user_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userB_dapp_score_id);
            dapp_score::reset_user_dapp_score_object_by_admin(
                &dapp_score_manager,
                &dapp_config,
                &mut user_dapp_score,
                utf8(b"target"),
                10,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
            ts::return_shared(user_dapp_score);
        };

        // check the score does change by UserB
        ts::next_tx(scenario, userB);
        {
            let userB_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userB_dapp_score_id);
            let score = dapp_score::get_score(&userB_dapp_score, utf8(b"target"));
            assert!(score == 10, 0);
            ts::return_shared(userB_dapp_score);
        };

        // update_user_dapp_score_object_by_admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let user_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userB_dapp_score_id);
            dapp_score::update_user_dapp_score_object_by_admin(
                &dapp_score_manager,
                &dapp_config,
                &mut user_dapp_score,
                utf8(b"target"),
                50,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
            ts::return_shared(user_dapp_score);
        };

        // check the score does change by UserB
        ts::next_tx(scenario, userB);
        {
            let userB_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userB_dapp_score_id);
            let score = dapp_score::get_score(&userB_dapp_score, utf8(b"target"));
            assert!(score == 60, 0);
            ts::return_shared(userB_dapp_score);
        };

        // test user_score_objects_map, dapp_score_objects_map is correctly set
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let user_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userB_dapp_score_id);
            let user_dapp_score_object_map = dapp_score::borrow_user_dapp_score_objects_by_user(
                &dapp_score_manager,
                userB
            );
            let user_dapp_score_id = table::borrow(user_dapp_score_object_map, utf8(b"MyDapp"));
            assert!(*user_dapp_score_id == userB_dapp_score_id, 0);

            let dapp_user_score_objects_map = dapp_score::borrow_dapp_user_score_objects_table(
                &dapp_score_manager,
                utf8(b"MyDapp")
            );
            let user_dapp_score_id = table::borrow(dapp_user_score_objects_map, userB);
            assert!(*user_dapp_score_id == userB_dapp_score_id, 0);

            ts::return_shared(dapp_score_manager);
            ts::return_shared(user_dapp_score);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    #[test]
    fun test_create_referrer_dapp_score_object_in_same_tx() {
        // Setup test scenario
        let admin = @0x1;
        let updater = @0x2;
        let dapp_admin = @0x3;
        let userA = @0x4;
        let userB = @0x5;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Add updater by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_updater(&mut dapp_score_manager, updater, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a target by dapp_admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Create a dapp score update request from userB with UserA as Referrer
        ts::next_tx(scenario, userB);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                &updater_config,
                utf8(b"MyDapp"),
                option::some(userA),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // update score
        ts::next_tx(scenario, updater);
        let userA_dapp_score_id;
        let userB_dapp_score_id;
        {
            let dapp_score_update_request = ts::take_from_address<DappScoreUpadteRequest>(scenario, updater);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let referrer_dapp_score = dapp_score::create_referrer_dapp_score_object_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                &dapp_score_update_request,
                ts::ctx(scenario)
            );
            userA_dapp_score_id = object::id(&referrer_dapp_score);
            let user_dapp_score = dapp_score::create_user_dapp_score_object_with_referrer_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                &dapp_score_update_request,
                &mut referrer_dapp_score,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_with_referrer_by_updater(
                &updater_config,
                &mut user_dapp_score,
                &mut referrer_dapp_score,
                &dapp_score_update_request,
                utf8(b"target"),
                utf8(b"referral__target"),
                150,
                ts::ctx(scenario)
            );
            userB_dapp_score_id = object::id(&user_dapp_score);
            dapp_score::transfer_user_dapp_score_object_to_public_share(user_dapp_score);
            dapp_score::transfer_user_dapp_score_object_to_public_share(referrer_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };

        // check userB get target score
        ts::next_tx(scenario, admin);
        {
            let userB_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userB_dapp_score_id);
            let score = dapp_score::get_score(&userB_dapp_score, utf8(b"target"));
            assert!(score == 150, 0);
            let referrer = dapp_score::get_referrer(&userB_dapp_score);
            assert!(referrer == option::some(userA), 0);
            ts::return_shared(userB_dapp_score);
        };

        // check userA get referral score
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let score = dapp_score::get_score(&userA_dapp_score, utf8(b"referral"));
            assert!(score == 1, 0);
            let referrer = dapp_score::get_referrer(&userA_dapp_score);
            assert!(referrer == option::none(), 0);
            ts::return_shared(userA_dapp_score);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    // test try to create a target starts with referral__ and fail
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_create_target_starts_with_referral__() {

        // Setup test scenario
        let admin = @0x1;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Add updater by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_updater(&mut dapp_score_manager, admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a target by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"referral__target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    #[test]
    fun test_super_admin_management() {
        // Setup test scenario
        let admin = @0x1;
        let super_admin = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Add super admin by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_super_admin(&mut dapp_score_manager, super_admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Remove super admin by super admin
        ts::next_tx(scenario, super_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::remove_super_admin(&mut dapp_score_manager, admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Add super admin by super admin
        ts::next_tx(scenario, super_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_super_admin(&mut dapp_score_manager, admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    #[test]
    fun test_dapp_admin_management() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Add dapp admin by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_admin(
                &mut dapp_score_manager,
                &mut dapp_config, 
                dapp_admin, 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // check the dapp_admin is admin now by dapp_admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::assert_is_dapp_admin(&dapp_config, dapp_admin);
            ts::return_shared(dapp_config);
        };

        // Remove dapp admin by dapp admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::remove_dapp_admin(
                &mut dapp_score_manager,
                &mut dapp_config,
                dapp_admin,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Create Target
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Change target weight to 200
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::edit_dapp_score_target_weight(
                &mut dapp_config, 
                utf8(b"target"), 
                200, 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // Check if target weight change
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let target = utf8(b"target");
            let weight = dapp_score::get_target_weight(&dapp_config, target);
            assert!(weight == 200, 0);
            ts::return_shared(dapp_config);
        }; 

        // Change target data
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::edit_dapp_score_target_data(
                &mut dapp_config, 
                utf8(b"target"), 
                utf8(b"New Data for target"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };
        

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }
    
    // test if someone else want to add super admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_add_super_admin_by_non_admin() {
        // Setup test scenario
        let admin = @0x1;
        let non_admin = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Add super admin by non admin
        ts::next_tx(scenario, non_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_super_admin(&mut dapp_score_manager, non_admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    // test if someone else want to remove super admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_remove_super_admin_by_non_admin() {
        // Setup test scenario
        let admin = @0x1;
        let super_admin = @0x2;
        let non_admin = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Add super admin by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_super_admin(&mut dapp_score_manager, super_admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Remove super admin by non admin
        ts::next_tx(scenario, non_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::remove_super_admin(&mut dapp_score_manager, super_admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    // test if someone else want to add dapp admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_add_dapp_admin_by_non_admin() {
        // Setup test scenario
        let admin = @0x1;
        let non_admin = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Add dapp admin by non admin
        ts::next_tx(scenario, non_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_admin(
                &mut dapp_score_manager,
                &mut dapp_config,
                non_admin,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    // test if someone else want to remove dapp admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_remove_dapp_admin_by_non_admin() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let non_admin = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Add dapp admin by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_admin(
                &mut dapp_score_manager,
                &mut dapp_config,
                dapp_admin,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Remove dapp admin by non admin
        ts::next_tx(scenario, non_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::remove_dapp_admin(
                &mut dapp_score_manager,
                &mut dapp_config,
                dapp_admin,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    // test if someone else want to create duplicated dapp config
    #[test]
    #[expected_failure(abort_code = ErrorDuplicated, location = liquidlink_dapp_score::dapp_score)]
    fun test_create_duplicated_dapp_config() {
        // Setup test scenario
        let admin = @0x1;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    // test if admin want to create duplicated target
    #[test]
    #[expected_failure(abort_code = ErrorDuplicated, location = liquidlink_dapp_score::dapp_score)]
    fun test_create_duplicated_target() {
        // Setup test scenario
        let admin = @0x1;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
            ts::return_shared(dapp_config);
        };

        // Clean up and conclude the test scenario
        ts::end(scenario_val);
    }

    #[test]
    fun test_modify_points_by_admin_cap() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let userB = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a target by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // Create a new Dapp score object for userA by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let userA_dapp_score = dapp_score::create_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userA,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userA_dapp_score,
                utf8(b"target"),
                100
            );
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"target")) == 100, 0);
            dapp_score::decrease_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userA_dapp_score,
                utf8(b"target"),
                50
            );
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"target")) == 50, 0);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
            dapp_score::transfer_user_dapp_score_object_to_public_share(userA_dapp_score);
        };

        // create a new userB dapp scoreobject with referrer is userA by admin cap
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let userA_dapp_score = ts::take_shared<UserDappScore>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let userB_dapp_score = dapp_score::create_user_dapp_score_object_with_referrer_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userB,
                &mut userA_dapp_score,
                ts::ctx(scenario)
            );
            //assert userA get referrer and get the score
            assert!(dapp_score::get_referrer(&userB_dapp_score) == option::some(userA), 0);
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"referral")) == 1, 0);

            dapp_score::increase_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userB_dapp_score,
                utf8(b"target"),
                100
            );
            assert!(dapp_score::get_score(&userB_dapp_score, utf8(b"target")) == 100, 0);
            dapp_score::decrease_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userB_dapp_score,
                utf8(b"target"),
                50
            );
            assert!(dapp_score::get_score(&userB_dapp_score, utf8(b"target")) == 50, 0);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
            ts::return_shared(userA_dapp_score);
            dapp_score::transfer_user_dapp_score_object_to_public_share(userB_dapp_score);
        };

        ts::end(scenario_val);
    }

    // test userA referr userB, then admin change the weight of referral to 200, check the score of userA, then admin change the sign of referral to negative, then check the score of userA
    #[test]
    fun test_modify_referral_weight() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let userB = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a target by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // Create a new Dapp score object for userA by admin
        ts::next_tx(scenario, admin);
        let userA_dapp_score_id;
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let userA_dapp_score = dapp_score::create_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userA,
                ts::ctx(scenario)
            );
            userA_dapp_score_id = object::id(&userA_dapp_score);
            dapp_score::increase_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userA_dapp_score,
                utf8(b"target"),
                100
            );
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"target")) == 100, 0);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
            dapp_score::transfer_user_dapp_score_object_to_public_share(userA_dapp_score);
        };

        // create a new userB dapp scoreobject with referrer is userA by admin cap
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let userB_dapp_score = dapp_score::create_user_dapp_score_object_with_referrer_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userB,
                &mut userA_dapp_score,
                ts::ctx(scenario)
            );
            //assert userA get referrer and get the score
            assert!(dapp_score::get_referrer(&userB_dapp_score) == option::some(userA), 0);
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"referral")) == 1, 0);

            dapp_score::increase_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userB_dapp_score,
                utf8(b"target"),
                100
            );
            assert!(dapp_score::get_score(&userB_dapp_score, utf8(b"target")) == 100, 0);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
            ts::return_shared(userA_dapp_score);
            dapp_score::transfer_user_dapp_score_object_to_public_share(userB_dapp_score);
        };

        // check the total score of userA, should be 100 * 100
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            
            let userA_total_score = dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            );
            assert!(userA_total_score == 100 * 100, 0);
            // debug::print(&dapp_score::get_score(&userA_dapp_score, utf8(b"referral")));
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"referral")) == 1, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        // change the weight of referral to 200
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::edit_dapp_score_target_weight(
                &mut dapp_config, 
                utf8(b"referral"), 
                200,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // check the score of userA
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            
            let userA_total_score = dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            );
            assert!(userA_total_score == 100 * 100 + 200, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        // change the target of referral to negative
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::edit_dapp_score_target_sign(
                &mut dapp_config, 
                utf8(b"referral"), 
                true, 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // check the score of userA
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared<UserDappScore>(scenario);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            assert!(dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            ) == 100 * 100 - 200, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        ts::end(scenario_val);
    }

    // test admin create a target, edit the weight, make weight immutable, then edit the weight again and get error
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_modify_target_weight() {
        // Setup test scenario
        let admin = @0x1;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a target by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // edit the weight of target
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::edit_dapp_score_target_weight(
                &mut dapp_config, 
                utf8(b"target"), 
                200,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // check the weight of target
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            assert!(dapp_score::get_target_weight(&dapp_config, utf8(b"target")) == 200, 0);
            ts::return_shared(dapp_config);
        };

        // make the weight of target immutable
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::make_weight_immutable(
                &mut dapp_config, 
                utf8(b"target"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // edit the weight of target again and get error
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::edit_dapp_score_target_weight(
                &mut dapp_config, 
                utf8(b"target"), 
                300,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        ts::end(scenario_val);
    }

    // test that use admin cap to increase user's pure score, and decrease the user pure score, calcualte the total score to reflect the change in each step
    #[test]
    fun test_modify_pure_score() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a new Dapp score object for userA by admin
        ts::next_tx(scenario, admin);
        let userA_dapp_score_id;
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let userA_dapp_score = dapp_score::create_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userA,
                ts::ctx(scenario)
            );
            userA_dapp_score_id = object::id(&userA_dapp_score);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
            dapp_score::transfer_user_dapp_score_object_to_public_share(userA_dapp_score);
        };

        // check the total score of userA, should be 0
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            
            let userA_total_score = dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            );
            assert!(userA_total_score == 0, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        // increase the pure score of userA for 100
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userA_dapp_score,
                utf8(b"pure_increase"), 
                100
            );
            assert!(dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            ) == 100, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        // check the total score of userA, should be 100
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            
            let userA_total_score = dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            );
            assert!(userA_total_score == 100, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        // increase the pure_decrease score of userA for 50
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userA_dapp_score,
                utf8(b"pure_decrease"), 
                50
            );
            assert!(dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            ) == 50, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        // check the total score of userA, should be 50
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            assert!(dapp_score::calculate_user_total_score_negative_sign(
                &dapp_config,
                &userA_dapp_score,
            ) == 0, 0);
            assert!(dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            ) == 50, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };

        // further increase the pure_decrease 200
        ts::next_tx(scenario, admin);
        {
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut userA_dapp_score,
                utf8(b"pure_decrease"), 
                200
            );
            assert!(dapp_score::calculate_user_total_score(
                &dapp_config,
                &userA_dapp_score,
            ) == 0, 0);
            assert!(dapp_score::calculate_user_total_score_negative_sign(
                &dapp_config,
                &userA_dapp_score,
            ) == 150, 0);
            ts::return_shared(userA_dapp_score);
            ts::return_shared(dapp_config);
        };


        ts::end(scenario_val);

    }

    // test a user want to serve as their own referrer but fail with error duplicated_user_dapp_score_object_error
    #[test]
    #[expected_failure(abort_code = ErrorDuplicatedUserDappScoreObject, location = liquidlink_dapp_score::dapp_score)]
    fun test_self_referrer_fail() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a new Dapp score object for userA by admin
        ts::next_tx(scenario, admin);
        let userA_dapp_score_id;
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let userA_dapp_score = dapp_score::create_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userA,
                ts::ctx(scenario)
            );
            userA_dapp_score_id = object::id(&userA_dapp_score);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
            dapp_score::transfer_user_dapp_score_object_to_public_share(userA_dapp_score);
        };

        // create a new userA dapp scoreobject with referrer is userA by admin cap
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let userA_dapp_score = ts::take_shared_by_id<UserDappScore>(scenario, userA_dapp_score_id);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let user_dapp_score = dapp_score::create_user_dapp_score_object_with_referrer_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userA,
                &mut userA_dapp_score,
                ts::ctx(scenario)
            );
            dapp_score::transfer_user_dapp_score_object_to_public_share(user_dapp_score);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
            ts::return_shared(userA_dapp_score);
        };

        ts::end(scenario_val);
    }

    // test user A create update reqeust with referrer is user A, and the updater create it without referrer and pass
    #[test]
    fun update_request_with_self_referrer() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let updater = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // admin add target
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };


        // create updater config by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_updater(
                &mut dapp_score_manager,
                updater,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };


        // Create a new Dapp score update request for userA by userA and referrer is userA
        ts::next_tx(scenario, userA);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                & updater_config,
                utf8(b"MyDapp"),
                option::some(userA),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // updater create userA dapp scoreobject without referrer
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_score_update_request = ts::take_from_sender<DappScoreUpadteRequest>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let userA_dapp_score = dapp_score::create_user_dapp_score_object_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                & dapp_score_update_request,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_by_updater(
                &updater_config,
                &mut userA_dapp_score,
                & dapp_score_update_request,
                utf8(b"target"),
                100,
                ts::ctx(scenario)
            );
            // check userA_dapp_score is 0 in referral and 100 in target
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"referral")) == 0, 0);
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"target")) == 100, 0);
            dapp_score::transfer_user_dapp_score_object_to_public_share(userA_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };
        ts::end(scenario_val);
    }

    // test user B create update reqeust with referrer is user A, and the updater create it without referrer and fail
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun update_request_with_referrer_fail() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let userB = @0x3;
        let updater = @0x4;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // admin add target
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // create updater config by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_updater(
                &mut dapp_score_manager,
                updater,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a new Dapp score update request for userB by userB and referrer is userA
        ts::next_tx(scenario, userB);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                & updater_config,
                utf8(b"MyDapp"),
                option::some(userA),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // updater create userB dapp scoreobject without referrer
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_score_update_request = ts::take_from_sender<DappScoreUpadteRequest>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let userB_dapp_score = dapp_score::create_user_dapp_score_object_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                & dapp_score_update_request,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_by_updater(
                &updater_config,
                &mut userB_dapp_score,
                & dapp_score_update_request,
                utf8(b"target"),
                100,
                ts::ctx(scenario)
            );
            dapp_score::transfer_user_dapp_score_object_to_public_share(userB_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };
        ts::end(scenario_val);
    }

    // test admin create user B profile by admin cap, then userB create update reqeust with referrer is user A, and the updater update it without referrer and fail
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun update_request_with_referrer_fail_2() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let userB = @0x3;
        let updater = @0x4;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // admin add target
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target"), 
                100, 
                utf8(b"Data for target"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // create userB dapp scoreobject by admin cap
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_admin_cap = dapp_score::create_dapp_admin_cap_by_admin(
                &dapp_config,
                ts::ctx(scenario)
            );
            let userB_dapp_score = dapp_score::create_user_dapp_score_object_by_admin_cap(
                &dapp_admin_cap,
                &mut dapp_score_manager,
                userB,
                ts::ctx(scenario)
            );
            dapp_score::transfer_user_dapp_score_object_to_public_share(userB_dapp_score);
            ts::return_shared(dapp_config);
            ts::return_shared(dapp_score_manager);
        };

        // create updater config by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_updater(
                &mut dapp_score_manager,
                updater,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a new Dapp score update request for userB by userB and referrer is userA
        ts::next_tx(scenario, userB);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                & updater_config,
                utf8(b"MyDapp"),
                option::some(userA),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // updater create userB dapp scoreobject without referrer
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_score_update_request = ts::take_from_sender<DappScoreUpadteRequest>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let userB_dapp_score = dapp_score::create_user_dapp_score_object_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                & dapp_score_update_request,
                ts::ctx(scenario)
            );
            dapp_score::increase_user_dapp_score_by_updater(
                &updater_config,
                &mut userB_dapp_score,
                & dapp_score_update_request,
                utf8(b"target"),
                100,
                ts::ctx(scenario)
            );
            dapp_score::transfer_user_dapp_score_object_to_public_share(userB_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };
        ts::end(scenario_val);
    }

    // test create a dapp and add three target then create a update request for userA and then updater update the userA dapp score object with all three target in batch. 
    // Then userB create a update request with referrer is userA and updater update the userB dapp score object with all three target in batch with userA as referrer

    #[test]
    fun update_request_batch() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let userB = @0x3;
        let updater = @0x4;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // Create Dapp configuration by admin
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_config_and_get_admin_cap(
                &mut dapp_score_manager, 
                utf8(b"MyDapp"), 
                utf8(b"My Dapp Display"), 
                utf8(b"A data for my Dapp"), 
                utf8(b"https://mydapp.com/image.png"), 
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // admin add target
        ts::next_tx(scenario, admin);
        {
            let dapp_config = ts::take_shared<DappConfig>(scenario);
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target1"), 
                100, 
                utf8(b"Data for target1"), 
                false,
                false,
                ts::ctx(scenario)
            );
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target2"), 
                200, 
                utf8(b"Data for target2"), 
                false,
                false,
                ts::ctx(scenario)
            );
            dapp_score::add_dapp_score_target(
                &mut dapp_config, 
                utf8(b"target3"), 
                300, 
                utf8(b"Data for target3"), 
                false,
                false,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_config);
        };

        // create the updater config
        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_updater(
                &mut dapp_score_manager,
                updater,
                ts::ctx(scenario)
            );
            ts::return_shared(dapp_score_manager);
        };

        // Create a new Dapp score update request for userA by userA and referrer is userA
        ts::next_tx(scenario, userA);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                & updater_config,
                utf8(b"MyDapp"),
                option::some(userA),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // updater create userA dapp scoreobject without referrer then update the userA dapp score object with all three target in batch
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_score_update_request = ts::take_from_sender<DappScoreUpadteRequest>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let userA_dapp_score = dapp_score::create_user_dapp_score_object_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                & dapp_score_update_request,
                ts::ctx(scenario)
            );
            // prepare the vectors for the batch update
            let targets = vector::empty();
            vector::push_back(&mut targets, utf8(b"target1"));
            vector::push_back(&mut targets, utf8(b"target2"));
            vector::push_back(&mut targets, utf8(b"target3"));

            let scores = vector::empty();
            vector::push_back(&mut scores, 100);
            vector::push_back(&mut scores, 200);
            vector::push_back(&mut scores, 300);

            dapp_score::batch_increase_user_dapp_score_by_updater(
                &updater_config,
                &mut userA_dapp_score,
                & dapp_score_update_request,
                targets,
                scores,
                ts::ctx(scenario)
            );

            dapp_score::transfer_user_dapp_score_object_to_public_share(userA_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };

        // check userA get the score
        ts::next_tx(scenario, userA);
        {
            let userA_dapp_score = ts::take_shared<UserDappScore>(scenario);
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"target1")) == 100, 0);
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"target2")) == 200, 0);
            assert!(dapp_score::get_score(&userA_dapp_score, utf8(b"target3")) == 300, 0);
            ts::return_shared(userA_dapp_score);
        };

        // Create a new Dapp score update request for userB by userB and referrer is userA
        ts::next_tx(scenario, userB);
        {
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            dapp_score::create_dapp_score_update_request(
                & updater_config,
                utf8(b"MyDapp"),
                option::some(userA),
                vector::empty(),
                ts::ctx(scenario)
            );
            ts::return_shared(updater_config);
        };

        // updater create userB dapp scoreobject without referrer then update the userB dapp score object with all three target in batch with userA as referrer
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_score_update_request = ts::take_from_sender<DappScoreUpadteRequest>(scenario);
            let updater_config = ts::take_shared<UpdaterConfig>(scenario);
            let userA_dapp_score = ts::take_shared<UserDappScore>(scenario);
            let userB_dapp_score = dapp_score::create_user_dapp_score_object_with_referrer_by_updater(
                &updater_config,
                &mut dapp_score_manager,
                & dapp_score_update_request,
                &mut userA_dapp_score,
                ts::ctx(scenario)
            );
            // prepare the vectors for the batch update
            let targets = vector::empty();
            vector::push_back(&mut targets, utf8(b"target1"));
            vector::push_back(&mut targets, utf8(b"target2"));
            vector::push_back(&mut targets, utf8(b"target3"));

            let referral_targets = vector::empty();
            vector::push_back(&mut referral_targets, utf8(b"referral__target1"));
            vector::push_back(&mut referral_targets, utf8(b"referral__target2"));
            vector::push_back(&mut referral_targets, utf8(b"referral__target3"));

            let scores = vector::empty();
            vector::push_back(&mut scores, 100);
            vector::push_back(&mut scores, 200);
            vector::push_back(&mut scores, 300);

            dapp_score::batch_increase_user_dapp_score_with_referrer_by_updater(
                &updater_config,
                &mut userB_dapp_score,
                &mut userA_dapp_score,
                & dapp_score_update_request,
                targets,
                referral_targets,
                scores,
                ts::ctx(scenario)
            );

            dapp_score::transfer_user_dapp_score_object_to_public_share(userB_dapp_score);
            dapp_score::delete_dapp_score_update_request_by_updater(
                &updater_config,
                dapp_score_update_request,
                ts::ctx(scenario)
            );
            ts::return_shared(userA_dapp_score);
            ts::return_shared(updater_config);
            ts::return_shared(dapp_score_manager);
        };

        // check userB get the score
        ts::next_tx(scenario, userB);
        {
            let userB_dapp_score = ts::take_shared<UserDappScore>(scenario);
            assert!(dapp_score::get_score(&userB_dapp_score, utf8(b"target1")) == 100, 0);
            assert!(dapp_score::get_score(&userB_dapp_score, utf8(b"target2")) == 200, 0);
            assert!(dapp_score::get_score(&userB_dapp_score, utf8(b"target3")) == 300, 0);
            ts::return_shared(userB_dapp_score);
        };

        ts::end(scenario_val);
    }


}
