
"""
    Variable

A data structure representing a probabilistic variable in a model.

A `Variable` encapsulates the essential components of a probabilistic variable, including its 
identity, current marginal belief (as a reactive signal), and any signals that should be 
automatically updated when the variable's marginal changes.

## Fields

- `name::Symbol`: The symbolic name of the variable, used for identification and display.
- `index::Any = nothing`: An optional index for the variable, useful for indexed variable families 
  (e.g., `x[1]`, `x[2]`, etc.). Can be any type that makes sense for the specific use case.
- `marginal::Signal = Signal()`: A reactive signal representing the current marginal belief 
  over this variable. Updated automatically during inference.
- `linked_signals::Vector{Signal} = Signal[]`: A collection of signals that should be 
  automatically updated when this variable's marginal changes. These might represent joint 
  marginals around factors, or any other derived quantities that depend on this variable.

## See Also

- [`get_variable_name`](@ref): Retrieve the variable's name
- [`get_variable_index`](@ref): Retrieve the variable's index  
- [`get_variable_marginal`](@ref): Retrieve the variable's marginal signal
- [`get_variable_linked_signals`](@ref): Retrieve the variable's linked signals
- [`link_signal_to_variable!`](@ref): Link additional signals to the variable
"""
Base.@kwdef struct Variable
    name::Symbol
    index::Any = nothing
    marginal::Signal = Signal()
    linked_signals::Vector{Signal} = Signal[]
end

"""
    get_variable_name(variable::Variable)

Retrieves the name of a variable.
"""
function get_variable_name(variable::Variable)
    return variable.name
end

"""
    get_variable_index(variable::Variable)

Retrieves the index of a variable.
"""
function get_variable_index(variable::Variable)
    return variable.index
end

"""
    get_variable_marginal(variable::Variable)

Retrieves the marginal of a variable.
"""
function get_variable_marginal(variable::Variable)
    return variable.marginal
end

"""
    get_variable_linked_signals(variable::Variable)

Retrieves the linked signals of a variable. 
The linked signals are the signals that should be updated when the marginal (which is a signal) of the variable is updated.
Those may, for example, represent joint marginals around certain factors, but any other signal can be linked as well.
"""
function get_variable_linked_signals(variable::Variable)
    return variable.linked_signals
end

"""
    link_signal_to_variable!(variable::Variable, signal::Signal)

Links a signal to a variable. The linked signal will be updated automatically when the marginal of the variable is updated.
"""
function link_signal_to_variable!(variable::Variable, signal::Signal)
    push!(variable.linked_signals, signal)
    return nothing
end

function Base.show(io::IO, variable::Variable)
    print(io, "Variable(name = $(variable.name)")
    if !isnothing(variable.index)
        print(io, ", index = $(variable.index)")
    end
    print(io, ")")
end

"""
    Factor

A data structure representing a probabilistic factor in a graphical model.

A `Factor` encapsulates the functional form of a probabilistic relationship between variables 
and maintains references to local marginal beliefs that are relevant to this factor's 
computation and inference updates.

## Fields

- `functional_form::Any`: The mathematical or computational representation of the factor. 
  This could be a function, a probability distribution, a constraint, or any other object 
  that defines the probabilistic relationship encoded by this factor.
- `local_marginals::Vector{Signal} = Signal[]`: A collection of reactive signals representing 
  local marginal beliefs associated with this factor. These signals are typically updated 
  during message-passing inference and may represent beliefs about individual variables 
  or joint beliefs over subsets of variables connected to this factor.

## See Also

- [`get_factor_functional_form`](@ref): Retrieve the factor's functional form
- [`get_factor_local_marginals`](@ref): Retrieve the factor's local marginals
- [`add_local_marginal_to_factor!`](@ref): Add a local marginal to the factor
- [`Variable`](@ref): The variable data structure that factors connect
"""
Base.@kwdef struct Factor
    functional_form::Any
    local_marginals::Vector{Signal} = Signal[]
end

"""
    get_factor_functional_form(factor::Factor)

Retrieves the functional form of a factor. 
The functional form represents the mathematical or computational definition of the probabilistic relationship encoded by the factor.
"""
function get_factor_functional_form(factor::Factor)
    return factor.functional_form
