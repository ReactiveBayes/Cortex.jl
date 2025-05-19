module GraphVizExt

using GraphViz, Cortex

# Default styling for all nodes
const DEFAULT_NODE_STYLE = Dict(
    "shape" => "plain",
    "style" => "filled",
    "fillcolor" => "gray95",
    "fontname" => "Helvetica,Arial,sans-serif"
)

# Additional styling for pending nodes
const PENDING_NODE_STYLE = Dict(
    "style" => "filled,bold",
    "fillcolor" => "lightblue"
)

# Color scheme for different types of edges
const EDGE_COLORS = Dict(
    :fresh_and_intermediate => "cadetblue3",
    :fresh => "dodgerblue3",
    :intermediate => "gray60",
    :default => "black"
)

# Returns (style, color) tuple for edge visualization based on dependency properties
function get_edge_style(is_weak::Bool, is_intermediate::Bool, is_fresh::Bool)
    style = is_weak ? "dashed" : "solid"
    color = if is_fresh && is_intermediate
        EDGE_COLORS[:fresh_and_intermediate]
    elseif is_fresh
        EDGE_COLORS[:fresh]
    elseif is_intermediate
        EDGE_COLORS[:intermediate]
    else
        EDGE_COLORS[:default]
    end
    return (style, color)
end

# Formats the signal's value for display, showing either the current value or a placeholder
function format_node_value(s::Cortex.Signal)
    if s.value !== Cortex.UndefValue()
        return """<tr> <td align="left">Current value: </td> <td align="left">$(s.value)</td> </tr>"""
    else
        return """<tr> <td align="left">Does not have a value</td></tr>"""
    end
end

# Formats the signal's metadata for display if present
function format_node_metadata(s::Cortex.Signal)
    if s.metadata !== Cortex.UndefMetadata()
        return """<tr> <td align="left">Metadata: </td> <td align="left">$(s.metadata)</td> </tr>"""
    else
        return """<tr> <td align="left">Does not have metadata</td></tr>"""
    end
end

# Formats the signal's type information using the provided type conversion function
function format_node_type(s::Cortex.Signal, type_to_string_fn::Function)
    if s.type !== 0x00
        return """<tr> <td align="left">Type: </td> <td align="left">$(type_to_string_fn(s.type))</td> </tr>"""
    else
        return """<tr> <td align="left">Does not have a type</td></tr>"""
    end
end

# Creates the node header with title and optional depth level indicator
function format_node_header(title::String, level::Int)
    depth_info = level > 0 ? """<font point-size="8" color="gray">Depth: $level</font>""" : ""
    return """<tr> <td align="left"><b>$title</b> $depth_info</td></tr>"""
end

# Creates a summary of dependencies when max_depth is reached
function format_dependencies_summary(n_dependencies::Int)
    return """
    <tr> <td align="left">$n_dependencies dependencies<br align="left" />
    <font point-size="8" color="gray">Use `max_depth` to render more dependencies</font>
    </td></tr>"""
end

# Combines default and pending node styles based on signal state
function get_node_attributes(s::Cortex.Signal)
    attrs = copy(DEFAULT_NODE_STYLE)
    if Cortex.is_pending(s)
        merge!(attrs, PENDING_NODE_STYLE)
    end
    return attrs
end

# Converts a dictionary of attributes to GraphViz format
function format_node_attributes(attrs::Dict{String, String})
    return join(["$k=\"$v\"" for (k, v) in attrs], "\n            ")
end

# Main entry point for converting a Signal to a GraphViz visualization
function GraphViz.load(s::Cortex.Signal; max_depth = 2, type_to_string_fn = Cortex.InferenceSignalTypes.to_string)
    io = IOBuffer()
    println(io, "digraph G {")
    
    # Set default node and edge styles
    node_defaults = format_node_attributes(DEFAULT_NODE_STYLE)
    print(io, """
        node [
            $node_defaults
        ]
        edge [
            color="$(EDGE_COLORS[:default])"
            style="solid"
        ]
    """)

    print_signal_node(
        io,
        s;
        id = "main",
        title = "MainSignal",
        max_depth = max_depth,
        level = 0,
        type_to_string_fn = type_to_string_fn
    )

    println(io, "}")

    graph = GraphViz.Graph(String(take!(io)))
    GraphViz.layout!(graph, engine = "dot")
    return graph
end

# Renders a single signal node with all its properties and dependencies
function print_signal_node(io::IO, s::Cortex.Signal; id, title, level, max_depth, type_to_string_fn)
    footer = String[]
    node_attrs = get_node_attributes(s)

    # Start node definition
    print(io, """
        $id [
            $(format_node_attributes(node_attrs))
            label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="4">
    """)

    # Node content
    print(io, format_node_header(title, level))
    print(io, """<tr> <td><table border="0" cellborder="0" cellspacing="0">""")
    print(io, format_node_value(s))
    print(io, format_node_metadata(s))
    print(io, format_node_type(s, type_to_string_fn))
    print(io, "</table></td></tr>")

    # Handle dependencies
    dependencies = Cortex.get_dependencies(s)
    if isempty(dependencies)
        print(io, """<tr> <td align="left">No dependencies</td></tr>""")
    elseif max_depth <= 0
        print(io, format_dependencies_summary(length(dependencies)))
    else
        print(io, process_dependencies(io, s, dependencies, id, level, max_depth, type_to_string_fn, footer))
    end

    # Close node definition
    print(io, "</table>>]")

    # Add footer content
    for element in footer
        print(io, element)
    end
end

# Processes and formats all dependencies of a signal node, creating child nodes and edges
function process_dependencies(io, s, dependencies, id, level, max_depth, type_to_string_fn, footer)
    result = IOBuffer()
    print(result, """<tr> <td> <table border="0" cellborder="0" cellspacing="0">""")
    
    for (i, dep) in enumerate(dependencies)
        # Add dependency entry
        print(result, """<tr> <td port="dep$i" align="left">- dependency $i</td></tr>""")

        # Create dependency node
        dependency_node_io = IOBuffer()
        dependency_node_id = "$(id)dep$(i)"
        print_signal_node(
            dependency_node_io,
            dep;
            id = dependency_node_id,
            title = "Dependency",
            level = level + 1,
            max_depth = max_depth - 1,
            type_to_string_fn = type_to_string_fn
        )
        push!(footer, String(take!(dependency_node_io)))

        # Get dependency properties and create edge with appropriate style
        is_weak = Cortex.is_dependency_weak(s.dependencies_props, i)
        is_intermediate = Cortex.is_dependency_intermediate(s.dependencies_props, i)
        is_fresh = Cortex.is_dependency_fresh(s.dependencies_props, i)

        edge_style, edge_color = get_edge_style(is_weak, is_intermediate, is_fresh)
        push!(footer, """$(id):dep$i -> $(dependency_node_id) [style="$edge_style" color="$edge_color"];""")
    end

    print(result, "</table></td></tr>")
    return String(take!(result))
end

end