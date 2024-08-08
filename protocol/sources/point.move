module liquidlink_protocol::point {
    public struct PointKey<phantom T> has store{}

    public struct Point has store{
        value: u64,
        time: u64
    }

    public(package) fun new_key<T>():PointKey<T>{
        PointKey<T>{}
    }
    public(package) fun drop_key<T>(key: PointKey<T>){
        let PointKey<T>{} = key;
    }
}
