module liquidlink_protocol::point {
    use std::type_name::{Self, TypeName};

    use sui::event;
    use sui::clock::Clock;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use sui::object;

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
    public struct StakePointRequest<phantom T, phantom Action> has key{
        id: UID,
        owner: address,
        /// This value already take account weights
        weight: u256,
        duration: u64,
        timestamp: u64
    }
    public struct UnstakePointRequest<phantom T, phantom Action> has key{
        id: UID,
        owner: address,
        weight: u256,
        duration: u64,
        timestamp: u64
    }

    public struct UserInfo has store, copy, drop{
        points: u256,
        configs: VecMap<TypeName, Config>
    }
    public struct Config has store, copy, drop{
        weight: u256,
        last_update: u64,
        duration: u64
    }
    /// Poiont Dashboard shared object
    public struct PointDashBoard<phantom T> has key, store{
        id: UID,
        total_points: u256,
        user_infos: Table<address, UserInfo>,
        // todo: add config history
    }
    public(package) fun new_point_dashboard<T>(ctx: &mut TxContext):PointDashBoard<T>{
        PointDashBoard<T>{
            id: object::new(ctx),
            total_points: 0,
            user_infos: table::new(ctx)
        }
    }
    public fun total_points<T>(dashboard: &PointDashBoard<T>):u256{
        dashboard.total_points
    }
    public fun get_user_info<T>(dashboard: &PointDashBoard<T>, user: address):Option<UserInfo>{
        if(dashboard.user_infos.contains(user)){
            option::some(dashboard.user_infos[user])
        }else{
            option::none()
        }
    }
    public fun get_user_iufo_points<T>(
        dashboard: &PointDashBoard<T>,
        user: address,
        clock: &Clock
    ):u256{
        let info = get_user_info<T>(dashboard, user);
        if(info.is_some()){
            let info_ = info.borrow();
            let keys = info_.configs.keys();
            let (mut i, len) = (0, keys.length());
            
            let mut total_points = info_.points;
            while(i < len){
                let accumulated_points = calculate_action_points(&info_.configs[&keys[i]], clock.timestamp_ms());
                total_points = total_points + accumulated_points;
                i = i + 1;
            };

            total_points
        }else{
            info.destroy_none();
            0
        }
    }

    // === event ===
    public struct LiquidlinkAddPointEvent<phantom T> has copy, drop{
        owner: address,
        req: ID,
        value: u256,
    }
    public struct LiquidlinkSubPointEvent<phantom T> has copy, drop{
        owner: address,
        req: ID,
        value: u256,
    }
    public struct LiquidlinkStakePointEvent<phantom T, phantom Action> has copy, drop{
        owner: address,
        req: ID,
        weight: u256,
        timestamp: u64,
        duration: u64,
    }
    public struct LiquidlinkUnstakePointEvent<phantom T, phantom Action> has copy, drop{
        owner: address,
        req: ID,
        weight: u256,
        timestamp: u64,
        duration: u64
    }

    // === Method Aliases ===
    public use fun liquidlink_protocol::profile::add_point_by_admin as PointDashBoard.add_point_by_admin;
    public use fun liquidlink_protocol::profile::sub_point_by_admin as PointDashBoard.sub_point_by_admin;
    public use fun liquidlink_protocol::profile::stake_point_by_admin as PointDashBoard.stake_point_by_admin;
    public use fun liquidlink_protocol::profile::unstake_point_by_admin as PointDashBoard.unstake_point_by_admin;

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

        init_user_info(dashboard, owner);

        dashboard.total_points = dashboard.total_points + value;
        *&mut dashboard.user_infos[owner].points = dashboard.user_infos[owner].points + value;
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

        dashboard.total_points = dashboard.total_points - value;
        let prev_user_point = dashboard.user_infos[owner].points;

