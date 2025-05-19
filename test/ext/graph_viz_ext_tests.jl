@testmodule GraphVizUtils begin
    using GraphViz, Cortex

    export to_svg

    function to_svg(s::Cortex.Signal; kwargs...)
        return repr(MIME"image/svg+xml"(), GraphViz.load(s; kwargs...))
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

    @testset "Two dependencies" begin
        s = Cortex.Signal()

        dep1 = Cortex.Signal("dep1", metadata = (:a, 1))
        dep2 = Cortex.Signal("hello world", metadata = (:b, 2))

        Cortex.add_dependency!(s, dep1)
        Cortex.add_dependency!(s, dep2)

        s_svg = to_svg(s)

        @test occursin("dependency 1", s_svg)
        @test occursin("dependency 2", s_svg)

        @test occursin("dep1", s_svg)
        @test occursin("hello world", s_svg)

        @test occursin("(:a, 1)", s_svg)
        @test occursin("(:b, 2)", s_svg)
    end

    @testset "A dependency but depth is too small for visualization" begin
        s = Cortex.Signal()

        dep1 = Cortex.Signal("dep1", metadata = (:a, 1))

        Cortex.add_dependency!(s, dep1)

        s_svg = to_svg(s; max_depth = 0)

        @test occursin("1 dependencies", s_svg)
        @test occursin("Use `max_depth` to render more dependencies", s_svg)

        @test !occursin("dep1", s_svg)
        @test !occursin("(:a, 1)", s_svg)
    end
end

@testitem "Signal visualization should reflect pending state" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    # Create a signal that will be pending
    source = Cortex.Signal(1)
    dependent = Cortex.Signal()
    Cortex.add_dependency!(dependent, source)

    # The dependent signal should be pending since source is computed
    @test Cortex.is_pending(dependent)
    s_pending = to_svg(dependent)

    # Check for pending signal styling
    @test occursin("lightyellow", s_pending)

    # Now set a value to clear pending state
    Cortex.set_value!(dependent, 42)
    @test !Cortex.is_pending(dependent)
    s_not_pending = to_svg(dependent)

    # Check for non-pending signal styling
    @test !occursin("lightyellow", s_not_pending)
end

@testitem "Signal visualization should show different dependency styles" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    svgs = []

    for (intermediate, weak) in ((true, true), (true, false), (false, true), (false, false))
        s = Cortex.Signal(1)

        dep1 = Cortex.Signal()
        dep2 = Cortex.Signal()

        Cortex.add_dependency!(s, dep1; intermediate = intermediate, weak = weak)
        Cortex.add_dependency!(s, dep2; weak = weak)

        dep3 = Cortex.Signal(3)
        dep4 = Cortex.Signal(4)

        Cortex.add_dependency!(dep1, dep3)
        Cortex.add_dependency!(dep1, dep4; intermediate = intermediate, weak = weak)

        dep5 = Cortex.Signal()

        Cortex.add_dependency!(dep2, dep5)

        s_svg = to_svg(s; max_depth = 100)

        push!(svgs, s_svg)
    end

    # Check that all SVGs are different
    for i in 1:length(svgs)
        for j in (i + 1):length(svgs)
            @test svgs[i] != svgs[j]
        end
    end
end
