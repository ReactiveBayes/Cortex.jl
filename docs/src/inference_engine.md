# [Inference Engine](@id inference)

The `InferenceEngine` is the central component in Cortex.jl for performing probabilistic inference. It acts as an abstraction layer over different model backends, providing a consistent API for interacting with models and running inference algorithms.

## Concept

The primary role of the `InferenceEngine` is to:

1.  **Manage a Model Backend:** It holds an instance of a specific model structure (e.g., a `BipartiteFactorGraph`).
2.  **Provide a Standardized API:** It offers a set of functions to access and manipulate model components like variables, factors, and their connections, regardless of the underlying backend's specific implementation.
3.  **Orchestrate Inference:** It uses the reactive `Signal` system to manage the flow of messages and marginals. When data or priors change, the engine helps identify which parts of the model need updates.
4.  **Execute Computations:** It facilitates the application of user-defined computation functions (rules for how messages and marginals are calculated) to update the model's state using the [`update_marginals!`](@ref) function.

Upon creation, the `InferenceEngine` can automatically prepare the metadata of the signals within the model (marginals, messages to variables, messages to factors) by calling [`prepare_signals_metadata!`](@ref). This step is crucial as it assigns specific types and metadata (like variable or factor IDs) to signals, which are often used by the computation functions during inference.

## Core API

```@docs
Cortex.InferenceEngine
Cortex.get_model_backend
```

### Accessing Model Components

The engine provides a suite of functions to retrieve data and reactive signals associated with variables, factors, and their connections from the model backend. Read more about the model backend in the [model backend](@ref model_backend) section.

#### Variables
```@docs
Cortex.get_variable_data(::Cortex.InferenceEngine, ::Any)
Cortex.get_variable_ids(::Cortex.InferenceEngine)
Cortex.get_marginal(::Cortex.InferenceEngine, ::Any)
```

#### Factors
```@docs
Cortex.get_factor_data(::Cortex.InferenceEngine, ::Any)
Cortex.get_factor_ids(::Cortex.InferenceEngine)
```

#### Connections and Messages
```@docs
Cortex.get_connection(::Cortex.InferenceEngine, ::Any, ::Any)
Cortex.get_connection_label(::Cortex.InferenceEngine, ::Any, ::Any)
Cortex.get_connection_index(::Cortex.InferenceEngine, ::Any, ::Any)
Cortex.get_message_to_variable(::Cortex.InferenceEngine, ::Any, ::Any)
Cortex.get_message_to_factor(::Cortex.InferenceEngine, ::Any, ::Any)
Cortex.get_connected_variable_ids(::Cortex.InferenceEngine, ::Any)
Cortex.get_connected_factor_ids(::Cortex.InferenceEngine, ::Any)
```

### Signal Metadata and Types

Understanding and managing signal metadata is key for many inference algorithms.

```@docs
Cortex.InferenceSignalTypes
Cortex.InferenceSignalTypes.MessageToVariable
Cortex.InferenceSignalTypes.MessageToFactor
Cortex.InferenceSignalTypes.ProductOfMessages
Cortex.InferenceSignalTypes.IndividualMarginal
Cortex.InferenceSignalTypes.JointMarginal
Cortex.prepare_signals_metadata!
```

### Running Inference

These functions are used to initiate and execute the inference process.

```@docs
Cortex.request_inference_for
Cortex.update_marginals!
``` 