# Value

The `Value` type is a mutable struct that holds a value and metadata about the value.

```@docs
Cortex.Value
Cortex.is_pending
Cortex.is_computed
```

The primary purpose of the `Value` type is to hold the result of a message and marginal computations. 
The inference engine will use the metadata to determine if the value is pending and must be re-computed.
Both messages and marginals use the `Value` type to hold their result either along edges of the graph or at the nodes of the graph.

```@docs
Cortex.set_pending!(::Cortex.Value)
Cortex.unset_pending!(::Cortex.Value)
Cortex.set_value!(::Cortex.Value, ::Any)
Cortex.UndefValue
```

## DualPendingGroup

The `DualPendingGroup` type is a helper struct that is used to track the pending state of a value.
It is used to optimize the computation of the pending state of a collection of values by using a bitwise operation.

```@docs
Cortex.DualPendingGroup
Cortex.is_pending_in
Cortex.is_pending_out
Cortex.set_pending!(::Cortex.DualPendingGroup, ::Int)
Cortex.add_element!(::Cortex.DualPendingGroup)
```