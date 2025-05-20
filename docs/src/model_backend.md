# [Probabilistic Model Backend](@id model_backend)

Cortex.jl is designed with flexibility in mind, allowing it to work with various probabilistic model representations. Instead of implementing a specific model backend, Cortex.jl defines an interface that any model backend can implement to be used with the inference engine.

## Why an Interface-Based Approach?

This design choice offers several advantages:

1. **Flexibility**: Users can choose or implement model backends that best suit their needs, whether it's a simple in-memory graph or a distributed database.
2. **Interoperability**: Existing probabilistic model implementations, both in Julia and other languages, can be integrated by implementing the interface.
3. **Performance**: Specialized model backends can be optimized for specific use cases without modifying Cortex.jl itself.
4. **Extensibility**: New model backends can be added without changing the core Cortex.jl codebase.

## Currently Supported Model Backends

At present, Cortex.jl officially supports the `BipartiteFactorGraph` type from the [BipartiteFactorGraphs.jl](https://github.com/ReactiveBayes/BipartiteFactorGraphs.jl) package. To use it:

```@example model_backend_bipartite_factor_graph
using BipartiteFactorGraphs
using Cortex
using Test #hide

# Create a bipartite factor graph
graph = BipartiteFactorGraph()
# ... add variables and factors to the graph ...

# Use it with Cortex's inference engine
engine = Cortex.InferenceEngine(model_backend = graph)

@test Cortex.get_model_backend(engine) isa BipartiteFactorGraph #hide

nothing #hide
```

You might be interested in the [`GraphPPL.jl`](https://github.com/ReactiveBayes/GraphPPL.jl) package which provides a more user-friendly interface for creating and manipulating probabilistic models in a form of a `BipartiteFactorGraph`.

## [Implementing a New Model Backend](@id supported_model_backend_trait)

To make a new data structure work as a model backend, first you need to implement the trait that indicates support:

```@docs
Cortex.is_backend_supported
Cortex.SupportedModelBackend
Cortex.UnsupportedModelBackend
```

If an unsupported data structure is used as a model backend, Cortex.jl will throw:

```@docs
Cortex.UnsupportedModelBackendError
Cortex.throw_if_backend_unsupported
```

## [Required Model Backend Methods](@id required_methods_for_model_backend)

After implementing the trait, model backends must implement the following methods:

```@docs 
Cortex.get_variable_data
Cortex.get_factor_data
Cortex.get_marginal
Cortex.get_variable_ids
Cortex.get_factor_ids
Cortex.get_connected_variable_ids
Cortex.get_connected_factor_ids
Cortex.get_connection
Cortex.get_connection_label
Cortex.get_connection_index
Cortex.get_message_to_variable
Cortex.get_message_to_factor
```

These methods form a complete interface that allows Cortex.jl to:
- Access variables and factors in your model
- Retrieve marginal distributions
- Navigate connections between variables and factors
- Perform inference using your model backend