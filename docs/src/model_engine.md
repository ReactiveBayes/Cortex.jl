# [Probabilistic Model Engine](@id model_engine)

## Overview

Cortex.jl is designed to allow it to work with various probabilistic model representations. Instead of implementing a specific model engine, Cortex.jl defines an interface that any model engine can implement to be used with the inference engine.

This design choice offers several advantages:

1. **Flexibility**: Users can choose or implement model engines that best suit their needs, whether it's a simple in-memory graph or a distributed database.
2. **Interoperability**: Existing probabilistic model implementations, both in Julia and other languages, can be integrated by implementing the interface.
3. **Performance**: Specialized model engines can be optimized for specific use cases without modifying Cortex.jl itself.
4. **Extensibility**: New model engines can be added without changing the core Cortex.jl codebase.

## [Core Data Structures](@id core_data_structures)

Model engines work with three core data structures:

- [`Variable`](@ref model_engine_variable) - Represents a random variable in the model.
- [`Factor`](@ref model_engine_factor) - Represents a factor in the model.
- [`Connection`](@ref model_engine_connection) - Represents a connection between a variable and a factor.

These structures provide a standardized interface for representing probabilistic models while allowing flexibility in the underlying implementation.

### [`Variable`](@id model_engine_variable)

```@docs
Cortex.Variable
Cortex.get_variable_name
Cortex.get_variable_index
Cortex.get_variable_marginal
Cortex.get_variable_linked_signals
Cortex.link_signal_to_variable!
```

### [`Factor`](@id model_engine_factor)

```@docs
Cortex.Factor
Cortex.get_factor_functional_form
Cortex.get_factor_local_marginals
Cortex.add_local_marginal_to_factor!
```

### [`Connection`](@id model_engine_connection)

```@docs
Cortex.Connection
Cortex.get_connection_label
Cortex.get_connection_index
Cortex.get_connection_message_to_variable
Cortex.get_connection_message_to_factor
```

## Currently Supported Model Engines

At present, Cortex.jl officially supports the `BipartiteFactorGraph` type from the [BipartiteFactorGraphs.jl](https://github.com/ReactiveBayes/BipartiteFactorGraphs.jl) package. To use it:

```@example model_engine_bipartite_factor_graph
using BipartiteFactorGraphs
using Cortex
using Test #hide

# Create a bipartite factor graph where 
# - the type of variables is `Cortex.Variable`
# - the type of factors is `Cortex.Factor`
# - the type of connections is `Cortex.Connection`
graph = BipartiteFactorGraph(Cortex.Variable, Cortex.Factor, Cortex.Connection)
# ... add variables and factors to the graph ...

# Use it with Cortex's inference engine
engine = Cortex.InferenceEngine(model_engine = graph)

@test Cortex.get_model_engine(engine) isa BipartiteFactorGraph #hide

nothing #hide
```

You might be interested in the [`GraphPPL.jl`](https://github.com/ReactiveBayes/GraphPPL.jl) package which provides a more user-friendly interface for creating and manipulating probabilistic models in a form of a `BipartiteFactorGraph`.

## [Implementing a New Model Engine](@id supported_model_engine_trait)

To make a new data structure work as a model engine, first you need to implement the trait that indicates support:

```@docs
Cortex.is_engine_supported
Cortex.SupportedModelEngine
Cortex.UnsupportedModelEngine
```

If an unsupported data structure is used as a model engine, Cortex.jl will throw:

```@docs
Cortex.UnsupportedModelEngineError
Cortex.throw_if_engine_unsupported
```

## [Required Model Engine Methods](@id required_methods_for_model_engine)

After implementing the trait, model engines must implement the following methods.

!!! note
    Some methods are aliases for the [`Cortex.InferenceEngine`](@ref) structure, those do not need to be implemented.

```@docs 
Cortex.get_variable
Cortex.get_factor
Cortex.get_variable_ids
Cortex.get_factor_ids
Cortex.get_connected_variable_ids
Cortex.get_connected_factor_ids
Cortex.get_connection
```

These methods form a complete interface that allows Cortex.jl to:
- Access variables and factors in your model using standardized `Variable` and `Factor` types
- Navigate connections between variables and factors using the `Connection` type
- Perform inference using your model engine

