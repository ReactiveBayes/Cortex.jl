# [Inference Engine](@id inference)

## Overview

The `InferenceEngine` is your gateway to probabilistic inference in Cortex.jl. The engine wraps your [model backend](@ref model_backend) and provides a unified interface for computing and updating messages and marginals required for inference.

Under the hood, the engine uses a [reactive signal system](@ref signals) to track dependencies between computations, update only what's necessary when data changes.
It identifies which parts of the model need updates and manages computation order for efficiency.

The engine also provides built-in [tracing capabilities](@ref inference_tracing) for debugging and performance analysis that records timing of signal computations, tracks value changes during inference, and monitors execution order of computations.

## API Reference

### Engine Management

```@docs
Cortex.InferenceEngine
Cortex.get_model_backend
```

### Variable Operations

```@docs
Cortex.get_variable_data(::Cortex.InferenceEngine, ::Any)
Cortex.get_variable_ids(::Cortex.InferenceEngine)
Cortex.get_marginal(::Cortex.InferenceEngine, ::Any)
```

### Factor Operations

```@docs
Cortex.get_factor_data(::Cortex.InferenceEngine, ::Any)
Cortex.get_factor_ids(::Cortex.InferenceEngine)
```

### Message Passing Interface

```@docs
Cortex.get_message_to_variable(::Cortex.InferenceEngine, ::Any, ::Any)
Cortex.get_message_to_factor(::Cortex.InferenceEngine, ::Any, ::Any)
Cortex.get_connected_variable_ids(::Cortex.InferenceEngine, ::Any)
Cortex.get_connected_factor_ids(::Cortex.InferenceEngine, ::Any)
```

### Signal Types

The engine uses different signal types to manage various aspects of inference:

```@docs
Cortex.InferenceSignalTypes
```

#### Available Signal Types

```@docs
Cortex.InferenceSignalTypes.MessageToVariable
Cortex.InferenceSignalTypes.MessageToFactor
Cortex.InferenceSignalTypes.ProductOfMessages
Cortex.InferenceSignalTypes.IndividualMarginal
Cortex.InferenceSignalTypes.JointMarginal
Cortex.prepare_signals_metadata!
```

### Running Inference

```@docs
Cortex.request_inference_for
Cortex.InferenceRequest
Cortex.scan_inference_request
Cortex.InferenceRequestScanner
Cortex.process_inference_request
Cortex.process!
Cortex.CallbackInferenceRequestProcessor
Cortex.update_marginals!
```

### [Tracing and Debugging](@id inference_tracing)

```@docs
Cortex.InferenceEngineWarning
Cortex.TracedInferenceExecution
Cortex.TracedInferenceRound
Cortex.TracedInferenceRequest
Cortex.InferenceEngineTracer
```