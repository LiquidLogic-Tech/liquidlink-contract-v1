module liquidlink_protocol::event {
    use sui::event;

    public struct ProfileManagerAdminRemoved has copy, drop {
        removed_admin: address,
        owner: address,
    }

    public struct ProfileCreated has copy, drop {
        owner: address,
        profile: ID
    }
    public fun profile_created(
        owner: address,
        profile: ID
    ){
        event::emit(
            ProfileCreated{
                owner,
                profile
            }
        );
    }

    public struct ProfileDestroyed has copy, drop {
        owner: address,
        profile: ID
    }
    public fun profile_destroyed(
        owner: address,
        profile: ID
    ){
        event::emit(
            ProfileCreated{
                owner,
                profile
            }
        );
    }
}
