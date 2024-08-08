module liquidlink_protocol::utils {
    use sui::clock::{Self, Clock};

    public fun timestamp_sec(clock: &Clock): u64 {
        clock::timestamp_ms(clock) / 1000
    }

}
