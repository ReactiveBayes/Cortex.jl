@testitem "Signal Dependencies Properties Should Return Index of Added Dependency" begin
    import Cortex: SignalDependenciesProps, add_dependency!

    props = SignalDependenciesProps()

    first_dependency = add_dependency!(props)
    second_dependency = add_dependency!(props)

    @test first_dependency !== second_dependency

    @test Cortex.is_dependency_weak(props, first_dependency) == false
    @test Cortex.is_dependency_intermediate(props, first_dependency) == false
    @test Cortex.is_dependency_computed(props, first_dependency) == false
    @test Cortex.is_dependency_fresh(props, first_dependency) == false

    @test Cortex.is_dependency_weak(props, second_dependency) == false
    @test Cortex.is_dependency_intermediate(props, second_dependency) == false
    @test Cortex.is_dependency_computed(props, second_dependency) == false
    @test Cortex.is_dependency_fresh(props, second_dependency) == false

    Cortex.set_dependency_weak!(props, first_dependency)
    @test Cortex.is_dependency_weak(props, first_dependency) == true
    @test Cortex.is_dependency_intermediate(props, first_dependency) == false
    @test Cortex.is_dependency_computed(props, first_dependency) == false
    @test Cortex.is_dependency_fresh(props, first_dependency) == false

    @test Cortex.is_dependency_weak(props, second_dependency) == false
    @test Cortex.is_dependency_intermediate(props, second_dependency) == false
    @test Cortex.is_dependency_computed(props, second_dependency) == false
    @test Cortex.is_dependency_fresh(props, second_dependency) == false
end

@testitem "Signal Dependencies Properties Basic Operations" begin
    import Cortex: SignalDependenciesProps, SignalDependenciesProps

    props = SignalDependenciesProps()

    @test props.ndependencies == 0

    Cortex.add_dependency!(props)

    @test props.ndependencies == 1

    @test Cortex.is_dependency_weak(props, 1) == false
    @test Cortex.is_dependency_intermediate(props, 1) == false
    @test Cortex.is_dependency_computed(props, 1) == false
    @test Cortex.is_dependency_fresh(props, 1) == false

    # we do this 4 times to make sure that repetative calls to the same function
    # do not change the result

    for i in 1:4
        Cortex.set_dependency_weak!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == true
        @test Cortex.is_dependency_intermediate(props, 1) == false
        @test Cortex.is_dependency_computed(props, 1) == false
        @test Cortex.is_dependency_fresh(props, 1) == false
    end

    for i in 1:4
        Cortex.set_dependency_intermediate!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == true
        @test Cortex.is_dependency_intermediate(props, 1) == true
        @test Cortex.is_dependency_computed(props, 1) == false
        @test Cortex.is_dependency_fresh(props, 1) == false
    end

    for i in 1:4
        Cortex.set_dependency_computed!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == true
        @test Cortex.is_dependency_intermediate(props, 1) == true
        @test Cortex.is_dependency_computed(props, 1) == true
        @test Cortex.is_dependency_fresh(props, 1) == false
    end

    for i in 1:4
        Cortex.set_dependency_fresh!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == true
        @test Cortex.is_dependency_intermediate(props, 1) == true
        @test Cortex.is_dependency_computed(props, 1) == true
        @test Cortex.is_dependency_fresh(props, 1) == true
    end

    for i in 1:4
        Cortex.unset_dependency_weak!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == false
        @test Cortex.is_dependency_intermediate(props, 1) == true
        @test Cortex.is_dependency_computed(props, 1) == true
        @test Cortex.is_dependency_fresh(props, 1) == true
    end

    for i in 1:4
        Cortex.unset_dependency_intermediate!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == false
        @test Cortex.is_dependency_intermediate(props, 1) == false
        @test Cortex.is_dependency_computed(props, 1) == true
        @test Cortex.is_dependency_fresh(props, 1) == true
    end

    for i in 1:4
        Cortex.unset_dependency_computed!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == false
        @test Cortex.is_dependency_intermediate(props, 1) == false
        @test Cortex.is_dependency_computed(props, 1) == false
        @test Cortex.is_dependency_fresh(props, 1) == true
    end

    for i in 1:4
        Cortex.unset_dependency_fresh!(props, 1)
        @test Cortex.is_dependency_weak(props, 1) == false
        @test Cortex.is_dependency_intermediate(props, 1) == false
        @test Cortex.is_dependency_computed(props, 1) == false
        @test Cortex.is_dependency_fresh(props, 1) == false
    end
end

