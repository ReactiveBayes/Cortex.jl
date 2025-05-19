module GraphVizExt

using GraphViz, Cortex

function GraphViz.load(s::Cortex.Signal; max_depth = 2, type_to_string_fn = Cortex.InferenceSignalTypes.to_string)
    io = IOBuffer()

    # Beginning of the dot specification
    println(io, "digraph G {")
    print(
        io,
        """
        node [
            fontname="Helvetica,Arial,sans-serif"
            shape=record
            style=filled
            fillcolor=gray95
        ]
        """
    )

    print_signal_node(
        io, s; id = "main", title = "MainSignal", max_depth = max_depth, type_to_string_fn = type_to_string_fn
    )

    # End of the dot specification
    println(io, "}")

    graph = GraphViz.Graph(String(take!(io)))

    GraphViz.layout!(graph, engine = "dot")

    return graph
end

function print_signal_node(io::IO, s::Cortex.Signal; id, title, max_depth, type_to_string_fn)
    footer = []

    print(
        io,
        """
        $id [
            shape=plain
            label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="4">
                <tr> <td> <b>$title</b> </td> </tr>
                <tr> <td>
                    <table border="0" cellborder="0" cellspacing="0" >
        """
    )

    if s.value !== Cortex.UndefValue()
        print(io, """<tr> <td align="left">Current value: </td> <td align="left" >$(s.value)</td> </tr>""")
    else
        print(io, """<tr> <td align="left">Does not have a value</td></tr>""")
    end

    if s.metadata !== Cortex.UndefMetadata()
        print(io, """<tr> <td align="left">Metadata: </td> <td align="left" >$(s.metadata)</td> </tr>""")
    else
        print(io, """<tr> <td align="left">Does not have metadata</td></tr>""")
    end

    if s.type !== 0x00
        print(io, """<tr> <td align="left">Type: </td> <td align="left" >$(type_to_string_fn(s.type))</td> </tr>""")
    else
        print(io, """<tr> <td align="left">Does not have a type</td></tr>""")
    end

    print(
        io,
        """
                    </table>
                </td> </tr>
        """
    )

    dependencies = Cortex.get_dependencies(s)

    if isempty(dependencies)
        print(io, """<tr> <td align="left">No dependencies</td></tr>""")
    elseif max_depth <= 0
        print(
            io,
            """<tr> <td align="left">$(length(dependencies)) dependencies<br align="left" /><font point-size="8" color="gray">Use `max_depth` to render more dependencies</font></td></tr>"""
        )
    else
        print(io, """<tr> <td> <table border="0" cellborder="0" cellspacing="0" >""")
        for (i, dep) in enumerate(dependencies)
            print(io, """<tr> <td port="dep$i" align="left">- dependency $i</td> </tr>""")

            dependency_node_io = IOBuffer()
            dependency_node_id = "$(id)dep$(i)"
            print_signal_node(
                dependency_node_io,
                dep;
                id = dependency_node_id,
                title = "Dependency",
                max_depth = max_depth - 1,
                type_to_string_fn = type_to_string_fn
            )

            push!(footer, String(take!(dependency_node_io)))
            push!(footer, "$(id):dep$i -> $(dependency_node_id);")
        end
        print(io, """</table> </td> </tr>""")
    end

    print(
        io,
        """
            </table>>
        ]
        """
    )

    # Add footer
    for element in footer
        print(io, element)
    end
end

end