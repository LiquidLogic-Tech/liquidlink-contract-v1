module liquidlink_protocol::profile {
    // === Imports ===
    use std::ascii::{Self, String};
    use std::type_name::{Self, TypeName};
    use std::string::utf8;

    use sui::vec_map::{Self, VecMap};
    use sui::table::{Self, Table};
    use sui::dynamic_field as df;
    use sui::dynamic_object_field as dof;
    use sui::display;
    use sui::package;
    use sui::clock::Clock;

    use liquidlink_protocol::point::{Self, PointKey, AddPointRequest, SubPointRequest, StakePointRequest, UnstakePointRequest, PointDashBoard};
    use liquidlink_protocol::event;

    // === Errors ===
    const ERR_REGISTERED_MODULE: u64 = 101;
    const ERR_ALREADY_ADDED_STATE: u64 = 102;
    const ERR_NOT_EXIST_STATE: u64 = 103;
    const ERR_NOT_EXIST_TYPE: u64 = 104;

    // === Constants ===
    const VERSION: u64 = 1;
    // display fields
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
        created_at: u64,
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
        _key: &PointKey<T>
    ):&S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::borrow(&self.id, type_)
    }
    public fun borrow_dof_state<T, S: key + store>(
        self: &Profile,
        _key: &PointKey<T>
    ):&S{
        let type_ = type_name::get<T>();
        assert!(dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::borrow(&self.id, type_)
    }

    public fun df_state_exists<T>(
        self: &Profile,
        _key: &PointKey<T>
    ):bool{
        let type_ = type_name::get<T>();
        df::exists_(&self.id, type_)
    }
    public fun dof_state_exists<T>(
        self: &Profile,
        _key: &PointKey<T>
    ):bool{
        let type_ = type_name::get<T>();
        dof::exists_(&self.id, type_)
    }

    public fun df_state_exists_with_type<T, S: store>(
        self: &Profile,
        _key: &PointKey<T>
    ):bool{
        let type_ = type_name::get<T>();
        df::exists_with_type<TypeName, S>(&self.id, type_)
    }
    public fun dof_state_exists_with_type<T, S: key + store>(
        self: &Profile,
        _key: &PointKey<T>
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
        _: T
    ):&mut PointKey<T>{
        df::borrow_mut(&mut reg.id, type_name::get<T>())
    }
    public fun borrow_df_state_mut<T, S: store>(
        self: &mut Profile,
        _: &mut PointKey<T>
    ):&mut S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::borrow_mut(&mut self.id, type_)
    }

    public fun borrow_dof_state_mut<T, S: key + store>(
        self: &mut Profile,
        _key: &PointKey<T>
    ):&mut S{
        let type_ = type_name::get<T>();
        assert!(dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::borrow_mut(&mut self.id, type_)
    }

    // === Admin Functions ===
    fun init(otw: PROFILE, ctx: &mut TxContext){
        let admin = ctx.sender();
        let reg = ProfileRegistry{
            id: object::new(ctx),
            version: VERSION,
            registry: table::new(ctx)
        };
        transfer::share_object(reg);

        let cap = AdmincCap{ id: object::new(ctx) };
        transfer::transfer(cap, admin);

        // display 
        let keys = vector[
            utf8(b"name"),
            utf8(b"image_url"),
            utf8(b"description"),
        ];
        let values = vector[
            utf8(NAME),
            utf8(IMAGE_URL),
            utf8(DESCRIPTION),
        ];
        let publisher = package::claim(otw, ctx);
        let mut display = display::new_with_fields<Profile>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(publisher, admin);
        transfer::public_transfer(display, admin);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(PROFILE{}, ctx);
    }

    public fun register_point_module<T:drop>(
        _: &AdmincCap,
        reg: &mut ProfileRegistry
    ){
        let type_ = type_name::get<T>();
        assert!(!df::exists_(&reg.id, type_), ERR_REGISTERED_MODULE);

        let key = point::new_point_key<T>();
        df::add(&mut reg.id, type_, key);
    }

    public fun remove_point_module<T: drop>(
        _: &AdmincCap,
        reg: &mut ProfileRegistry
    ){
        let type_ = type_name::get<T>();
        assert!(df::exists_(&reg.id, type_), ERR_NOT_EXIST_TYPE);

        let profile_key:PointKey<T> = df::remove(&mut reg.id, type_);
        point::drop_point_key(profile_key);
    }

    #[allow(lint(share_owned))]
    entry public fun new_point_dashboard<T: drop>(
        cap: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        if(!module_exist<T>(reg)) register_point_module<T>(cap, reg);
        let dashboard = point::new_point_dashboard<T>(ctx);
        transfer::public_share_object(dashboard);
    }

    public fun add_point_by_admin<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        _: &AdmincCap,
        req: AddPointRequest<T>
    ){
        point::add_point(dashboard, req);
    }

    public fun sub_point_by_admin<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        _: &AdmincCap,
        req: SubPointRequest<T>
    ){
        point::sub_point(dashboard, req);
    }

    public fun stake_point_by_admin<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        _: &AdmincCap,
        req: StakePointRequest<T>,
    ){
        point::stake_point<T>(dashboard, req);
    }

    public fun unstake_point_by_admin<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        _: &AdmincCap,
        req: UnstakePointRequest<T>
    ){
        point::unstake_point<T>(dashboard, req);
    }

    // === Public-Package Functions ===
    public fun register(
        reg: &mut ProfileRegistry,
        avatar_url: String,
        name: String,
        description: String,
        metadata_keys: vector<String>,
        metadata_values: vector<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let owner = ctx.sender();
        let metadata = vec_map::from_keys_values(metadata_keys, metadata_values);
        let profile = register_(reg, owner, clock.timestamp_ms(), avatar_url, name, description, metadata, ctx);

        transfer::transfer(profile, owner);
    }

    public fun register_for(
        reg: &mut ProfileRegistry,
        owner: address,
        avatar_url: String,
        name: String,
        description: String,
        metadata_keys: vector<String>,
        metadata_values: vector<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let metadata = vec_map::from_keys_values(metadata_keys, metadata_values);
        let profile = register_(reg, owner, clock.timestamp_ms(), avatar_url, name, description, metadata, ctx);

        transfer::transfer(profile, owner);
    }
    public fun drop(
        profile: Profile,
        reg: &mut ProfileRegistry
    ){
        let Profile {
            id,
            owner,
            created_at: _,
            avatar_url: _,
            name: _,
            description: _,
            metadata: _,
        } = profile;

        let profile_id = reg.registry.remove(owner);

        event::profile_destroyed(owner, profile_id);
        object::delete(id);
    }

    public fun update_avatar_url(
        self: &mut Profile,
        url: String,
    ){
        self.avatar_url = url;
    }

    public fun update_name(
        self: &mut Profile,
        name: String,
    ){
        self.name = name;
    }

    public fun update_description(
        self: &mut Profile,
        description: String,
    ){
        self.description = description;
    }

    public fun update_metadata(
        self: &mut Profile,
        key: String,
        value: String
    ){
        if(self.metadata.contains(&key)){
            let prev_value = &mut self.metadata[&key];
            *prev_value = value;
        }else{
            self.metadata.insert(key, value);
        };
    }

    public fun remove_metadata(
        self: &mut Profile,
        key: String
    ){
        self.metadata.remove(&key);
    }

    public fun add_df_state<T, S: store>(
        self: &mut Profile,
        _key: &mut PointKey<T>,
        state: S
    ){
        let type_ = type_name::get<T>();
        assert!(!df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::add(&mut self.id, type_, state);
    }

    public fun add_dof_state<T, S: key + store>(
        self: &mut Profile,
        _key: &mut PointKey<T>,
        state: S
    ){
        let type_ = type_name::get<T>();
        assert!(!dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::add(&mut self.id, type_, state);
    }

    public fun remove_df_state<T, S: store>(
        self: &mut Profile,
        _key: &mut PointKey<T>,
    ):S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_NOT_EXIST_STATE);

        df::remove(&mut self.id, type_)
    }

    public fun remove_dof_state<T, S: key + store>(
        self: &mut Profile,
        _key: &mut PointKey<T>
    ):S{
        let type_ = type_name::get<T>();
        assert!(dof::exists_(&self.id, type_), ERR_NOT_EXIST_STATE);

        dof::remove(&mut self.id, type_)
    }

    // === Private Functions ===
    fun register_(
        reg: &mut ProfileRegistry,
        owner: address,
        created_at: u64,
        avatar_url: String,
        name: String,
        description: String,
        metadata: VecMap<String, String>,
        ctx: &mut TxContext
    ):Profile{
        let profile = Profile{
            id: object::new(ctx),
            owner,
            created_at,
            avatar_url,
            name,
            description,
            metadata
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
        let mut profile = register_(&mut registry, @0xA, 1000, ascii::string(b""), ascii::string(b""), ascii::string(b""), vec_map::empty(), ctx);
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
