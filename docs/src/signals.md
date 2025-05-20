# [Signals: The Core of Reactivity](@id signals)

At the heart of Cortex.jl's reactivity system lies the [`Signal`](@ref Cortex.Signal).

## Concept

Think of a [`Signal`](@ref Cortex.Signal) as a container for a value that can change over time. The key idea is that other parts of your system can *depend* on a signal. When the signal's value changes, anything that depends on it (its *listeners*) is notified, allowing the system to react on changes and recompute values.

Imagine a spreadsheet cell. When you change the value in one cell (like `A1`), other cells that use `A1` in their formulas (like `B1 = A1 * 2`) automatically update. A [`Signal`](@ref Cortex.Signal) is like that cell – it holds a value, and changes can trigger updates elsewhere.

More technically, [`Signal`](@ref Cortex.Signal)s form a directed graph (potentially cyclic). Each [`Signal`](@ref Cortex.Signal) node stores a value, an optional `type` identifier (`UInt8`), optional `metadata`, and maintains lists of its dependencies and listeners. When a signal is updated via [`set_value!`](@ref Cortex.set_value!), it propagates a notification to its direct listeners, potentially marking them as 'pending'. This 'pending' state indicates that the signal's value might be stale and needs recomputation. The actual recomputation logic is defined externally via the [`compute!`](@ref Cortex.compute!) function. A signal may become 'pending' if all its dependencies meet the criteria: weak dependencies are computed, and strong dependencies are computed and **fresh** (i.e., have new, unused values). This also means that a signal never recomputes its own value, as it must be done externally.

## Key Features

*   **Value Storage:** Holds the current value.
*   **Type Identifier:** Stores an optional `UInt8` type ([`get_type`](@ref Cortex.get_type)), defaulting to `0x00`. This might be particularly useful for choosing different computation strategies for different types of signals within the [`compute!`](@ref Cortex.compute!) function.
*   **Optional Metadata:** Can store arbitrary metadata ([`get_metadata`](@ref Cortex.get_metadata)), defaulting to `UndefMetadata()`.
*   **Dependency Tracking:** Knows which other signals it depends on (`dependencies`) and which signals depend on it (see  [`get_listeners`](@ref Cortex.get_listeners)).
*   **Notification:** When updated via [`set_value!`](@ref Cortex.set_value!), it notifies its active listeners.
*   **Pending State:** Can be marked as [`is_pending`](@ref Cortex.is_pending) if its dependencies have updated appropriately, signaling a need for recomputation via [`compute!`](@ref Cortex.compute!).
*   **External Computation:** Relies on the [`compute!`](@ref Cortex.compute!) function and a provided strategy to update its value based on dependencies.
*   **Weak Dependencies:** Supports 'weak' dependencies, which influence the pending state based only on whether they are computed ([`is_computed`](@ref Cortex.is_computed)), not their 'fresh' status in the same way as strong dependencies. See [`add_dependency!`](@ref Cortex.add_dependency!) for more details.
*   **Controlled Listening:** Allows dependencies to be added without automatically listening to their updates (`listen=false` in [`add_dependency!`](@ref Cortex.add_dependency!)).
*   **GraphViz Support:** Signals can be visualized using the `GraphViz.jl` package. Cortex automatically loads the visualization extension when `GraphViz.jl` package is loaded in the current Julia session.

```@docs
Cortex.Signal
Cortex.UndefValue
Cortex.UndefMetadata
```

## Core Operations

```@setup signal_examples
using Cortex # Load the main package
using Test
```

!!! note
    Before we proceed, we load the package itslef and we also load the `GraphViz.jl` package in order to enable the visualization extension.
    ```@example signal_examples
    using GraphViz # Enable the visualization extension
    ```
    To get the SVG representation of the signal graph, we can use the `GraphViz.load` function.

Here are some basic examples demonstrating how to use signals.

### Creating Signals and Checking Properties

Signal can be created using the `Cortex.Signal` constructor

```@example signal_examples
a_signal_with_no_value = Cortex.Signal()
```

