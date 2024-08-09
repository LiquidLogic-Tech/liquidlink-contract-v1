module liquidlink_periphery::bucket {
    use std::type_name::{Self, TypeName};

    use sui::vec_map::{Self, VecMap};
    use sui::clock::Clock;
    use sui::object_bag::{Self, ObjectBag};
    use sui::event;

    use liquidlink_protocol::profile::{Self, AdmincCap, ProfileRegistry};
    use liquidlink_protocol::point::PointKey;
    use liquidlink_protocol::point_periphery;
    use liquidlink_protocol::utils;

    // === Constants ===
    const BUCKET_VERSION: u64 = 1;

    // === Struct ===
    public struct Bucket has drop {}

    /// time window
    /// repeated times prevent wash-trading
    public struct BucketStateV0 has store{
        /// Mapping assetType to Borrow_state
        borrow: VecMap<TypeName, Borrow>,
        /// Mapping assetType to PSMIn_state
        psm_in: VecMap<TypeName, PSMIn>
    }
    public struct Borrow has store{
        times: u64, 
        acc_collateral_value: u64,
        minted_buck: u64,
        last_update:u64,
    }
    public struct PSMIn has store{
        times: u64, 
        acc_value: u64,
        minted_buck: u64,
        last_update:u64,
    }
    public struct Event has copy, drop{

    }

    public fun new(
        cap: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        let point_key = profile::register_module<Bucket>(cap, reg, ctx);

        let periphery = BucketPeripheryV0{
            id: object::new(ctx),
            point_key: option::some(point_key),
            profile_state: object_bag::new(ctx),
            frequency: 0,
            locked:false
        };

        transfer::share_object(periphery);
    }

    /// Internal logic for calculating points by specific rules determined by each protocol
    public fun calculate_state_v0_point(state: &BucketStateV0):u64{

    }

    fun log_point_data(){
        event::emit(

        )
    }
    
}
