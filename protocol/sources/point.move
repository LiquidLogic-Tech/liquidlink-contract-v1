module liquidlink_protocol::point {
    use sui::event;
    use sui::table::{Self, Table};

    use liquidlink_protocol::constant;

    // === struct ===

    /// PointKey to access Profile's Point instance
    public struct PointKey<phantom T> has store{}

    public(package) fun new_point_key<T>():PointKey<T>{
        PointKey<T>{}
    }

    public(package) fun drop_point_key<T>(key: PointKey<T>){
        let PointKey<T>{} = key;
    }

    /// PointReq to send the update point request
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

    /// Poiont Dashboard shared object
    public struct PointDashBoard<phantom T> has key, store{
        id: UID,
        total_points: u256,
        /// Mapping user "address" to "points"
        user_points: Table<address, u256>
    }
    public(package) fun new_point_dashboard<T>(ctx: &mut TxContext):PointDashBoard<T>{
        PointDashBoard<T>{
            id: object::new(ctx),
            total_points: 0,
            user_points: table::new(ctx)
        }
    }
    public fun total_points<T>(dashboard: &PointDashBoard<T>):u256{
        dashboard.total_points
    }
    public fun get_user_points<T>(dashboard: &PointDashBoard<T>, user: address):u256{
        if(dashboard.user_points.contains(user)){
            dashboard.user_points[user]
        }else{
            0
        }
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

    // === Method Aliases ===
    public use fun liquidlink_protocol::profile::add_point_by_admin as PointDashBoard.add_point_by_admin;

    //  Updater function
    public(package) fun add_point<T>(
        dashboard: &mut PointDashBoard<T>,
        req: AddPointRequest<T>
    ){
        let AddPointRequest{
            id,
            owner,
            value
        } = req;
        object::delete(id);

        if(!dashboard.user_points.contains(owner)){
            dashboard.user_points.add(owner, 0);
        };

        dashboard.total_points = dashboard.total_points + value;
        let value = dashboard.user_points[owner] + value;
        *&mut dashboard.user_points[owner] = value;
    }

    public(package) fun sub_point<T>(
        dashboard: &mut PointDashBoard<T>,
        req: SubPointRequest<T>
    ){
        let SubPointRequest{
            id,
            owner,
            value
        } = req;
        object::delete(id);

        if(!dashboard.user_points.contains(owner)){
            dashboard.user_points.add(owner, 0);
        };

        dashboard.total_points = dashboard.total_points - value;
        let prev_user_point = dashboard.user_points[owner];

        if(prev_user_point <= value){
            dashboard.user_points.remove(owner);
        }else{
            let new_value = prev_user_point - value;
            *&mut dashboard.user_points[owner] = new_value;
        };
    }

    //  Update Point Request
    public fun send_add_point_req<T: drop>(
        value: u256,   
        witness: T,
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(constant::point_updater(), value, ctx);
    }
    #[test_only]
    public fun send_add_point_req_for_testing<T: drop>(
        witness: T,
        updater: address,
        value: u256,   
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(updater, value, ctx);
    }
    public fun send_add_point_external_owner_req<T>(
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
    public fun send_sub_point_req<T>(
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
    public fun send_sub_point_external_owner_req<T>(
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

    // private function
    fun send_add_point_req_<T>(
        updater: address,
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
        transfer::transfer(point, updater);
    }

}
