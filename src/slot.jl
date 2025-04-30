
module DependencyType
const RuntimeDispatch::UInt8 = 0x0
const MessageToFactor::UInt8 = 0x1
const MessageToVariable::UInt8 = 0x2
end

abstract type AbstractDependency end

struct MessageToFactor <: AbstractDependency
    variable::Int
    factor::Int
end

struct MessageToVariable <: AbstractDependency
    variable::Int
    factor::Int
end

struct Dependency
    type::UInt8
    wrapped::AbstractDependency
end

Dependency(dependency::AbstractDependency) = Dependency(DependencyType.RuntimeDispatch, dependency)
Dependency(dependency::MessageToFactor) = Dependency(DependencyType.MessageToFactor, dependency)

struct Slot
    value::Value
    dependencies::Vector{Tuple{Slot, Dependency}}
    dependents::Vector{Slot}

    Slot() = new(Value(), Tuple{Slot, Dependency}[], Slot[])
end

is_pending(slot::Slot)::Bool = is_pending(slot.value)::Bool
is_computed(slot::Slot)::Bool = is_computed(slot.value)::Bool

set_pending!(slot::Slot) = set_pending!(slot.value)
unset_pending!(slot::Slot) = unset_pending!(slot.value)

function set_value!(slot::Slot, @nospecialize(value))
    set_value!(slot.value, value)
    for dependent in slot.dependents
        set_pending!(dependent)
    end
end

add_dependency!(to::Slot, from::Slot, dependency::AbstractDependency) = add_dependency!(to, from, Dependency(dependency))

function add_dependency!(to::Slot, from::Slot, dependency::Dependency)
    if to === from 
        throw(ArgumentError("A slot cannot be a dependency of itself"))
    end
    push!(to.dependencies, (from, dependency))
    push!(from.dependents, to)
end