By default, the signal has no value. We can check this by calling the [`Cortex.get_value`](@ref Cortex.get_value) function.

```@example signal_examples
@test Cortex.get_value(a_signal_with_no_value) === Cortex.UndefValue() # hide
Cortex.get_value(a_signal_with_no_value)
```

We can also create a signal with an initial value.

```@example signal_examples
a_signal_with_value = Cortex.Signal(10)
```

We can check the value of the signal by calling the [`Cortex.get_value`](@ref Cortex.get_value) function.

```@example signal_examples
@test Cortex.get_value(a_signal_with_value) == 10 # hide
Cortex.get_value(a_signal_with_value)
```

Additionally, we can check if the signal is computed with the [`Cortex.is_computed`](@ref Cortex.is_computed) function.

```@example signal_examples
@test Cortex.is_computed(a_signal_with_no_value) == false # hide
Cortex.is_computed(a_signal_with_no_value)
```

```@example signal_examples
@test Cortex.is_computed(a_signal_with_value) == true # hide
Cortex.is_computed(a_signal_with_value)
```

Signals themselves do not know how to compute their value. This is done externally via the [`compute!`](@ref Cortex.compute!) function.
However, in order to update the value of a signal, we need to know if the signal is pending. If signal is pending, it means that it needs to be recomputed. On the contrary, if the signal is not pending, it means that the value is up to date and we can use the value without recomputing it. Normally, the signal becomes pending automatically when [its dependencies](@ref signal-adding-dependencies) are updated.

We can check if a signal is pending with the [`Cortex.is_pending`](@ref Cortex.is_pending) function.

```@example signal_examples
@test Cortex.is_pending(a_signal_with_value) == false # hide
Cortex.is_pending(a_signal_with_value)
```

Since our signals does not have any dependencies, it is not pending. We will talk more about the dependencies and the [pending state](@ref signal-pending-state) in the [Adding Dependencies](@ref signal-adding-dependencies) section.

We can manually update a signal's value with [`set_value!`](@ref Cortex.set_value!). The `set_value!` function doesn't check if the signal is pending or not. It only updates the value of the signal. Read the [Updating Signal Values](@ref signal-updating-values) section for a more structured way to update a signal's value.
    

```@example signal_examples
some_signal  = Cortex.Signal()
@test Cortex.get_value(some_signal) === Cortex.UndefValue() # hide
Cortex.get_value(some_signal)
```

```@example signal_examples
Cortex.set_value!(some_signal, 99.0)
```
```@example signal_examples
@test Cortex.get_value(some_signal) == 99.0 # hide
Cortex.get_value(some_signal)
```

!!! warning
    **Important:** Normally, it is implied that [`set_value!`](@ref Cortex.set_value!) must be called only on signals that are pending. Also see the [`compute!`](@ref Cortex.compute!) function for a more general way to update signal values.

#### Signal Type and Metadata

You can optionally specify a `type` identifier and `metadata`. Specifying the type identifier and metadata is useful when you want to choose different computation strategies for different types of signals within the [`compute!`](@ref Cortex.compute!) function.

```@example signal_examples
# Signal with type and metadata
signal_with_type_and_metadata = Cortex.Signal(type=0x01, metadata=Dict(:info => "flag", :some_value => 10))
```

The type can be accessed with the [`Cortex.get_type`](@ref Cortex.get_type) function and the metadata can be accessed with the [`Cortex.get_metadata`](@ref Cortex.get_metadata) function.

```@example signal_examples
Cortex.get_type(signal_with_type_and_metadata)
```

```@example signal_examples
Cortex.get_metadata(signal_with_type_and_metadata)
```

The metadata can be any object, not just a dictionary.

```@example signal_examples
signal_with_metadata = Cortex.Signal(metadata="hello world!")
```

#### API Reference

```@docs
Cortex.get_value(::Cortex.Signal)
Cortex.get_type(::Cortex.Signal)
Cortex.get_metadata(::Cortex.Signal)
Cortex.is_computed(::Cortex.Signal)
Cortex.is_pending(::Cortex.Signal)
Cortex.set_value!(::Cortex.Signal, value)
```

