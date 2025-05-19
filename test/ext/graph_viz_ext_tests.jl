@testitem "GraphViz extension should enable visualization of the Signal" begin
    using GraphViz

    # Empty signal
    @testset let s = Cortex.Signal()
        @test GraphViz.load(s) isa GraphViz.Graph
    end

    # Initialized signal
    @testset let s = Cortex.Signal(1)
        @test GraphViz.load(s) isa GraphViz.Graph
    end

    # Initialized signal with a metadata
    @testset let s = Cortex.Signal("hello", metadata = (:a, 1))
        @test GraphViz.load(s) isa GraphViz.Graph
    end

    # Check that the result is actually different
    signal1 = Cortex.Signal("hello 1", metadata = (:a, 1))
    signal2 = Cortex.Signal("hello 2", metadata = (:a, 1))

    mime_svg = MIME"image/svg+xml"()
    @test repr(mime_svg, GraphViz.load(signal1)) != repr(mime_svg, GraphViz.load(signal2))
end

@testitem "Signal visualization should include the value" begin
    using GraphViz

    for value in (1, 1.0, "hello", [1, 2, 3], (a = 1, b = 2))
        @testset let s = Cortex.Signal(value)
            viz = GraphViz.load(s)
            svg = repr(MIME"image/svg+xml"(), viz)
            @test occursin(string(value), svg)
        end
    end
end
