module liquidlink_protocol::point {
    use std::ascii::String;

    use sui::event;
    use sui::clock::Clock;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};

    use liquidlink_protocol::constant;

    // === const ===
    const ERR_OBSOLETE_REQUEST: u64 = 101;

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
        action: String,
        value: u256
    }
    public struct SubPointRequest<phantom T> has key{
        id: UID,
        owner: address,
        action: String,
        value: u256
    }
    public struct StakePointRequest<phantom T> has key{
        id: UID,
        owner: address,
        action: String,
        weight: u256,
        duration: u64,
        timestamp: u64
    }
    public struct UnstakePointRequest<phantom T> has key{
        id: UID,
        owner: address,
        action: String,
        weight: u256,
        duration: u64,
        timestamp: u64
    }
    public struct UserInfo has store, copy, drop{
        points: VecMap<String, u256>,
        configs: VecMap<String, Config>
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
    public fun get_user_info_points<T>(
        dashboard: &PointDashBoard<T>,
        user: address,
        clock: &Clock
    ):u256{
        let mut points = 0;
        let info = get_user_info<T>(dashboard, user);
        if(info.is_some()){
            let info_ = info.borrow();

            //. settled points
            let keys = info_.points.keys();
            let (mut i, len) = (0, keys.length());
            while(i < len){
                points = points + info_.points[&keys[i]];
                i = i + 1;
            };

            // configs
            let keys = info_.configs.keys();
            let (mut i, len) = (0, keys.length());
            while(i < len){
                let accumulated_points = calculate_config_points(&info_.configs[&keys[i]], clock.timestamp_ms());
                points = points + accumulated_points;
                i = i + 1;
            };
        };

        points
    }

    public fun get_user_info_point_by_action<T>(
        dashboard: &PointDashBoard<T>,
        user: address,
        action: String,
        clock: &Clock
    ):u256{
        if(!dashboard.user_infos.contains(user)){
            0
        }else{
            let user_info = dashboard.user_infos[user];
            let points = if(user_info.points.contains(&action)) user_info.points[&action] else 0;
            let staking_points = if(user_info.configs.contains(&action)) calculate_config_points(&user_info.configs[&action], clock.timestamp_ms()) else 0;

            points + staking_points
        }
    }

    // === event ===
    public struct LiquidlinkAddPointEvent<phantom T> has copy, drop{
        owner: address,
        action: String,
        req: ID,
        value: u256,
    }
    public struct LiquidlinkSubPointEvent<phantom T> has copy, drop{
        owner: address,
        action: String,
        req: ID,
        value: u256,
    }
    public struct LiquidlinkStakePointEvent<phantom T> has copy, drop{
        owner: address,
        action: String,
        req: ID,
        weight: u256,
        timestamp: u64,
        duration: u64,
    }
    public struct LiquidlinkUnstakePointEvent<phantom T> has copy, drop{
        owner: address,
        action: String,
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
    public(package) fun add_point<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        req: AddPointRequest<T>
    ){
        let AddPointRequest{
            id,
            owner,
            action,
            value
        } = req;
        object::delete(id);

        init_user_info(dashboard, owner);

        let user_info = &mut dashboard.user_infos[owner];
        if(!user_info.points.contains(&action)){
            user_info.points.insert(action, value);
        }else{
            let prev_point = user_info.points[&action];
            *&mut user_info.points[&action] = prev_point + value;
        };

        dashboard.total_points = dashboard.total_points + value;
    }

    public(package) fun sub_point<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        req: SubPointRequest<T>
    ){
        let SubPointRequest{
            id,
            owner,
            action,
            value
        } = req;
        object::delete(id);

        init_user_info(dashboard, owner);

        let user_info = &mut dashboard.user_infos[owner];
        if(user_info.points.contains(&action)){
            let prev_user_point = *&user_info.points[&action];
    
            let deducted_points = if(prev_user_point <= value){
                user_info.points.remove(&action);
                prev_user_point
            }else{
                *&mut user_info.points[&action] = prev_user_point - value;
                value
            };
            dashboard.total_points = dashboard.total_points - deducted_points;
        };
    }

    public(package) fun stake_point<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        req: StakePointRequest<T>
    ){
        let StakePointRequest<T>{
            id,
            owner,
            action,
            weight,
            timestamp,
            duration
        } = req;
        object::delete(id);

        init_user_info(dashboard, owner);

        let info = &mut dashboard.user_infos[owner];
        if(!info.configs.contains(&action)){
            info.configs.insert(
                action,
                Config{
                    weight,
                    last_update: timestamp,
                    duration
                }
            );
        }else{
            let config = &mut info.configs[&action];
            let acc_points = config.checkpoint(timestamp, weight, duration);
               
            // update dashboard
            dashboard.total_points = dashboard.total_points + acc_points;

            // settled staked points
            if(!info.points.contains(&action)){
                info.points.insert(action, acc_points);
            }else{
                let prev_point = info.points[&action];
                *&mut info.points[&action] = prev_point + acc_points;
            };
        }
    }

    public(package) fun unstake_point<T: drop>(
        dashboard: &mut PointDashBoard<T>,
        req: UnstakePointRequest<T>
    ){
        let UnstakePointRequest<T>{
            id,
            owner,
            action,
            weight,
            timestamp,
            duration
        } = req;
        object::delete(id);

        init_user_info(dashboard, owner);

        let info = &mut dashboard.user_infos[owner];
        
        if(info.configs.contains(&action)){
            let config = &mut info.configs[&action];
            let acc_points = config.checkpoint(timestamp, weight, duration);

            // update dashboard
            dashboard.total_points = dashboard.total_points + acc_points;
            // settled staked points
            if(!info.points.contains(&action)){
                info.points.insert(action, acc_points);
            }else{
                let prev_point = info.points[&action];
                *&mut info.points[&action] = prev_point + acc_points;
            };
        }
    }

    // ===== Add Point =====
    public fun send_add_point_req<T: drop>(
        _witness: &T,
        action: String,
        value: u256,   
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(constant::point_updater(), ctx.sender(), action, value, ctx);
    }
    #[test_only]
    public fun send_add_point_req_with_assigned_updater<T: drop>(
        _witness: &T,
        updater: address,
        owner: address,
        action: String,
        value: u256,   
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(updater, owner, action, value, ctx);
    }

    public fun send_add_point_req_with_owner<T: drop>(
        _witness: &T,
        owner: address,
        action: String,
        value: u256,
        ctx: &mut TxContext
    ){
        send_add_point_req_<T>(constant::point_updater(), owner, action, value, ctx);
    }

    // ===== Sub Point =====
    /// Use the function carefully as it's possible on-chain point zero out while off-chain calculation ends up in positive
    /// ex: if we have requests with (+1, -3, +2), on-chain: +2; off-chain: 0
    public fun send_sub_point_req<T: drop>(
        _witness: &T,
        action: String,
        value: u256,   
        ctx: &mut TxContext
    ){
        send_sub_point_req_<T>(constant::point_updater(), ctx.sender(), action, value, ctx);
    }

    #[test_only]
    public fun send_sub_point_req_with_assigned_updater<T: drop>(
        _witness: &T,
        updater: address,
        owner: address,
        action: String,
        value: u256,   
        ctx: &mut TxContext
    ){
        send_sub_point_req_<T>(updater, owner, action, value, ctx);
    }

    public fun send_sub_point_req_with_owner<T: drop>(
        _witness: &T,
        owner: address,
        action: String,
        value: u256,
        ctx: &mut TxContext
    ){
        send_sub_point_req_<T>(constant::point_updater(), owner, action, value, ctx);
    }

    // ===== Stake Point =====
    public fun send_stake_point_req<T: drop>(
        _witness: &T,
        action: String,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_stake_point_req_<T>(constant::point_updater(), ctx.sender(), action, weight, duration, clock, ctx);
    }
    #[test_only]
    public fun send_stake_point_req_with_assigned_updater<T: drop>(
        _witness: &T,
        updater: address,
        owner: address,
        action: String,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_stake_point_req_<T>(updater, owner, action, weight, duration, clock, ctx);
    }

    public fun send_stake_point_req_with_owner<T: drop>(
        _witness: &T,
        owner: address,
        action: String,
        weight: u256,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_stake_point_req_<T>(constant::point_updater(), owner, action, weight, duration, clock, ctx);
    }

    // ===== Unstake Point =====
    public fun send_unstake_point_req<T: drop>(
        _witness: &T,
        action: String,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_unstake_point_req_<T>(constant::point_updater(), ctx.sender(), action, weight, duration, clock, ctx);
    }
    #[test_only]
    public fun send_unstake_point_req_with_assigned_updater<T: drop>(
        _witness: &T,
        updater: address,
        owner: address,
        action: String,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_unstake_point_req_<T>(updater, owner, action, weight, duration, clock, ctx);
    }

    public fun send_unstake_point_req_with_owner<T: drop>(
        _witness: &T,
        owner: address,
        action: String,
        weight: u256,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        send_unstake_point_req_<T>(constant::point_updater(), owner, action, weight, duration, clock, ctx);
    }

    // private function
    fun init_user_info<T: drop>(dashboard: &mut PointDashBoard<T>, owner: address){
        if(!dashboard.user_infos.contains(owner)){
            dashboard.user_infos.add(
                owner, 
                UserInfo{ 
                    points: vec_map::empty(),
                    configs: vec_map::empty()
                }
            );
        };
    }
    fun send_add_point_req_<T: drop>(
        updater: address,
        owner: address,
        action: String,
        value: u256,   
        ctx: &mut TxContext
    ){
        let point = AddPointRequest<T>{
            id: object::new(ctx),
            owner,
            action,
            value
        };
        event::emit(
            LiquidlinkAddPointEvent<T>{
                owner,
                action,
                req: object::id(&point),
                value
            }
        );
        transfer::transfer(point, updater);
    }

    fun send_sub_point_req_<T: drop>(
        updater: address,
        owner: address,
        action: String,
        value: u256,   
        ctx: &mut TxContext
    ){
        let point = SubPointRequest<T>{
            id: object::new(ctx),
            owner,
            action,
            value
        };
        event::emit(
            LiquidlinkSubPointEvent<T>{
                owner,
                action,
                req: object::id(&point),
                value
            }
        );
        transfer::transfer(point, updater);
    }

    fun send_stake_point_req_<T: drop>(
        updater: address,
        owner: address,
        action: String,
        weight: u256,   
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let timestamp = clock.timestamp_ms();
        let req = StakePointRequest<T>{
            id: object::new(ctx),
            owner,
            action,
            weight,
            timestamp,
            duration
        };
        event::emit(
            LiquidlinkStakePointEvent<T>{
                owner,
                action,
                req: object::id(&req),
                weight,
                timestamp,
                duration
            }
        );
        transfer::transfer(req, updater);
    }

    fun send_unstake_point_req_<T: drop>(
        updater: address,
        owner: address,
        action: String,
        weight: u256,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let timestamp = clock.timestamp_ms();
        let req = UnstakePointRequest<T>{
            id: object::new(ctx),
            owner,
            action,
            weight,
            duration,
            timestamp
        };
        event::emit(
            LiquidlinkUnstakePointEvent<T>{
                owner,
                action,
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
        duration: u64
    ):u256{
        assert!(timestamp > config.last_update, ERR_OBSOLETE_REQUEST);
        let acc_points = calculate_config_points(config, timestamp);

        config.weight = weight;
        config.last_update = timestamp;
        config.duration = duration;
        
        acc_points
    }

    fun calculate_config_points(config: &Config, current_time: u64):u256{
        if(config.duration == 0 ) return 0;
        let elapsed = (( current_time - config.last_update ) as u256);
        ( config.weight as u256 ) * elapsed / ( config.duration as u256 )
    }
}
