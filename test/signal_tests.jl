@testitem "Basic Signal Operations" begin
    import Cortex: Signal, set_value!, get_value

    # Create a signal with initial value
    s = Signal(42)
    @test get_value(s) == 42

    # Update signal value using set_value!
    set_value!(s, 100)
    @test get_value(s) == 100
end

@testitem "Setting Value Updates Age" begin
    import Cortex: Signal, set_value!, get_age

    @testset "Initialized Signal" begin
        s = Signal(42)
        initial_age = get_age(s)
        @test initial_age == 1

        set_value!(s, 100)
        @test get_age(s) > initial_age
        age_after_first_set = get_age(s)

        set_value!(s, 200)
        @test get_age(s) > age_after_first_set
    end

    @testset "Empty Signal" begin
        s = Signal()
        initial_age = get_age(s)
        @test initial_age == 0

        set_value!(s, 100)
        @test get_age(s) > initial_age
        age_after_first_set = get_age(s)

        set_value!(s, 200)
        @test get_age(s) > age_after_first_set
    end
end

@testitem "Empty Signal Creation" begin
    import Cortex: Signal, UndefValue, get_value, get_age, get_dependencies, get_listeners

    s = Signal()
    @test get_value(s) === UndefValue()
    @test get_age(s) == 0
    @test isempty(get_dependencies(s))
    @test isempty(get_listeners(s))
end

@testitem "Signal Creation with Value Sets Age" begin
    import Cortex: Signal, get_value, get_age

    s = Signal(10)
    @test get_value(s) == 10
    @test get_age(s) == 1
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

@testitem "Setting Value Updates Dependent Age" begin
    import Cortex: Signal, set_value!, get_age, add_dependency!, is_computed, is_pending

    @testset "Simple Case (Uninitialized)" begin
        s1 = Signal()
        s2 = Signal()
        add_dependency!(s1, s2)

        @test get_age(s1) == 0 && get_age(s2) == 0

        set_value!(s2, 3)
        @test get_age(s1) == 0
        @test get_age(s2) > 0

        set_value!(s1, 4)
        @test get_age(s1) > get_age(s2)
        @test get_age(s2) > 0
    end

    @testset "Simple Case (Initialized)" begin
        s1 = Signal(10) # age 1
        s2 = Signal(20) # age 1
        add_dependency!(s1, s2)

        @test get_age(s1) == get_age(s2)

        set_value!(s2, 30)
        @test get_age(s2) > get_age(s1)

        set_value!(s1, 40)
        @test get_age(s1) > get_age(s2)
    end

    @testset "Multiple Intermediate Updates" begin
        s1 = Signal() # age 0
        s2 = Signal() # age 0
        add_dependency!(s1, s2)

        set_value!(s2, 3)
        @test get_age(s2) > get_age(s1)
        @test is_computed(s2)

        set_value!(s2, 4)
        @test get_age(s2) > get_age(s1)
        @test is_pending(s1)
        @test !is_computed(s1)

        set_value!(s1, 5)
        @test get_age(s1) > get_age(s2)
        @test !is_pending(s1)
        @test is_computed(s1)
    end
end

@testitem "Weak Dependencies Basic" begin
    import Cortex:
        Signal, add_dependency!, get_dependencies, get_listeners, is_pending, is_computed, set_value!, get_age

    weak_dep = Signal(1)   # Computed
    strong_dep = Signal(2) # Computed
    derived = Signal()     # Not computed

    add_dependency!(derived, weak_dep; weak = true)
    add_dependency!(derived, strong_dep) # Strong is default

    @test get_dependencies(derived) == [weak_dep, strong_dep]
    @test get_listeners(weak_dep) == [derived]
    @test get_listeners(strong_dep) == [derived]

    @test is_pending(derived)
    @test !is_computed(derived)

    set_value!(derived, 10)
    @test !is_pending(derived)
    @test is_computed(derived)
    derived_age_after_set = get_age(derived)

    set_value!(strong_dep, 3)

    @test is_pending(derived)
    @test get_age(strong_dep) > derived_age_after_set

    set_value!(derived, 11)
    @test !is_pending(derived)
    @test is_computed(derived)
    derived_age_after_second_set = get_age(derived)

    set_value!(weak_dep, 4)
    @test !is_pending(derived)

    set_value!(strong_dep, 5)
    @test is_pending(derived)
    @test get_age(strong_dep) > derived_age_after_second_set
end