end

"""
    get_factor_local_marginals(factor::Factor)

Retrieves the local marginals associated with a factor.
Local marginals are reactive signals that represent beliefs about variables or variable 
subsets that are relevant to this factor's inference computations.
"""
function get_factor_local_marginals(factor::Factor)
    return factor.local_marginals
end

"""
    add_local_marginal_to_factor!(factor::Factor, local_marginal::Signal)

Adds a local marginal signal to a factor's collection of local marginals.
"""
function add_local_marginal_to_factor!(factor::Factor, local_marginal::Signal)
    push!(factor.local_marginals, local_marginal)
    return nothing
end

function Base.show(io::IO, factor::Factor)
    print(io, "Factor(functional_form = $(factor.functional_form))")
end

"""
    Connection

A data structure representing a connection between a variable and a factor in a probabilistic graphical model.

A `Connection` encapsulates the communication interface between variables and factors during 
message-passing inference. It maintains the bidirectional message signals and provides 
identification through labels and indices.

## Fields

- `label::Symbol`: A symbolic label identifying the role or type of this connection 
  (e.g., `:observation`, `:prior`, `:likelihood`). Used for semantic identification 
  of the connection's purpose in the model.
- `index::Int = 0`: A numeric index for the connection, useful when multiple connections 
  of the same type exist between a variable-factor pair, or for ordering connections 
  in message-passing algorithms.
- `message_to_variable::Signal = Signal()`: A reactive signal carrying messages sent 
  from the factor to the variable. Updated during factor-to-variable message passing.
- `message_to_factor::Signal = Signal()`: A reactive signal carrying messages sent 
  from the variable to the factor. Updated during variable-to-factor message passing.
"""
Base.@kwdef struct Connection
    label::Symbol
    index::Int = 0
    message_to_variable::Signal = Signal()
    message_to_factor::Signal = Signal()
end

"""
    get_connection_label(connection::Connection)

Retrieves the symbolic label of a connection.
"""
function get_connection_label(connection::Connection)
    return connection.label
end

"""
    get_connection_index(connection::Connection)

Retrieves the numeric index of a connection.
"""
function get_connection_index(connection::Connection)
    return connection.index
end

"""
    get_connection_message_to_variable(connection::Connection)

Retrieves the reactive signal carrying messages from factor to variable.
"""
function get_connection_message_to_variable(connection::Connection)
    return connection.message_to_variable
end

"""
    get_connection_message_to_factor(connection::Connection)

Retrieves the reactive signal carrying messages from variable to factor.
"""
function get_connection_message_to_factor(connection::Connection)
    return connection.message_to_factor
end

function Base.show(io::IO, connection::Connection)
    print(io, "Connection(label = $(connection.label)")
    if !iszero(connection.index)
        print(io, ", index = $(connection.index)")
    end
    print(io, ")")
end

"""
    UnsupportedModelEngineError(engine, [ missing_function ])

An error thrown when attempting to use an unsupported model engine.

This error is typically thrown by [`throw_if_engine_unsupported`](@ref) when [`is_engine_supported`](@ref)
returns [`UnsupportedModelEngine`](@ref). Additionaly, accepts a function name that was missing from the model engine.
In this case, the error message will include the missing function name.

## Fields

- `model_engine`: The unsupported model engine instance.
- `missing_function`: The name of the function that was missing from the model engine.

## See Also

- [`is_engine_supported`](@ref)
- [`throw_if_engine_unsupported`](@ref)
- [`UnsupportedModelEngine`](@ref)
"""
struct UnsupportedModelEngineError{B, F} <: Exception
    model_engine::B
    missing_function::F
end

function Base.showerror(io::IO, e::UnsupportedModelEngineError)
    if isnothing(e.missing_function)
        print(io, "The model engine of type `$(typeof(e.model_engine))` is not supported.")
    else
        print(
            io,
            "The model engine of type `$(typeof(e.model_engine))` does not implement the function `$(e.missing_function)`."
        )
    end
end