## [Adding Dependencies](@id signal-adding-dependencies)

Signals can depend on other signals. This is particularly useful when you want to compute a signal's value based on the values of other signals. To add a new dependency, use [`add_dependency!`](@ref Cortex.add_dependency!). This populates the `dependencies` list of the dependent signal and the `listeners` list of the dependency.

```@example signal_examples
source_1 = Cortex.Signal(1)
source_2 = Cortex.Signal(2)

derived = Cortex.Signal() # A signal that will depend on source_1 and source_2

Cortex.add_dependency!(derived, source_1)
Cortex.add_dependency!(derived, source_2)
```
```@example signal_examples
@test length(Cortex.get_dependencies(derived)) == 2 # hide
length(Cortex.get_dependencies(derived)) # 2
```
```@example signal_examples
@test length(Cortex.get_listeners(source_1)) == 1 # hide
length(Cortex.get_listeners(source_1))           # 1
```
```@example signal_examples
@test length(Cortex.get_listeners(source_2)) == 1 # hide
length(Cortex.get_listeners(source_2))           # 1
```

Here we can also use the `GraphViz.jl` package to visualize the dependency graph.

```@example signal_examples
GraphViz.load(derived)
```

By default, the visualization uses different colors and styles to distinguish between different types of dependencies as well as their pending states. Read more about it in the [Visualization](@ref signals-visualization) section.

### [Pending State](@id signal-pending-state)

A signal becomes pending ([`is_pending`](@ref Cortex.is_pending) returns `true`) when its dependencies are updated in a way that satisfies the pending criteria (all [weak dependencies](@ref signal-strong-vs-weak-dependencies) are computed, and all [strong dependencies](@ref signal-strong-vs-weak-dependencies) are **fresh** and computed). Adding a computed dependency can also immediately mark a signal as pending.

Updating a dependency can mark listeners as pending:
```@example signal_examples
source_1 = Cortex.Signal(1)
source_2 = Cortex.Signal(2)

derived = Cortex.Signal() # A signal that will depend on s1 and s2

Cortex.add_dependency!(derived, source_1)
Cortex.add_dependency!(derived, source_2)

@test Cortex.is_pending(derived) == true # hide
Cortex.is_pending(derived) # true
```

```@example signal_examples
GraphViz.load(derived)
```

`derived` is pending because both `source_1` and `source_2` have been computed and are considered fresh with respect to `derived` at the time of dependency addition. Let's try a different example:

```@example signal_examples
some_source = Cortex.Signal()
derived = Cortex.Signal()

Cortex.add_dependency!(derived, some_source)

@test Cortex.is_pending(derived) == false # hide
Cortex.is_pending(derived) # false
```

```@example signal_examples
GraphViz.load(derived)
```

```@example signal_examples
Cortex.set_value!(some_source, 1)

@test Cortex.is_pending(derived) == true # hide
Cortex.is_pending(derived) # true
```

```@example signal_examples
GraphViz.load(derived)
```

After setting the value of `some_source`, `derived` becomes pending because `some_source` is now computed and fresh with respect to `derived`.

Here, we can compute a new value for the derived signal based on the new value of `some_source`:

```@example signal_examples
Cortex.set_value!(derived, 2 * Cortex.get_value(some_source))
```

```@example signal_examples
@test Cortex.get_value(derived) == 2 # hide
Cortex.get_value(derived) # 2
```

```@example signal_examples
GraphViz.load(derived)
```

As we can see, the derived signal is no longer in the pending state after calling the `set_value!` function. It is implied that the `set_value!` function is only called on signals that are pending. See the [Computing Signal Values](@ref signal-computing-values) section for a more structured way to compute a signal's value.

### API Reference

```@docs
Cortex.add_dependency!(::Cortex.Signal, ::Cortex.Signal)
Cortex.get_dependencies(::Cortex.Signal)
Cortex.get_listeners(::Cortex.Signal)
```

## [Types of Dependencies](@id signal-types-of-dependencies)

