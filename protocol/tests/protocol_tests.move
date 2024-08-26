#[test_only]
module liquidlink_protocol::protocol_tests {
    use std::ascii::{Self, string, String};

    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::clock::{Self, Clock, increment_for_testing as add_time, set_for_testing as set_time};
    use sui::coin::{ Self, Coin, TreasuryCap, CoinMetadata, mint_for_testing as mint, burn_for_testing as burn};
    use sui::balance::{ Self, Balance, create_for_testing as create, destroy_for_testing as destroy};
    use sui::math;

    use liquidlink_protocol::profile::{Self, ProfileRegistry, Profile, AdmincCap};
    use liquidlink_protocol::point::{Self, AddPointRequest, SubPointRequest, StakePointRequest, UnstakePointRequest, PointDashBoard};

    fun people():(address, address, address){
        (@0xA, @0xB, @0xC)
    }

    public struct FAKE_OTW has drop {}

    public struct FAKE_BORROW {}
    
    public struct FakeProfileState has key, store{
        id: UID,
        value: u64
    }
    fun drop_state(s: FakeProfileState){
        let FakeProfileState{
            id,
            value: _
        } = s;
        object::delete(id);
    }
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

    fun send_stake_request<Action>(
        owner: address,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        point::send_stake_point_req_with_assigned_updater<FAKE_OTW, Action>(
            FAKE_OTW{},
            UPDATER,
            owner,
            weight,
            duration,
            clock,
            ctx
        );
    }

    fun send_unstake_request<Action>(
        owner: address,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        point::send_unstake_point_req_with_assigned_updater<FAKE_OTW, Action>(
            FAKE_OTW{},
            UPDATER,
            owner,
            weight,
            duration,
            clock,
            ctx
        );
    }

    fun setup():(Scenario, Clock){
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

        (scenario, clock)
    }

    #[test]
    fun test_basic() {
        let (a, updater, _) = people();
        let (mut scenario, clock) = setup();
        let s = &mut scenario;

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

            let user_point = dashboard.get_user_iufo_points(a, &clock);
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
            let user_point = dashboard.get_user_iufo_points(a, &clock);

            assert!(user_point == 0, 404);

            test::return_shared(dashboard);
        };

        // insert the state into profile slot 
        next_tx(s,a);{
            let mut reg = test::take_shared<ProfileRegistry>(s);
            let point_key_mut = profile::point_key_mut<FAKE_OTW>(&mut reg, FAKE_OTW{});
            let mut profile = test::take_from_sender<Profile>(s);
            // update both df & dof state
            profile.add_df_state<FAKE_OTW,FakeProfileState>(point_key_mut, FakeProfileState{
                id: object::new(ctx(s)),
                value: 0
            });
            profile.add_dof_state<FAKE_OTW,FakeProfileState>(point_key_mut, FakeProfileState{
                id: object::new(ctx(s)),
                value: 0
            });
            
            test::return_to_sender(s, profile);
            test::return_shared(reg);
        };

        // retrieve the profile state
        next_tx(s,a);{
            let reg = test::take_shared<ProfileRegistry>(s);
            // don't require witness instance
            let point_key = profile::point_key<FAKE_OTW>(&reg);
            let profile = test::take_from_sender<Profile>(s);
            // update both df & dof state
            let df_state = profile.borrow_df_state<FAKE_OTW, FakeProfileState>(point_key);
            let dof_state = profile.borrow_dof_state<FAKE_OTW, FakeProfileState>(point_key);

            assert!(df_state.value == 0, 404);
            assert!(df_state.value == dof_state.value, 404);
            
            test::return_to_sender(s, profile);
            test::return_shared(reg);
        };

        // remove the state
        next_tx(s,a);{
            let mut reg = test::take_shared<ProfileRegistry>(s);
            let point_key_mut = profile::point_key_mut<FAKE_OTW>(&mut reg, FAKE_OTW{});
            let mut profile = test::take_from_sender<Profile>(s);
            // update both df & dof state
            let df_state = profile.remove_df_state<FAKE_OTW,FakeProfileState>(point_key_mut);
            df_state.drop_state();
            let dof_state = profile.remove_dof_state<FAKE_OTW,FakeProfileState>(point_key_mut);
            dof_state.drop_state();
            
            test::return_to_sender(s, profile);
            test::return_shared(reg);
        };
        