@testitem "Signal Dependencies Properties Basic Operations with Many Dependencies" begin
    import Cortex: SignalDependenciesProps, SignalDependenciesProps

    n = 100

    for k in 1:n
        props = SignalDependenciesProps()

        @test props.ndependencies == 0

        for i in 1:n
            Cortex.add_dependency!(props)
        end

        @test props.ndependencies == n

        for i in 1:n
            @test !Cortex.is_dependency_weak(props, i)
            @test !Cortex.is_dependency_intermediate(props, i)
            @test !Cortex.is_dependency_computed(props, i)
            @test !Cortex.is_dependency_fresh(props, i)
        end

        Cortex.set_dependency_weak!(props, k)

        for i in 1:n
            @test Cortex.is_dependency_weak(props, i) == (i == k)
        end

        Cortex.set_dependency_intermediate!(props, k)

        for i in 1:n
            @test Cortex.is_dependency_weak(props, i) == (i == k)
            @test Cortex.is_dependency_intermediate(props, i) == (i == k)
        end

        Cortex.set_dependency_computed!(props, k)

        for i in 1:n
            @test Cortex.is_dependency_weak(props, i) == (i == k)
            @test Cortex.is_dependency_intermediate(props, i) == (i == k)
            @test Cortex.is_dependency_computed(props, i) == (i == k)
        end

        Cortex.set_dependency_fresh!(props, k)

        for i in 1:n
            @test Cortex.is_dependency_weak(props, i) == (i == k)
            @test Cortex.is_dependency_intermediate(props, i) == (i == k)
            @test Cortex.is_dependency_computed(props, i) == (i == k)
            @test Cortex.is_dependency_fresh(props, i) == (i == k)
        end

        Cortex.unset_dependency_weak!(props, k)

        for i in 1:n
            @test !Cortex.is_dependency_weak(props, i)
            @test Cortex.is_dependency_intermediate(props, i) == (i == k)
            @test Cortex.is_dependency_computed(props, i) == (i == k)
            @test Cortex.is_dependency_fresh(props, i) == (i == k)
        end

        Cortex.unset_dependency_intermediate!(props, k)

        for i in 1:n
            @test !Cortex.is_dependency_weak(props, i)
            @test !Cortex.is_dependency_intermediate(props, i)
            @test Cortex.is_dependency_computed(props, i) == (i == k)
            @test Cortex.is_dependency_fresh(props, i) == (i == k)
        end

        Cortex.unset_dependency_computed!(props, k)

        for i in 1:n
            @test !Cortex.is_dependency_weak(props, i)
            @test !Cortex.is_dependency_intermediate(props, i)
            @test !Cortex.is_dependency_computed(props, i)
            @test Cortex.is_dependency_fresh(props, i) == (i == k)
        end

        Cortex.unset_dependency_fresh!(props, k)

        for i in 1:n
            @test !Cortex.is_dependency_weak(props, i)
            @test !Cortex.is_dependency_intermediate(props, i)
            @test !Cortex.is_dependency_computed(props, i)
            @test !Cortex.is_dependency_fresh(props, i)
        end
    end
end

@testitem "Signal Dependencies Properties Unset All Fresh" begin
    import Cortex: SignalDependenciesProps, SignalDependenciesProps

    props = SignalDependenciesProps()

    n = 100

    for i in 1:n
        Cortex.add_dependency!(props)
    end

    for i in 1:n
        for i in 1:4
            for k in 1:i
                Cortex.set_dependency_fresh!(props, k)
            end

            for j in 1:n
                @test Cortex.is_dependency_fresh(props, j) == (j <= i)
            end
        end

        for i in 1:4
            Cortex.unset_all_fresh!(props)

            for j in 1:n
                @test !Cortex.is_dependency_fresh(props, j)
            end
        end
    end
end

@testitem "Signal Dependencies Properties is_pending #1" begin
    import Cortex: SignalDependenciesProps

    @testset for ndependencies in 1:100
        props = SignalDependenciesProps()

        for i in 1:ndependencies
            Cortex.add_dependency!(props)
        end

        # In the beginning, the props cannot be pending
        @test !Cortex.is_pending(props)

        # If we set all dependencies to computed, the props should not be pending
        # as it also requires all dependencies to be fresh
        for i in 1:ndependencies
            Cortex.set_dependency_computed!(props, i)
            @test !Cortex.is_pending(props)
        end

        @test !Cortex.is_pending(props)

        # If we set all dependencies to fresh, the props should be pending
        for i in 1:ndependencies
            Cortex.set_dependency_fresh!(props, i)
            if i < ndependencies
                # If we have not set all dependencies to fresh, the props should not be pending
                @test !Cortex.is_pending(props)
            else
                # If we have set all dependencies to fresh AND computed, the props should be pending
                @test Cortex.is_pending(props)
            end
        end
    end
end

@testitem "Signal Dependencies Properties is_pending #2" begin
    import Cortex: SignalDependenciesProps

    @testset for ndependencies in 1:100
        props = SignalDependenciesProps()

        for i in 1:ndependencies
            Cortex.add_dependency!(props)
        end

        # In the beginning, the props cannot be pending
        @test !Cortex.is_pending(props)

        # If we set all dependencies to computed, the props should not be pending
        # the dependencies can either be weak or fresh
        for i in 1:ndependencies
            Cortex.set_dependency_computed!(props, i)
            @test !Cortex.is_pending(props)
        end

        @test !Cortex.is_pending(props)

        # If we set all dependencies to fresh, the props should be pending
        for i in 1:ndependencies
            if div(i, 2) == 0
                Cortex.set_dependency_weak!(props, i)
            else
                Cortex.set_dependency_fresh!(props, i)
            end
            if i < ndependencies
                # If we have not set all dependencies to fresh, the props should not be pending
                @test !Cortex.is_pending(props)
            else
                # If we have set all dependencies to fresh AND computed, the props should be pending
                @test Cortex.is_pending(props)
            end
        end
    end
end