Signals might have different types of dependencies through options in [`add_dependency!`](@ref Cortex.add_dependency!). Different types of dependencies have different purpose and behavior. Most importantly, they affect the way the signal becomes pending.

### [Strong vs. Weak Dependencies](@id signal-strong-vs-weak-dependencies)

By default, dependencies are "strong," meaning they must be both computed and fresh (recently updated) for a signal to become pending. With `weak=true`, a dependency only needs to be computed (not necessarily fresh) to contribute to the pending state.

```@example signal_examples
weak_dependency = Cortex.Signal(1)
strong_dependency = Cortex.Signal(2)

derived = Cortex.Signal(3)

Cortex.add_dependency!(derived, weak_dependency; weak=true)
Cortex.add_dependency!(derived, strong_dependency)

@test Cortex.is_pending(derived) == false # hide
Cortex.is_pending(derived) # false
```

```@example signal_examples
GraphViz.load(derived)
```

```@example signal_examples
Cortex.set_value!(strong_dependency, 10)

@test Cortex.is_pending(derived) == true # hide
Cortex.is_pending(derived) # true
```

```@example signal_examples
GraphViz.load(derived)
```

Here, even though `weak_dependency` has not been updated, `derived` is still in the pending state because it only needs `strong_dependency` to be updated and `weak_dependency` only needs to be computed once (or set via constructor).

We can still update the weak dependency:

```@example signal_examples
Cortex.set_value!(weak_dependency, 10)
```

```@example signal_examples
@test Cortex.is_pending(derived) == true # hide
Cortex.is_pending(derived) # true
```

```@example signal_examples
GraphViz.load(derived)
```

As we can see, the derived signal remains in the pending state, but now it can also use the fresh value of the weak dependency.

### Intermediate Dependencies

Setting `intermediate=true` marks a dependency as intermediate, which affects how [`process_dependencies!`](@ref Cortex.process_dependencies!) traverses the dependency graph. This is useful for complex dependency trees within signals where some signals serve as connectors between other signals. This might be exploited to create a reduction operation on a collection of signals and use its result as a dependency for another signal.

```@example signal_examples
some_dependency_1 = Cortex.Signal()
some_dependency_2 = Cortex.Signal()
intermediate_dependency = Cortex.Signal()
derived = Cortex.Signal()

Cortex.add_dependency!(derived, intermediate_dependency; intermediate=true)
Cortex.add_dependency!(intermediate_dependency, some_dependency_1)
Cortex.add_dependency!(intermediate_dependency, some_dependency_2)
```

```@example signal_examples
GraphViz.load(derived)
```

### Listening vs. Non-listening Dependencies

With `listen=true` (default), a signal is notified when its dependency changes. Setting `listen=false` creates a dependency relationship without automatic notifications, useful when you want to manually control when a signal responds to changes.

```@example signal_examples
s_source = Cortex.Signal()
s_non_listener = Cortex.Signal()
s_listener = Cortex.Signal()

Cortex.add_dependency!(s_non_listener, s_source; listen=false)
Cortex.add_dependency!(s_listener, s_source)
```
```@example signal_examples
@test Cortex.is_pending(s_non_listener) == false # hide
Cortex.is_pending(s_non_listener) # false
```

```@example signal_examples
GraphViz.load(s_source)
```

Now, normally, if we update the value of `s_source`, all listeners should be notified and become pending.
However, since we set `listen=false` for the `s_non_listener`, it is not notified and is not changing its pending state.

```@example signal_examples
# Update s_source. s_non_listener is NOT notified.
Cortex.set_value!(s_source, 6)
```
```@example signal_examples
@test Cortex.is_pending(s_non_listener) == false # hide
Cortex.is_pending(s_non_listener) # false
```

```@example signal_examples
GraphViz.load(s_source)
```

## [Computing Signal Values](@id signal-computing-values)

