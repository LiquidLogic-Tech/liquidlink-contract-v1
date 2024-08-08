module liquidlink_periphery::bucket {
    use std::type_name::{Self, TypeName};

    use sui::vec_map::{Self, VecMap};
    use sui::clock::Clock;
    use sui::object_bag::{Self, ObjectBag};

    use liquidlink_protocol::profile::{Self, AdmincCap, ProfileRegistry};
    use liquidlink_protocol::point::PointKey;
    use liquidlink_protocol::utils;

    public struct Bucket has drop {}

    /// time window
    /// repeated times prevent wash-trading
    public struct BucketPeripheryV0 has key{
        id: UID,
        point_key: Option<PointKey<Bucket>>,
        /// Mapping owner address to BucketStateV0
        profile_state: ObjectBag,
        /// frequency
        frequency: u64,
        /// locked
        locked: bool
    }

    public struct BucketStateV0 has store{
        /// Mapping assetType to Borrow_state
        borrow: VecMap<TypeName, Borrow>,
        /// Mapping assetType to PSM_state
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

    fun is_valid_time(last_update: u64, frequency:u64, clock: &Clock):bool{
        (last_update + frequency <= utils::timestamp_sec(clock))
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
    
}
