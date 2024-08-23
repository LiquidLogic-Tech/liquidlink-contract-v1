module liquidlink_protocol::profile {
    // === Imports ===
    use std::ascii::{Self, String};
    use std::type_name::{Self, TypeName};

    use sui::vec_map::{Self, VecMap};
    use sui::vec_set::{Self, VecSet};
    use sui::table::{Self, Table};
    use sui::dynamic_field as df;
    use sui::dynamic_object_field as dof;

    use liquidlink_protocol::point::{Self, PointKey, AddPointRequest, SubPointRequest, PointDashBoard};
    use liquidlink_protocol::event;

    // === Errors ===
    const ERR_REGISTERED_MODULE: u64 = 101;
    const ERR_ALREADY_ADDED_STATE: u64 = 102;
    const ERR_NOT_EXIST_STATE: u64 = 103;
    const ERR_NOT_EXIST_TYPE: u64 = 104;
    const ERR_ALREADY_REGISTERED: u64 = 105;

    // === Constants ===
    const VERSION: u64 = 1;
    const NAME: vector<u8> = b"{name}";
    const IMAGE_URL: vector<u8> = b"https://liquidlink.io/api/profile/{id}/image";
    const DESCRIPTION: vector<u8> = b"{name}'s profile at LiquidLink. Check it out at https://liquidlink.io/{id}. Create your own at https://liquidlink.io";

    public struct PROFILE has drop {}

    // === Structs ===
    public struct AdmincCap has key, store {
        id: UID
    }

    public struct ProfileRegistry has key{
        id: UID,
        version: u64,
        /// Mapping owner address to Profile ID
        registry: Table<address, ID>
    }

    public struct Profile has key{
        id: UID,
        owner: address,
        avatar_url: String,
        name: String,
        description: String,
        metadata: VecMap<String, String>
    }

    // === Method Aliases ===

    // === Public-View Functions ===
    public fun owner(self: &Profile):address{
        self.owner
    }
    public fun avatar_url(self: &Profile):String{
        self.avatar_url
    }
    public fun name(self: &Profile):String{
        self.name
    }
    public fun description(self: &Profile):String{
        self.description
    }
    public fun metadata(self: &Profile):VecMap<String, String>{
        self.metadata
    }
    public fun profile_contains(reg: &ProfileRegistry, owner: address):bool{
        reg.registry.contains(owner)
    }
    public fun profile_of(reg: &ProfileRegistry, owner: address):ID{
        *reg.registry.borrow(owner)
    }
    // Point
    public fun point_key<T: drop>(reg: &ProfileRegistry):&PointKey<T>{
        df::borrow(&reg.id, type_name::get<T>())
    }

    public fun borrow_df_state<T, S: store>(
        self: &Profile,
        key: &PointKey<T>
    ):&S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::borrow(&self.id, type_)
    }
    public fun borrow_dof_state<T, S: key + store>(
        self: &Profile,
        key: &PointKey<T>
    ):&S{
        let type_ = type_name::get<T>();
        assert!(dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::borrow(&self.id, type_)
    }

    public fun df_state_exists<T, S: store>(
        self: &Profile,
        key: &PointKey<T>
    ):bool{
        let type_ = type_name::get<T>();
        df::exists_(&self.id, type_)
    }
    public fun dof_state_exists<T, S: key + store>(
        self: &Profile,
        key: &PointKey<T>
    ):bool{
        let type_ = type_name::get<T>();
        dof::exists_(&self.id, type_)
    }

    public fun df_state_exists_with_type<T, S: store>(
        self: &Profile,
        key: &PointKey<T>,
    ):bool{
        let type_ = type_name::get<T>();
        df::exists_with_type<TypeName, S>(&self.id, type_)
    }
    public fun dof_state_exists_with_type<T, S: key + store>(
        self: &Profile,
        key: &PointKey<T>
    ):bool{
        let type_ = type_name::get<T>();
        dof::exists_with_type<TypeName, S>(&self.id, type_)
    }
    public fun module_exist<T: drop>(
        reg: &ProfileRegistry
    ):bool{
        let type_ = type_name::get<T>();
        df::exists_(&reg.id, type_)
    }

    // === Public-Mutative Functions ===
    public fun point_key_mut<T: drop>(
        reg: &mut ProfileRegistry,
        witness: T
    ):&mut PointKey<T>{
        df::borrow_mut(&mut reg.id, type_name::get<T>())
    }
    public fun borrow_df_state_mut<T, S: store>(
        self: &mut Profile,
        key: &mut PointKey<T>
    ):&mut S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::borrow_mut(&mut self.id, type_)
    }

    public fun borrow_dof_state_mut<T, S: key + store>(
        self: &mut Profile,
        key: &mut PointKey<T>
    ):&mut S{
        let type_ = type_name::get<T>();
        assert!(dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::borrow_mut(&mut self.id, type_)
    }

    // === Admin Functions ===
    fun init(owt: PROFILE, ctx: &mut TxContext){
        let reg = ProfileRegistry{
            id: object::new(ctx),
            version: VERSION,
            registry: table::new(ctx)
        };
        transfer::share_object(reg);

        let cap = AdmincCap{ id: object::new(ctx) };
        transfer::transfer(cap, ctx.sender());
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(PROFILE{}, ctx);
    }

    public fun register_point_module<T:drop>(
        _: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        let type_ = type_name::get<T>();
        assert!(!df::exists_(&reg.id, type_), ERR_REGISTERED_MODULE);

        let key = point::new_point_key<T>();
        df::add(&mut reg.id, type_, key);
    }

    public fun remove_point_module<T: drop>(
        _: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        let type_ = type_name::get<T>();
        assert!(df::exists_(&reg.id, type_), ERR_NOT_EXIST_TYPE);

        let profile_key:PointKey<T> = df::remove(&mut reg.id, type_);
        point::drop_point_key(profile_key);
    }

    public fun new_point_dashboard<T: drop>(
        cap: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        if(!module_exist<T>(reg)) register_point_module<T>(cap, reg, ctx);
        let dashboard = point::new_point_dashboard<T>(ctx);
        transfer::public_share_object(dashboard);
    }

    public fun add_point_by_admin<T>(
        dashboard: &mut PointDashBoard<T>,
        _: &AdmincCap,
        req: AddPointRequest<T>
    ){
        point::add_point(dashboard, req);
    }

    public fun sub_point_by_admin<T>(
        dashboard: &mut PointDashBoard<T>,
        _: &AdmincCap,
        req: SubPointRequest<T>
    ){
        point::sub_point(dashboard, req);
    }

    // === Public-Package Functions ===
    public fun register(
        reg: &mut ProfileRegistry,
        avatar_url: String,
        name: String,
        description: String,
        ctx: &mut TxContext
    ){
        let owner = ctx.sender();
        let profile = register_(reg, owner, avatar_url, name, description, ctx);

        transfer::transfer(profile, owner);
    }

    public fun register_for(
        reg: &mut ProfileRegistry,
        owner: address,
        avatar_url: String,
        name: String,
        description: String,
        ctx: &mut TxContext
    ){
        let profile = register_(reg, owner, avatar_url, name, description, ctx);

        transfer::transfer(profile, owner);
    }
    public fun drop(
        profile: Profile,
        reg: &mut ProfileRegistry
    ){
        let Profile {
            id,
            owner,
            avatar_url: _,
            name: _,
            description: _,
            metadata: _,
        } = profile;

        let profile_id = reg.registry.remove(owner);

        event::profile_destroyed(owner, profile_id);
        object::delete(id);
    }

    public fun add_df_state<T, S: store>(
        self: &mut Profile,
        key: &mut PointKey<T>,
        state: S
    ){
        let type_ = type_name::get<T>();
        assert!(!df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::add(&mut self.id, type_, state);
    }

    public fun add_dof_state<T, S: key + store>(
        self: &mut Profile,
        key: &mut PointKey<T>,
        state: S
    ){
        let type_ = type_name::get<T>();
        assert!(!dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::add(&mut self.id, type_, state);
    }

    public fun remove_df_state<T, S: store>(
        self: &mut Profile,
        key: &mut PointKey<T>
    ):S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_NOT_EXIST_STATE);

        df::remove(&mut self.id, type_)
    }

    public fun remove_dof_state<T, S: key + store>(
        self: &mut Profile,
        key: &mut PointKey<T>
    ):S{
        let type_ = type_name::get<T>();
        assert!(dof::exists_(&self.id, type_), ERR_NOT_EXIST_STATE);

        dof::remove(&mut self.id, type_)
    }

    // === Private Functions ===
    fun new (
        reg: &mut ProfileRegistry,
        owner: address,
        avatar_url: String,
        name: String,
        description: String,
        ctx: &mut TxContext
    ): Profile {
        let profile = Profile{
            id: object::new(ctx),
            owner,
            avatar_url,
            name,
            description,
            metadata: vec_map::empty()
        };
        
        event::profile_created(owner, object::id(&profile));
        profile
    }
    fun register_(
        reg: &mut ProfileRegistry,
        owner: address,
        avatar_url: String,
        name: String,
        description: String,
        ctx: &mut TxContext
    ):Profile{
        let profile = Profile{
            id: object::new(ctx),
            owner,
            avatar_url,
            name,
            description,
            metadata: vec_map::empty()
        };
        let profile_id = object::id(&profile);
        event::profile_created(owner, profile_id);
        reg.registry.add(owner, profile_id);
        
        profile
    }

    // === Test Functions ===
    #[test_only]
    use sui::test_utils;
    #[test_only]
    public struct DFState has store{}
    #[test_only]
    public struct DOFState has key, store{
        id: UID
    }
    #[test]
    fun test_basic(){
        let mut tx_context = sui::tx_context::dummy();
        let ctx = &mut tx_context;
        
        let mut registry = ProfileRegistry{
            id: object::new(ctx),
            version: VERSION,
            registry: table::new(ctx)
        };
        let mut profile_key = point::new_point_key<PROFILE>();
        let mut profile = register_(&mut registry, @0xA, ascii::string(b""), ascii::string(b""), ascii::string(b""), ctx);
        profile.add_df_state(
            &mut profile_key,
            DFState{}
        );

        profile.add_dof_state(&mut profile_key, DOFState{id: object::new(ctx)});

        profile.drop(&mut registry);

        test_utils::destroy(registry);
        test_utils::destroy(profile_key);
    }
}
