module liquidlink_protocol::point_periphery {
    use std::type_name::{Self, TypeName};

    use sui::vec_map::{Self, VecMap};
    use sui::clock::Clock;
    use sui::object_bag::{Self, ObjectBag};

    use liquidlink_protocol::profile::{Self, AdmincCap, ProfileRegistry};
    use liquidlink_protocol::point::PointKey;
    use liquidlink_protocol::utils;

    public struct PeripheryV0<phantom T> has key{
        id: UID,
        version: u64,
        /// key to access profile NFT's state and update point system
        point_key: Option<PointKey<T>>,
        /// frequency to record the info
        frequency: u64,
        /// locked
        locked: bool,
        /// Mapping <OwnerAddress> to <Customized State>
        profile_state: ObjectBag
    }

    // === Public-View Functions ===
    fun version<T>(self: &PeripheryV0<T>):u64{
        self.version
    }
    fun point_key<T>(self: &PeripheryV0<T>):&Option<PointKey<T>>{
        &self.point_key
    }
    fun frequency<T>(self: &PeripheryV0<T>):u64{
        self.frequency
    }
    fun locked<T>(self: &PeripheryV0<T>):bool{
        self.locked
    }
    fun profile_state<T>(self: &PeripheryV0<T>):&ObjectBag{
        &self.profile_state
    }

    // === Public-Mutative Functions ===
    fun point_key_mut<T>(self: &mut PeripheryV0<T>):&mut Option<PointKey<T>>{
        &mut self.point_key
    }
    fun profile_state_mut<T>(self: &mut PeripheryV0<T>):&mut ObjectBag{
        &mut self.profile_state
    }

    // === Admin Functions ===
    public fun update_version<T>(
        self: &mut PeripheryV0<T>,
        _: &AdmincCap,
        version: u64
    ){
        self.version = version;
    }
    public fun update_frequency<T>(
        self: &mut PeripheryV0<T>,
        _: &AdmincCap,
        frequency: u64
    ){
        self.frequency = frequency;
    }
    public fun update_locked<T>(
        self: &mut PeripheryV0<T>,
        _: &AdmincCap,
        locked: bool
    ){
        self.locked = locked;
    }

    public fun new<T:drop>(
        cap: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        let point_key = profile::register_module<T>(cap, reg, ctx);

        let periphery = PeripheryV0<T>{
            id: object::new(ctx),
            version: 1,
            point_key: option::some(point_key),
            frequency: 0,
            locked:false,
            profile_state: object_bag::new(ctx),
        };

        transfer::share_object(periphery);
    }
}
