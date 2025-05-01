# [Signals: The Core of Reactivity](@id signals)

At the heart of Cortex.jl's reactivity system lies the [`Signal`](@ref).

## Concept

Think of a [`Signal`](@ref) as a container for a value that can change over time. The key idea is that other parts of your system can *depend* on a signal. When the signal's value changes, anything that depends on it (its *listeners*) is notified, allowing the system to react automatically.

**For Beginners:** Imagine a spreadsheet cell. When you change the value in one cell (like `A1`), other cells that use `A1` in their formulas (like `B1 = A1 * 2`) automatically update. A [`Signal`](@ref) is like that cell – it holds a value, and changes can trigger updates elsewhere.

**For Advanced Users:** Signals form a directed graph (potentially cyclic, although cycles might affect update logic depending on how they are handled). Each [`Signal`](@ref) node stores a value, an optional `type` identifier (`UInt8`), optional `metadata`, and maintains lists of its dependencies and listeners. When a signal is updated via [`set_value!`](@ref), it propagates a notification through the graph, potentially marking downstream signals as 'pending'. This 'pending' state indicates that the signal's value might be stale and needs recomputation. The actual recomputation logic is defined externally via the [`compute!`](@ref) function, which uses the signal's `type` and `metadata` (along with dependency values) to calculate the new value.

## Key Features

*   **Value Storage:** Holds the current value.
*   **Type Identifier:** Stores an optional `UInt8` type ([`get_type`](@ref)), defaulting to `0x00`.
*   **Optional Metadata:** Can store arbitrary metadata ([`get_metadata`](@ref)), defaulting to `UndefMetadata()`.
*   **Dependency Tracking:** Knows which other signals it depends on (`dependencies`) and which signals depend on it ([`listeners`](@ref) via [`get_listeners`](@ref)).
*   **Notification:** When updated via [`set_value!`](@ref), it notifies its active listeners.
*   **Pending State:** Can be marked as [`is_pending`](@ref) if its dependencies have updated appropriately, signaling a need for recomputation via [`compute!`](@ref).
*   **External Computation:** Relies on the [`compute!`](@ref) function and a provided strategy to update its value based on dependencies.
*   **Weak Dependencies:** Supports 'weak' dependencies, which influence the pending state based only on whether they are computed ([`is_computed`](@ref)), not their age relative to the listener.
*   **Controlled Listening:** Allows dependencies to be added without automatically listening to their updates (`listen=false` in [`add_dependency!`](@ref)).
*   **Controlled Initial Check:** Allows dependencies to be added without immediately checking their computed state (`check_computed=false` in [`add_dependency!`](@ref)).

## Usage Examples

Here are some basic examples demonstrating how to use signals.

### Creating Signals and Checking Properties

Signals can be created with or without an initial value. You can optionally specify a `type` identifier and `metadata`.

Create signals:
```@example signal_examples
import Cortex
using Test # hide

# Create signals
s1 = Cortex.Signal(10)
```

```@example signal_examples
 # Initial value, computed=true
s2 = Cortex.Signal(5)
```

```@example signal_examples
# No initial value, computed=false
s3 = Cortex.Signal()        
```

```@example signal_examples
# Signal with type and metadata
s4 = Cortex.Signal(true; type=0x01, metadata=Dict(:info => "flag"))
```
Check their properties:
```@example signal_examples
@test Cortex.get_value(s1) == 10 # hide
Cortex.get_value(s1)   # 10
```
```@example signal_examples
@test Cortex.get_value(s3) === Cortex.UndefValue() # hide
Cortex.get_value(s3)   # Cortex.UndefValue()
```
```@example signal_examples
@test Cortex.is_computed(s1) == true # hide
Cortex.is_computed(s1) # true
```
```@example signal_examples
@test Cortex.is_computed(s3) == false # hide
Cortex.is_computed(s3) # false
```
```@example signal_examples
@test Cortex.get_type(s1) === 0x00 # hide
Cortex.get_type(s1) # 0x00 (default)
```
```@example signal_examples
@test Cortex.get_type(s4) === 0x01 # hide
Cortex.get_type(s4) # 0x01
```
```@example signal_examples
@test Cortex.get_metadata(s1) === Cortex.UndefMetadata() # hide
Cortex.get_metadata(s1) # UndefMetadata() (default)
```
```@example signal_examples
@test Cortex.get_metadata(s4) == Dict(:info => "flag") # hide
Cortex.get_metadata(s4) # Dict{Symbol, String}(:info => "flag")
```

### Setting Values

Use [`Cortex.set_value!`](@ref) to update a signal's value. This marks the signal as computed and updates its age.

Setting a value updates the age and computed status:
```@example signal_examples
Cortex.set_value!(s3, 99.0)
```
```@example signal_examples
@test Cortex.get_value(s3) == 99.0 # hide
Cortex.get_value(s3)   # 99.0
```
```@example signal_examples
@test Cortex.is_computed(s3) == true # hide
Cortex.is_computed(s3) # true
```

### Adding Dependencies

Signals can depend on other signals. Use [`Cortex.add_dependency!`](@ref) to create these links. This populates the `dependencies` list of the dependent signal and the `listeners` list of the dependency.

Adding dependencies links signals:
```@example signal_examples
s_derived = Cortex.Signal() # A signal that will depend on s1 and s2

Cortex.add_dependency!(s_derived, s1)
Cortex.add_dependency!(s_derived, s2)
```
```@example signal_examples
@test length(Cortex.get_dependencies(s_derived)) == 2 # hide
length(Cortex.get_dependencies(s_derived)) # 2
```
```@example signal_examples
@test length(Cortex.get_listeners(s1)) == 1 # hide
length(Cortex.get_listeners(s1))           # 1
```
```@example signal_examples
@test length(Cortex.get_listeners(s2)) == 1 # hide
length(Cortex.get_listeners(s2))           # 1
```

