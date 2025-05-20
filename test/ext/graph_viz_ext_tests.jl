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

    # Now set a value to clear pending state
    Cortex.set_value!(dependent, 42)
    @test !Cortex.is_pending(dependent)
    s_not_pending = to_svg(dependent)

    @test s_pending != s_not_pending
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

@testitem "Signal visualization should respect display options" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    s = Cortex.Signal(42, metadata = (:test, 1), type = 0x01)

    # Test show_value option
    s_with_value = to_svg(s; show_value = true)
    s_without_value = to_svg(s; show_value = false)
    @test occursin("Current value: ", s_with_value)
    @test !occursin("Current value: ", s_without_value)
    @test occursin("42", s_with_value)
    @test !occursin("42", s_without_value)

    # Test show_metadata option
    s_with_metadata = to_svg(s; show_metadata = true)
    s_without_metadata = to_svg(s; show_metadata = false)
    @test occursin("Metadata: ", s_with_metadata)
    @test !occursin("Metadata: ", s_without_metadata)
    @test occursin("(:test, 1)", s_with_metadata)
    @test !occursin("(:test, 1)", s_without_metadata)

    # Test show_type option
    s_with_type = to_svg(s; show_type = true, type_to_string_fn = repr)
    s_without_type = to_svg(s; show_type = false, type_to_string_fn = repr)
    @test occursin("Type: ", s_with_type)
    @test !occursin("Type: ", s_without_type)
    @test occursin("0x01", s_with_type)
    @test !occursin("0x01", s_without_type)

    # Test that options propagate to dependencies
    source = Cortex.Signal(1, metadata = (:src, 1), type = 0x02)
    dependent = Cortex.Signal(2, metadata = (:dep, 2), type = 0x03)
    Cortex.add_dependency!(dependent, source)

    # Check with all options disabled
    s_minimal = to_svg(
        dependent; show_value = false, show_metadata = false, show_type = false, type_to_string_fn = repr
    )
    @test !occursin("Current value: ", s_minimal)
    @test !occursin("Metadata: ", s_minimal)
    @test !occursin("Type: ", s_minimal)
    @test !occursin("(:src, 1)", s_minimal)
    @test !occursin("(:dep, 2)", s_minimal)
    @test !occursin("0x02", s_minimal)
    @test !occursin("0x03", s_minimal)

    # Check with all options enabled
    s_full = to_svg(dependent; show_value = true, show_metadata = true, show_type = true, type_to_string_fn = repr)
    @test occursin("Current value: ", s_full)
    @test occursin("Metadata: ", s_full)
    @test occursin("Type: ", s_full)
    @test occursin("(:src, 1)", s_full)
    @test occursin("(:dep, 2)", s_full)
    @test occursin("0x02", s_full)
    @test occursin("0x03", s_full)
end

@testitem "Signal visualization should respect max_dependencies limit" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    # Create a signal with many dependencies
    main = Cortex.Signal(1)
    dependencies = [Cortex.Signal(i) for i in 1:15]

    # Add dependencies with different properties
    for (i, dep) in enumerate(dependencies)
        is_weak = i % 2 == 0
        is_intermediate = i % 3 == 0
        Cortex.add_dependency!(main, dep; weak = is_weak, intermediate = is_intermediate)

        # Make some signals pending
        if i % 4 == 0
            Cortex.set_value!(dep, i)  # This should make dependent signals pending
        end
    end

    # Test with default max_dependencies (10)
    s_default = to_svg(main)
    @test occursin("5 more dependencies", s_default)
    @test occursin("Use `max_dependencies` to show more dependencies", s_default)

    # Verify statistics are shown correctly
    @test occursin("2 weak", s_default)
    @test occursin("2 intermediate", s_default)

    # Test with custom max_dependencies
    s_custom = to_svg(main; max_dependencies = 5)
    @test occursin("10 more dependencies", s_custom)
    @test occursin("Use `max_dependencies` to show more dependencies", s_custom)

    # Test with max_dependencies larger than total dependencies
    s_all = to_svg(main; max_dependencies = 20)
    @test !occursin("more dependencies", s_all)
    @test !occursin("Use `max_dependencies`", s_all)
end

@testitem "Signal visualization should show listeners with appropriate styles" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    # Create a signal with both active and inactive listeners
    main = Cortex.Signal(1)

    # Create listeners with different listening states
    active_listener = Cortex.Signal(2)
    inactive_listener = Cortex.Signal(3)

    # Add dependencies with different listening states
    Cortex.add_dependency!(active_listener, main; listen = true)
    Cortex.add_dependency!(inactive_listener, main; listen = false)

    # Test the visualization with listeners shown
    s_with_listeners = to_svg(main; show_listeners = true)

    # Test the visualization with listeners hidden
    s_without_listeners = to_svg(main; show_listeners = false)

    @test s_with_listeners != s_without_listeners
end

@testitem "Signal visualization should respect max_listeners limit" setup = [GraphVizUtils] begin
    using GraphViz
    using .GraphVizUtils

    # Create a signal with many listeners
    main = Cortex.Signal(1)

    # Create listeners with different listening states
    listeners = [Cortex.Signal(i) for i in 1:15]

    # Add dependencies with alternating listening states
    for (i, listener) in enumerate(listeners)
        Cortex.add_dependency!(listener, main; listen = i % 2 == 0)
    end

    # Test with default max_listeners (10)
    s_default = to_svg(main; show_listeners = true)
    @test occursin("5 more listeners", s_default)
    @test occursin("Use `max_listeners` to show more listeners", s_default)

    # Verify statistics are shown correctly
    @test occursin("2 active", s_default)
    @test occursin("3 inactive", s_default)

    # Test with custom max_listeners
    s_custom = to_svg(main; show_listeners = true, max_listeners = 5)
    @test occursin("10 more listeners", s_custom)
    @test occursin("Use `max_listeners` to show more listeners", s_custom)

    # Test with max_listeners larger than total listeners
    s_all = to_svg(main; show_listeners = true, max_listeners = 20)
    @test !occursin("more listeners", s_all)
    @test !occursin("Use `max_listeners`", s_all)

    # Test with listeners hidden
    s_no_listeners = to_svg(main; show_listeners = false)
    @test !occursin("listener", s_no_listeners)
end