        // burn the profile
        next_tx(s,a);{
            let mut reg = test::take_shared<ProfileRegistry>(s);
            let profile = test::take_from_sender<Profile>(s);
            
            profile.drop(&mut reg);
            assert!(reg.profile_contains(a) == false, 404);

            test::return_shared(reg);
        };


        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    public fun test_stake(){
        let (a, updater, _) = people();
        let (mut scenario, mut clock) = setup();
        let s = &mut scenario;

        // stake point
        next_tx(s,a);{
            let weight = 1_000_000_000; // 1 SU1
            let duration = 86400 * 1000; // 1 day in ms
            send_stake_request<FAKE_BORROW>(a, weight, duration, &clock, ctx(s));
        };

        next_tx(s, a);{
            let mut dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
            let req = test::take_from_sender<StakePointRequest<FAKE_OTW, FAKE_BORROW>>(s);

            dashboard.stake_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        // validation
        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let user_point = dashboard.get_user_iufo_points(a, &clock);

            assert!(user_point == 0, 404);

            test::return_shared(dashboard);
        };

        // past 1 day
        clock.add_time(86400 * 1000);
        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let user_point = dashboard.get_user_iufo_points(a, &clock);

            assert!(user_point == 1_000_000_000, 404);

            test::return_shared(dashboard);
        };

        // past 6 day
        clock.add_time(6 * 86400 * 1000);
        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let user_point = dashboard.get_user_iufo_points(a, &clock);

            assert!(user_point == 7 * 1_000_000_000, 404);

            test::return_shared(dashboard);
        };

        // unstake half point
        next_tx(s,a);{
            let weight = 0_500_000_000; // 1 SU1
            let duration = 86400 * 1000; // 1 day in ms
            send_unstake_request<FAKE_BORROW>(a, weight, duration, &clock, ctx(s));
        };

        next_tx(s, a);{
            let mut dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
            let req = test::take_from_sender<UnstakePointRequest<FAKE_OTW, FAKE_BORROW>>(s);

            dashboard.unstake_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        // past 1 day
        clock.add_time(1 * 86400 * 1000);
        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let user_point = dashboard.get_user_iufo_points(a, &clock);
            assert!(user_point == 7 * 1_000_000_000 + 0_500_000_000, 404);

            test::return_shared(dashboard);
        };

        // past 6 days
        clock.add_time(6 * 86400 * 1000);
        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let user_point = dashboard.get_user_iufo_points(a, &clock);

            assert!(user_point == 7 * 1_000_000_000 + 7 * 0_500_000_000, 404);

            test::return_shared(dashboard);
        };

        // add point
        next_tx(s,a);{
            send_add_request(a, 0_500_000_000, ctx(s))
        };

        next_tx(s, a);{
            let mut dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);

            let req = test::take_from_sender<AddPointRequest<FAKE_OTW>>(s);
            dashboard.add_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);

            let user_point = dashboard.get_user_iufo_points(a, &clock);
            assert!(user_point == 11 * 1_000_000_000, 404);

            test::return_shared(dashboard);
        };

        // sub points
        next_tx(s,a);{
            send_sub_request(a, 6 * 1_000_000_000, ctx(s))
        };

        next_tx(s, a);{
            let mut dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let cap = test::take_from_sender<AdmincCap>(s);
            let req = test::take_from_sender<SubPointRequest<FAKE_OTW>>(s);

            dashboard.sub_point_by_admin(&cap, req);
    
            test::return_to_sender(s, cap);
            test::return_shared(dashboard);
        };

        next_tx(s,a);{
            let dashboard = test::take_shared<PointDashBoard<FAKE_OTW>>(s);
            let user_point = dashboard.get_user_iufo_points(a, &clock);

            assert!(user_point == 5 * 1_000_000_000, 404);

            test::return_shared(dashboard);
        };
        

        clock.destroy_for_testing();
        scenario.end();
    }
}
