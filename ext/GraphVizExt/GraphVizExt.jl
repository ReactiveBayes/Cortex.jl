module GraphVizExt

using GraphViz, Cortex

# Default styling for all nodes
const DEFAULT_NODE_STYLE = Dict(
    "shape" => "plain", "style" => "filled", "fillcolor" => "white", "fontname" => "Helvetica,Arial,sans-serif"
)

# Additional styling for computed nodes
const COMPUTED_NODE_STYLE = Dict("style" => "filled,bold", "fillcolor" => "lightyellow")

# Additional styling for pending nodes
const PENDING_NODE_STYLE = Dict("style" => "filled,bold", "fillcolor" => "lightblue")

# Color scheme for different types of edges
const EDGE_COLORS = Dict(
    :fresh_and_intermediate => "cadetblue3", :fresh => "dodgerblue3", :intermediate => "gray60", :default => "black"
)

# Styles for listener edges
const LISTENER_EDGE_STYLES = Dict(
    :active => Dict("style" => "solid", "color" => "black"), :inactive => Dict("style" => "dotted", "color" => "gray40")
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
    pending_str = Cortex.is_pending(s) ? " (pending)" : ""
    if s.value !== Cortex.UndefValue()
        return """<tr> <td align="left">Current value: </td> <td align="left">$(s.value) $(pending_str)</td> </tr>"""
    else
        return """<tr> <td align="left">Does not have a value</td> <td align="left">$(pending_str)</td></tr>"""
    end
end

# Formats the signal's variant for display if present
function format_node_variant(s::Cortex.Signal, variant_to_string_fn::Function)
    variant = Cortex.get_variant(s)
    if variant !== Cortex.UndefVariant()
        return """<tr> <td align="left">Variant: </td> <td align="left">$(variant_to_string_fn(variant))</td> </tr>"""
    else
        return """<tr> <td align="left">Does not have a variant</td></tr>"""
    end
end



# Creates the node header with title and optional depth level indicator
function format_node_header(title::String, level::Int; show_depth::Bool = true)
    depth_info = show_depth && level > 0 ? """<font point-size="8" color="gray">Depth: $level</font>""" : ""
    return """<tr> <td port="header" align="left"><b>$title</b> $depth_info</td></tr>"""
end

# Creates a summary of dependencies when max_depth is reached
function format_dependencies_summary(n_dependencies::Int; show_hints::Bool = true)
    hints = show_hints ? """
    <font point-size="8" color="gray">Use `max_depth` to render more dependencies</font>
    """ : ""
    return """
    <tr> <td align="left">$n_dependencies dependencies<br align="left" />
    $hints
    </td></tr>"""
end

# Combines default and pending node styles based on signal state
function get_node_attributes(s::Cortex.Signal)
    attrs = copy(DEFAULT_NODE_STYLE)
    if Cortex.is_computed(s)
        merge!(attrs, COMPUTED_NODE_STYLE)
    end
    if Cortex.is_pending(s)
        merge!(attrs, PENDING_NODE_STYLE)
    end
    return attrs
end

# Converts a dictionary of attributes to GraphViz format
function format_node_attributes(attrs::Dict{String, String})
    return join(["$k=\"$v\"" for (k, v) in attrs], "\n            ")
end

# Calculates statistics for a collection of dependencies
function calculate_dependency_stats(s::Cortex.Signal, dependencies::Vector{<:Cortex.Signal}, start_idx::Int)
    stats = Dict(
        :total => length(dependencies) - start_idx + 1, :weak => 0, :intermediate => 0, :fresh => 0, :pending => 0
    )

    for i in start_idx:length(dependencies)
        stats[:weak] += Cortex.is_dependency_weak(s.dependencies_props, i) ? 1 : 0
        stats[:intermediate] += Cortex.is_dependency_intermediate(s.dependencies_props, i) ? 1 : 0
        stats[:fresh] += Cortex.is_dependency_fresh(s.dependencies_props, i) ? 1 : 0
        stats[:pending] += Cortex.is_pending(dependencies[i]) ? 1 : 0
    end

    return stats
end

# Formats dependency statistics into a human-readable string
function format_dependency_stats(stats::Dict{Symbol, Int})
    details = String[]

    push!(details, "$(stats[:total]) more dependencies")
    stats[:weak] > 0 && push!(details, "$(stats[:weak]) weak")
    stats[:intermediate] > 0 && push!(details, "$(stats[:intermediate]) intermediate")
    stats[:fresh] > 0 && push!(details, "$(stats[:fresh]) fresh")
    stats[:pending] > 0 && push!(details, "$(stats[:pending]) pending")

    summary = join(details, ", ")
    return """
    <tr> <td align="left"> ... </td></tr>
    <tr> <td align="left"> <font point-size="8" color="gray">$summary</font><br align="left" />
    <font point-size="8" color="gray">Use `max_dependencies` to show more dependencies</font>
    </td></tr>"""
end

# Formats the edge attributes for a listener based on its listening status
function format_listener_edge_attrs(is_listening::Bool)
    style = is_listening ? LISTENER_EDGE_STYLES[:active] : LISTENER_EDGE_STYLES[:inactive]
    return join(["$k=\"$v\"" for (k, v) in style], " ")
end

# Calculates statistics for a collection of listeners
function calculate_listener_stats(signal::Cortex.Signal, start_idx::Int)
    listeners = Cortex.get_listeners(signal)
    listenmask = signal.listenmask

    stats = Dict(:total => length(listeners) - start_idx + 1, :active => 0, :inactive => 0)

    for i in start_idx:length(listeners)
        if listenmask[i]
            stats[:active] += 1
        else
            stats[:inactive] += 1
        end
    end

    return stats
end

# Formats listener statistics into a human-readable string
function format_listener_stats(stats::Dict{Symbol, Int}; show_hints::Bool = true)
    details = String[]

    push!(details, "$(stats[:total]) more listeners")
    stats[:active] > 0 && push!(details, "$(stats[:active]) active")
    stats[:inactive] > 0 && push!(details, "$(stats[:inactive]) inactive")

    summary = join(details, ", ")
    hints = show_hints ? """
    <font point-size="8" color="gray">Use `max_listeners` to show more listeners</font>
    """ : ""
    return """
    <tr> <td align="left">
    <font point-size="8" color="gray">$summary</font><br align="left" />
    $hints
    </td></tr>"""
end

# Formats the listeners section of a signal node
function format_signal_listeners(
    signal::Cortex.Signal,
    id::String,
    footer::Vector{String};
    max_listeners::Int = 10,
    variant_to_string_fn,
    show_value::Bool = true,
    show_variant::Bool = true,
    show_hints::Bool = true
)
    result = IOBuffer()

    listeners = Cortex.get_listeners(signal)
    listenmask = signal.listenmask

    if isempty(listeners)
        print(result, """<tr> <td align="left">No listeners</td></tr>""")
        return String(take!(result))
    end

    print(result, """<tr> <td> <table border="0" cellborder="0" cellspacing="0">""")

    # Get the number of listeners to show
    n_listeners = length(listeners)
    show_listeners = min(n_listeners, max_listeners)

    for i in 1:show_listeners
        listener = listeners[i]
        is_listening = listenmask[i]

        # Add listener entry with a port
        print(
            result,
            """<tr> <td port="listener$i" align="left">- listener $i $(is_listening ? "" : "(not listening)")</td></tr>"""
        )

        # Create listener node
        listener_node_id = "$(id)listener$(i)"
        listener_node_io = IOBuffer()
        print_signal_node(
            listener_node_io,
            listener;
            id = listener_node_id,
            title = "Listener",
            level = 1,
            max_depth = 0,  # Don't show listener's dependencies
            max_dependencies = 0,
            max_listeners = 0,
            variant_to_string_fn = variant_to_string_fn,
            show_value = show_value,
            show_variant = show_variant,
            show_listeners = false,  # Don't show listener's listeners to avoid recursion
            show_depth = false, # Don't show depth as it is irrelevant for listeners
            show_hints = false # Don't show hints as it is irrelevant for listeners
        )
        push!(footer, String(take!(listener_node_io)))

        # Add edge with appropriate style
        edge_attrs = format_listener_edge_attrs(is_listening)
        push!(footer, """$(id):listener$i -> $listener_node_id:header [$edge_attrs]""")
    end

    # If we have more listeners than the limit, show statistics
    if n_listeners > max_listeners
        stats = calculate_listener_stats(signal, show_listeners + 1)
        print(result, format_listener_stats(stats; show_hints = show_hints))
    end

    print(result, "</table></td></tr>")
    return String(take!(result))
end

"""
    GraphViz.load(s::Signal; 
        max_depth::Int = 2,
        max_dependencies::Int = 10,
        max_listeners::Int = 10,
        variant_to_string_fn = string,
        show_value::Bool = true,
        show_variant::Bool = true,
        show_listeners::Bool = true
    ) -> GraphViz.Graph

Creates a GraphViz visualization of a Signal and its dependency graph.

The visualization includes:
- The signal's value and variant (if present)
- Dependencies and their relationships
- Listeners and their states
- Visual indicators for pending, computed, and intermediate states

# Arguments
- `s::Signal`: The signal to visualize

# Keyword Arguments
- `max_depth::Int = 2`: Maximum depth of the dependency tree to display
- `max_dependencies::Int = 10`: Maximum number of dependencies to show per signal
- `max_listeners::Int = 10`: Maximum number of listeners to show per signal
- `variant_to_string_fn = string`: Function to convert signal variant to string
- `show_value::Bool = true`: Whether to display signal values
- `show_variant::Bool = true`: Whether to display signal variants
- `show_listeners::Bool = true`: Whether to display signal listeners

# Visual Styling
- Nodes use different colors and styles to indicate their state:
  - Computed nodes: Light yellow background with bold text
  - Pending nodes: Light blue background with bold text
  - Regular nodes: White background
- Edges have different styles based on dependency properties:
  - Weak dependencies: Dashed lines
  - Intermediate dependencies: Gray color
  - Fresh dependencies: Blue color
  - Fresh and intermediate: Cadet blue color
- Listener edges:
  - Active listeners: Solid black lines
  - Inactive listeners: Dotted gray lines

# Returns
A `GraphViz.Graph` object representing the signal's dependency graph.
"""
function GraphViz.load(
    s::Cortex.Signal;
    max_depth = 2,
    max_dependencies = 10,
    max_listeners = 10,
    variant_to_string_fn = string,
    show_value = true,
    show_variant = true,
    show_listeners = true
)
    io = IOBuffer()
    println(io, "digraph G {")

    # Set default node and edge styles
    node_defaults = format_node_attributes(DEFAULT_NODE_STYLE)
    print(
        io,
        """
        rankdir="RL"
        node [
            $node_defaults
        ]
        edge [
            color="$(EDGE_COLORS[:default])"
            style="solid"
        ]
        """
    )

    print_signal_node(
        io,
        s;
        id = "main",
        title = "MainSignal",
        max_depth = max_depth,
        max_dependencies = max_dependencies,
        max_listeners = max_listeners,
        level = 0,
        variant_to_string_fn = variant_to_string_fn,
        show_value = show_value,
        show_variant = show_variant,
        show_listeners = show_listeners
    )

    println(io, "}")

    graph = GraphViz.Graph(String(take!(io)))
    GraphViz.layout!(graph, engine = "dot")
    return graph
end

# Renders a single signal node with all its properties and dependencies
function print_signal_node(
    io::IO,
    s::Cortex.Signal;
    id,
    title,
    level,
    max_depth,
    max_dependencies,
    max_listeners,
    variant_to_string_fn,
    show_value = true,
    show_variant = true,
    show_listeners = true,
    show_depth = true,
    show_hints = true
)
    footer = String[]
    node_attrs = get_node_attributes(s)

    # Start node definition
    print(
        io,
        """
        $id [
            $(format_node_attributes(node_attrs))
            label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="4">
        """
    )

    # Node content
    print(io, format_node_header(title, level; show_depth = show_depth))
    print(io, """<tr> <td><table border="0" cellborder="0" cellspacing="0">""")

    # Ensure we always have at least one row to avoid empty table syntax errors
    has_content = false
    if show_value
        print(io, format_node_value(s))
        has_content = true
    end
    if show_variant
        print(io, format_node_variant(s, variant_to_string_fn))
        has_content = true
    end
    
    # If no content was added, add a placeholder row
    if !has_content
        print(io, """<tr> <td align="left"></td></tr>""")
    end

    print(io, "</table></td></tr>")

    # Handle dependencies
    dependencies = Cortex.get_dependencies(s)
    if isempty(dependencies)
        print(io, """<tr> <td align="left">No dependencies</td></tr>""")
    elseif max_depth <= 0
        print(io, format_dependencies_summary(length(dependencies); show_hints = show_hints))
    else
        print(
            io,
            format_signal_dependencies(
                s,
                dependencies,
                id,
                level,
                max_depth,
                max_dependencies,
                variant_to_string_fn,
                footer,
                show_value,
                show_variant
            )
        )
    end

    # Add listeners section if requested (only for the main signal)
    if show_listeners
        print(
            io,
            format_signal_listeners(
                s,
                id,
                footer;
                max_listeners = max_listeners,
                variant_to_string_fn = variant_to_string_fn,
                show_value = show_value,
                show_variant = show_variant,
                show_hints = show_hints
            )
        )
    end

    # Close node definition
    print(io, "</table>>]")

    # Add footer content
    for element in footer
        print(io, element)
    end
end

# Formats and renders dependencies of a signal node, creating child nodes and edges
function format_signal_dependencies(
    s,
    dependencies,
    id,
    level,
    max_depth,
    max_dependencies,
    variant_to_string_fn,
    footer,
    show_value,
    show_variant
)
    result = IOBuffer()
    print(result, """<tr> <td> <table border="0" cellborder="0" cellspacing="0">""")

    n_deps = length(dependencies)
    show_deps = min(n_deps, max_dependencies)

    for i in 1:show_deps
        dep = dependencies[i]
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
            max_dependencies = max_dependencies,
            max_listeners = 0,
            variant_to_string_fn = variant_to_string_fn,
            show_value = show_value,
            show_variant = show_variant,
            show_listeners = false
        )
        push!(footer, String(take!(dependency_node_io)))

        # Get dependency properties and create edge with appropriate style
        is_weak = Cortex.is_dependency_weak(s.dependencies_props, i)
        is_intermediate = Cortex.is_dependency_intermediate(s.dependencies_props, i)
        is_fresh = Cortex.is_dependency_fresh(s.dependencies_props, i)

        edge_style, edge_color = get_edge_style(is_weak, is_intermediate, is_fresh)
        push!(footer, """$(dependency_node_id):header -> $(id):dep$i [style="$edge_style" color="$edge_color"];""")
    end

    # If we have more dependencies than the limit, show statistics
    if n_deps > max_dependencies
        stats = calculate_dependency_stats(s, dependencies, show_deps + 1)
        print(result, format_dependency_stats(stats))
    end

    print(result, "</table></td></tr>")
    return String(take!(result))
end

end
