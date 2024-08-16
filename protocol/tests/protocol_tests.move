#[test_only]
module liquidlink_protocol::protocol_tests {
    use std::ascii::{Self, string, String};

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::clock::{Self, Clock, increment_for_testing as add_time, set_for_testing as set_time};
    use sui::coin::{ Self, Coin, TreasuryCap, CoinMetadata, mint_for_testing as mint, burn_for_testing as burn};
    use sui::balance::{ Self, Balance, create_for_testing as create, destroy_for_testing as destroy};
    use sui::math;

    use liquidlink_protocol::profile::{Self, ProfileRegistry, Profile, AdmincCap};
    use liquidlink_protocol::point::{Self, AddPointRequest, SubPointRequest, PointDashBoard};

    fun people():(address, address, address){
        (@0xA, @0xB, @0xC)
    }

    public struct FAKE_OTW has drop {}
    const UPDATER:address = @0xA;

    // Mocked function for emitting the addPointRequest
    fun send_add_request(
        owner: address,
        value: u256,
        ctx: &mut TxContext
    ){
        point::send_add_point_req_with_assigned_updater<FAKE_OTW>(
            FAKE_OTW{},
            UPDATER,
            owner,
            value,
            ctx
        );
    }
    fun send_sub_request(
        owner: address,
        value: u256,
        ctx: &mut TxContext
    ){
        point::send_sub_point_req_with_assigned_updater<FAKE_OTW>(
            FAKE_OTW{},
            UPDATER,
            owner,
            value,
            ctx
        );
    }

    #[test]
    fun test_protocol() {
        let (a, updater, _) = people();

        let mut scenario = test::begin(@0xA);
        let s = &mut scenario;
        let mut clock = clock::create_for_testing(ctx(s));
        
        profile::init_for_testing(ctx(s));

        // Profile Info
        let avatar_url = string(b"avatar_url");
        let name = string(b"name");
        let description = string(b"description");

        // register
        next_tx(s,a);{
            let mut reg = test::take_shared<ProfileRegistry>(s);
            
            profile::register(&mut reg, avatar_url, name, description, ctx(s));

            test::return_shared(reg);
        };
        next_tx(s,a);{
            let reg = test::take_shared<ProfileRegistry>(s);
            let profile = test::take_from_sender<Profile>(s);
                
            assert!(profile.owner() == a, 404);
            assert!(profile.avatar_url() == avatar_url, 404);
            assert!(profile.name() == name, 404);
            assert!(profile.description() == description, 404);
            assert!(profile.metadata() == sui::vec_map::empty<String, String>(), 404);
            assert!(reg.profile_of(a) == object::id(&profile), 404);

            test::return_shared(reg);
            test::return_to_sender(s, profile);
        };

        // register_module & create dashboard
        next_tx(s,a);{
            let mut reg = test::take_shared<ProfileRegistry>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
        
            profile::register_point_module<FAKE_OTW>(&cap, &mut reg, ctx(s));
            profile::new_point_dashboard<FAKE_OTW>(&cap, &mut reg, ctx(s));

            test::return_shared(reg);
            test::return_to_sender(s, cap);
        };

        let point = 123;
        next_tx(s,a);{
            send_add_request(a, point, ctx(s))
        };

        next_tx(s, a);{
            let mut dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);

            let req = test::take_from_sender<AddPointRequest<FAKE_OTW>>(s);
            dashboard.add_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        // validate points
        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);

            let user_point = dashboard.get_user_points(a);
            assert!(user_point == point, 404);

            test::return_shared(dashboard);
        };

        // sub points
        next_tx(s,a);{
            send_sub_request(a, point, ctx(s))
        };

        next_tx(s, a);{
            let mut dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);

            let req = test::take_from_sender<SubPointRequest<FAKE_OTW>>(s);
            dashboard.sub_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        // validate points
        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);

            let user_point = dashboard.get_user_points(a);
            assert!(user_point == 0, 404);

            test::return_shared(dashboard);
        };

        clock.destroy_for_testing();
        scenario.end();
    }
}
