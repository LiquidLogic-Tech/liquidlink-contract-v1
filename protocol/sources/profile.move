module liquidlink_protocol::profile {
    // === Imports ===
    use std::ascii::String;
    use std::type_name::{Self, TypeName};

    use sui::vec_map::{Self, VecMap};
    use sui::vec_set::{Self, VecSet};
    use sui::table::{Self, Table};
    use sui::dynamic_field as df;
    use sui::dynamic_object_field as dof;

    use liquidlink_protocol::event;

    // === Errors ===
    const ERR_REGISTERED_MODULE: u64 = 101;

    // === Constants ===
    const NAME: vector<u8> = b"{display_name}";
    const IMAGE_URL: vector<u8> = b"https://liquidlink.io/api/profile/{id}/image";
    const DESCRIPTION: vector<u8> = b"{display_name}'s profile at LiquidLink. Check it out at https://liquidlink.io/{id}. Create your own at https://liquidlink.io";

    public struct PROFILE has drop {}

    // === Structs ===
    public struct AdmincCap has key, store {
        id: UID
    }

    public struct ProfileRegistry has key{
        id: UID,
        /// Mapping owner address to Profile ID
        registry: Table<address, ID>,
        modules: VecSet<TypeName>
    }

    /// Key of Profile tp access dynamic field or object dyanmic fields state
    public struct ProfileKey<phantom T> has key, store{
        id: UID
    }

    public struct Profile has key{
        id: UID,
        avatar_url: String,
        display_name: String,
        description: String,
        metadata: VecMap<String, String>
    }

    // === Method Aliases ===

    // === Public-Mutative Functions ===

    // === Public-View Functions ===

    // === Admin Functions ===
    fun init(owt: PROFILE, ctx: &mut TxContext){
        let reg = ProfileRegistry{
            id: object::new(ctx),
            registry: table::new(ctx),
            modules: vec_set::empty()
        };
        transfer::share_object(reg);

        let cap = AdmincCap{ id: object::new(ctx) };

        transfer::transfer(cap, ctx.sender());
    }

    public fun register_key<T:drop>(
        _: &AdmincCap,
        reg: &mut ProfileRegistry,
        ctx: &mut TxContext
    ):ProfileKey<T>{
        assert!(!reg.modules.contains(&type_name::get<T>()), ERR_REGISTERED_MODULE);

        reg.modules.insert(type_name::get<T>());

        ProfileKey<T>{
            id: object::new(ctx)
        }
    }
    
    public fun add_state<T>(
               
    ){

    }

    // === Public-Package Functions ===

    // === Private Functions ===
    fun new (
        registry: &mut ProfileRegistry,
        avatar_url: String,
        display_name: String,
        description: String,
        ctx: &mut TxContext
    ): Profile {
        let profile = Profile{
            id: object::new(ctx),
            avatar_url,
            display_name,
            description,
            metadata: vec_map::empty()
        };
    
        event::profile_created(ctx.sender(), object::id(&profile));
        
        profile
    }

    fun destroy(
        reg: &mut ProfileRegistry,
        profile: Profile,
        ctx: &TxContext
    ) {
        let Profile {
            id,
            avatar_url: _,
            display_name: _,
            description: _,
            metadata: _,
        } = profile;

        event::profile_destroyed(ctx.sender(), id.uid_to_inner());

        object::delete(id);
    }
    // === Test Functions ===
}
