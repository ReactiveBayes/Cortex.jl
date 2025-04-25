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
Cortex.set_pending!
Cortex.unset_pending!
Cortex.set_value!
Cortex.UndefValue
```


