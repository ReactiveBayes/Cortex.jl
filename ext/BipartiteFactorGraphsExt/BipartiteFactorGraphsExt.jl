module BipartiteFactorGraphsExt

using Cortex, BipartiteFactorGraphs

function Cortex.is_backend_supported(::BipartiteFactorGraphs.BipartiteFactorGraph)
    return Cortex.SupportedModelBackend()
end

function Cortex.get_variable(backend::BipartiteFactorGraphs.BipartiteFactorGraph, variable_id)
    return BipartiteFactorGraphs.get_variable_data(backend, variable_id)
end

function Cortex.get_factor(backend::BipartiteFactorGraphs.BipartiteFactorGraph, factor_id)
    return BipartiteFactorGraphs.get_factor_data(backend, factor_id)
end

function Cortex.get_connection(backend::BipartiteFactorGraphs.BipartiteFactorGraph, variable_id, factor_id)
    return BipartiteFactorGraphs.get_edge_data(backend, variable_id, factor_id)
end

end