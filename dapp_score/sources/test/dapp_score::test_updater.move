
#[test_only]
#[allow(unused_use)]
module liquidlink_dapp_score::test_updater{
    use sui::test_scenario::{Self as ts};
    use std::vector::{Self};
    use std::option::{Self};
    // use sui::object::{Self};
    
    use std::string::{utf8};
    // use sui::table;

    use std::debug::{print};

    use liquidlink_dapp_score::dapp_score::{
        Self, 
        DappScoreManager, 
        DappScoreUpadteRequest,
    };
    use liquidlink_dapp_score::error::{
        ErrorNotAuthorized, 
        ErrorDuplicated,
        // ErrorDuplicatedUserDappScoreObject,
    };

    #[test]
    fun test_dapp_score_set_and_update() {
        // Setup test scenario
        let admin = @0x1;
        let updater = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::change_updater(&mut dapp_score_manager, updater, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_dapp_score_unauthorized_set_updater() {
        // Setup test scenario
        let admin = @0x1;
        let updater = @0x2;
        let userA = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::change_updater(&mut dapp_score_manager, updater, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test update userA offchain score by updater
    #[test]
    fun test_update_user_offchain_score() {
        // Setup test scenario
        let admin = @0x1;
        let updater = @0x2;
        let dapp_admin = @0x3;
        let userA = @0x4;
        let referrer = @0x5;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::change_updater(&mut dapp_score_manager, updater, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // create dapp
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp1"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::update_user_offchain_score(&mut dapp_score_manager, 0, userA, option::some(referrer), 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 100, 0);
            ts::return_shared(dapp_score_manager);
        };

        // update it again
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::update_user_offchain_score(&mut dapp_score_manager, 0, userA, option::some(referrer), 200, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };
        
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 0, userA) == 200, 0);
            ts::return_shared(dapp_score_manager);
        };

        // create another dapp
        ts::next_tx(scenario, dapp_admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp(&mut dapp_score_manager, utf8(b"dapp2"), utf8(b"test_data"), utf8(b"test_image_url"), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // update it, too
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::update_user_offchain_score(&mut dapp_score_manager, 1, userA, option::some(referrer), 300, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(dapp_score::get_user_score(&dapp_score_manager, 1, userA) == 300, 0);
            ts::return_shared(dapp_score_manager);
        };

        // check the referrer 
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(option::extract(&mut dapp_score::get_user_referrer(&dapp_score_manager, 0, userA)) == referrer, 0);
            assert!(option::extract(&mut dapp_score::get_user_referrer(&dapp_score_manager, 1, userA)) == referrer, 0);
            ts::return_shared(dapp_score_manager);
        };

        // check the users' dapp list
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            assert!(vector::length(&dapp_score::get_user_dapps(&dapp_score_manager, userA)) == 2, 0);
            assert!(vector::contains(&dapp_score::get_user_dapps(&dapp_score_manager, userA), &0), 0);
            assert!(vector::contains(&dapp_score::get_user_dapps(&dapp_score_manager, userA), &1), 0);
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test non-updater try to update userA offchain score and fail
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_unauthorized_update_user_offchain_score() {
        // Setup test scenario
        let admin = @0x1;
        let updater = @0x2;
        let userA = @0x3;
        let userB = @0x4;
        let referrer = @0x5;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::change_updater(&mut dapp_score_manager, updater, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::next_tx(scenario, userB);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::update_user_offchain_score(&mut dapp_score_manager, 0, userA, option::some(referrer), 100, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }
}
