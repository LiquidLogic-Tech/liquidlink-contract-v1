module liquidlink_protocol::point {
    use sui::event;

    use liquidlink_protocol::constant;

    // === struct ===

    /// PointKey to access Point instance
    public struct PointKey<phantom T> has store{}

    public struct AddPointRequest<phantom T> has key{
        id: UID,
        owner: address,
        value: u256
    }
    public struct SubPointRequest<phantom T> has key{
        id: UID,
        owner: address,
        value: u256
    }
    
    // === event ===
    public struct LiquidlinkAddPointEvent<phantom T> has copy, drop{
        owner: address,
        value: u256
    }
    public struct LiquidlinkSubPointEvent<phantom T> has copy, drop{
        owner: address,
        value: u256
    }

    /// public fun
    public fun add_point<T>(
        value: u256,   
        ctx: &mut TxContext
    ){
        let point = AddPointRequest<T>{
            id: object::new(ctx),
            owner: ctx.sender(),
            value
        };
        event::emit(
            LiquidlinkAddPointEvent<T>{
                owner: ctx.sender(),
                value
            }
        );
        transfer::transfer(point, constant::point_updater());
    }
    public fun add_point_external_owner<T>(
        owner: address,
        value: u256,
        ctx: &mut TxContext
    ){
        let point = AddPointRequest<T>{
            id: object::new(ctx),
            owner: ctx.sender(),
            value
        };
        event::emit(
            LiquidlinkAddPointEvent<T>{
                owner,
                value
            }
        );
        transfer::transfer(point, constant::point_updater());
    }
    public fun sub_point<T>(
        value: u256,   
        ctx: &mut TxContext
    ){
        let point = SubPointRequest<T>{
            id: object::new(ctx),
            owner: ctx.sender(),
            value
        };
        event::emit(
            LiquidlinkSubPointEvent<T>{
                owner: ctx.sender(),
                value
            }
        );
        transfer::transfer(point, constant::point_updater());
    }
    public fun sub_point_external_owner<T>(
        owner: address,
        value: u256,
        ctx: &mut TxContext
    ){
        let point = SubPointRequest<T>{
            id: object::new(ctx),
            owner,
            value
        };
        event::emit(
            LiquidlinkSubPointEvent<T>{
                owner,
                value
            }
        );
        transfer::transfer(point, constant::point_updater());
    }

    public(package) fun new_key<T>():PointKey<T>{
        PointKey<T>{}
    }

    public(package) fun drop_key<T>(key: PointKey<T>){
        let PointKey<T>{} = key;
    }
}
