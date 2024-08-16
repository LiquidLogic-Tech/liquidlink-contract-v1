# Liquidlink

### LiquidLink Integration

1. create Witness as the registas the type

```typescript
public struct OTW has drop {}
```

2. Liqudilink help create dashboard and register Witness

3. Integrated protcol call the method to send add/sub point request

```typescript
    // add the points for sender address
    point::send_add_point_req<OTW>(
       value,
       OTW{}, // create Instance as the validation
       ctx
    )
    // add the points for assigned owner
    point::send_add_point_req_with_owner<OTW>(
       value,
       OTW{}, // create Instance as the validation
       ctx
    )
    // sub the points for sender address
    point::send_sub_point_req<OTW>(
       value,
       OTW{}, // create Instance as the validation
       ctx
    )
    // sub the points for assigned owner
    point::send_sub_point_req_with_owner<OTW>(
       value,
       OTW{}, // create Instance as the validation
       ctx
    )
```
