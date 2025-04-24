# Implementation Details

## Value

The `Value` type is a mutable struct that holds a value and metadata about the value.

```@docs
Cortex.Value
Cortex.ispending
Cortex.iscomputed
```

The primary purpose of the `Value` type is to hold the result of a message and marginal computations. 
The inference engine will use the metadata to determine if the value is pending and must be re-computed.
Both messages and marginals use the `Value` type to hold their result either along edges of the graph or at the nodes of the graph.

```@docs
Cortex.setpending!
Cortex.setvalue!
Cortex.UndefValue
```


