
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
    # If a slot receives a new value, we need to check if all of its dependents can be marked as pending
    for dependent in slot.dependents
        # They can be marked as pending if all of their dependencies are computed (including the current slot)
        if all((t) -> is_computed(t[1]::Slot)::Bool, dependent.dependencies)
            set_pending!(dependent)
        end
    end
end

add_dependency!(to::Slot, from::Slot, dependency::AbstractDependency) = add_dependency!(
    to, from, Dependency(dependency)
)

function add_dependency!(to::Slot, from::Slot, dependency::Dependency)
    # TODO: check performance if we remove this condition
    if to === from
        throw(ArgumentError("A slot cannot be a dependency of itself"))
    end
    push!(to.dependencies, (from, dependency))
    push!(from.dependents, to)
end
