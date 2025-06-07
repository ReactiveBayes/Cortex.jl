module BipartiteFactorGraphsExt

using Cortex, BipartiteFactorGraphs

import Cortex: Variable, Factor, Connection
import Cortex:
    is_engine_supported,
    get_variable,
    get_variable_ids,
    get_factor_ids,
    get_factor,
    get_connection,
    get_connected_variable_ids,
    get_connected_factor_ids

const CortexBipartiteFactorGraph = BipartiteFactorGraphs.BipartiteFactorGraph{Variable, Factor, Connection}

function is_engine_supported(::CortexBipartiteFactorGraph)
    return Cortex.SupportedModelEngine()
end

function Cortex.get_variable(engine::CortexBipartiteFactorGraph, variable_id::Int)
    return BipartiteFactorGraphs.get_variable_data(engine, variable_id)
end

function Cortex.get_variable_ids(engine::CortexBipartiteFactorGraph)
    return BipartiteFactorGraphs.variables(engine)
end

function Cortex.get_factor_ids(engine::CortexBipartiteFactorGraph)
    return BipartiteFactorGraphs.factors(engine)
end

function Cortex.get_factor(engine::CortexBipartiteFactorGraph, factor_id::Int)
    return BipartiteFactorGraphs.get_factor_data(engine, factor_id)
end

function Cortex.get_connection(engine::CortexBipartiteFactorGraph, variable_id::Int, factor_id::Int)
    return BipartiteFactorGraphs.get_edge_data(engine, variable_id, factor_id)
end

function Cortex.get_connected_variable_ids(engine::CortexBipartiteFactorGraph, factor_id::Int)
    return BipartiteFactorGraphs.neighbors(engine, factor_id)
end

function Cortex.get_connected_factor_ids(engine::CortexBipartiteFactorGraph, variable_id::Int)
    return BipartiteFactorGraphs.neighbors(engine, variable_id)
end

end
