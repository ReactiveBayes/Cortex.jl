module GraphVizExt

using GraphViz, Cortex

function GraphViz.load(s::Cortex.Signal)
    io = IOBuffer()

    # Beginning of the dot specification
    println(io, "digraph G {")

    print_main_signal_node(io, s)

    # End of the dot specification
    println(io, "}")

    return GraphViz.Graph(String(take!(io)))
end

function print_main_signal_node(io::IO, s::Cortex.Signal)
    print(
        io,
        """
        MainSignal [
            shape=plain
            label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="4">
                <tr> <td> <b>Main Signal</b> </td> </tr>
                <tr> <td>
                    <table border="0" cellborder="0" cellspacing="0" >
        """
    )

    if s.value !== Cortex.UndefValue()
        print(io, """<tr> <td align="left" >Current value: $(s.value)</td> </tr>""")
    else
        print(io, """<tr> <td align="left" >Does not have a value</td> </tr>""")
    end

    if s.metadata !== Cortex.UndefMetadata()
        print(io, """<tr> <td align="left" >Metadata: $(s.metadata)</td> </tr>""")
    else
        print(io, """<tr> <td align="left" >Does not have metadata</td> </tr>""")
    end

    print(
        io,
        """
                    </table>
                </td> </tr>
                <tr> <td align="left">+ method<br/>...<br align="left"/></td> </tr>
            </table>>
        ]
        """
    )
end

end