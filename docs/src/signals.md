# [Signals: The Core of Reactivity](@id signals)

At the heart of Cortex.jl's reactivity system lies the [`Signal`](@ref).

## Concept

Think of a [`Cortex.Signal`](@ref) as a container for a value that can change over time. The key idea is that other parts of your system can *depend* on a signal. When the signal's value changes, anything that depends on it (its *listeners*) is notified, allowing the system to react automatically.

**For Beginners:** Imagine a spreadsheet cell. When you change the value in one cell (like `A1`), other cells that use `A1` in their formulas (like `B1 = A1 * 2`) automatically update. A [`Cortex.Signal`](@ref) is like that cell – it holds a value, and changes can trigger updates elsewhere.

**For Advanced Users:** Signals form a directed graph (potentially cyclic, although cycles might affect update logic depending on how they are handled). Each [`Cortex.Signal`](@ref) node stores a value and maintains lists of its dependencies (signals it reads from) and listeners (signals that read from it). When a signal is updated via [`Cortex.set_value!`](@ref), it propagates a notification through the graph, potentially marking downstream signals as 'pending'. This 'pending' state indicates that the signal's value might be stale and needs recomputation. The actual recomputation logic, however, is typically managed by a higher-level construct like a `Slot` (assuming `Slot` is documented elsewhere, otherwise keep as ``Slot`` or add its reference if available), which observes the pending state.

## Key Features

*   **Value Storage:** Holds the current value.
*   **Optional Labeling:** Can be assigned a `label` via the constructor for identification ([`Cortex.get_label`](@ref)).
*   **Dependency Tracking:** Knows which other signals it depends on (`dependencies`) and which signals depend on it `listeners` via [`Cortex.get_listeners`](@ref).
*   **Notification:** When updated via [`Cortex.set_value!`](@ref), it notifies its active listeners.
*   **Pending State:** Can be marked as [`Cortex.is_pending`](@ref) if its dependencies have updated appropriately, signaling a need for potential recomputation.
*   **Weak Dependencies:** Supports 'weak' dependencies, which influence the pending state based only on whether they are computed ([`Cortex.is_computed`](@ref)), not their age relative to the listener.
*   **Controlled Listening:** Allows dependencies to be added without automatically listening to their updates (`listen=false` in [`Cortex.add_dependency!`](@ref)).
*   **Controlled Initial Check:** Allows dependencies to be added without immediately checking their computed state (`check_computed=false` in [`Cortex.add_dependency!`](@ref)).

## Usage Examples

Here are some basic examples demonstrating how to use signals.

Create signals:
```@example signal_examples
import Cortex
using Test # hide

# Create signals
s1 = Cortex.Signal(10)
```

```@example signal_examples
 # Initial value, computed=true
s2 = Cortex.Signal("hello")
```

```@example signal_examples
# No initial value, computed=false
s3 = Cortex.Signal()        
```

```@example signal_examples
# Labeled signal
s4 = Cortex.Signal(42; label = :label)        
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

Updating a dependency can mark listeners as pending:

```@example signal_examples
@test Cortex.is_pending(s_derived) == true # hide
Cortex.is_pending(s_derived) # true
```

`s_derived` is pending because both `s1` and `s2` have been computed at the time of dependency addition.

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
Cortex.UndefLabel
Cortex.Signal
Cortex.is_pending(::Cortex.Signal)
Cortex.is_computed(::Cortex.Signal)
Cortex.get_value(::Cortex.Signal)
Cortex.get_label(::Cortex.Signal)
Cortex.get_age(::Cortex.Signal)
Cortex.get_dependencies(::Cortex.Signal)
Cortex.get_listeners(::Cortex.Signal)
Cortex.set_value!(::Cortex.Signal, value)
Cortex.add_dependency!(::Cortex.Signal, ::Cortex.Signal)
```
