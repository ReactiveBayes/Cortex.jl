# [Inference Engine](@id inference)

## Overview

The `InferenceEngine` is your gateway to probabilistic inference in Cortex.jl. The engine wraps your [model engine](@ref model_engine) and provides a unified interface for computing and updating messages and marginals required for inference.

Under the hood, the engine uses a [reactive signal system](@ref signals) to track dependencies between computations, update only what's necessary when data changes.
It identifies which parts of the model need updates and manages computation order for efficiency.

The engine also provides built-in [tracing capabilities](@ref inference_tracing) for debugging and performance analysis that records timing of signal computations, tracks value changes during inference, and monitors execution order of computations.

## API Reference

### Engine Management

```@docs
Cortex.InferenceEngine
Cortex.get_model_engine
```

### Variable Operations

```@docs
Cortex.get_variable(::Cortex.InferenceEngine, ::Int)
Cortex.get_variable_ids(::Cortex.InferenceEngine)
```

### Factor Operations

```@docs
Cortex.get_factor(::Cortex.InferenceEngine, ::Int)
Cortex.get_factor_ids(::Cortex.InferenceEngine)
```

### Connection and Message Passing Interface

```@docs
Cortex.get_connection(::Cortex.InferenceEngine, ::Int, ::Int)
Cortex.get_connection_message_to_variable(::Cortex.InferenceEngine, ::Int, ::Int)
Cortex.get_connection_message_to_factor(::Cortex.InferenceEngine, ::Int, ::Int)
Cortex.get_connected_variable_ids(::Cortex.InferenceEngine, ::Int)
Cortex.get_connected_factor_ids(::Cortex.InferenceEngine, ::Int)
```

### Signal Variants

The engine uses different signal variants to manage various aspects of inference:

```@docs
Cortex.InferenceSignalVariants
Cortex.InferenceSignalVariants.Unspecified
Cortex.InferenceSignalVariants.MessageToFactor
Cortex.InferenceSignalVariants.MessageToVariable
Cortex.InferenceSignalVariants.ProductOfMessages
Cortex.InferenceSignalVariants.IndividualMarginal
Cortex.InferenceSignalVariants.JointMarginal
Cortex.InferenceSignalVariant
Cortex.InferenceSignal
Cortex.create_inference_signal
Cortex.set_signals_variants!
```

### Running Inference

```@docs
Cortex.request_inference_for
Cortex.InferenceRequest
Cortex.scan_inference_request
Cortex.InferenceRequestScanner
Cortex.AbstractInferenceRequestProcessor
Cortex.compute_message_to_variable
Cortex.compute_message_to_factor
Cortex.compute_individual_marginal
Cortex.compute_product_of_messages
Cortex.compute_joint_marginal
Cortex.process_inference_request
Cortex.process!
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