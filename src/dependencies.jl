module DependencyType
const RuntimeDispatchDependency::UInt8 = 0x0
const MessageToFactorDependency::UInt8 = 0x1
end

abstract type AbstractDependency end

struct MessageToFactorDependency <: AbstractDependency
    value::Value
    variable::Int
    factor::Int
end

is_pending(dependency::MessageToFactorDependency) = is_pending(dependency.value)
is_computed(dependency::MessageToFactorDependency) = is_computed(dependency.value)

struct Dependency
    type::UInt8
    wrapped::AbstractDependency
end

Dependency(dependency::AbstractDependency) = Dependency(DependencyType.RuntimeDispatchDependency, dependency)
Dependency(dependency::MessageToFactorDependency) = Dependency(DependencyType.MessageToFactorDependency, dependency)

function is_pending(dependency::Dependency)::Bool
    if dependency.type == DependencyType.MessageToFactorDependency
        return is_pending(dependency.wrapped::MessageToFactorDependency)::Bool
    else
        return is_pending(dependency.wrapped::AbstractDependency)::Bool
    end
end

function is_computed(dependency::Dependency)::Bool
    if dependency.type == DependencyType.MessageToFactorDependency
        return is_computed(dependency.wrapped::MessageToFactorDependency)::Bool
    else
        return is_computed(dependency.wrapped::AbstractDependency)::Bool
    end
end