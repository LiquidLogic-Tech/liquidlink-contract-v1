module liquidlink_protocol::profile {
    // === Imports ===
    use std::ascii::{Self, String};
    use std::type_name::{Self, TypeName};

    use sui::vec_map::{Self, VecMap};
    use sui::vec_set::{Self, VecSet};
    use sui::table::{Self, Table};
    use sui::dynamic_field as df;
    use sui::dynamic_object_field as dof;

    use liquidlink_protocol::point::{Self, PointKey};
    use liquidlink_protocol::event;

    // === Errors ===
    const ERR_REGISTERED_MODULE: u64 = 101;
    const ERR_ALREADY_ADDED_STATE: u64 = 102;
    const ERR_NOT_EXIST_STATE: u64 = 103;
    const ERR_NOT_EXIST_MODULE: u64 = 104;

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
        registry: Table<address, ID>,
        modules: VecSet<TypeName>
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

    // === Public-Mutative Functions ===
    public fun borrow_df_state_mut<T, S: store>(
        self: &mut Profile,
        key: &PointKey<T>
    ):&mut S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::borrow_mut(&mut self.id, type_)
    }

    public fun borrow_dof_state_mut<T, S: key + store>(
        self: &mut Profile,
        key: &PointKey<T>
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
            registry: table::new(ctx),
            modules: vec_set::empty()
        };
        transfer::share_object(reg);

        let cap = AdmincCap{ id: object::new(ctx) };

        transfer::transfer(cap, ctx.sender());
    }

    public fun register_point_module<T:drop>(
        _: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ):PointKey<T>{
        assert!(!reg.modules.contains(&type_name::get<T>()), ERR_REGISTERED_MODULE);

        reg.modules.insert(type_name::get<T>());

        point::new_key<T>()
    }

    public fun remove_module<T: drop>(
        _: &AdmincCap,
        profile_key: PointKey<T>,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ){
        assert!(reg.modules.contains(&type_name::get<T>()), ERR_NOT_EXIST_MODULE);
        point::drop_key(profile_key);

        reg.modules.remove(&type_name::get<T>());
    }

    
    // === Public-Package Functions ===
    public fun add_df_state<T, S: store>(
        self: &mut Profile,
        key: &PointKey<T>,
        state: S
    ){
        let type_ = type_name::get<T>();
        assert!(!df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::add(&mut self.id, type_, state);
    }

    public fun add_dof_state<T, S: key + store>(
        self: &mut Profile,
        key: &PointKey<T>,
        state: S
    ){
        let type_ = type_name::get<T>();
        assert!(!dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::add(&mut self.id, type_, state);
    }

    public fun remove_df_state<T, S: store>(
        self: &mut Profile,
        key: &PointKey<T>
    ):S{
        let type_ = type_name::get<T>();
        assert!(df::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        df::remove(&mut self.id, type_)
    }

    public fun remove_dof_state<T, S: key + store>(
        self: &mut Profile,
        key: &PointKey<T>
    ):S{
        let type_ = type_name::get<T>();
        assert!(dof::exists_(&self.id, type_), ERR_ALREADY_ADDED_STATE);

        dof::remove(&mut self.id, type_)
    }

    // === Private Functions ===
    fun new (
        registry: &mut ProfileRegistry,
        avatar_url: String,
        name: String,
        description: String,
        ctx: &mut TxContext
    ): Profile {
        let owner = ctx.sender();
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

    fun destroy(
        profile: Profile,
        reg: &mut ProfileRegistry,
        ctx: &TxContext
    ) {
        let Profile {
            id,
            owner: _,
            avatar_url: _,
            name: _,
            description: _,
            metadata: _,
        } = profile;

        event::profile_destroyed(ctx.sender(), id.uid_to_inner());

        object::delete(id);
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
            registry: table::new(ctx),
            modules: vec_set::empty()
        };
        let profile_key = point::new_key<PROFILE>();
        let mut profile = new(&mut registry, ascii::string(b""), ascii::string(b""), ascii::string(b""), ctx);
        profile.add_df_state(
            &profile_key,
            DFState{}
        );

        profile.add_dof_state(&profile_key, DOFState{id: object::new(ctx)});

        profile.destroy(&mut registry, ctx);

        test_utils::destroy(registry);
        test_utils::destroy(profile_key);
    }
}
