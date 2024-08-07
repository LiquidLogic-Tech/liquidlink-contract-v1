
#[test_only]
#[allow(unused_use)]
module liquidlink_dapp_score::test_dapp_score_udpate_request{
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
        DappScoreUpadteRequest
    };
    use liquidlink_dapp_score::error::{
        ErrorNotAuthorized, 
        ErrorDuplicated,
        // ErrorDuplicatedUserDappScoreObject,
    };

    #[test]
    fun test_create_dapp_score_update_request() {
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

        // create dapp score update request
        ts::next_tx(scenario, userA);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            dapp_score::create_dapp_score_update_request(updater, 0, option::some(referrer), vector::empty(), ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        // delete dapp score update request by updater
        ts::next_tx(scenario, updater);
        {
            let dapp_score_manager = ts::take_shared<DappScoreManager>(scenario);
            let dapp_score_update_request = ts::take_from_sender<DappScoreUpadteRequest>(scenario);
            dapp_score::delete_dapp_score_update_request(&dapp_score_manager, dapp_score_update_request, ts::ctx(scenario));
            ts::return_shared(dapp_score_manager);
        };

        ts::end(scenario_val);
    }
}