We demonstrated how can we set a signal's value manually with [`set_value!`](@ref Cortex.set_value!). Cortex provides a more structured and safer way to compute a signal's value with the [`compute!`](@ref Cortex.compute!) function. The `compute!` function takes a strategy (often a simple function) to calculate the new value based on dependencies. Computing a signal typically clears its pending state.

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
GraphViz.load(signal_to_be_computed)
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
GraphViz.load(signal_to_be_computed)
```

!!! note
    By default, `compute!` throws an `ArgumentError` if called on a signal that is not pending ([`is_pending`](@ref Cortex.is_pending) returns `false`). You can override this check using the `force=true` keyword argument.
    ```@example signal_examples
    # This would normally throw an error:
    # compute!(compute_sum, signal_to_be_computed)

    # But we can force it:
    Cortex.compute!(compute_sum, signal_to_be_computed; force=true)

    @test Cortex.get_value(signal_to_be_computed) == 42 # hide
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

Then, implement the [`compute_value!`](@ref Cortex.compute_value!) method for your strategy type:

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

```@docs
Cortex.compute!(Any, ::Cortex.Signal)
Cortex.compute_value!(Any, ::Cortex.Signal, ::Vector{Cortex.Signal})
```

## Processing/Traversal of Dependencies

The `process_dependencies!` function provides a powerful way to traverse and operate on the dependency graph of a signal. It's particularly useful for scenarios where you need more control over how dependencies are evaluated or when implementing custom update schedulers.

The function recursively applies a user-defined function `f` to each dependency. `f` should return `true` if it considers the dependency "processed" by its own logic, and `false` otherwise. `process_dependencies!` propagates this status and can optionally retry processing an intermediate dependency if its own sub-dependencies were processed.

**Use Cases:**

*   Implementing custom evaluation orders for signals.
*   Performing actions on dependencies before computing a parent signal.
*   Debugging or inspecting the state of a signal's dependency graph.

**Conceptual Example:**

Imagine you want to traverse the dependency graph of a signal and you want to log which ones were already computed and which ones are not.

```@example signal_examples
signal1 = Cortex.Signal(1; metadata = :signal1) # computed
signal2 = Cortex.Signal(; metadata = :signal2)  # not computed
signal3 = Cortex.Signal(3; metadata = :signal3)  # computed

intermediate_signal = Cortex.Signal(metadata = :intermediate_signal)

Cortex.add_dependency!(intermediate_signal, signal2)
Cortex.add_dependency!(intermediate_signal, signal3)

derived = Cortex.Signal(metadata = :derived)

Cortex.add_dependency!(derived, signal1)
Cortex.add_dependency!(derived, intermediate_signal; intermediate=true)

function my_processing_function(dependency_signal::Cortex.Signal)
    if !Cortex.is_computed(dependency_signal)
        println("The dependency signal: ", Cortex.get_metadata(dependency_signal), " is not computed")
    else 
        println("The dependency signal: ", Cortex.get_metadata(dependency_signal), " is computed. The value is: ", Cortex.get_value(dependency_signal))
    end
    # always return false to process all the dependencies
    return false
end

Cortex.process_dependencies!(my_processing_function, derived)
nothing #hide
```

Let's see if that actually the case by visualizing the dependency graph:

```@example signal_examples
GraphViz.load(derived)
```

This example illustrates how you can inject custom logic into the dependency traversal. The actual computation or state change would happen within `my_processing_function`. For example, here how can we `compute!` the signal if it is not computed:

```@example signal_examples
signal1 = Cortex.Signal(1; metadata = :signal1)
signal2 = Cortex.Signal(2; metadata = :signal2)
signal3 = Cortex.Signal(3; metadata = :signal3)

intermediate_signal = Cortex.Signal(metadata = :intermediate_signal)

Cortex.add_dependency!(intermediate_signal, signal2)
Cortex.add_dependency!(intermediate_signal, signal3)

derived = Cortex.Signal(metadata = :derived)

Cortex.add_dependency!(derived, signal1)
Cortex.add_dependency!(derived, intermediate_signal; intermediate=true)

function compute_if_not_computed(signal::Cortex.Signal)
    if Cortex.is_pending(signal)
        println("Computing the signal: ", Cortex.get_metadata(signal))
        Cortex.compute!((signal, deps) -> sum(Cortex.get_value, deps), signal)
        return true
    end
    return false
end

Cortex.process_dependencies!(compute_if_not_computed, derived; retry = true)
nothing #hide
```

