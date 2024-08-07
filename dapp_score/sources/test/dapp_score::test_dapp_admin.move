

#[test_only]
#[allow(unused_use)]
module liquidlink_dapp_score::test_dapp_admin {
    use sui::test_scenario::{Self as ts};
    use std::vector::{Self};
    use std::option::{Self};
    // use sui::object::{Self};
    
    use std::string::{utf8};
    // use sui::table;

    use std::debug::{print};
    use sui::dynamic_field::{EFieldAlreadyExists};

    use liquidlink_dapp_score::dapp_score::{
        Self, 
        DappScoreManager, 
    };
    use liquidlink_dapp_score::error::{
        ErrorNotAuthorized, 
        ErrorDuplicated,
        // ErrorDuplicatedUserDappScoreObject,
    };

    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_dapp_score_unauthorized_remove_super_admin() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x4;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::remove_super_admin(&mut dapp_score_manager, admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    #[test]
    fun test_create_dapp_and_change_dapp_fields() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(vector::length(&dapp_score::get_dapp_admins(&dapp_score_manager, 0)) == 1, 0);
            assert!(dapp_score::get_dapp_name(&dapp_score_manager, 0) == utf8(b"dapp1"), 0);
            assert!(dapp_score::get_dapp_data(&dapp_score_manager, 0) == utf8(b"test_data"), 0);
            assert!(dapp_score::get_dapp_image_url(&dapp_score_manager, 0) == utf8(b"test_image_url"), 0);
        

            dapp_score::update_dapp_name(&mut dapp_score_manager, 0, utf8(b"test_name2"), ts::ctx(scenario));
            dapp_score::update_dapp_data(&mut dapp_score_manager, 0, utf8(b"test_data2"), ts::ctx(scenario));
            dapp_score::update_dapp_image_url(&mut dapp_score_manager, 0, utf8(b"test_image_url2"), ts::ctx(scenario));
            dapp_score::add_dapp_admin(&mut dapp_score_manager, 0, userA, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(vector::length(&dapp_score::get_dapp_admins(&dapp_score_manager, 0)) == 2, 0);
            assert!(vector::contains(&dapp_score::get_dapp_admins(&dapp_score_manager, 0), &userA), 0);
            assert!(vector::contains(&dapp_score::get_dapp_admins(&dapp_score_manager, 0), &dapp_admin), 0);
            assert!(dapp_score::get_dapp_name(&dapp_score_manager, 0) == utf8(b"test_name2"), 0);
            assert!(dapp_score::get_dapp_data(&dapp_score_manager, 0) == utf8(b"test_data2"), 0);
            assert!(dapp_score::get_dapp_image_url(&dapp_score_manager, 0) == utf8(b"test_image_url2"), 0);
            dapp_score::remove_dapp_admin(&mut dapp_score_manager, 0, dapp_admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(vector::length(&dapp_score::get_dapp_admins(&dapp_score_manager, 0)) == 1, 0);
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test someone unauthorized to change dapp fields
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_unauthorized_change_dapp_fields() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::update_dapp_name(&mut dapp_score_manager, 0, utf8(b"dapp1_2"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test someone non dapp admin try to remove dapp admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_unauthorized_remove_dapp_admin() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::remove_dapp_admin(&mut dapp_score_manager, 0, dapp_admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test admin try to remove themself as last dapp admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_remove_last_dapp_admin() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::remove_dapp_admin(&mut dapp_score_manager, 0, dapp_admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test someone remove non-exist dapp admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_remove_non_exist_dapp_admin() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // increase userA 100 score by admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::increase_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };


        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::remove_dapp_admin(&mut dapp_score_manager, 0, userA, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test dapp admin modify user score
    #[test]
    fun test_dapp_admin_modify_user_score() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // create dapp
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // increase userA offchain score by dapp admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::increase_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check the score is updated
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 100, 0);
            ts::return_shared(dapp_score_manager);
        };

        // decrease it 50
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::decrease_user_score_by_admin(&mut dapp_score_manager, 0, userA, 50, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 50, 0);
            ts::return_shared(dapp_score_manager);
        };

        // increase it 100 again, check, then decrease it 100, then check
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::increase_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 150, 0);
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::decrease_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 50, 0);
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test dapp admin modify user score with a decrease and check
    #[test]
    fun test_dapp_admin_modify_user_score_decrease_first() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // create dapp
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // decrease userA offchain score by dapp admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::decrease_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check the score is updated
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 0, 0);
            ts::return_shared(dapp_score_manager);
        };

        // increase it 50
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::increase_user_score_by_admin(&mut dapp_score_manager, 0, userA, 50, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 0, 0);
            ts::return_shared(dapp_score_manager);
        };

        // increase it 100
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::increase_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 50, 0);
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test_non dapp_admin_modify_user_score and fail
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_non_dapp_admin_modify_user_score() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // create dapp
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // increase userA offchain score by dapp admin
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::increase_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // increase and decrease score by admin cap
    #[test]
    fun test_increase_and_decrease_score_by_admin_cap() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // create dapp
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // increase userA offchain score by dapp admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let admin_cap = dapp_score::get_admin_cap(&dapp_score_manager, 0, ts::ctx(scenario));
            dapp_score::increase_score_by_admin_cap(&mut dapp_score_manager, admin_cap, userA, option::none(), 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check the score is updated
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 100, 0);
            ts::return_shared(dapp_score_manager);
        };

        // decrease it 50
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let admin_cap = dapp_score::get_admin_cap(&dapp_score_manager, 0, ts::ctx(scenario));
            dapp_score::decrease_score_by_admin_cap(&mut dapp_score_manager, admin_cap, userA, option::none(), 50, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 50, 0);
            ts::return_shared(dapp_score_manager);
        };

        // increase it 100 again
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let admin_cap = dapp_score::get_admin_cap(&dapp_score_manager, 0, ts::ctx(scenario));
            dapp_score::increase_score_by_admin_cap(&mut dapp_score_manager, admin_cap, userA, option::none(), 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 150, 0);
            ts::return_shared(dapp_score_manager);
        };

        // decrease it 100 again
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let admin_cap = dapp_score::get_admin_cap(&dapp_score_manager, 0, ts::ctx(scenario));
            dapp_score::decrease_score_by_admin_cap(&mut dapp_score_manager, admin_cap, userA, option::none(), 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 50, 0);
            ts::return_shared(dapp_score_manager);
        };

        // then increase it 100 by admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::increase_user_score_by_admin(&mut dapp_score_manager, 0, userA, 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 150, 0);
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // modify score by admin cap decrease first
    #[test]
    fun test_modify_score_by_admin_cap_decrease_first() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        // create dapp
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // decrease userA offchain score by dapp admin
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let admin_cap = dapp_score::get_admin_cap(&dapp_score_manager, 0, ts::ctx(scenario));
            dapp_score::decrease_score_by_admin_cap(&mut dapp_score_manager, admin_cap, userA, option::none(), 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check the score is updated
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 0, 0);
            ts::return_shared(dapp_score_manager);
        };

        // increase it 50
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let admin_cap = dapp_score::get_admin_cap(&dapp_score_manager, 0, ts::ctx(scenario));
            dapp_score::increase_score_by_admin_cap(&mut dapp_score_manager, admin_cap, userA, option::none(), 50, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 0, 0);
            ts::return_shared(dapp_score_manager);
        };

        // increase it 100
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let admin_cap = dapp_score::get_admin_cap(&dapp_score_manager, 0, ts::ctx(scenario));
            dapp_score::increase_score_by_admin_cap(&mut dapp_score_manager, admin_cap, userA, option::none(), 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // check
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 50, 0);
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }
}



