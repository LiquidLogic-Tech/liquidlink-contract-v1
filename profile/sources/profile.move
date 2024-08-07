module liquidlink_profile::profile {
  // Importing Modules
    use sui::object::{Self, UID, ID};
    use std::string::{String, utf8};
    use std::vector;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::package;
    use sui::display;

    use liquidlink_profile::error::{
        duplicated_error,
        not_authorized_error,
        address_not_belong_to_same_profile_error,
        address_not_linked_error,
        address_has_linked_error,
    };

  // OTW

    struct PROFILE has drop {}
    
  // Event Structs

    struct ProfileManagerAdminAdded has copy, drop {
        new_admin: address,
        by: address,
    }

    struct ProfileManagerAdminRemoved has copy, drop {
        removed_admin: address,
        by: address,
    }

    struct ProfileCreated has copy, drop {
        profile_id: ID,
        owner: address,
        by: address,
    }

    struct ProfileDeleted has copy, drop {
        profile_id: ID,
        owner: address,
        by: address,
    }

    struct ProfileOwnershipTransferred has copy, drop {
        profile_id: ID,
        old_owner: address,
        new_owner: address,
        by: address,
    }

    struct LinkAddressRequestCreated has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        profile_owner: address,
        by: address,
    }

    struct LinkAddressRequestAccepted has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        profile_owner: address,
        by: address,
    }

    struct LinkAddressRequestDeclined has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        by: address,
    }

    struct LinkAddressRequestDeleted has copy, drop {
        link_address_request_id: ID,
        profile_id: ID,
        requester: address,
        by: address,
    }

    struct LinkedAddressRemoved has copy, drop {
        profile_id: ID,
        linked_address: address,
        by: address,
    }

  // Object Structs

    struct ProfileManager has key, store {
        id: UID,
        admins: vector<address>,
        creator: address,
        linked_addresses: Table<address, LinkedAddressWrapper>,
    }

    struct LinkedAddressWrapper has store, drop {
        profile_id: ID,
    }

    struct LinkAddressRquest has key, store {
        id: UID,
        profile_id: ID,
        requester: address,
    }

    struct Link has store, copy, drop {
        name: String,
        icon: String,
        url: String,
        data: String,
    }

    struct Profile has key {
        id: UID,
        owner: address,
        linked_addresses: vector<address>,
        avatar_url: String,
        background_url: String,
        display_name: String,
        description: String,
        data: String,
        links: vector<Link>,
        creator: address,
        created_at: u64,
        updated_at: u64
    }
    const NAME: vector<u8> = b"{display_name}";
    const IMAGE_URL: vector<u8> = b"https://liquidlink.io/api/profile/{id}/image";
    const DESCRIPTION: vector<u8> = b"{display_name}'s profile at LiquidLink. Check it out at https://liquidlink.io/{id}. Create your own at https://liquidlink.io";
    const CREATOR: vector<u8> = b"{creator}";

  // Constructor
    
    fun init (otw: PROFILE, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];
        let values = vector[
            utf8(NAME),
            utf8(IMAGE_URL),
            utf8(DESCRIPTION),
            utf8(b"https://liquidlink.io"),
            utf8(CREATOR),
        ];
        let publisher = package::claim(otw, ctx);
        let display = display::new_with_fields<Profile>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        let deployer = tx_context::sender(ctx);
        transfer::public_transfer(publisher, deployer);
        transfer::public_transfer(display, deployer);

        let admins = vector::empty();
        vector::push_back(&mut admins, tx_context::sender(ctx));
        let linked_addresses = table::new(ctx);
        let profile_manager = ProfileManager {
            id: object::new(ctx),
            admins,
            creator: tx_context::sender(ctx),
            linked_addresses,
        };
        transfer::share_object(profile_manager);
    }

  // Profile manager functions

    public fun profile_manager_add_admin (
        profile_manager: &mut ProfileManager,
        new_admin: address,
        ctx: &mut TxContext
    ) {
        assert_is_profile_manager_admin(profile_manager, tx_context::sender(ctx));
        assert!(
            !vector::contains(&profile_manager.admins, &new_admin),
            duplicated_error()
        );
        vector::push_back(&mut profile_manager.admins, new_admin);

        event::emit(ProfileManagerAdminAdded{
            new_admin,
            by: tx_context::sender(ctx),
        });
    }
    
    public fun profile_manager_remove_admin (
        profile_manager: &mut ProfileManager,
        removed_admin: address,
        ctx: &mut TxContext
    ) {
        assert_is_profile_manager_admin(profile_manager, tx_context::sender(ctx));
        let (admin_exist, index) = vector::index_of(&profile_manager.admins, &removed_admin);
        assert!(
            admin_exist && 
            vector::length(&profile_manager.admins) > 1,
            not_authorized_error()
        );
        vector::swap_remove(&mut profile_manager.admins, index);

        event::emit(ProfileManagerAdminRemoved{
            removed_admin,
            by: tx_context::sender(ctx),
        });
    }

  // Profile manager getter functions

    public fun get_profile_manager_creator (
        profile_manager: &ProfileManager
    ) : address {
        profile_manager.creator
    }

    public fun get_profile_manager_admins (
        profile_manager: &ProfileManager
    ) : vector<address> {
        profile_manager.admins
    }

    public fun is_address_linked (
        profile_manager: &ProfileManager,
        address: address
    ) : bool {
        table::contains(&profile_manager.linked_addresses, address)
    }

    public fun assert_is_address_linked (
        profile_manager: &ProfileManager,
        address: address
    ) {
        assert!(
            is_address_linked(profile_manager, address),
            address_not_linked_error()
        );
    }

    public fun assert_is_address_not_linked (
        profile_manager: &ProfileManager,
        address: address
    ) {
        assert!(
            !is_address_linked(profile_manager, address),
            address_has_linked_error()
        );
    }

    public fun is_profile_manager_admin (
        profile_manager: &ProfileManager,
        address: address
    ) : bool {
        vector::contains(&profile_manager.admins, &address)
    }

    public fun assert_is_profile_manager_admin (
        profile_manager: &ProfileManager,
        address: address
    ) {
        assert!(
            is_profile_manager_admin(profile_manager, address),
            not_authorized_error()
        );
    }

  // Profile Operations

    fun internal_add_linked_address (
        profile_manager: &mut ProfileManager,
        profile: &mut Profile,
        user_address: address
    ) {
        assert_is_address_not_linked(profile_manager, user_address);
        vector::push_back(&mut profile.linked_addresses, user_address);
        table::add(
            &mut profile_manager.linked_addresses,
            user_address,
            LinkedAddressWrapper{
                profile_id: object::uid_to_inner(&profile.id),
            }
        );
    }


    fun internal_remove_linked_address (
        profile_manager: &mut ProfileManager,
        profile: &mut Profile,
        user_address: address
    ) {
        assert_is_address_linked(profile_manager, user_address);
        let (exist, index) = vector::index_of(&profile.linked_addresses, &user_address);
        assert!(exist, not_authorized_error());
        vector::remove(&mut profile.linked_addresses, index);
        let linked_address_wrapper = table::remove(&mut profile_manager.linked_addresses, user_address);
        assert!(
            object::uid_to_inner(&profile.id) == linked_address_wrapper.profile_id,
            not_authorized_error()
        );
    }

    fun internal_create_profile (
        profile_manager: &mut ProfileManager,
        avatar_url: String,
        background_url: String,
        display_name: String,
        description: String,
        data: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) : Profile {
        let sender = tx_context::sender(ctx);
        let linked_addresses = vector::empty();

        let profile = Profile{
            id: object::new(ctx),
            owner: sender,
            linked_addresses,
            avatar_url,
            background_url,
            display_name,
            description,
            data,
            links: vector::empty(),
            creator: tx_context::sender(ctx),
            created_at: clock::timestamp_ms(clock),
            updated_at: clock::timestamp_ms(clock),
        };
        // !Disable this because I need to test in frontend.
        
        internal_add_linked_address(profile_manager, &mut profile, tx_context::sender(ctx));

        // !Workaround below because I need to test in frontend.
        
        // if(is_address_linked(profile_manager, sender) == false) {
        //     internal_add_linked_address(profile_manager, &mut profile, sender);
        // } else {
        //     vector::push_back(&mut profile.linked_addresses, tx_context::sender(ctx));
        // };
        // !Workaround above because I need to test in frontend.

        event::emit(ProfileCreated{
            profile_id: object::id(&profile),
            owner: tx_context::sender(ctx),
            by: tx_context::sender(ctx),
        });
        
        profile
    }

    fun internal_delete_profile(
        profile_manager: &mut ProfileManager,
        profile: Profile,
        ctx: &TxContext
    ) {
        event::emit(ProfileDeleted{
            profile_id: object::id(&profile),
            owner: profile.owner,
            by: tx_context::sender(ctx),
        });
        
        let linked_address_count = vector::length(&profile.linked_addresses);
        let i: u64 = 0;
        loop {
            if (i >= linked_address_count) {
                break
            };
            let linked_address = *vector::borrow(&profile.linked_addresses, i);
            internal_remove_linked_address(profile_manager, &mut profile, linked_address);
            i = i + 1;
        };
        let Profile {
            id,
            owner: _,
            linked_addresses: _,
            avatar_url: _,
            background_url: _,
            display_name: _,
            description: _,
            data: _,
            links: _,
            creator: _,
            created_at: _,
            updated_at: _,
        } = profile;
        object::delete(id);
    }

    public fun delete_profile (
        profile_manager: &mut ProfileManager,
        profile: Profile,
        ctx: &mut TxContext
    ) {
        internal_delete_profile(profile_manager, profile, ctx);
    }

    public fun create_profile (
        profile_manager: &mut ProfileManager,
        avatar_url: String,
        background_url: String,
        display_name: String,
        description: String,
        data: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let profile = internal_create_profile(profile_manager, avatar_url, background_url, display_name, description, data, clock, ctx);
        transfer::transfer(profile, tx_context::sender(ctx));
    }

    public fun create_profile_with_links (
        profile_manager: &mut ProfileManager,
        avatar_url: String,
        background_url: String,
        display_name: String,
        description: String,
        data: String,
        link_names: vector<String>,
        link_icons: vector<String>,
        link_urls: vector<String>,
        link_datas: vector<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let profile = internal_create_profile(profile_manager, avatar_url, background_url, display_name, description, data, clock, ctx);
        let link_count = vector::length(&link_names);
        let i: u64 = 0;
        loop {
            if (i >= link_count) {
                break
            };
            let link = Link{
                name: *vector::borrow(&link_names, i),
                icon: *vector::borrow(&link_icons, i),
                url: *vector::borrow(&link_urls, i),
                data: *vector::borrow(&link_datas, i)
            };
            vector::push_back(&mut profile.links, link);
            i = i + 1;
        };
        transfer::transfer(profile, tx_context::sender(ctx));
    }

    public fun transfer_profile_ownership (
        profile: Profile,
        new_owner: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(
            vector::contains(&profile.linked_addresses, &new_owner),
            not_authorized_error()
        );
        profile.owner = new_owner;
        profile.updated_at = clock::timestamp_ms(clock);

        event::emit(ProfileOwnershipTransferred{
            profile_id: object::id(&profile),
            old_owner: tx_context::sender(ctx),
            new_owner,
            by: tx_context::sender(ctx),
        });
        transfer::transfer(profile, new_owner);
        
    }

    public fun add_link_to_profile (
        profile: &mut Profile,
        name: String,
        icon: String,
        url: String,
        data: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let link = Link {
            name,
            icon,
            url,
            data,
        };
        vector::push_back(&mut profile.links, link);
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun remove_link_from_profile (
        profile: &mut Profile,
        link_index: u64,
        _ctx: &mut TxContext
    ) {
        vector::remove(&mut profile.links, link_index);
    }

    public fun edit_link_in_profile (
        profile: &mut Profile,
        link_index: u64,
        name: String,
        icon: String,
        url: String,
        data: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let link = vector::borrow_mut(&mut profile.links, link_index);
        link.name = name;
        link.icon = icon;
        link.url = url;
        link.data = data;
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun reorder_links_in_prilfe (
        profile: &mut Profile,
        link_indexes: vector<u64>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let link_count = vector::length(&profile.links);
        let reordered_links = vector::empty();
        let i: u64 = 0;
        loop {
            if (i >= link_count) {
                break
            };
            let link_index = *vector::borrow(&link_indexes, i);
            let link = vector::borrow(&profile.links, link_index);
            vector::push_back(&mut reordered_links, *link);
            i = i + 1;
        };
        profile.links = reordered_links;
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun replace_links_in_prilfe (
        profile: &mut Profile,
        link_names: vector<String>,
        link_icons: vector<String>,
        link_urls: vector<String>,
        link_datas: vector<String>,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let link_count = vector::length(&link_names);
        let links = vector::empty();
        let i: u64 = 0;
        loop {
            if (i >= link_count) {
                break
            };
            let link = Link{
                name: *vector::borrow(&link_names, i),
                icon: *vector::borrow(&link_icons, i),
                url: *vector::borrow(&link_urls, i),
                data: *vector::borrow(&link_datas, i)
            };
            vector::push_back(&mut links, link);
            i = i + 1;
        };
        profile.links = links;
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun edit_profile_avatar_url (
        profile: &mut Profile,
        avatar_url: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        profile.avatar_url = avatar_url;
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun edit_profile_background_url (
        profile: &mut Profile,
        background_url: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        profile.background_url = background_url;
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun edit_profile_display_name (
        profile: &mut Profile,
        display_name: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        profile.display_name = display_name;
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun edit_profile_description (
        profile: &mut Profile,
        description: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        profile.description = description;
        profile.updated_at = clock::timestamp_ms(clock);
    }

    public fun edit_profile_data (
        profile: &mut Profile,
        data: String,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        profile.data = data;
        profile.updated_at = clock::timestamp_ms(clock);
    }

  // Linked Address Getter functions

    fun internal_get_address_linked_profile_id (
        profile_manager: &ProfileManager,
        address: address
    ) : ID {
        let linked_address_wrapper = table::borrow(&profile_manager.linked_addresses, address);
        linked_address_wrapper.profile_id
    }

    public fun get_address_linked_profile_id (
        profile_manager: &ProfileManager,
        address: address
    ) : ID {
        assert!(is_address_linked(profile_manager, address), address_not_linked_error());
        internal_get_address_linked_profile_id(profile_manager, address)
    }

    public fun is_addresses_in_same_profile (
        profile_manager: &ProfileManager,
        address1: address,
        address2: address
    ) : bool {
        if (is_address_linked(profile_manager, address1) == false ||
            is_address_linked(profile_manager, address2) == false
        ) {
            return false
        };

        let profile_id1 = internal_get_address_linked_profile_id(profile_manager, address1);
        let profile_id2 = internal_get_address_linked_profile_id(profile_manager, address2);
        profile_id1 == profile_id2
    }

    public fun assert_is_addresses_in_same_profile (
        profile_manager: &ProfileManager,
        address1: address,
        address2: address
    ) {
        assert!(
            is_addresses_in_same_profile(profile_manager, address1, address2),
            address_not_belong_to_same_profile_error()
        );
    }

    public fun assert_is_addresses_not_in_same_profile (
        profile_manager: &ProfileManager,
        address1: address,
        address2: address
    ) {
        assert!(
            !is_addresses_in_same_profile(profile_manager, address1, address2),
            address_not_belong_to_same_profile_error()
        );
    }

    public fun is_address_profile_overlap_with_others (
        profile_manager: &ProfileManager,
        addr: address,
        others: vector<address>
    ) : bool {
        let profile_id = internal_get_address_linked_profile_id(profile_manager, addr);
        let address_count = vector::length(&others);
        let i: u64 = 0;
        loop {
            if (i >= address_count) {
                break
            };
            let other = *vector::borrow(&others, i);
            if (is_address_linked(profile_manager, other) &&
                profile_id == internal_get_address_linked_profile_id(profile_manager, other)
            ) {
                return true
            };
            i = i + 1;
        };
        false
    }

    public fun assert_address_profile_overlap_with_others (
        profile_manager: &ProfileManager,
        addr: address,
        others: vector<address>
    ) {
        assert!(
            is_address_profile_overlap_with_others(profile_manager, addr, others),
            address_not_belong_to_same_profile_error()
        );
    }

    public fun assert_address_profile_not_overlap_with_others (
        profile_manager: &ProfileManager,
        addr: address,
        others: vector<address>
    ) {
        assert!(
            !is_address_profile_overlap_with_others(profile_manager, addr, others),
            address_not_belong_to_same_profile_error()
        );
    }
    

  // Linked Address Management
    
    public fun create_link_address_request (
        profile_manager: &mut ProfileManager,
        profile_id: address,
        profile_owner: address,
        ctx: &mut TxContext
    ) {
        assert_is_address_not_linked(profile_manager, tx_context::sender(ctx));
        let requester = tx_context::sender(ctx);
        let link_address_request = LinkAddressRquest{
            id: object::new(ctx),
            profile_id: object::id_from_address(profile_id),
            requester,
        };
        event::emit(LinkAddressRequestCreated {
            link_address_request_id: object::id(&link_address_request),
            profile_id: object::id_from_address(profile_id),
            requester,
            profile_owner,
            by: tx_context::sender(ctx),
        });
        transfer::public_transfer(link_address_request, profile_owner);
    }

    public fun accept_link_address_request (
        profile_manager: &mut ProfileManager,
        link_address_request: LinkAddressRquest,
        profile: &mut Profile,
        ctx: &mut TxContext
    ) {
        assert!(
            object::uid_to_inner(&profile.id) == link_address_request.profile_id,
            not_authorized_error()
        );
        internal_add_linked_address(
            profile_manager, 
            profile,
            link_address_request.requester
        );

        event::emit(LinkAddressRequestAccepted{
            link_address_request_id: object::id(&link_address_request),
            profile_id: object::id(profile),
            requester: tx_context::sender(ctx),
            profile_owner: profile.owner,
            by: tx_context::sender(ctx),
        });
        internal_delete_link_address_request(link_address_request, ctx);
    }

    public fun decline_link_address_request (
        link_address_request: LinkAddressRquest,
        ctx: &mut TxContext
    ) {
        event::emit(LinkAddressRequestDeclined{
            link_address_request_id: object::id(&link_address_request),
            profile_id: link_address_request.profile_id,
            requester: link_address_request.requester,
            by: tx_context::sender(ctx),
        });
        internal_delete_link_address_request(link_address_request, ctx);
    }

    fun internal_delete_link_address_request (
        link_address_request: LinkAddressRquest,
        ctx: & TxContext
    ) {
        event::emit(LinkAddressRequestDeleted{
            link_address_request_id: object::id(&link_address_request),
            profile_id: link_address_request.profile_id,
            requester: link_address_request.requester,
            by: tx_context::sender(ctx),
        });
        let LinkAddressRquest {
            id,
            profile_id: _,
            requester: _,
        } = link_address_request;
        object::delete(id);
    }

    public fun remove_linked_address_from_profile (
        profile_manager: &mut ProfileManager,
        profile: &mut Profile,
        linked_address: address,
        ctx: &mut TxContext
    ) {
        internal_remove_linked_address(profile_manager, profile, linked_address);
        event::emit(LinkedAddressRemoved{
            profile_id: object::id(profile),
            linked_address,
            by: tx_context::sender(ctx),
        });
    }

  // Profile Getter functions

    public fun get_profile_owner (
        profile: &Profile
    ) : address {
        profile.owner
    }

    public fun get_profile_linked_addresses (
        profile: &Profile
    ) : vector<address> {
        profile.linked_addresses
    }

    public fun get_profile_avatar_url (
        profile: &Profile
    ) : String {
        profile.avatar_url
    }

    public fun get_profile_background_url (
        profile: &Profile
    ) : String {
        profile.background_url
    }

    public fun get_profile_display_name (
        profile: &Profile
    ) : String {
        profile.display_name
    }

    public fun get_profile_description (
        profile: &Profile
    ) : String {
        profile.description
    }

    public fun get_profile_data (
        profile: &Profile
    ) : String {
        profile.data
    }

    public fun borrow_profile_links (
        profile: &Profile
    ) : &vector<Link> {
        &profile.links
    }

    public fun get_profile_creator (
        profile: &Profile
    ) : address {
        profile.creator
    }

    public fun get_profile_created_at (
        profile: &Profile
    ) : u64 {
        profile.created_at
    }

    public fun get_profile_updated_at (
        profile: &Profile
    ) : u64 {
        profile.updated_at
    }

    public fun get_link_name (
        link: &Link
    ) : String {
        link.name
    }

    public fun get_link_icon (
        link: &Link
    ) : String {
        link.icon
    }

    public fun get_link_url (
        link: &Link
    ) : String {
        link.url
    }

    public fun get_link_data (
        link: &Link
    ) : String {
        link.data
    }
    
  // Test
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(PROFILE { }, ctx);
    }

}






#[test_only]
module liquidlink_profile::test_profile {
    use sui::test_scenario::{Self as ts};
    use sui::object::{Self};
    use sui::clock::{Self};
    use std::string::{utf8};
    use std::vector;
    use liquidlink_profile::profile::{
        Self, 
        ProfileManager, 
        Profile,
        LinkAddressRquest,
    };
    use liquidlink_profile::error::{
        ErrorNotAuthorized, 
        ErrAddressHasLinked,
    };
    // use std::debug;
    

    #[test]
    fun test_profile_creation() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let userB = @0x3;
        let userA_second_address = @0x4;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;
        let timestamp = 1687974871000;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // Create a profile for userA with two links
        ts::next_tx(scenario, userA);
        let userA_profile_id_address;
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            clock::set_for_testing(&mut clockObj, timestamp);

            let link_names = vector::empty();
            let link_icons = vector::empty();
            let link_urls = vector::empty();
            let link_datas = vector::empty();
            {
                vector::push_back(&mut link_names, utf8(b"Link 1"));
                vector::push_back(&mut link_icons, utf8(b"https://link1.com/icon"));
                vector::push_back(&mut link_urls, utf8(b"https://link1.com"));
                vector::push_back(&mut link_datas, utf8(b"Link 1 data"));
                vector::push_back(&mut link_names, utf8(b"Link 2"));
                vector::push_back(&mut link_icons, utf8(b"https://link2.com/icon"));
                vector::push_back(&mut link_urls, utf8(b"https://link2.com"));
                vector::push_back(&mut link_datas, utf8(b"Link 2 data"));
            };

            profile::create_profile_with_links(
                &mut profile_manager,
                utf8(b"https://avatar.com"),
                utf8(b"https://background.com"),
                utf8(b"User A"),
                utf8(b"User A's profile"),
                utf8(b"User A's data"),
                link_names,
                link_icons,
                link_urls,
                link_datas,
                &clockObj,
                ts::ctx(scenario)
            );
            
            ts::return_shared(profile_manager);
            clock::destroy_for_testing(clockObj);
        };
        
        // userA assert the profile data is as expected
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            userA_profile_id_address = object::id_address(&profile);
            assert!(profile::get_profile_owner(&profile) == userA, 999);
            assert!(profile::get_profile_avatar_url(&profile) == utf8(b"https://avatar.com"), 999);
            assert!(profile::get_profile_background_url(&profile) == utf8(b"https://background.com"), 999);
            assert!(profile::get_profile_display_name(&profile) == utf8(b"User A"), 999);
            assert!(profile::get_profile_description(&profile) == utf8(b"User A's profile"), 999);
            assert!(profile::get_profile_data(&profile) == utf8(b"User A's data"), 999);
            let profile_links = profile::borrow_profile_links(&profile);
            assert!(vector::length(profile_links) == 2, 999);
            assert!(profile::get_link_name(vector::borrow(profile_links, 0)) == utf8(b"Link 1"), 999);
            assert!(profile::get_link_icon(vector::borrow(profile_links, 0)) == utf8(b"https://link1.com/icon"), 999);
            assert!(profile::get_link_url(vector::borrow(profile_links, 0)) == utf8(b"https://link1.com"), 999);
            assert!(profile::get_link_data(vector::borrow(profile_links, 0)) == utf8(b"Link 1 data"), 999);
            assert!(profile::get_link_name(vector::borrow(profile_links, 1)) == utf8(b"Link 2"), 999);
            assert!(profile::get_link_icon(vector::borrow(profile_links, 1)) == utf8(b"https://link2.com/icon"), 999);
            assert!(profile::get_link_url(vector::borrow(profile_links, 1)) == utf8(b"https://link2.com"), 999);
            assert!(profile::get_link_data(vector::borrow(profile_links, 1)) == utf8(b"Link 2 data"), 999);
            assert!(profile::get_profile_creator(&profile) == userA, 999);
            assert!(profile::get_profile_created_at(&profile) == timestamp, 999);
            assert!(profile::get_profile_updated_at(&profile) == timestamp, 999);
            ts::return_to_sender(scenario, profile);
        };

        // userA_second_address create a link request for user A's profile
        ts::next_tx(scenario, userA_second_address);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::create_link_address_request(
                &mut profile_manager,
                userA_profile_id_address,
                userA,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
        };

        // userA accept the connect request
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            let profile = ts::take_from_sender<Profile>(scenario);
            let link_address_request = ts::take_from_sender<LinkAddressRquest>(scenario);
            profile::accept_link_address_request(
                &mut profile_manager,
                link_address_request,
                &mut profile,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
            ts::return_to_sender(scenario, profile);
        };

        // userB create a link request for user A's profile
        ts::next_tx(scenario, userB);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::create_link_address_request(
                &mut profile_manager,
                userA_profile_id_address,
                userA,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
        };

        // userA reject the link request
        ts::next_tx(scenario, userA);
        {
            let link_address_request = ts::take_from_sender<LinkAddressRquest>(scenario);
            profile::decline_link_address_request(
                link_address_request,
                ts::ctx(scenario)
            );
        };

        // userA transfer ownership to userA_second_address
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            clock::set_for_testing(&mut clockObj, timestamp + 1000);
            profile::transfer_profile_ownership(
                profile,
                userA_second_address,
                &clockObj,
                ts::ctx(scenario)
            );
            clock::destroy_for_testing(clockObj);
        };

        // check userA and userA second address are in the same profile by userB
        ts::next_tx(scenario, userB);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::assert_is_addresses_in_same_profile(&profile_manager, userA, userA_second_address);
            let relevant_address_vector = vector::empty();
            vector::push_back(&mut relevant_address_vector, userA);
            assert!(profile::is_address_profile_overlap_with_others(&profile_manager, userA_second_address, relevant_address_vector), 999);
            profile::assert_address_profile_overlap_with_others(&profile_manager, userA_second_address, relevant_address_vector);

            // some dummy address
            let irelevant_address_vector = vector::empty();
            vector::push_back(&mut irelevant_address_vector, userB);
            assert!(!profile::is_address_profile_overlap_with_others(&profile_manager, userA_second_address, irelevant_address_vector), 999);
            profile::assert_address_profile_not_overlap_with_others(&profile_manager, userA_second_address, irelevant_address_vector);

            ts::return_shared(profile_manager);
        };


        // userA_second_address remove userA from linked addresses
        ts::next_tx(scenario, userA_second_address);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            let profile = ts::take_from_sender<Profile>(scenario);
            profile::remove_linked_address_from_profile(
                &mut profile_manager,
                &mut profile,
                userA,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
            ts::return_to_sender(scenario, profile);
        };

        // check userA_second_address now own the profile and userA is not linked by is_address_linked
        ts::next_tx(scenario, userA_second_address);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            assert!(profile::get_profile_owner(&profile) == userA_second_address, 999);
            assert!(vector::length(&profile::get_profile_linked_addresses(&profile)) == 1, 999);
            assert!(profile::is_address_linked(&profile_manager, userA_second_address), 999);
            assert!(!profile::is_address_linked(&profile_manager, userA), 999);
            
            ts::return_to_sender(scenario, profile);
            ts::return_shared(profile_manager);
        };

        // userA_second_address delete the profile
        ts::next_tx(scenario, userA_second_address);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::delete_profile(&mut profile_manager, profile, ts::ctx(scenario));
            ts::return_shared(profile_manager);
        };

        ts::end(scenario_val);
    }


    // A test for the following:
    // add_link_to_profile
    // remove_link_from_profile
    // edit_profile_avatar_url
    // edit_profile_background_url
    // edit_profile_display_name
    // edit_profile_description
    // edit_profile_data
    #[test]
    fun test_profile_editing() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;
        let timestamp = 1687974871000;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // Create a profile for userA
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            clock::set_for_testing(&mut clockObj, timestamp);

            profile::create_profile(
                &mut profile_manager,
                utf8(b"https://avatar.com"),
                utf8(b"https://background.com"),
                utf8(b"User A"),
                utf8(b"User A's profile"),
                utf8(b"User A's data"),
                &clockObj,
                ts::ctx(scenario)
            );
            
            ts::return_shared(profile_manager);
            clock::destroy_for_testing(clockObj);
        };

        // userA add a link to the profile
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            clock::set_for_testing(&mut clockObj, timestamp + 1000);
            profile::add_link_to_profile(
                &mut profile,
                utf8(b"Link 1"),
                utf8(b"https://link1.com/icon"),
                utf8(b"https://link1.com"),
                utf8(b"Link 1 data"),
                &clockObj,
                ts::ctx(scenario)
            );
            ts::return_to_sender(scenario, profile);
            clock::destroy_for_testing(clockObj);
        };

        // userA edit the profile
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            clock::set_for_testing(&mut clockObj, timestamp + 2000);
            profile::edit_profile_avatar_url(
                &mut profile,
                utf8(b"https://avatar2.com"),
                &clockObj,
                ts::ctx(scenario)
            );
            profile::edit_profile_background_url(
                &mut profile,
                utf8(b"https://background2.com"),
                &clockObj,
                ts::ctx(scenario)
            );
            profile::edit_profile_display_name(
                &mut profile,
                utf8(b"User A 2"),
                &clockObj,
                ts::ctx(scenario)
            );
            profile::edit_profile_description(
                &mut profile,
                utf8(b"User A's profile 2"),
                &clockObj,
                ts::ctx(scenario)
            );
            profile::edit_profile_data(
                &mut profile,
                utf8(b"User A's data 2"),
                &clockObj,
                ts::ctx(scenario)
            );

            profile::edit_link_in_profile(
                &mut profile,
                0,
                utf8(b"Link 1 2"),
                utf8(b"https://link1.com/icon2"),
                utf8(b"https://link1.com/2"),
                utf8(b"Link 1 data 2"),
                &clockObj,
                ts::ctx(scenario)
            );
            ts::return_to_sender(scenario, profile);
            clock::destroy_for_testing(clockObj);
        };

        // check the profile is edited
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            assert!(profile::get_profile_avatar_url(&profile) == utf8(b"https://avatar2.com"), 999);
            assert!(profile::get_profile_background_url(&profile) == utf8(b"https://background2.com"), 999);
            assert!(profile::get_profile_display_name(&profile) == utf8(b"User A 2"), 999);
            assert!(profile::get_profile_description(&profile) == utf8(b"User A's profile 2"), 999);
            assert!(profile::get_profile_data(&profile) == utf8(b"User A's data 2"), 999);
            let profile_links = profile::borrow_profile_links(&profile);
            assert!(vector::length(profile_links) == 1, 999);
            assert!(profile::get_link_name(vector::borrow(profile_links, 0)) == utf8(b"Link 1 2"), 999);
            assert!(profile::get_link_icon(vector::borrow(profile_links, 0)) == utf8(b"https://link1.com/icon2"), 999);
            assert!(profile::get_link_url(vector::borrow(profile_links, 0)) == utf8(b"https://link1.com/2"), 999);
            assert!(profile::get_link_data(vector::borrow(profile_links, 0)) == utf8(b"Link 1 data 2"), 999);
            assert!(profile::get_profile_created_at(&profile) == timestamp, 999);
            assert!(profile::get_profile_updated_at(&profile) == timestamp + 2000, 999);
            ts::return_to_sender(scenario, profile);
        };

        // userA add more link
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            clock::set_for_testing(&mut clockObj, timestamp + 3000);
            profile::add_link_to_profile(
                &mut profile,
                utf8(b"Link 2"),
                utf8(b"https://link2.com/icon"),
                utf8(b"https://link2.com"),
                utf8(b"Link 2 data"),
                &clockObj,
                ts::ctx(scenario)
            );
            profile::add_link_to_profile(
                &mut profile,
                utf8(b"Link 3"),
                utf8(b"https://link3.com/icon"),
                utf8(b"https://link3.com"),
                utf8(b"Link 3 data"),
                &clockObj,
                ts::ctx(scenario)
            );
            ts::return_to_sender(scenario, profile);
            clock::destroy_for_testing(clockObj);
        };

        // user A reorder the link
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            clock::set_for_testing(&mut clockObj, timestamp + 3000);
            let link_indexes = vector::empty();
            vector::push_back(&mut link_indexes, 1);
            vector::push_back(&mut link_indexes, 2);
            vector::push_back(&mut link_indexes, 0);

            profile::reorder_links_in_prilfe(
                &mut profile,
                link_indexes,
                &clockObj,
                ts::ctx(scenario)
            );
            ts::return_to_sender(scenario, profile);
            clock::destroy_for_testing(clockObj);
        };
        

        // check the link is reordered
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let profile_links = profile::borrow_profile_links(&profile);
            assert!(vector::length(profile_links) == 3, 999);
            assert!(profile::get_link_name(vector::borrow(profile_links, 0)) == utf8(b"Link 2"), 999);
            assert!(profile::get_link_name(vector::borrow(profile_links, 1)) == utf8(b"Link 3"), 999);
            assert!(profile::get_link_name(vector::borrow(profile_links, 2)) == utf8(b"Link 1 2"), 999);
            ts::return_to_sender(scenario, profile);
        };
        
        
        // user A remove the link
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            profile::remove_link_from_profile(
                &mut profile,
                0,
                ts::ctx(scenario)
            );
            ts::return_to_sender(scenario, profile);
        };

        // check the link is removed
        ts::next_tx(scenario, userA);
        {
            let profile = ts::take_from_sender<Profile>(scenario);
            let profile_links = profile::borrow_profile_links(&profile);
            assert!(vector::length(profile_links) == 2, 999);
            ts::return_to_sender(scenario, profile);
        };

        ts::end(scenario_val);
    }
    
    #[test]
    fun test_profile_management() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // Admin add userA as admin
        ts::next_tx(scenario, admin);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::profile_manager_add_admin(&mut profile_manager, userA, ts::ctx(scenario));
            ts::return_shared(profile_manager);
        };

        // userA check he has admin and remove admin's address
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            assert!(profile::is_profile_manager_admin(&profile_manager, userA), 999);
            profile::profile_manager_remove_admin(&mut profile_manager, admin, ts::ctx(scenario));
            ts::return_shared(profile_manager);
        };

        // admin check he is not admin
        ts::next_tx(scenario, admin);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            assert!(!profile::is_profile_manager_admin(&profile_manager, admin), 999);
            ts::return_shared(profile_manager);
        };

        // end
        ts::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_profile::profile)]
    fun test_profile_management_admin_remove_themself_and_no_admin_left() {
        // Setup test scenario
        let admin = @0x1;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // Admin remove themself
        ts::next_tx(scenario, admin);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::profile_manager_remove_admin(&mut profile_manager, admin, ts::ctx(scenario));
            ts::return_shared(profile_manager);
        };

        // end
        ts::end(scenario_val);
    }

    // test if someone who is not admin try to add admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_profile::profile)]
    fun test_profile_management_add_admin_by_non_admin() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // userA try to add admin
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::profile_manager_add_admin(&mut profile_manager, userA, ts::ctx(scenario));
            ts::return_shared(profile_manager);
        };

        // end
        ts::end(scenario_val);
    }

    // test if someone who is not admin try to remove admin
    #[test]
    #[expected_failure(abort_code = ErrorNotAuthorized, location = liquidlink_profile::profile)]
    fun test_profile_management_remove_admin_by_non_admin() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // userA try to remove admin
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::profile_manager_remove_admin(&mut profile_manager, admin, ts::ctx(scenario));
            ts::return_shared(profile_manager);
        };

        // end
        ts::end(scenario_val);
    }

    // test if someone want to create profile twice
    #[test]
    #[expected_failure(abort_code = ErrAddressHasLinked, location = liquidlink_profile::profile)]
    fun test_profile_creation_twice() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // Create a profile for userA
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            profile::create_profile(
                &mut profile_manager,
                utf8(b"https://avatar.com"),
                utf8(b"https://background.com"),
                utf8(b"User A"),
                utf8(b"User A's profile"),
                utf8(b"User A's data"),
                &clockObj,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
            clock::destroy_for_testing(clockObj);
        };

        // Create a profile for userA again
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            profile::create_profile(
                &mut profile_manager,
                utf8(b"https://avatar.com"),
                utf8(b"https://background.com"),
                utf8(b"User A"),
                utf8(b"User A's profile"),
                utf8(b"User A's data"),
                &clockObj,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
            clock::destroy_for_testing(clockObj);
        };

        // end
        ts::end(scenario_val);
    }

    // test if someone who is linked create link address request
    #[test]
    #[expected_failure(abort_code = ErrAddressHasLinked, location = liquidlink_profile::profile)]
    fun test_create_link_address_request_by_linked_address() {
        // Setup test scenario
        let admin = @0x1;
        let userA = @0x2;
        let userB = @0x3;
        let scenario_val = ts::begin(admin);
        let scenario = &mut scenario_val;

        // Initialize ProfileManager with admin
        {
            profile::init_for_testing(ts::ctx(scenario));
        };

        // Create a profile for userA
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            let clockObj = clock::create_for_testing(ts::ctx(scenario));
            profile::create_profile(
                &mut profile_manager,
                utf8(b"https://avatar.com"),
                utf8(b"https://background.com"),
                utf8(b"User A"),
                utf8(b"User A's profile"),
                utf8(b"User A's data"),
                &clockObj,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
            clock::destroy_for_testing(clockObj);
        };

        // userA create a link request for userB
        ts::next_tx(scenario, userA);
        {
            let profile_manager = ts::take_shared<ProfileManager>(scenario);
            profile::create_link_address_request(
                &mut profile_manager,
                userA,
                userB,
                ts::ctx(scenario)
            );
            ts::return_shared(profile_manager);
        };

        // end
        ts::end(scenario_val);
    }
}