@testitem "Add Many Weak Dependencies" begin
    import Cortex:
        Signal, add_dependency!, get_dependencies, get_listeners, is_pending, is_computed, set_value!, get_age

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
        set_value!(strong1, 10) # strong1 age -> 2
        # check_and_set_pending!(strong1, derived) called
        # weak1: is_weak=true, is_computed=false -> false
        # Conditions fail -> derived should not be pending
        @test !is_pending(derived)
        @test !is_computed(derived)
    end

    @testset "Update One Weak Dependency" begin
        # derived age = 0, strong1 age = 2
        set_value!(weak1, 1) # weak1 age -> 2
        # check_and_set_pending!(weak1, derived) called
        # weak1: is_weak=true, is_computed=true -> true
        # weak2: is_weak=true, is_computed=false -> false
        # Conditions fail -> derived should not be pending
        @test !is_pending(derived)
        @test !is_computed(derived)
    end

    @testset "Update Second Weak Dependency" begin
        # derived age = 0, strong1 age = 2, weak1 age = 2
        set_value!(weak2, 2) # weak2 age -> 2
        # check_and_set_pending!(weak2, derived) called
        # weak1: is_weak=true, is_computed=true -> true
        # weak2: is_weak=true, is_computed=true -> true
        # strong1: is_weak=false, age=2 > derived_age=0 -> true
        # All conditions met -> derived should be pending
        @test is_pending(derived)
        @test !is_computed(derived)
    end

    @testset "Set Derived Value" begin
        # derived age = 0, strong1 age = 2, weak1 age = 2, weak2 age = 2
        set_value!(derived, 100) # derived age -> max(2, 2, 2) + 1 = 3
        @test !is_pending(derived)
        @test is_computed(derived)
        derived_age_after_set = get_age(derived) # 3
    end

    @testset "Update Strong Dependency Again" begin
        # derived age = 3, strong1 age = 2, weak1 age = 2, weak2 age = 2
        set_value!(strong1, 11) # strong1 age -> 2 + 2 = 4
        # check_and_set_pending!(strong1, derived) called
        # weak1: is_weak=true, is_computed=true -> true
        # weak2: is_weak=true, is_computed=true -> true
        # strong1: is_weak=false, age=4 > derived_age=3 -> true
        # All conditions met -> derived should be pending
        @test is_pending(derived)
    end

    @testset "Set Derived Value Again" begin
        # derived age = 3, strong1 age = 4, weak1 age = 2, weak2 age = 2
        set_value!(derived, 101) # derived age -> max(2, 2, 4) + 1 = 5
        @test !is_pending(derived)
        @test is_computed(derived)
        derived_age_after_second_set = get_age(derived) # 5
    end

    @testset "Update Weak Dependency Again" begin
        # derived age = 5, strong1 age = 4, weak1 age = 2, weak2 age = 2
        set_value!(weak1, 3) # weak1 age -> 2 + 2 = 4
        # check_and_set_pending!(weak1, derived) called
        # weak1: is_weak=true, is_computed=true -> true
        # weak2: is_weak=true, is_computed=true -> true
        # strong1: is_weak=false, age=4 > derived_age=5 -> false
        # Conditions fail -> derived should NOT be pending
        @test !is_pending(derived)
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
    import Cortex: Signal, add_dependency!, set_value!, is_pending, is_computed, get_age

    @testset "Case: Strong dep not computed" begin
        derived = Signal()
        strong_dep = Signal()
        add_dependency!(derived, strong_dep)

        # Call check_and_set_pending explicitly or via trigger
        # Here, add_dependency! calls it, but strong_dep is not computed, so nothing happens
        @test !is_pending(derived)

        # Trigger check again after derived is computed (age > 0)
        set_value!(derived, 1) # derived age = 2
        @test !is_pending(derived)
        # Manually calling check (pretend strong_dep notified derived)
        Cortex.check_and_set_pending!(strong_dep, derived)
        # strong_dep: is_weak=false, is_computed=false -> check returns false
        @test !is_pending(derived)
    end

    @testset "Case: Weak dep not computed" begin
        derived = Signal()
        weak_dep = Signal()
        add_dependency!(derived, weak_dep; weak = true)

        @test !is_pending(derived)

        # Trigger check again after derived is computed
        set_value!(derived, 1) # derived age = 2
        @test !is_pending(derived)
        Cortex.check_and_set_pending!(weak_dep, derived)
        # weak_dep: is_weak=true, is_computed=false -> check returns false
        @test !is_pending(derived)
    end

    @testset "Case: Strong dep computed but not older" begin
        derived = Signal(1) # age 1
        strong_dep = Signal(10) # age 1
        add_dependency!(derived, strong_dep) # derived is NOT set pending here

        @test !is_pending(derived)
        @test get_age(derived) == 1
        @test get_age(strong_dep) == 1

        # Manually trigger check (e.g., if strong_dep was set to same age somehow)
        Cortex.check_and_set_pending!(strong_dep, derived)
        # strong_dep: is_weak=false, is_computed=true, age=1 > derived_age=1 -> false
        @test !is_pending(derived)

        # Make ages equal via set_value!
        set_value!(derived, 100) # derived age -> max(1)+1 = 2
        set_value!(strong_dep, 101) # strong_dep age -> 1+2 = 3
        # Now strong_dep is older, derived should be pending
        @test is_pending(derived)

        # Set derived again
        set_value!(derived, 102) # derived age -> max(3)+1 = 4
        @test !is_pending(derived)
        @test get_age(derived) == 4
        @test get_age(strong_dep) == 3

        # Manually trigger check again
        Cortex.check_and_set_pending!(strong_dep, derived)
        # strong_dep: is_weak=false, is_computed=true, age=3 > derived_age=4 -> false
        @test !is_pending(derived)
    end

    @testset "Case: All conditions met (Mixed)" begin
        derived = Signal() # age 0
        weak_dep = Signal() # age 0
        strong_dep = Signal() # age 0

        add_dependency!(derived, weak_dep; weak = true)
        add_dependency!(derived, strong_dep)

        @test !is_pending(derived)

        set_value!(weak_dep, 1) # weak age = 2
        # check for derived: weak=computed, strong=not computed -> no pending
        @test !is_pending(derived)

        set_value!(strong_dep, 2) # strong age = 2
        # check for derived: weak=computed, strong age=2 > derived age=0 -> pending!
        @test is_pending(derived)
    end
end

# Ensure previous tests still exist below if not refactored above
# ... (rest of the original tests if any were not touched) ...
# Note: I have integrated and refactored all provided tests into the sections above.
