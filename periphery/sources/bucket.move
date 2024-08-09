module liquidlink_periphery::bucket {
    use std::type_name::{Self, TypeName};

    use sui::vec_map::{Self, VecMap};
    use sui::clock::Clock;
    use sui::object_bag::{Self, ObjectBag};
    use sui::event;

    use liquidlink_protocol::profile::{Self, AdmincCap, ProfileRegistry};
    use liquidlink_protocol::point::PointKey;
    use liquidlink_protocol::utils;

    // === Constants ===
    const BUCKET_VERSION: u64 = 1;

    // === Struct ===
    public struct Bucket has drop {}

    public struct BucketPointPeripheryV0 has key{
        id: UID,
        version: u64,
        /// key to access profile NFT's state and update point system
        point_key: Option<PointKey<Bucket>>,
        /// frequency to record the info
        frequency: u64,
        /// locked
        locked: bool,
        /// Mapping <OwnerAddress> to <BucketStateV0>
        profile_state: ObjectBag,
        /// Weights information
        borrow_weights: VecMap<TypeName, Weights>,
        psm_in_weights: VecMap<TypeName, Weights>
    }
    public struct Weights has store{
        asset: u64,
        minted_buck: u64
    }

    /// the state we're going to store in PointPeriphery's profile state
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
    public struct BorrowLog<T> has copy, drop{
        times: u64,
        collateral_value: u64,
        minted_buck: u64,
        update_at: u64
    }

    public struct PSMIn has store{
        times: u64, 
        acc_value: u64,
        minted_buck: u64,
        last_update:u64,
    }
    public struct PSMInLog<T> has copy, drop{
        times: u64,
        swapped_value: u64,
        minted_buck: u64,
        update_at: u64
    }


    // === Public-View Functions ===
    public fun version(self: &BucketPointPeripheryV0):u64{
        self.version
    }
    public fun point_key(self: &BucketPointPeripheryV0):&Option<PointKey<Bucket>>{
        &self.point_key
    }
    public fun frequency(self: &BucketPointPeripheryV0):u64{
        self.frequency
    }
    public fun locked(self: &BucketPointPeripheryV0):bool{
        self.locked
    }
    public fun profile_state(self: &BucketPointPeripheryV0):&ObjectBag{
        &self.profile_state
    }

    // === Admin Functions ===
    public fun update_version(
        self: &mut BucketPointPeripheryV0,
        _: &AdmincCap,
        version: u64
    ){
        self.version = version;
    }
    public fun update_frequency(
        self: &mut BucketPointPeripheryV0,
        _: &AdmincCap,
        frequency: u64
    ){
        self.frequency = frequency;
    }
    public fun update_locked(
        self: &mut BucketPointPeripheryV0,
        _: &AdmincCap,
        locked: bool
    ){
        self.locked = locked;
    }
    public fun update_borrow_weights<T>(
        self: &mut BucketPointPeripheryV0,
        _: &AdmincCap,
        is_asset: bool,
        val: u64
    ){
        let weights = &mut self.borrow_weights;
        let type_ = type_name::get<T>();
        if(!weights.contains(&type_)){
            let weight = Weights{
                asset: 0,
                minted_buck: 0
            };
            weights.insert(type_, weight);
        };

        let weight = &mut weights[&type_];
        if(is_asset) weight.asset = val else weight.minted_buck = val;
    }
    public fun update_psm_in_weights<T>(
        self: &mut BucketPointPeripheryV0,
        _: &AdmincCap,
        is_asset: bool,
        val: u64
    ){
        let weights = &mut self.psm_in_weights;
        let type_ = type_name::get<T>();
        if(!weights.contains(&type_)){
            let weight = Weights{
                asset: 0,
                minted_buck: 0
            };
            weights.insert(type_, weight);
        };

        let weight = &mut weights[&type_];
        if(is_asset) weight.asset = val else weight.minted_buck = val;
    }


    public fun new<T:drop>(
        cap: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        let point_key = profile::register_point_module(cap, reg, ctx);
        let periphery = BucketPointPeripheryV0{
            id: object::new(ctx),
            version: BUCKET_VERSION,
            point_key: option::some(point_key),
            frequency: 0,
            locked:false,
            profile_state: object_bag::new(ctx),
            borrow_weights: vec_map::empty(),
            psm_in_weights: vec_map::empty()
        };

        transfer::share_object(periphery);
    }

    /// Internal logic for calculating points by specific rules determined by each protocol
    public fun calculate_state_v0_point(state: &BucketStateV0):u64{
        0
    }

    fun is_valid_version(self: &BucketPointPeripheryV0):bool{
        self.version == BUCKET_VERSION
    }

    fun log_point_data(){
        event::emit(

        )
    }
    
}
