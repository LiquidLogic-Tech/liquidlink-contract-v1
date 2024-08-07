#[test_only]
module liquidlink_protocol::protocol_tests {
    // uncomment this line to import the module
    use liquidlink_protocol::profile;

    const ENotImplemented: u64 = 0;

    #[test]
    fun test_protocol() {
        // pass
    }

    #[test, expected_failure(abort_code = ::liquidlink_protocol::protocol_tests::ENotImplemented)]
    fun test_protocol_fail() {
        abort ENotImplemented
    }
}