Now, since we processed and computed all the dependencies, the derived signal should be in the pending state:

```@example signal_examples
@test Cortex.is_pending(derived) == true # hide
Cortex.is_pending(derived) # true
```

```@example signal_examples
GraphViz.load(derived)
```

Which we can also compute using the same function:

```@example signal_examples
compute_if_not_computed(derived)

@test Cortex.get_value(derived) == 6 # hide
Cortex.get_value(derived) # 6
```

```@example signal_examples
GraphViz.load(derived)
```

```@docs
Cortex.process_dependencies!(Any, ::Cortex.Signal)
```

## [Signal Visualization](@id signals-visualization)

The `Cortex.jl` package provides a function to visualize the dependency graph of a signal.
This function becomes available when the `GraphViz.jl` package is installed in your environment.
Let's start with an example:

```@example signal_examples
using GraphViz # enables visualization

s = Cortex.Signal()

dep1 = Cortex.Signal()
dep2 = Cortex.Signal()

Cortex.add_dependency!(s, dep1; intermediate = true, weak = true)
Cortex.add_dependency!(s, dep2; weak = true)

dep3 = Cortex.Signal(3)
dep4 = Cortex.Signal(4)

Cortex.add_dependency!(dep1, dep3)
Cortex.add_dependency!(dep1, dep4; intermediate = true, weak = true)

dep5 = Cortex.Signal()

Cortex.add_dependency!(dep2, dep5)

listener1 = Cortex.Signal()
listener2 = Cortex.Signal(2)

Cortex.add_dependency!(listener1, s)
Cortex.add_dependency!(listener2, s; listen = false)

GraphViz.load(s)
```

### API Reference

```@example signal-vis-docs
using GraphViz, Cortex #hide
GraphVizExt = Base.get_extension(Cortex, :GraphVizExt) #hide
@doc(GraphVizExt.GraphViz.load) #hide
```

## Internal Mechanics (For Developers)

!!! warning "Advanced Topic"
    The details in this section are primarily for developers working on or extending Cortex.jl's core reactivity. Regular users do not typically need to interact with these internal components directly.

The efficient tracking of dependency states (intermediate, weak, computed, and fresh) is managed internally by a structure associated with each signal, `SignalDependenciesProps`.

### `SignalDependenciesProps`: Packed Dependency Information

To minimize overhead, the properties for each dependency are bit-packed into 4-bit "nibbles" within `UInt64` chunks. This allows a single `UInt64` to hold status information for 16 dependencies. The bits are assigned as follows (from LSB to MSB):

*   **Bit 1 (`0x1`): `IsIntermediate`**: True if the dependency is an intermediate one for processing logic (see [`process_dependencies!`](@ref Cortex.process_dependencies!)).
*   **Bit 2 (`0x2`): `IsWeak`**: True if the dependency is weak.
*   **Bit 3 (`0x4`): `IsComputed`**: True if the dependency itself holds a computed value.
*   **Bit 4 (`0x8`): `IsFresh`**: True if the dependency has provided a new value that has not yet been consumed by the current signal's computation.

### Determining Pending State

The [`is_pending(signal)`](@ref Cortex.is_pending) function relies on an internal check (currently `is_meeting_pending_criteria`) that operates on these packed properties. A signal is considered to meet the criteria to become pending if, for **every** one of its dependencies:

`(IsComputed AND (IsWeak OR IsFresh))`

This means:
*   A **weak** dependency must simply be `IsComputed`.
*   A **strong** (non-weak) dependency must be `IsComputed` AND `IsFresh`.

When [`set_value!`](@ref Cortex.set_value!) is called on a signal:
1.  The `IsFresh` flags for all its own dependencies are cleared (as their values have now been "used").
2.  For each of its listeners, the original signal (which just got a new value) is marked as `IsComputed` and `IsFresh` in that listener's dependency properties. This, in turn, can cause the listener to become pending.

This bit-packed approach allows for efficient batch updates and checks across many dependencies.