@testitem "Signal Dependencies Properties is_pending Granular" begin
    # This is Cursor auto-generated testset

    import Cortex:
        SignalDependenciesProps,
        add_dependency!,
        set_dependency_computed!,
        set_dependency_fresh!,
        set_dependency_weak!,
        is_pending

    # Helper function to create and setup props based on a list of states
    # Each state is a tuple: (is_computed, is_fresh, is_weak)
    function setup_props_with_states(states::Vector{Tuple{Bool, Bool, Bool}})
        props = SignalDependenciesProps()
        for (i, state) in enumerate(states)
            add_dependency!(props)
            is_c, is_f, is_w = state
            if is_c
                set_dependency_computed!(props, i)
            end
            if is_f
                set_dependency_fresh!(props, i)
            end
            if is_w
                set_dependency_weak!(props, i)
            end
        end
        return props
    end

    # Condition for a single dependency to pass: Computed AND (Weak OR Fresh)
    # C=true, W=true, F=true  -> T
    # C=true, W=true, F=false -> T
    # C=true, W=false, F=true -> T
    # C=true, W=false, F=false -> F (Strong, Computed, Not Fresh)
    # C=false, W=any, F=any   -> F

    @testset "Zero Dependencies" begin
        props = SignalDependenciesProps()
        @test !is_pending(props) # Should be false as per current implementation
    end

    @testset "Single Dependency Exhaustive" begin
        # Format: (Computed, Fresh, Weak) -> Expected is_pending result
        test_cases = [
            # Passing states
            ((true, true, true), true),
            ((true, false, true), true), # Weak, Computed
            ((true, true, false), true), # Strong, Computed, Fresh
            # Failing states
            ((true, false, false), false), # Strong, Computed, NOT Fresh
            ((false, true, true), false),
            ((false, false, true), false),
            ((false, true, false), false),
            ((false, false, false), false)
        ]

        for (state_tuple, expected) in test_cases
            props = setup_props_with_states([state_tuple])
            @test is_pending(props) == expected
        end
    end

    @testset "Multiple Dependencies (e.g., 3)" begin
        pass_state = (true, true, true) # C=T, F=T, W=T (passes)
        fail_state_not_computed = (false, true, true) # C=F (fails)
        fail_state_strong_not_fresh = (true, false, false) # C=T, F=F, W=F (fails)

        # All pass
        props = setup_props_with_states([pass_state, pass_state, pass_state])
        @test is_pending(props)

        # One fails (not computed)
        props = setup_props_with_states([fail_state_not_computed, pass_state, pass_state])
        @test !is_pending(props)
        props = setup_props_with_states([pass_state, fail_state_not_computed, pass_state])
        @test !is_pending(props)
        props = setup_props_with_states([pass_state, pass_state, fail_state_not_computed])
        @test !is_pending(props)

        # One fails (strong, computed, but not fresh)
        props = setup_props_with_states([fail_state_strong_not_fresh, pass_state, pass_state])
        @test !is_pending(props)
        props = setup_props_with_states([pass_state, fail_state_strong_not_fresh, pass_state])
        @test !is_pending(props)
        props = setup_props_with_states([pass_state, pass_state, fail_state_strong_not_fresh])
        @test !is_pending(props)
    end

    @testset "Chunk Boundary Tests" begin
        pass_state = (true, true, true)
        fail_state = (false, false, false) # Fails due to not computed

        num_deps_to_test = [1, 15, 16, 17, 31, 32, 33, 63, 64, 65]

        for N in num_deps_to_test
            @testset "N = $N Dependencies" begin
                # All pass
                all_pass_states = [pass_state for _ in 1:N]
                props = setup_props_with_states(all_pass_states)
                @test is_pending(props)

                # Single failure at various positions
                if N > 0
                    fail_positions = unique([1, N > 1 ? div(N, 2) + 1 : 1, N])
                    for fail_idx in fail_positions
                        states = [pass_state for _ in 1:N]
                        states[fail_idx] = fail_state
                        props = setup_props_with_states(states)
                        @test !is_pending(props)
                    end
                end
            end
        end
    end
end

@testitem "Basic Signal Operations" begin
    import Cortex: Signal, set_value!, get_value

    # Create a signal with initial value
    s = Signal(42)
    @test get_value(s) == 42

    # Update signal value using set_value!
    set_value!(s, 100)
    @test get_value(s) == 100
end

@testitem "Signal Type and Metadata" begin
    import Cortex: Signal, get_type, get_metadata, UndefMetadata

    @testset "Default Values" begin
        s = Signal(42)
        @test get_type(s) === 0x00
        @test get_metadata(s) === UndefMetadata()
        s_empty = Signal()
        @test get_type(s_empty) === 0x00
        @test get_metadata(s_empty) === UndefMetadata()
    end

    @testset "Custom Type" begin
        s = Signal(42; type = 0x05)
        @test get_type(s) === 0x05
        @test get_metadata(s) === UndefMetadata()
    end

    @testset "Custom Metadata" begin
        meta = Dict("info" => "extra data")
        s = Signal(42; metadata = meta)
        @test get_type(s) === 0x00
        @test get_metadata(s) === meta
    end

    @testset "Custom Type and Metadata" begin
        meta = (:a, 1)
        s = Signal(42; type = 0xff, metadata = meta)
        @test get_type(s) === 0xff
        @test get_metadata(s) === meta
    end
end

@testitem "Empty Signal Creation" begin
    import Cortex:
        Signal,
        UndefValue,
        get_value,
        get_dependencies,
        get_listeners,
        get_type,
        get_metadata,
        UndefMetadata,
        is_pending,
        is_computed

    s = Signal()
    @test get_value(s) === UndefValue()
    @test get_type(s) === 0x00
    @test get_metadata(s) === UndefMetadata()
    @test isempty(get_dependencies(s))
    @test isempty(get_listeners(s))
    @test !is_pending(s)
    @test !is_computed(s)
end

@testitem "Signal Creation with Value Sets Computed" begin
    import Cortex: Signal, get_value, is_computed, is_pending

    s = Signal(10)
    @test get_value(s) == 10
    @test is_computed(s)
    @test !is_pending(s)
end

@testitem "Add Dependency Basic" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, set_value!

    sig_a = Signal(1)
    sig_b = Signal(2)

    @testset "Initial State" begin
        @test isempty(get_dependencies(sig_a))
        @test isempty(get_listeners(sig_a))
        @test isempty(get_dependencies(sig_b))
        @test isempty(get_listeners(sig_b))
        @test !is_pending(sig_a)
        @test !is_pending(sig_b)
    end

    @testset "Add Dependency (sig_a depends on sig_b)" begin
        add_dependency!(sig_a, sig_b)

        # Check dependencies/listeners
        @test get_dependencies(sig_a) == [sig_b]
        @test isempty(get_listeners(sig_a))
        @test isempty(get_dependencies(sig_b))
        @test get_listeners(sig_b) == [sig_a]

        # Check pending state (should not change yet)
        @test !is_pending(sig_a)
        @test !is_pending(sig_b)
    end

    @testset "Update Dependency (sig_b)" begin
        set_value!(sig_b, 3)

        # Check pending state (sig_a should become pending)
        @test is_pending(sig_a)
        @test !is_pending(sig_b)
    end
