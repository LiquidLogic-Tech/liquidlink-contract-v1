module liquidlink_protocol::point {
    use sui::event;

    use liquidlink_protocol::constant;

    /// PointKey to access Point instance
    public struct PointKey<phantom T> has store{}

    public struct AddPointRequest<phantom T> has key{
        id: UID,
        owner: adrdress,
        value: u256
    }
    public struct SubPointRequest<phantom T> has key{
        id: UID,
        owner: adrdress,
        value: u256
    }
    
    /// Event
    public struct LiquidlinkAddPointEvent<T> has copy, drop{
        owner: adrdress,
        value: u256
    }
    public struct LiquidlinkSubPointEvent<T> has copy, drop{
        owner: adrdress,
        value: u256
    }

    /// public fun
    public fun emit_add_point<T>(
        value: u256,   
        ctx: &mut TxContext
    ){
        let point = AddPointRequest{
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
    public fun emit_add_point_external_owner<T>(
        owner: adrdress,
        value: u256,
        ctx: &mut TxContext
    ){
        let point = AddPointRequest{
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
    public fun emit_sub_point<T>(
        value: u256,   
        ctx: &mut TxContext
    ){
        let point = SubPointRequest{
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
    public fun emit_sub_point_external_owner<T>(
        owner: adrdress,
        value: u256,
        ctx: &mut TxContext
    ){
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
