@testmodule GraphVizUtils begin
    using GraphViz, Cortex

    export to_svg

    function to_svg(s::Cortex.Signal)
        return repr(MIME"image/svg+xml"(), GraphViz.load(s))
    end
end

@testitem "GraphViz extension should enable visualization of the Signal" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

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

    @test to_svg(signal1) != to_svg(signal2)
end

@testitem "Signal visualization should include the value" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    @testset "No value" begin
        s = Cortex.Signal()
        @test occursin("Does not have a value", to_svg(s))
    end

    for value in (1, 1.0, "hello", [1, 2, 3], (a = 1, b = 2))
        @testset let s = Cortex.Signal(value)
            @test occursin(string(value), to_svg(s))
        end
    end
end

@testitem "Signal visualization should include the metadata" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    @testset "No metadata" begin
        s = Cortex.Signal(1)
        @test occursin("Does not have metadata", to_svg(s))
    end

    for metadata in (1, 1.0, "hello", [1, 2, 3], (a = 1, b = 2))
        @testset let s = Cortex.Signal(1, metadata = metadata)
            @test occursin(string(metadata), to_svg(s))
        end
    end
end

@testitem "Signal visualization should include the type" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    @testset "No type" begin
        s = Cortex.Signal(1)
        @test !occursin("0x00", to_svg(s)) && !occursin("Custom type", to_svg(s))
    end

    for type in (
        Cortex.InferenceSignalTypes.MessageToVariable,
        Cortex.InferenceSignalTypes.MessageToFactor,
        Cortex.InferenceSignalTypes.ProductOfMessages,
        Cortex.InferenceSignalTypes.IndividualMarginal,
        Cortex.InferenceSignalTypes.JointMarginal
    )
        @testset let s = Cortex.Signal(1, type = type)
            @test occursin(Cortex.InferenceSignalTypes.to_string(type), to_svg(s))
        end
    end
end

@testitem "Signal visualization should include the dependencies" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    @testset "No dependencies" begin
        s = Cortex.Signal()
        @test occursin("No dependencies", to_svg(s))
    end

    @testset "One dependency" begin
        s = Cortex.Signal()

        dep1 = Cortex.Signal()
        dep2 = Cortex.Signal()

        Cortex.add_dependency!(s, dep1)
        Cortex.add_dependency!(s, dep2)

        @test occursin("dependency #1", to_svg(s))
        @test occursin("dependency #2", to_svg(s))
    end
end
