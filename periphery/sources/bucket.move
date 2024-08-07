module liquidlink_periphery::bucket {

    public struct Bucket has drop {}

    public struct BucketPeriphery has key{
        id: UID,
        weight: VecSet<TypeName, u8>
    }
    
}

