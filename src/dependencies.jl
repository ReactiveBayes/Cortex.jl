abstract type AbstractDependencyResolver end

struct DefaultDependencyResolver <: AbstractDependencyResolver end

function resolve_dependencies!(resolver::AbstractDependencyResolver, engine::InferenceEngine)
    # Resolve dependencies for each factor
    for factor_id in get_factor_ids(engine)
        resolve_factor_dependencies!(resolver, engine, factor_id)
    end

    # Resolve dependencies for each variable
    for variable_id in get_variable_ids(engine)
        resolve_variable_dependencies!(resolver, engine, variable_id)
    end
end

function resolve_factor_dependencies!(::DefaultDependencyResolver, engine::InferenceEngine, factor_id)
    ids_of_variables_connected_to_factor = get_connected_variable_ids(engine, factor_id)

    # This is a simple Belief Propagation dependency scheme 
    # Each factor sends a 'outbound' message to each of its variables 
    # where each message is a function of the other 'outbound' messages from the other variables
    for variable_id_1 in ids_of_variables_connected_to_factor, variable_id_2 in ids_of_variables_connected_to_factor
        if variable_id_1 !== variable_id_2
            add_dependency!(
                get_message_to_variable(engine, variable_id_1, factor_id), # outbound message from factor_id to variable_id_1
                get_message_to_factor(engine, variable_id_2, factor_id)    # inbound message from variable_id_2 to factor_id
            )
        end
    end
end

function resolve_variable_dependencies!(::DefaultDependencyResolver, engine::InferenceEngine, variable_id)
    ids_of_factors_connected_to_variable = get_connected_factor_ids(engine, variable_id)

    marginal_of_variable = get_marginal(engine, variable_id)
    nfactors = length(ids_of_factors_connected_to_variable)

    # This is normally not the case in real probabilistic models, but it can happen in some edge cases
    # like when the model has dangling edges, in this case we "assume" that the other message is just one
    # So the marginal is equal to the single message coming from the single factor
    if nfactors < 2
        add_dependency!(
            marginal_of_variable,
            get_message_to_variable(engine, variable_id, first(ids_of_factors_connected_to_variable));
            intermediate = true
        )
        return nothing
    end

    # Use a simplified approach for small numbers of neighbors
    # This is beneficial in terms of memory allocation and speed and is usually the case for state space models
    # where a typical variable has at most 3 neighbors
    if nfactors <= 5

        # Marginal of the variable is a function of the messages coming from the factors
        for factor in ids_of_factors_connected_to_variable
            add_dependency!(
                marginal_of_variable, get_message_to_variable(engine, variable_id, factor); intermediate = true
            )
        end

        # Messages on edge 'k' are a function of messages coming from other factors `!= k`
        for f1 in ids_of_factors_connected_to_variable, f2 in ids_of_factors_connected_to_variable
            if f1 !== f2
                add_dependency!(
                    get_message_to_factor(engine, variable_id, f1),
                    get_message_to_variable(engine, variable_id, f2);
                    intermediate = true
                )
            end
        end

        return nothing
    end

    middle_point = div(nfactors, 2)

    left_range = 1:middle_point
    right_range = (middle_point + 1):nfactors

    left_dependency = form_segment_tree_dependency!(
        engine, left_range, ids_of_factors_connected_to_variable, variable_id
    )
    right_dependency = form_segment_tree_dependency!(
        engine, right_range, ids_of_factors_connected_to_variable, variable_id
    )

    for left_factor in view(ids_of_factors_connected_to_variable, left_range)
        add_dependency!(get_message_to_factor(engine, variable_id, left_factor), right_dependency; intermediate = true)
    end

    for right_factor in view(ids_of_factors_connected_to_variable, right_range)
        add_dependency!(get_message_to_factor(engine, variable_id, right_factor), left_dependency; intermediate = true)
    end

    add_dependency!(marginal_of_variable, left_dependency; intermediate = true)
    add_dependency!(marginal_of_variable, right_dependency; intermediate = true)
end

function form_segment_tree_dependency!(engine::InferenceEngine, range, factors_connected_to_variable, variable_id)
    @assert length(range) >= 1

    if length(range) == 1
        return get_message_to_variable(engine, variable_id, first(view(factors_connected_to_variable, range)))
    end

    middle_point = div(length(range), 2)
    left_range = range[begin:middle_point]
    right_range = range[(middle_point + 1):end]

    left_dependency = form_segment_tree_dependency!(engine, left_range, factors_connected_to_variable, variable_id)
    right_dependency = form_segment_tree_dependency!(engine, right_range, factors_connected_to_variable, variable_id)

    for left_factor in view(factors_connected_to_variable, left_range)
        add_dependency!(get_message_to_factor(engine, variable_id, left_factor), right_dependency; intermediate = true)
    end

    for right_factor in view(factors_connected_to_variable, right_range)
        add_dependency!(get_message_to_factor(engine, variable_id, right_factor), left_dependency; intermediate = true)
    end

    intermediate = Signal(type = Cortex.InferenceSignalTypes.IndividualMarginal)

    add_dependency!(intermediate, left_dependency; intermediate = true)
    add_dependency!(intermediate, right_dependency; intermediate = true)

    return intermediate
end
