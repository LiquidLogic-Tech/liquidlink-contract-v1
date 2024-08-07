module liquidlink_protocol::point {
    public struct PointKey<phantom T> has store{}

    public struct Point has store{
        value: u64,
        time: u64
    }
}