end

@testitem "Add Dependency (Initialized)" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, set_value!, is_computed

    s_dep = Signal(1) # Already computed dependency
    s = Signal()      # Uncomputed signal

    @test !is_pending(s)
    @test !is_computed(s)
    @test is_computed(s_dep)

    add_dependency!(s, s_dep)

    @test get_dependencies(s) == [s_dep]
    @test get_listeners(s_dep) == [s]

    # Adding a computed dependency should trigger check_and_set_pending!
    @test is_pending(s)
    @test !is_computed(s)
end

@testitem "Add Single Non-Initialized Weak Dependency" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, set_value!, is_computed

    s1 = Signal()
    s2 = Signal()

    add_dependency!(s2, s1; weak = true)

    @test get_dependencies(s2) == [s1]
    @test get_listeners(s1) == [s2]

    @test !is_pending(s2)
    @test !is_computed(s2)

    set_value!(s1, 10)

    @test is_pending(s2)
    @test !is_computed(s2)
end

@testitem "Add Single Initialized Weak Dependency" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, set_value!, is_computed

    s1 = Signal(1)
    s2 = Signal()

    add_dependency!(s2, s1; weak = true)

    @test get_dependencies(s2) == [s1]
    @test get_listeners(s1) == [s2]

    @test is_pending(s2) # Should be pending because `s1` is initialized and is weak
    @test !is_computed(s2)

    set_value!(s1, 10)

    @test is_pending(s2)
    @test !is_computed(s2)
end

@testitem "Add Single Initialized Dependency Without Checking if it is computed" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, set_value!, is_computed

    s1 = Signal(1)
    s2 = Signal()

    add_dependency!(s2, s1; check_computed = false)

    @test get_dependencies(s2) == [s1]
    @test get_listeners(s1) == [s2]

    @test !is_pending(s2) # Should not be pending because `s1` is initialized but we did not check if it is computed
    @test !is_computed(s2)

    set_value!(s1, 10)

    @test is_pending(s2)
    @test !is_computed(s2)
end

@testitem "Add Many Dependencies (All Strong)" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, set_value!, is_computed

    source1 = Signal()
    source2 = Signal()
    source3 = Signal()
    derived = Signal()

    @testset "Add Dependencies" begin
        add_dependency!(derived, source1)
        add_dependency!(derived, source2)
        add_dependency!(derived, source3)

        @test get_dependencies(derived) == [source1, source2, source3]
        @test get_listeners(source1) == [derived]
        @test get_listeners(source2) == [derived]
        @test get_listeners(source3) == [derived]
        @test !is_pending(derived)
        @test !is_computed(derived)
    end

    @testset "Update Dependencies Sequentially" begin
        set_value!(source1, 1)
        @test !is_pending(derived)
        @test is_computed(source1)

        set_value!(source2, 2)
        @test !is_pending(derived)
        @test is_computed(source2)

        set_value!(source3, 3)
        @test is_pending(derived)
        @test is_computed(source3)
        @test !is_computed(derived)
    end

    @testset "Set Derived Value" begin
        set_value!(derived, 10)
        @test !is_pending(derived)
        @test is_computed(derived)
    end
end

@testitem "Update Dependency Marks Signal as Pending" begin
    import Cortex: Signal, set_value!, add_dependency!, is_pending, is_computed

    @testset "Uninitialized signals (dependency added, then updated)" begin
        s1 = Signal()
        s2 = Signal()

        # Initial state
        @test !is_pending(s1) && !is_pending(s2)
        @test !is_computed(s1) && !is_computed(s2)

        # Add dependency
        add_dependency!(s1, s2)
        @test !is_pending(s1) && !is_pending(s2)
        @test !is_computed(s1) && !is_computed(s2)

        # Update dependency s2
        set_value!(s2, 3)
        @test is_pending(s1)
        @test !is_pending(s2)
        @test !is_computed(s1)
        @test is_computed(s2)
    end

    @testset "Initialized signals (dependency added, then updated)" begin
        s1 = Signal(1)
        s2 = Signal(2)

        # Initial state
        @test !is_pending(s1) && !is_pending(s2)
        @test is_computed(s1) && is_computed(s2)

        # Add dependency
        add_dependency!(s1, s2)
        @test !is_pending(s1) && !is_pending(s2)
        @test is_computed(s1) && is_computed(s2)

        # Update dependency s2
        set_value!(s2, 3)
        @test is_pending(s1)
        @test !is_pending(s2)
        @test is_computed(s1)
        @test is_computed(s2)
    end
end

@testitem "Weak Dependencies Basic" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, is_computed, set_value!

    weak_dep = Signal(1)
    strong_dep = Signal(2)
    derived = Signal()

    add_dependency!(derived, weak_dep; weak = true)
    add_dependency!(derived, strong_dep)

    @test get_dependencies(derived) == [weak_dep, strong_dep]
    @test get_listeners(weak_dep) == [derived]
    @test get_listeners(strong_dep) == [derived]

    @test is_pending(derived)
    @test !is_computed(derived)

    set_value!(derived, 10)
    @test !is_pending(derived)
    @test is_computed(derived)

    set_value!(strong_dep, 3)
    @test is_pending(derived)

    set_value!(derived, 11)
    @test !is_pending(derived)
    @test is_computed(derived)

    set_value!(weak_dep, 4)
    @test !is_pending(derived)

    set_value!(strong_dep, 5)
    @test is_pending(derived)
