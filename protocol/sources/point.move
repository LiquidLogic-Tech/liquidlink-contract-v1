module liquidlink_protocol::point {
    use liquidlink_protocol::decimal::{Self, Decimal};

    /// PointKey to access Point instance
    public struct PointKey<phantom T> has store{}

    public struct Point<phantom T> has store{
        value: Decimal
    }

    public fun value<T>(
        self: &Point<T>,
        _: &PointKey<T>
    ):&Decimal{
        &self.value
    }

    public fun value_mut<T>(
        self: &mut Point<T>,
        _: &PointKey<T>
    ):&mut Decimal{
        &mut self.value
    }

    public(package) fun new_key<T>():PointKey<T>{
        PointKey<T>{}
    }

    public(package) fun drop_key<T>(key: PointKey<T>){
        let PointKey<T>{} = key;
    }
}
