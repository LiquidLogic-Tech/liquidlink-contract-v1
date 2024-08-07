module liquidlink_profile::error {
    
    const ErrorNotAuthorized: u64 = 1;
    public fun not_authorized_error(): u64 {
        ErrorNotAuthorized
    }

    const ErrorDuplicatedUserDappScoreObject: u64 = 2;
    public fun duplicated_user_dapp_score_object_error(): u64 {
        ErrorDuplicatedUserDappScoreObject
    }

    const ErrorDuplicated: u64 = 3;
    public fun duplicated_error(): u64 {
        ErrorDuplicated
    }

    const ErrorNotExist: u64 = 4;
    public fun not_exist_error(): u64 {
        ErrorNotExist
    }

    const ErrorUpdaterExpired: u64 = 5;
    public fun updater_expired_error(): u64 {
        ErrorUpdaterExpired
    }

    const ErrorTargetNotExist: u64 = 6;
    public fun target_not_exist_error(): u64 {
        ErrorTargetNotExist
    }

    const ErrorScoreUnderZero: u64 = 7;
    public fun score_under_zero_error(): u64 {
        ErrorScoreUnderZero
    }

    const ErrorAddressNotBelongToSameProfile: u64 = 8;
    public fun address_not_belong_to_same_profile_error(): u64 {
        ErrorAddressNotBelongToSameProfile
    }

    const ErrAddressNotLinked: u64 = 9;
    public fun address_not_linked_error(): u64 {
        ErrAddressNotLinked
    }
    
    const ErrAddressHasLinked: u64 = 10;
    public fun address_has_linked_error(): u64 {
        ErrAddressHasLinked
    }

    const ErrHasExist: u64 = 11;
    public fun has_exist_error(): u64 {
        ErrHasExist
    }
    

}