"A trait object indicating a supported model engine. Use this as a return value of [`Cortex.is_engine_supported`](@ref)."
struct SupportedModelEngine end

"A trait object indicating an unsupported model engine. Used as a default return value of [`Cortex.is_engine_supported`](@ref)."
struct UnsupportedModelEngine end

"""
    is_engine_supported(engine::Any) -> Union{SupportedModelEngine, UnsupportedModelEngine}

Checks if a given `engine` is supported by the `InferenceEngine`.

This function should be extended by specific engine implementations.

## Arguments

- `engine::Any`: The model engine instance to check.

## Returns

- `SupportedModelEngine()` if the engine is supported.
- `UnsupportedModelEngine()` otherwise.

## Example 

```jldoctest
julia> struct CustomModelEngine end

julia> Cortex.is_engine_supported(::CustomModelEngine) = Cortex.SupportedModelEngine();
```

```jldoctest
julia> struct SomeOtherDataStructure end

julia> Cortex.is_engine_supported(::SomeOtherDataStructure) = Cortex.UnsupportedModelEngine();
```

## See Also

- [`SupportedModelEngine`](@ref)
- [`UnsupportedModelEngine`](@ref)
- [`throw_if_engine_unsupported`](@ref)
"""
is_engine_supported(::Any) = UnsupportedModelEngine()

"""
    throw_if_engine_unsupported(engine::Any)

Throws an [`UnsupportedModelEngineError`](@ref) if the engine is unsupported.
"""
function throw_if_engine_unsupported end

throw_if_engine_unsupported(engine::Any) = throw_if_engine_unsupported(is_engine_supported(engine), engine)
throw_if_engine_unsupported(::UnsupportedModelEngine, engine::Any) = throw(UnsupportedModelEngineError(engine, nothing))
throw_if_engine_unsupported(::SupportedModelEngine, engine::Any) = engine

"""
    get_variable(model_engine, variable_id::Int)::Variable

Retrieves the data structure representing a specific variable from the model engine.
This function must be implemented by specific model engines. The returned object be [`Cortex.Variable`](@ref).
"""
function get_variable(engine::Any, variable_id::Int)::Variable
    throw(UnsupportedModelEngineError(engine, get_variable))
end

"""
    get_factor(model_engine, factor_id::Int)::Factor

Retrieves the data structure representing a specific factor from the model engine.
This function must be implemented by specific model engines. The returned object be [`Cortex.Factor`](@ref).
"""
function get_factor(engine::Any, factor_id::Int)::Factor
    throw(UnsupportedModelEngineError(engine, get_factor))
end

"""
    get_variable_ids(model_engine)

Retrieves an iterator over all variable identifiers in the model engine.
This function must be implemented by specific model engines.
"""
function get_variable_ids(engine::Any)
    throw(UnsupportedModelEngineError(engine, get_variable_ids))
end

"""
    get_factor_ids(model_engine)

Retrieves an iterator over all factor identifiers in the model engine.
This function must be implemented by specific model engines.
"""
function get_factor_ids(engine::Any)
    throw(UnsupportedModelEngineError(engine, get_factor_ids))
end

"""
    get_connection(model_engine, variable_id::Int, factor_id::Int)::Connection

Retrieves the data structure representing the connection between a specified variable and factor.
The returned object must be [`Cortex.Connection`](@ref).
"""
function get_connection(engine::Any, variable_id::Int, factor_id::Int)::Connection
    throw(UnsupportedModelEngineError(engine, get_connection))
end

"""
    get_connected_variable_ids(model_engine, factor_id::Int)

Retrieves an iterator over the identifiers of variables connected to a given factor.
This function must be implemented by specific model engines.
"""
function get_connected_variable_ids(engine::Any, factor_id::Int)
    throw(UnsupportedModelEngineError(engine, get_connected_variable_ids))
end

"""
    get_connected_factor_ids(model_engine, variable_id::Int)

Retrieves an iterator over the identifiers of factors connected to a given variable.
This function must be implemented by specific model engines.
"""
function get_connected_factor_ids(engine::Any, variable_id::Int)
    throw(UnsupportedModelEngineError(engine, get_connected_factor_ids))
end