end

@testitem "Add Many Weak Dependencies" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, is_pending, is_computed, set_value!

    weak1 = Signal()
    weak2 = Signal()
    strong1 = Signal()
    derived = Signal()

    @testset "Setup Dependencies" begin
        add_dependency!(derived, weak1; weak = true)
        add_dependency!(derived, weak2; weak = true)
        add_dependency!(derived, strong1) # Strong

        @test get_dependencies(derived) == [weak1, weak2, strong1]
        @test get_listeners(weak1) == [derived]
        @test get_listeners(weak2) == [derived]
        @test get_listeners(strong1) == [derived]
        @test !is_pending(derived)
        @test !is_computed(derived)
        @test !is_computed(weak1) && !is_computed(weak2) && !is_computed(strong1)
    end

    @testset "Update Strong Dependency Only" begin
        # derived age = 0
        set_value!(strong1, 10)
        # Weak deps not computed -> derived should not be pending
        @test !is_pending(derived)
        @test !is_computed(derived)
    end

    @testset "Update One Weak Dependency" begin
        # strong1 is computed
        set_value!(weak1, 1)
        # Weak2 not computed -> derived should not be pending
        @test !is_pending(derived)
        @test !is_computed(derived)
    end

    @testset "Update Second Weak Dependency" begin
        # strong1, weak1 computed
        set_value!(weak2, 2)
        # All deps meet criteria -> derived should be pending
        @test is_pending(derived)
        @test !is_computed(derived)
    end

    @testset "Set Derived Value" begin
        set_value!(derived, 100)
        @test !is_pending(derived)
        @test is_computed(derived)
    end

    @testset "Update Strong Dependency Again" begin
        set_value!(strong1, 11)
        @test is_pending(derived)
    end

    @testset "Set Derived Value Again" begin
        set_value!(derived, 101)
        @test !is_pending(derived)
        @test is_computed(derived)
    end

    @testset "Update Weak 1 Dependency Again" begin
        set_value!(weak1, 3)
        @test !is_pending(derived)
    end

    @testset "Update Strong Dependency Again" begin
        set_value!(strong1, 333)
        @test is_pending(derived)
    end
end

@testitem "Edge Case: Duplicate Dependencies Are Allowed" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, set_value!, is_pending

    s1 = Signal()
    s2 = Signal()

    add_dependency!(s1, s2)
    add_dependency!(s1, s2) # Add the same dependency again

    @test get_dependencies(s1) == [s2, s2]
    @test get_listeners(s2) == [s1, s1]
    @test length(get_dependencies(s1)) == 2
    @test length(get_listeners(s2)) == 2

    @test !is_pending(s1)

    set_value!(s2, 1)

    @test is_pending(s1)
end

@testitem "Edge Case: Circular Dependencies" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, set_value!, is_pending, get_age

    s1 = Signal()
    s2 = Signal()

    @testset "Setup Circular Dependency" begin
        add_dependency!(s1, s2)
        add_dependency!(s2, s1)

        @test get_dependencies(s1) == [s2]
        @test get_listeners(s1) == [s2]
        @test get_dependencies(s2) == [s1]
        @test get_listeners(s2) == [s1]
        @test !is_pending(s1) && !is_pending(s2)
    end

    @testset "Set Value s1" begin
        set_value!(s1, 1)
        @test !is_pending(s1)
        @test is_pending(s2)
    end

    @testset "Set Value s2" begin
        set_value!(s2, 2)
        @test is_pending(s1)
        @test !is_pending(s2)
    end

    @testset "Set Value s2 Again" begin
        set_value!(s2, 3)
        @test is_pending(s1)
        @test !is_pending(s2)
    end

    @testset "Set Value s1 Again" begin
        set_value!(s1, 4)
        @test !is_pending(s1)
        @test is_pending(s2)
    end
end

@testitem "Edge Case: Self Dependency Does Nothing" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, set_value!, is_pending, get_age

    s1 = Signal()

    @testset "Setup Self Dependency" begin
        add_dependency!(s1, s1) # s1 depends on itself

        @test get_dependencies(s1) == []
        @test get_listeners(s1) == []
        @test !is_pending(s1)
    end
end

@testitem "Pending State Logic Coverage" begin
    import Cortex: Signal, add_dependency!, set_value!, is_pending, is_computed

    @testset "Case: Strong dep not computed" begin
        derived = Signal()
        strong_dep = Signal()
        add_dependency!(derived, strong_dep)

        @test !is_pending(derived)
        set_value!(derived, 1)
        @test !is_pending(derived)

        # Reset for clarity
        derived = Signal()
        strong_dep = Signal()
        add_dependency!(derived, strong_dep)
        @test !is_pending(derived)
        set_value!(strong_dep, 10)
        @test is_pending(derived)
    end

    @testset "Case: Weak dep not computed" begin
        derived = Signal()
        weak_dep = Signal()
        add_dependency!(derived, weak_dep; weak = true)

        @test !is_pending(derived)
        set_value!(derived, 1)
        @test !is_pending(derived)
        set_value!(weak_dep, 10)
        @test is_pending(derived)
    end

    @testset "Case: Strong dep computed but not older" begin
        derived = Signal(1)
        strong_dep = Signal(10)
        add_dependency!(derived, strong_dep)
        @test !is_pending(derived)

        set_value!(derived, 100)
        @test !is_pending(derived)

        set_value!(strong_dep, 101)
        @test is_pending(derived)

        set_value!(derived, 102)
        @test !is_pending(derived)

        set_value!(strong_dep, 103)
        @test is_pending(derived)
    end

    @testset "Case: All conditions met (Mixed)" begin
        derived = Signal() # age 0
        weak_dep = Signal() # age 0
        strong_dep = Signal() # age 0

        add_dependency!(derived, weak_dep; weak = true)
        add_dependency!(derived, strong_dep)

        @test !is_pending(derived)

        set_value!(weak_dep, 1)
        @test !is_pending(derived)

        set_value!(strong_dep, 2)
        @test is_pending(derived)
    end
