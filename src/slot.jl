
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

function is_pending(model, dependency::MessageToFactor)::Bool
    return is_pending(Cortex.get_edge_message_to_factor(model, dependency.variable, dependency.factor)::Slot)::Bool
end

function is_computed(model, dependency::MessageToFactor)::Bool
    return is_computed(Cortex.get_edge_message_to_factor(model, dependency.variable, dependency.factor)::Slot)::Bool
end

struct MessageToVariable <: AbstractDependency
    variable::Int
    factor::Int
end

function is_pending(model, dependency::MessageToVariable)::Bool
    return is_pending(Cortex.get_edge_message_to_variable(model, dependency.variable, dependency.factor)::Slot)::Bool
end

function is_computed(model, dependency::MessageToVariable)::Bool
    return is_computed(Cortex.get_edge_message_to_variable(model, dependency.variable, dependency.factor)::Slot)::Bool
end

struct Dependency
    type::UInt8
    wrapped::AbstractDependency
end

Dependency(dependency::AbstractDependency) = Dependency(DependencyType.RuntimeDispatch, dependency)
Dependency(dependency::MessageToFactor) = Dependency(DependencyType.MessageToFactor, dependency)

function is_pending(model, dependency::Dependency)::Bool
    if dependency.type == DependencyType.MessageToFactor
        return is_pending(model, dependency.wrapped::MessageToFactor)::Bool
    elseif dependency.type == DependencyType.MessageToVariable
        return is_pending(model, dependency.wrapped::MessageToVariable)::Bool
    else
        return is_pending(model, dependency.wrapped::AbstractDependency)::Bool
    end
end

function is_computed(model, dependency::Dependency)::Bool
    if dependency.type == DependencyType.MessageToFactor
        return is_computed(model, dependency.wrapped::MessageToFactor)::Bool
    elseif dependency.type == DependencyType.MessageToVariable
        return is_computed(model, dependency.wrapped::MessageToVariable)::Bool
    else
        return is_computed(model, dependency.wrapped::AbstractDependency)::Bool
    end
end

struct Slot
    value::Value
    dependencies::Vector{Tuple{Slot, Dependency}}
    dependents::Vector{Slot}

    Slot() = new(Value(), Tuple{Slot, Dependency}[], Slot[])
end

is_pending(slot::Slot)::Bool = is_pending(slot.value)::Bool
is_computed(slot::Slot)::Bool = is_computed(slot.value)::Bool
set_value!(slot::Slot, value) = set_value!(slot.value, value)

set_pending!(slot::Slot) = set_pending!(slot.value)
unset_pending!(slot::Slot) = unset_pending!(slot.value)

add_dependency!(to::Slot, from::Slot, dependency::AbstractDependency) = add_dependency!(to, from, Dependency(dependency))

function add_dependency!(to::Slot, from::Slot, dependency::Dependency)
    if to === from 
        throw(ArgumentError("A slot cannot be a dependency of itself"))
    end
    push!(to.dependencies, (from, dependency))
    push!(from.dependents, to)
end
