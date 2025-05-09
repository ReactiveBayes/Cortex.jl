abstract type AbstractDependencyResolver end

struct DefaultDependencyResolver <: AbstractDependencyResolver end

function resolve_dependencies!(resolver::AbstractDependencyResolver, model::AbstractCortexModel)
    # Resolve dependencies for each variable
    for variable in get_variables(model)
        resolve_variable_dependencies!(resolver, model, variable)
    end

    # Resolve dependencies for each factor
    for factor in get_factors(model)
        resolve_factor_dependencies!(resolver, model, factor)
    end
end

function resolve_factor_dependencies!(::DefaultDependencyResolver, model::AbstractCortexModel, factor::FactorId)
    variables_connected_to_factor = get_factor_neighbors(model, factor)

    for v1 in variables_connected_to_factor, v2 in variables_connected_to_factor
        if v1 !== v2
            add_dependency!(
                get_edge_message_to_variable(model, v1, factor), get_edge_message_to_factor(model, v2, factor)
            )
        end
    end
end

function resolve_variable_dependencies!(::DefaultDependencyResolver, model::AbstractCortexModel, variable::VariableId)
    # We have to `collect` here because we use `view` in `form_segment_tree_dependency!`
    factors_connected_to_variable = get_variable_neighbors(model, variable) |> collect

    marginal_of_variable = get_variable_marginal(model, variable)
    nfactors = length(factors_connected_to_variable)

    # This is normally not the case in real probabilistic models, but it can happen in some edge cases
    # like when the model has dangling edges, in this case we "assume" that the other message is just one
    # So the marginal is equal to the single message coming from the single factor
    if nfactors < 2
        add_dependency!(
            marginal_of_variable,
            get_edge_message_to_variable(model, variable, first(factors_connected_to_variable));
            intermediate = true
        )
        return nothing
    end

    # Use a simplified approach for small numbers of neighbors
    # This is beneficial in terms of memory allocation and speed and is usually the case for state space models
    # where a typical variable has at most 3 neighbors
    if nfactors <= 5

        # Marginal of the variable is a function of the messages coming from the factors
        for factor in factors_connected_to_variable
            add_dependency!(
                marginal_of_variable, get_edge_message_to_variable(model, variable, factor); intermediate = true
            )
        end

        # Messages on edge 'k' are a function of messages coming from other factors `!= k`
        for f1 in factors_connected_to_variable, f2 in factors_connected_to_variable
            if f1 !== f2
                add_dependency!(
                    get_edge_message_to_factor(model, variable, f1),
                    get_edge_message_to_variable(model, variable, f2);
                    intermediate = true
                )
            end
        end

        return nothing
    end

    middle_point = div(nfactors, 2)

    left_range = 1:middle_point
    right_range = (middle_point + 1):nfactors

    left_dependency = form_segment_tree_dependency!(model, left_range, factors_connected_to_variable, variable)
    right_dependency = form_segment_tree_dependency!(model, right_range, factors_connected_to_variable, variable)

    for left_factor in view(factors_connected_to_variable, left_range)
        add_dependency!(get_edge_message_to_factor(model, variable, left_factor), right_dependency; intermediate = true)
    end

    for right_factor in view(factors_connected_to_variable, right_range)
        add_dependency!(get_edge_message_to_factor(model, variable, right_factor), left_dependency; intermediate = true)
    end

    add_dependency!(marginal_of_variable, left_dependency; intermediate = true)
    add_dependency!(marginal_of_variable, right_dependency; intermediate = true)
end

function form_segment_tree_dependency!(model::AbstractCortexModel, range, factors_connected_to_variable, variable)
    @assert length(range) >= 1

    if length(range) == 1
        return get_edge_message_to_variable(model, variable, first(view(factors_connected_to_variable, range)))
    end

    middle_point = div(length(range), 2)
    left_range = range[begin:middle_point]
    right_range = range[(middle_point + 1):end]

    left_dependency = form_segment_tree_dependency!(model, left_range, factors_connected_to_variable, variable)
    right_dependency = form_segment_tree_dependency!(model, right_range, factors_connected_to_variable, variable)

    for left_factor in view(factors_connected_to_variable, left_range)
        add_dependency!(get_edge_message_to_factor(model, variable, left_factor), right_dependency; intermediate = true)
    end

    for right_factor in view(factors_connected_to_variable, right_range)
        add_dependency!(get_edge_message_to_factor(model, variable, right_factor), left_dependency; intermediate = true)
    end

    intermediate = Signal(type = Cortex.InferenceSignalTypes.IndividualMarginal)

    add_dependency!(intermediate, left_dependency; intermediate = true)
    add_dependency!(intermediate, right_dependency; intermediate = true)

    return intermediate
end