end

@testitem "A Chain Of Signals" begin
    import Cortex: Signal, add_dependency!, get_value, set_value!, is_pending

    # Create a chain of signals
    s1 = Signal(1)
    s2 = Signal()
    s3 = Signal()

    add_dependency!(s2, s1)
    add_dependency!(s3, s2)

    @test !is_pending(s1)
    @test is_pending(s2) # since s1 is initialized
    @test !is_pending(s3)

    set_value!(s1, 2)
    @test !is_pending(s1)
    @test is_pending(s2)
    @test !is_pending(s3)

    set_value!(s2, 3)
    @test !is_pending(s1)
    @test !is_pending(s2)
    @test is_pending(s3)

    set_value!(s3, 4)
    @test !is_pending(s1)
    @test !is_pending(s2)
    @test !is_pending(s3)

    set_value!(s1, 5)
    @test !is_pending(s1)
    @test is_pending(s2)
    @test !is_pending(s3)

    set_value!(s2, 6)
    @test !is_pending(s1)
    @test !is_pending(s2)
    @test is_pending(s3)

    set_value!(s3, 7)
    @test !is_pending(s1)
    @test !is_pending(s2)
    @test !is_pending(s3)
end

@testitem "Not-Listening Dependency" begin
    import Cortex: Signal, add_dependency!, get_value, set_value!, is_pending

    @testset "Case: A single dependency non-weak dependency" begin
        s1 = Signal(1)
        s2 = Signal(2)

        # `s2` depends on `s1`, but it does not listen to updates   
        add_dependency!(s2, s1; listen = false)

        @test !is_pending(s2)

        set_value!(s1, 10)

        @test !is_pending(s2)
    end

    @testset "Case: A single dependency weak dependency" begin
        s1 = Signal(1)
        s2 = Signal(2)

        # `s2` depends on `s1`, but it does not listen to updates   
        add_dependency!(s2, s1; listen = false, weak = true)

        @test is_pending(s2) # `s2` is pending because it has only weak dependency, which is computed

        set_value!(s1, 10)

        @test is_pending(s2)
    end

    @testset "Case: A single dependency without checking if it is computed" begin
        s1 = Signal(1)
        s2 = Signal(2)

        # `s2` depends on `s1`, but it does not listen to updates   
        add_dependency!(s2, s1; listen = false, check_computed = false)

        # `s2` is not pending because it does not listen to updates from `s1`
        # AND it does not check if `s1` is computed
        @test !is_pending(s2)

        set_value!(s1, 10)

        @test !is_pending(s2)
    end

    @testset "Case: Multiple dependencies" begin
        s1 = Signal()
        s2 = Signal()
        s3 = Signal()

        add_dependency!(s3, s1; listen = false)
        add_dependency!(s3, s2)

        @test !is_pending(s3)

        set_value!(s2, 10)

        @test !is_pending(s3) # we set value to `s2`, but `s3` also requires `s1` to be set

        set_value!(s1, 10)

        @test !is_pending(s3) # we set value to `s1`, but `s3` does not listen to updates from `s1`

        set_value!(s2, 30)

        # we set value to `s2` and `s3` listens to updates from `s2`
        # in this case `s1` is also set, so `s3` should be pending
        @test is_pending(s3)
    end
end

@testitem "Edge Case: Adding a computed signal and then uncomputed should unset pending state" begin
    import Cortex: Signal, add_dependency!, set_value!, is_pending

    @testset "Case: check_computed = true" begin
        s1 = Signal(1)
        s2 = Signal()

        derived = Signal()

        add_dependency!(derived, s1)

        # Since s1 is computed, derived should be pending
        @test is_pending(derived)

        add_dependency!(derived, s2)

        # Since s2 is not computed, derived should not be pending
        @test !is_pending(derived)
    end

    @testset "Case: check_computed = false" begin
        s1 = Signal(1)
        s2 = Signal()

        derived = Signal()

        add_dependency!(derived, s1; check_computed = true)

        # Since s1 is computed, derived should be pending
        @test is_pending(derived)

        add_dependency!(derived, s2; check_computed = false)

        # Since s2 is not computed, but we don't check if it is computed,
        # derived should remain pending
        @test is_pending(derived)
    end
end

@testitem "Signal Representation" begin
    import Cortex: Signal, set_value!, add_dependency!, get_type, get_metadata, UndefMetadata

    @testset "Uninitialized Signal" begin
        s_no_meta = Signal()
        @test repr(s_no_meta) == "Signal(value=#undef, pending=false)"

        s_meta = Signal(metadata = :test)
        @test repr(s_meta) == "Signal(value=#undef, pending=false, metadata=:test)"

        s_type = Signal(type = 0x01)
        @test repr(s_type) == "Signal(value=#undef, pending=false, type=0x01)"

        s_both = Signal(type = 0xab, metadata = [1, 2])
        @test repr(s_both) == "Signal(value=#undef, pending=false, type=0xab, metadata=[1, 2])"
    end

    @testset "Initialized Signal" begin
        s_int = Signal(123)
        @test repr(s_int) == "Signal(value=123, pending=false)"

        s_str_meta = Signal("test"; metadata = "some info")
        @test repr(s_str_meta) == "Signal(value=\"test\", pending=false, metadata=\"some info\")"
    end

    @testset "Pending Signal" begin
        s1 = Signal(1)
        s_pending = Signal(type = 0x1f, metadata = ("meta", 1.0))
        add_dependency!(s_pending, s1)
        @test repr(s_pending) == "Signal(value=#undef, pending=true, type=0x1f, metadata=(\"meta\", 1.0))"

        set_value!(s_pending, 50)
        @test repr(s_pending) == "Signal(value=50, pending=false, type=0x1f, metadata=(\"meta\", 1.0))"

        set_value!(s1, 2)
        @test repr(s_pending) == "Signal(value=50, pending=true, type=0x1f, metadata=(\"meta\", 1.0))"
    end
