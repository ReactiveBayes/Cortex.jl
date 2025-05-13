module BipartiteFactorGraphsExt

using Cortex, BipartiteFactorGraphs

function Cortex.is_backend_supported(::BipartiteFactorGraphs.BipartiteFactorGraph)
    return Cortex.SupportedModelBackend()
end

function Cortex.get_variable_data(backend::BipartiteFactorGraphs.BipartiteFactorGraph, variable_id)
    return BipartiteFactorGraphs.get_variable_data(backend, variable_id)
end

function Cortex.get_variable_ids(backend::BipartiteFactorGraphs.BipartiteFactorGraph)
    return BipartiteFactorGraphs.variables(backend)
end

function Cortex.get_factor_ids(backend::BipartiteFactorGraphs.BipartiteFactorGraph)
    return BipartiteFactorGraphs.factors(backend)
end

function Cortex.get_factor_data(backend::BipartiteFactorGraphs.BipartiteFactorGraph, factor_id)
    return BipartiteFactorGraphs.get_factor_data(backend, factor_id)
end

function Cortex.get_connection(backend::BipartiteFactorGraphs.BipartiteFactorGraph, variable_id, factor_id)
    return BipartiteFactorGraphs.get_edge_data(backend, variable_id, factor_id)
end

function Cortex.get_connected_variable_ids(backend::BipartiteFactorGraphs.BipartiteFactorGraph, factor_id)
    return BipartiteFactorGraphs.neighbors(backend, factor_id)
end

function Cortex.get_connected_factor_ids(backend::BipartiteFactorGraphs.BipartiteFactorGraph, variable_id)
    return BipartiteFactorGraphs.neighbors(backend, variable_id)
end

end
