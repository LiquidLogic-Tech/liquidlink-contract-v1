#[test_only]
#[allow(unused_use)]
module liquidlink_dapp_score::test_admin {
    use sui::test_scenario::{Self as ts};
    use std::vector::{Self};
    // use std::option::{Self};
    // use sui::object::{Self};
    
    use std::string::{utf8};
    // use sui::table;

    use std::debug::{print};

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
    fun test_dapp_score_creator_remove_super_admin() {
        // Setup test scenario
        let admin = @0x1;
        let dapp_admin = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_super_admin(&mut dapp_score_manager, dapp_admin, ts::ctx(scenario));
            dapp_score::remove_super_admin(&mut dapp_score_manager, admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    // test creator remove admin but he was last admin, and fail
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_dapp_score_creator_remove_super_admin_last_admin() {
        // Setup test scenario
        let admin = @0x1;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::remove_super_admin(&mut dapp_score_manager, admin, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    #[test]
    fun test_dapp_score_creator_add_super_admin() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x4;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize DappScoreManager with admin
        {
            dapp_score::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, admin);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::add_super_admin(&mut dapp_score_manager, userA, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_dapp_score::dapp_score)]
    fun test_dapp_score_unauthorized_add_super_admin() {
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
            dapp_score::add_super_admin(&mut dapp_score_manager, userA, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };
        ts::end(scenario_val);
    }


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
}
