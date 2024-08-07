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

    public struct LinkAddressRequestCreated has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        profile_owner: address,
        by: address,
    }

    public struct LinkAddressRequestAccepted has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        profile_owner: address,
        by: address,
    }

    public struct LinkAddressRequestDeclined has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        by: address,
    }

    public struct LinkAddressRequestDeleted has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        by: address,
    }

    public struct LinkedAddressRemoved has copy, drop {
        profile_id: ID,
        linked_address: address,
        by: address,
    }
}