end

@testitem "Signal JET Coverage" begin
    import Cortex: Signal, UndefMetadata
    import JET

    # Test default constructors
    JET.@test_opt Cortex.Signal()
    JET.@test_opt Cortex.Signal(1)
    JET.@test_opt Cortex.Signal("1")
    # Test constructors with keywords
    JET.@test_opt Cortex.Signal(type = 0x01)
    JET.@test_opt Cortex.Signal(metadata = :meta)
    JET.@test_opt Cortex.Signal(metadata = UndefMetadata())
    JET.@test_opt Cortex.Signal(1; type = 0x02, metadata = "meta")
    JET.@test_opt Cortex.Signal(1; metadata = UndefMetadata())

    # Test getters
    JET.@test_opt Cortex.is_pending(Cortex.Signal())
    JET.@test_opt Cortex.is_pending(Cortex.Signal(1))
    JET.@test_opt Cortex.is_pending(Cortex.Signal("1"))
    JET.@test_opt Cortex.is_computed(Cortex.Signal())
    JET.@test_opt Cortex.is_computed(Cortex.Signal(1))
    JET.@test_opt Cortex.is_computed(Cortex.Signal("1"))
    JET.@test_opt Cortex.get_value(Cortex.Signal())
    JET.@test_opt Cortex.get_value(Cortex.Signal(1))
    JET.@test_opt Cortex.get_value(Cortex.Signal("1"))
    JET.@test_opt Cortex.get_dependencies(Cortex.Signal())
    JET.@test_opt Cortex.get_dependencies(Cortex.Signal(1))
    JET.@test_opt Cortex.get_dependencies(Cortex.Signal("1"))
    JET.@test_opt Cortex.get_listeners(Cortex.Signal())
    JET.@test_opt Cortex.get_listeners(Cortex.Signal(1))
    JET.@test_opt Cortex.get_listeners(Cortex.Signal("1"))
    JET.@test_opt Cortex.set_value!(Cortex.Signal(), 1)
    JET.@test_opt Cortex.set_value!(Cortex.Signal(1), 1)
    JET.@test_opt Cortex.set_value!(Cortex.Signal("1"), 1)
    JET.@test_opt Cortex.set_value!(Cortex.Signal(1), "1")
    JET.@test_opt Cortex.add_dependency!(Cortex.Signal(1), Cortex.Signal(2))
    JET.@test_opt Cortex.add_dependency!(Cortex.Signal(1), Cortex.Signal(2); weak = true)
    JET.@test_opt Cortex.add_dependency!(Cortex.Signal(1), Cortex.Signal(2); check_computed = false)
    JET.@test_opt Cortex.add_dependency!(Cortex.Signal(1), Cortex.Signal(2); listen = false)
    JET.@test_opt Cortex.get_type(Cortex.Signal())
    JET.@test_opt Cortex.get_metadata(Cortex.Signal())
    JET.@test_opt Cortex.get_metadata(Cortex.Signal(metadata = 123))
    JET.@test_opt Cortex.add_dependency!(Cortex.Signal(1), Cortex.Signal(2); listen = false)
end

@testitem "A Signal Can Be Computed With A Lambda Function" begin
    import Cortex: Signal, compute!, add_dependency!, set_value!, get_value, is_pending, is_computed

    @testset "Basic Case" begin
        s1 = Signal(1)
        s2 = Signal(2)
        s3 = Signal()

        add_dependency!(s3, s1)
        add_dependency!(s3, s2)

        @test is_pending(s3)
        @test !is_computed(s3)

        strategy = (_, deps) -> sum(get_value, deps)

        compute!(strategy, s3)

        @test is_computed(s3)
        @test !is_pending(s3) # compute! should unset pending
        @test get_value(s3) == 3

        # s3 is no longer pending
        @test_throws ArgumentError compute!(strategy, s3) # Should throw error without force=true
        @test compute!(strategy, s3; force = true) === nothing # Should run with force=true
        @test get_value(s3) == 3 # Value remains the same as deps didn't change
        @test !is_pending(s3) # Still not pending

        set_value!(s1, 10)
        set_value!(s2, 20)
        @test is_pending(s3) # Now pending again

        compute!(strategy, s3)

        @test is_computed(s3)
        @test !is_pending(s3)
        @test get_value(s3) == 30
    end

    @testset "Pyramid of Signals" begin
        s01 = Signal(1)
        s02 = Signal(2)

        s11 = Signal(3)
        s12 = Signal(4)

        s21 = Signal()
        s22 = Signal()

        add_dependency!(s21, s01)
        add_dependency!(s21, s02)

        add_dependency!(s22, s11)
        add_dependency!(s22, s12)

        s3 = Signal()

        add_dependency!(s3, s21)
        add_dependency!(s3, s22)

        @test is_pending(s21)
        @test is_pending(s22)
        @test !is_computed(s21)
        @test !is_computed(s22)
        @test !is_pending(s3)
        @test !is_computed(s3)

        strategy = (_, deps) -> sum(get_value, deps)

        compute!(strategy, s21)
        compute!(strategy, s22)

        @test !is_pending(s21)
        @test !is_pending(s22)
        @test is_pending(s3) # s3 becomes pending after its deps are computed
        @test !is_computed(s3)

        compute!(strategy, s3)

        @test is_computed(s3)
        @test !is_pending(s3)
        @test get_value(s3) == (1 + 2) + (3 + 4) # 3 + 7 = 10
    end
