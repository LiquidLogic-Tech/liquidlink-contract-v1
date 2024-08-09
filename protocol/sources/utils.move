module liquidlink_protocol::utils {
    use sui::clock::{Self, Clock};

    public fun timestamp_sec(clock: &Clock): u64 {
        clock::timestamp_ms(clock) / 1000
    }

    fun is_valid_time<T>(
        last_update: u64,
        frequency: u64,
        clock: &Clock
    ):bool{
        (last_update + frequency <= timestamp_sec(clock))
    }
}
