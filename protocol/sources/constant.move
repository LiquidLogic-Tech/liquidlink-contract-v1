module liquidlink_protocol::constant {
    
    const POINT_UPDATER: address = @0x2ca9e149e1a1b403d6636568ebd9e62f681a1037d7510164df77aebe7b9cf4a71;

    public fun point_updater():address{
        POINT_UPDATER
    }
}