end

@testitem "It is possible to add intermediate dependencies" begin
    import Cortex: Signal, add_dependency!, get_dependencies

    source = Signal()
    intermediate = Signal()
    derived = Signal()

    add_dependency!(intermediate, source)
    add_dependency!(derived, intermediate; intermediate = true)

    @test get_dependencies(derived) == [intermediate]
    @test get_dependencies(intermediate) == [source]
end

@testitem "`process_dependencies!` function should step down recursively for intermediate dependencies" begin
    import Cortex: Signal, add_dependency!, process_dependencies!

    source = Signal()
    intermediate = Signal()
    derived = Signal()

    add_dependency!(intermediate, source)
    add_dependency!(derived, intermediate; intermediate = true)

    @testset "Case: retry = false, callback returns false" begin
        attempted_to_process = []

        at_least_one_dependency_processed = process_dependencies!(derived; retry = false) do dependency
            push!(attempted_to_process, dependency)
            return false
        end

        @test length(attempted_to_process) == 2
        @test attempted_to_process[1] == intermediate
        @test attempted_to_process[2] == source
        # `process_dependencies!` should return false because no dependency was processed
        # since the callback returned false for all dependencies
        @test !at_least_one_dependency_processed
    end

    @testset "Case: retry = true, callback returns false" begin
        attempted_to_process = []

        at_least_one_dependency_processed = process_dependencies!(derived; retry = true) do dependency
            push!(attempted_to_process, dependency)
            return false
        end

        @test length(attempted_to_process) == 2
        @test attempted_to_process[1] == intermediate
        @test attempted_to_process[2] == source
        # `process_dependencies!` should return false because no dependency was processed
        # since the callback returned false for all dependencies
        @test !at_least_one_dependency_processed
    end

    @testset "Case: retry = false, callback returns true" begin
        attempted_to_process = []

        at_least_one_dependency_processed = process_dependencies!(derived; retry = false) do dependency
            push!(attempted_to_process, dependency)
            return true
        end

        @test length(attempted_to_process) == 1
        @test attempted_to_process[1] == intermediate
        @test at_least_one_dependency_processed
    end

    @testset "Case: retry = true, callback returns true" begin
        attempted_to_process = []

        at_least_one_dependency_processed = process_dependencies!(derived; retry = true) do dependency
            push!(attempted_to_process, dependency)
            return true
        end

        @test length(attempted_to_process) == 1
        @test attempted_to_process[1] == intermediate
        @test at_least_one_dependency_processed
    end

    @testset "Case: retry = false, callback returns false for `intermediate` and true for `source`" begin
        attempted_to_process = []

        at_least_one_dependency_processed = process_dependencies!(derived; retry = false) do dependency
            push!(attempted_to_process, dependency)
            return dependency === intermediate ? false : true
        end

        @test length(attempted_to_process) == 2
        @test attempted_to_process[1] == intermediate
        @test attempted_to_process[2] == source
        @test at_least_one_dependency_processed
    end

    @testset "Case: retry = true, callback returns false for `intermediate` and true for `source`" begin
        attempted_to_process = []

        at_least_one_dependency_processed = process_dependencies!(derived; retry = true) do dependency
            push!(attempted_to_process, dependency)
            return dependency === intermediate ? false : true
        end

        @test length(attempted_to_process) == 3
        @test attempted_to_process[1] == intermediate
        @test attempted_to_process[2] == source
        @test attempted_to_process[3] == intermediate # should retry on intermediate
        @test at_least_one_dependency_processed
    end
end

@testitem "`process_dependencies!` function should NOT step down recursively for non-intermediate dependencies" begin
    import Cortex: Signal, add_dependency!, process_dependencies!

    source = Signal()
    not_intermediate = Signal()
    derived = Signal()

    add_dependency!(not_intermediate, source)
    add_dependency!(derived, not_intermediate)

    @testset for retry in [false, true]
        @testset for callback_returns in [false, true]
            attempted_to_process = []

            at_least_one_dependency_processed = process_dependencies!(derived; retry = retry) do dependency
                push!(attempted_to_process, dependency)
                return callback_returns
            end

            @test length(attempted_to_process) == 1
            @test attempted_to_process[1] == not_intermediate
            if callback_returns === true
                @test at_least_one_dependency_processed
            else
                @test !at_least_one_dependency_processed
            end
        end
    end
end

@testitem "`process_dependencies!` should return true if at least one dependency was processed" begin
    import Cortex: Signal, add_dependency!, process_dependencies!

    source = Signal()
    intermediate = Signal()
    derived = Signal()

    add_dependency!(intermediate, source)
    add_dependency!(derived, intermediate; intermediate = true)

    @testset for retry in [false, true]
        attempted_to_process = []

        at_least_one_dependency_processed = process_dependencies!(derived; retry = retry) do dependency
            push!(attempted_to_process, dependency)
            return dependency === source
        end

        @test length(attempted_to_process) >= 1
        @test at_least_one_dependency_processed
    end
end

@testitem "`process_dependencies!` should be type-stable" begin
    import Cortex: Signal, add_dependency!, process_dependencies!
    import JET

    source = Signal()
    intermediate = Signal()
    derived = Signal()

    add_dependency!(intermediate, source)
    add_dependency!(derived, intermediate; intermediate = true)

    JET.@test_opt process_dependencies!(derived; retry = true) do dependency
        return dependency === source
    end

    JET.@test_opt process_dependencies!(derived; retry = true) do dependency
        return true
    end

    JET.@test_opt process_dependencies!(derived; retry = true) do dependency
        return false
    end

    JET.@test_opt process_dependencies!(derived; retry = false) do dependency
        return true
    end

    JET.@test_opt process_dependencies!(derived; retry = false) do dependency
        return false
    end
end