### Pending State

A signal becomes pending ([`Cortex.is_pending`](@ref) returns `true`) when its dependencies are updated in a way that satisfies the pending criteria (all weak computed, all strong older and computed). Adding a computed dependency can also immediately mark a signal as pending.

Updating a dependency can mark listeners as pending:
```@example signal_examples
@test Cortex.is_pending(s_derived) == true # hide
Cortex.is_pending(s_derived) # true
```

`s_derived` is pending because both `s1` and `s2` have been computed at the time of dependency addition.

### Computing Signal Values

To compute a signal, use the [`Cortex.compute!`](@ref) function, providing a strategy (often a simple function) to calculate the new value based on dependencies. Computing a signal typically clears its pending state.

!!! note
    By default, `compute!` throws an `ArgumentError` if called on a signal that is not pending ([`Cortex.is_pending`](@ref) returns `false`). You can override this check using the `force=true` keyword argument.

```@example signal_examples

signal_1 = Cortex.Signal(1)
signal_2 = Cortex.Signal(41)

signal_to_be_computed = Cortex.Signal()

Cortex.add_dependency!(signal_to_be_computed, signal_1)
Cortex.add_dependency!(signal_to_be_computed, signal_2)

@test Cortex.is_pending(signal_to_be_computed) == true # hide
Cortex.is_pending(signal_to_be_computed) # true
```

```@example signal_examples
# Define a strategy (a function) to compute the value
compute_sum = (signal, deps) -> sum(Cortex.get_value, deps)

# Apply the strategy using compute!
Cortex.compute!(compute_sum, signal_to_be_computed)
```
```@example signal_examples
@test Cortex.get_value(signal_to_be_computed) == 1 + 41 # hide
Cortex.get_value(signal_to_be_computed) # 42
```
```@example signal_examples
@test Cortex.is_pending(signal_to_be_computed) == false # hide
Cortex.is_pending(signal_to_be_computed) # false
```
```@example signal_examples
# This would normally throw an error:
# compute!(compute_sum, signal_to_be_computed)

# But we can force it:
Cortex.compute!(compute_sum, signal_to_be_computed; force=true)

@test Cortex.get_value(signal_to_be_computed) == 42 # hide (value unchanged as deps are same)
Cortex.get_value(signal_to_be_computed) # 42
```

### Custom Compute Strategies

You can define custom types and methods to implement more complex computation logic beyond simple functions. This allows strategies to hold their own state or parameters.

First, define a struct for your strategy:

```@example signal_examples
struct CustomStrategy
    multiplier::Int
end
```

Then, implement the [`Cortex.compute_value!`](@ref) method for your strategy type:

```@example signal_examples
function Cortex.compute_value!(strategy::CustomStrategy, signal::Cortex.Signal, dependencies)
    # Example: Use signal's metadata if available
    meta = Cortex.get_metadata(signal)
    base_sum = sum(Cortex.get_value, dependencies)
    offset = meta isa Dict && haskey(meta, :offset) ? meta[:offset] : 0
    return strategy.multiplier * base_sum + offset
end
```

Now, you can use this strategy with your signals:

```@example signal_examples
strategy = CustomStrategy(2)

signal_with_meta = Cortex.Signal(metadata=Dict(:offset => 10))

Cortex.add_dependency!(signal_with_meta, signal_1)
Cortex.add_dependency!(signal_with_meta, signal_2)
@test Cortex.is_pending(signal_with_meta) # hide

Cortex.compute!(strategy, signal_with_meta)

@test Cortex.get_value(signal_with_meta) == 2 * (1 + 41) + 10 # hide
Cortex.get_value(signal_with_meta) # 94
```

```@example signal_examples
Cortex.compute!(CustomStrategy(3), signal_with_meta; force=true)

@test Cortex.get_value(signal_with_meta) == 3 * (1 + 41) + 10 # hide
Cortex.get_value(signal_with_meta) # 136
```


### Non-Listening Dependencies

Using `listen=false` in [`Cortex.add_dependency!`](@ref) creates a dependency relationship, but prevents the dependent signal from being automatically notified (and potentially marked pending) when the dependency's value changes.

Using `listen=false` creates a dependency without automatic notifications:
```@example signal_examples
s_source = Cortex.Signal()
s_non_listener = Cortex.Signal()

Cortex.add_dependency!(s_non_listener, s_source; listen=false)
```
```@example signal_examples
@test Cortex.is_pending(s_non_listener) == false # hide
Cortex.is_pending(s_non_listener) # false
```
```@example signal_examples
# Update s_source. s_non_listener is NOT notified.
Cortex.set_value!(s_source, 6)
```
```@example signal_examples
@test Cortex.is_pending(s_non_listener) == false # hide
Cortex.is_pending(s_non_listener) # false
```

## API Reference

Here is the detailed API documentation for the `Signal` type and its associated functions:

```@docs
Cortex.UndefValue
Cortex.UndefMetadata
Cortex.Signal
Cortex.is_pending(::Cortex.Signal)
Cortex.is_computed(::Cortex.Signal)
Cortex.get_value(::Cortex.Signal)
Cortex.get_type(::Cortex.Signal)
Cortex.get_metadata(::Cortex.Signal)
Cortex.get_age(::Cortex.Signal)
Cortex.get_dependencies(::Cortex.Signal)
Cortex.get_listeners(::Cortex.Signal)
Cortex.set_value!(::Cortex.Signal, value)
Cortex.add_dependency!(::Cortex.Signal, ::Cortex.Signal)
Cortex.compute!(Any, ::Cortex.Signal)
Cortex.compute_value!(Any, ::Cortex.Signal, ::Vector{Cortex.Signal})
```