        if(prev_user_point <= value){
            dashboard.user_infos.remove(owner);
        }else{
            let new_value = prev_user_point - value;
            *&mut dashboard.user_infos[owner].points = new_value;
        };
    }

    public(package) fun stake_point<T, Action>(
        dashboard: &mut PointDashBoard<T>,
        req: StakePointRequest<T, Action>
    ){
        let StakePointRequest<T, Action>{
            id,
            owner,
            weight,
            timestamp,
            duration
        } = req;
        object::delete(id);

        let type_ = type_name::get<Action>();

        init_user_info(dashboard, owner);

        let info = &mut dashboard.user_infos[owner];
        if(!info.configs.contains(&type_)){
            info.configs.insert(
                type_,
                Config{
                    weight,
                    last_update: timestamp,
                    duration
                }
            );
        }else{
            let config = &mut info.configs[&type_];
            let acc_points = config.checkpoint(timestamp, weight, duration, true);
               
            // update dashboard
            dashboard.total_points = dashboard.total_points + acc_points;
            // update personal information
            info.points = info.points + acc_points;
        }
    }

    public(package) fun unstake_point<T, Action>(
        dashboard: &mut PointDashBoard<T>,
        req: UnstakePointRequest<T, Action>
    ){
        let UnstakePointRequest<T, Action>{
            id,
            owner,
            weight,
            timestamp,
            duration
        } = req;
        object::delete(id);

        let type_ = type_name::get<Action>();

        init_user_info(dashboard, owner);

        let info = &mut dashboard.user_infos[owner];
        
        // if user don't have corresponsing config, we skip updating the info

        if(info.configs.contains(&type_)){
            let config = &mut info.configs[&type_];
            let acc_points = config.checkpoint(timestamp, weight, duration, false);

            // update dashboard
            dashboard.total_points = dashboard.total_points + acc_points;
            // update personal information
            info.points = info.points + acc_points;
        }
    }

    // ===== Add Point =====
    public fun send_add_point_req<T: drop>(
        value: u256,   
        witness: T,
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(constant::point_updater(), ctx.sender(), value, ctx);
    }
    #[test_only]
    public fun send_add_point_req_with_assigned_updater<T: drop>(
        witness: T,
        updater: address,
        owner: address,
        value: u256,   
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(updater, owner, value, ctx);
    }

    public fun send_add_point_req_with_owner<T>(
        owner: address,
        value: u256,
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(constant::point_updater(), owner, value, ctx);
    }

    // ===== Sub Point =====
    /// Use the function carefully as it's possible on-chain point zero out while off-chain calculation ends up in positive
    /// ex: if we have requests with (+1, -3, +2), on-chain: +2; off-chain: 0
    public fun send_sub_point_req<T>(
        value: u256,   
        ctx: &mut TxContext
    ){
        send_sub_point_req_<T>(constant::point_updater(), ctx.sender(), value, ctx);
    }

    #[test_only]
    public fun send_sub_point_req_with_assigned_updater<T: drop>(
        witness: T,
        updater: address,
        owner: address,
        value: u256,   
        ctx: &mut TxContext
    ){
        send_sub_point_req_<T>(updater, owner, value, ctx);
    }

    public fun send_sub_point_req_with_owner<T>(
        owner: address,
        value: u256,
        ctx: &mut TxContext
    ){
        send_sub_point_req_<T>(constant::point_updater(), owner, value, ctx);
    }

    // ===== Stake Point =====
    public fun send_stake_point_req<T: drop, Action>(
        weight: u256,   
        witness: T,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_stake_point_req_<T, Action>(constant::point_updater(), ctx.sender(), weight, duration, clock, ctx);
    }
    #[test_only]
    public fun send_stake_point_req_with_assigned_updater<T: drop, Action>(
        witness: T,
        updater: address,
        owner: address,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_stake_point_req_<T, Action>(updater, owner, weight, duration, clock, ctx);
    }

    public fun send_stake_point_req_with_owner<T, Action>(
        owner: address,
        weight: u256,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_stake_point_req_<T, Action>(constant::point_updater(), owner, weight, duration, clock, ctx);
    }

    // ===== Unstake Point =====
    public fun send_unstake_point_req<T: drop, Action>(
        weight: u256,   
        witness: T,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_unstake_point_req_<T, Action>(constant::point_updater(), ctx.sender(), weight, duration, clock, ctx);
    }
    #[test_only]
    public fun send_unstake_point_req_with_assigned_updater<T: drop, Action>(
        witness: T,
        updater: address,
        owner: address,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_unstake_point_req_<T, Action>(updater, owner, weight, duration, clock, ctx);
    }

    public fun send_unstake_point_req_with_owner<T, Action>(
        owner: address,
        weight: u256,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_unstake_point_req_<T, Action>(constant::point_updater(), owner, weight, duration, clock, ctx);
    }

    // private function
    fun init_user_info<T>(dashboard: &mut PointDashBoard<T>, owner: address){
        if(!dashboard.user_infos.contains(owner)){
            dashboard.user_infos.add(
                owner, 
                UserInfo{ 
                    points: 0, 
                    configs: vec_map::empty()
                }
            );
        };
    }
    fun send_add_point_req_<T>(
        updater: address,
        owner: address,
        value: u256,   
        ctx: &mut TxContext
    ){
        let point = AddPointRequest<T>{
            id: object::new(ctx),
            owner,
            value
        };
        event::emit(
            LiquidlinkAddPointEvent<T>{
                owner,
                req: object::id(&point),
                value
            }
        );
        transfer::transfer(point, updater);
    }

    fun send_sub_point_req_<T>(
        updater: address,
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
                req: object::id(&point),
                value
            }
        );
        transfer::transfer(point, updater);
    }

    fun send_stake_point_req_<T, Action>(
        updater: address,
        owner: address,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let timestamp = clock.timestamp_ms();
        let req = StakePointRequest<T, Action>{
            id: object::new(ctx),
            owner,
            weight,
            timestamp,
            duration
        };
        event::emit(
            LiquidlinkStakePointEvent<T, Action>{
                owner,
                req: object::id(&req),
                weight,
                timestamp,
                duration
            }
        );
        transfer::transfer(req, updater);
    }

    fun send_unstake_point_req_<T, Action>(
        updater: address,
        owner: address,
        weight: u256,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let timestamp = clock.timestamp_ms();
        let req = UnstakePointRequest<T, Action>{
            id: object::new(ctx),
            owner,
            weight,
            duration,
            timestamp
        };
        event::emit(
            LiquidlinkUnstakePointEvent<T, Action>{
                owner,
                req: object::id(&req),
                weight,
                timestamp,
                duration
            }
        );
        transfer::transfer(req, updater);
    }

    fun checkpoint(
        config: &mut Config,
        timestamp: u64,
        weight: u256,
        duration: u64,
        stake: bool
    ):u256{
        let acc_points = calculate_action_points(config, timestamp);
        let weight = if(stake){
            config.weight + weight
        }else{
            if(config.weight < weight) 0 else config.weight - weight
        };
        config.weight = weight;
        config.last_update = timestamp;
        config.duration = duration;
        
        acc_points
    }

    fun calculate_action_points(config: &Config, current_time: u64):u256{
        if(config.duration == 0 ) return 0;
        let frequency = ( current_time - config.last_update ) / config.duration;
        ( config.weight as u256 )  * ( frequency as u256 )
    }
}
