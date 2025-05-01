@testitem "Basic Signal Operations" begin
    import Cortex: Signal, set_value!, get_value

    # Create a signal with initial value
    s = Signal(42)
    @test get_value(s) == 42

    # Update signal value using set_value!
    set_value!(s, 100)
    @test get_value(s) == 100
end

@testitem "A Signal Can Have A Label" begin
    import Cortex: Signal, get_label, UndefLabel

    @testset let s = Signal(42)
        @test get_label(s) === UndefLabel()
    end

    @testset let s = Signal(42; label = :message)
        @test get_label(s) == :message
    end

    struct ArbitraryLabel
        val::Int
    end

    @testset let s = Signal(42; label = ArbitraryLabel(1))
        @test get_label(s) isa ArbitraryLabel
        @test get_label(s).val == 1
    end

    @testset let s = Signal(42; label = "message")
        @test get_label(s) == "message"
    end
end

@testitem "Setting Value Updates Age" begin
    import Cortex: Signal, set_value!, get_age

    @testset "Initialized Signal" begin
        s = Signal(42)
        initial_age = get_age(s)
        @test initial_age == 1 # Test constructor assignment

        set_value!(s, 100)
        age_after_first_set = get_age(s)
        @test age_after_first_set > initial_age

        set_value!(s, 200)
        age_after_second_set = get_age(s)
        @test age_after_second_set > age_after_first_set
    end

    @testset "Empty Signal" begin
        s = Signal()
        initial_age = get_age(s)
        @test initial_age == 0 # Test constructor assignment

        set_value!(s, 100)
        age_after_first_set = get_age(s)
        @test age_after_first_set > initial_age

        set_value!(s, 200)
        age_after_second_set = get_age(s)
        @test age_after_second_set > age_after_first_set
    end
end

@testitem "Empty Signal Creation" begin
    import Cortex: Signal, UndefValue, get_value, get_age, get_dependencies, get_listeners

    s = Signal()
    @test get_value(s) === UndefValue()
    @test get_age(s) == 0 # Test constructor assignment
    @test isempty(get_dependencies(s))
    @test isempty(get_listeners(s))
end

@testitem "Signal Creation with Value Sets Age" begin
    import Cortex: Signal, get_value, get_age

    s = Signal(10)
    @test get_value(s) == 10
    @test get_age(s) == 1 # Test constructor assignment
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

@testitem "Setting Value Updates Dependent Age" begin
    import Cortex: Signal, set_value!, get_age, add_dependency!, is_computed, is_pending

    @testset "Simple Case (Uninitialized)" begin
        s1 = Signal()
        s2 = Signal()
        add_dependency!(s1, s2)
        age_s1_initial = get_age(s1)
        age_s2_initial = get_age(s2)
        @test age_s1_initial == age_s2_initial # Should both be 0 initially

        set_value!(s2, 3)
        age_s1_after_s2_set = get_age(s1)
        age_s2_after_s2_set = get_age(s2)
        @test age_s1_after_s2_set == age_s1_initial # s1 age unchanged
        @test age_s2_after_s2_set > age_s2_initial # s2 age increased

        set_value!(s1, 4)
        age_s1_after_s1_set = get_age(s1)
        age_s2_after_s1_set = get_age(s2)
        @test age_s1_after_s1_set > age_s2_after_s2_set # s1 should now be older than s2
        @test age_s2_after_s1_set == age_s2_after_s2_set # s2 age unchanged
    end

    @testset "Simple Case (Initialized)" begin
        s1 = Signal(10)
        s2 = Signal(20)
        add_dependency!(s1, s2)
        age_s1_initial = get_age(s1)
        age_s2_initial = get_age(s2)
        @test age_s1_initial == age_s2_initial # Should both be 1 initially

        set_value!(s2, 30)
        age_s1_after_s2_set = get_age(s1)
        age_s2_after_s2_set = get_age(s2)
        @test age_s2_after_s2_set > age_s1_after_s2_set # s2 age increased and should be greater
        @test age_s1_after_s2_set == age_s1_initial # s1 age unchanged

        set_value!(s1, 40)
        age_s1_after_s1_set = get_age(s1)
        age_s2_after_s1_set = get_age(s2)
        @test age_s1_after_s1_set > age_s2_after_s1_set # s1 should now be older than s2
        @test age_s2_after_s1_set == age_s2_after_s2_set # s2 age unchanged
    end

    @testset "Multiple Intermediate Updates" begin
        s1 = Signal()
        s2 = Signal()
        add_dependency!(s1, s2)
        age_s1_initial = get_age(s1)
        age_s2_initial = get_age(s2)

        set_value!(s2, 3)
        age_s2_after_first_set = get_age(s2)
        @test age_s2_after_first_set > age_s1_initial # s2 older than initial s1
        @test is_computed(s2)

        set_value!(s2, 4)
        age_s2_after_second_set = get_age(s2)
        @test age_s2_after_second_set > age_s2_after_first_set # s2 age increased again
        @test age_s2_after_second_set > get_age(s1) # s2 should still be older than s1 (which hasn't been set)
        @test is_pending(s1)
        @test !is_computed(s1)

        set_value!(s1, 5)
        age_s1_after_set = get_age(s1)
        @test age_s1_after_set > age_s2_after_second_set # s1 should now be older than s2
        @test !is_pending(s1)
        @test is_computed(s1)
    end
end

@testitem "Weak Dependencies Basic" begin
    import Cortex:
        Signal, add_dependency!, get_dependencies, get_listeners, is_pending, is_computed, set_value!, get_age

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
    derived_age_after_set = get_age(derived)
    weak_dep_age_before_update = get_age(weak_dep)
    strong_dep_age_before_update = get_age(strong_dep)

    set_value!(strong_dep, 3)
    strong_dep_age_after_update = get_age(strong_dep)
    @test is_pending(derived)
    @test strong_dep_age_after_update > strong_dep_age_before_update
    # Test that strong_dep is now older than derived was before this update
    @test strong_dep_age_after_update > derived_age_after_set

    set_value!(derived, 11)
    @test !is_pending(derived)
    @test is_computed(derived)
    derived_age_after_second_set = get_age(derived)
    weak_dep_age_before_update_2 = get_age(weak_dep)
    strong_dep_age_before_update_2 = get_age(strong_dep)

    set_value!(weak_dep, 4)
    @test !is_pending(derived) # Updating weak dep shouldn't make it pending if strong dep is older
    @test get_age(weak_dep) > weak_dep_age_before_update_2

    set_value!(strong_dep, 5)
    strong_dep_age_after_update_2 = get_age(strong_dep)
    @test is_pending(derived)
    @test strong_dep_age_after_update_2 > strong_dep_age_before_update_2
    # Test that strong_dep is now older than derived was before this update
    @test strong_dep_age_after_update_2 > derived_age_after_second_set
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
        # All deps computed
        age_strong1_before = get_age(strong1)
        age_weak1_before = get_age(weak1)
        age_weak2_before = get_age(weak2)
        set_value!(derived, 100)
        @test !is_pending(derived)
        @test is_computed(derived)
        derived_age_after_set = get_age(derived)
        # Derived age should be greater than all dependencies' ages before it was set
        @test derived_age_after_set > age_strong1_before
        @test derived_age_after_set > age_weak1_before
        @test derived_age_after_set > age_weak2_before
    end

    @testset "Update Strong Dependency Again" begin
        derived_age_before_strong_update = get_age(derived)
        age_strong1_before_update = get_age(strong1)
        set_value!(strong1, 11)
        age_strong1_after_update = get_age(strong1)
        # Strong dep updated and is older -> derived should be pending
        @test is_pending(derived)
        @test age_strong1_after_update > age_strong1_before_update
        # Check if strong dep is older than derived *was* before this update
        @test age_strong1_after_update > derived_age_before_strong_update
    end

    @testset "Set Derived Value Again" begin
        age_strong1_before = get_age(strong1)
        age_weak1_before = get_age(weak1)
        age_weak2_before = get_age(weak2)
        set_value!(derived, 101)
        @test !is_pending(derived)
        @test is_computed(derived)
        derived_age_after_second_set = get_age(derived)
        # Derived age should be greater than all dependencies' ages before it was set
        @test derived_age_after_second_set > age_strong1_before
        @test derived_age_after_second_set > age_weak1_before
        @test derived_age_after_second_set > age_weak2_before
    end

    @testset "Update Weak Dependency Again" begin
        age_strong1 = get_age(strong1)
        derived_age = get_age(derived)
        age_weak1_before_update = get_age(weak1)
        set_value!(weak1, 3)
        age_weak1_after_update = get_age(weak1)
        # Weak dep updated, but strong dep might not be older than derived -> derived should NOT be pending
        # Check based on derived_age and age_strong1 captured before weak update.
        if age_strong1 > derived_age
            @test is_pending(derived) # Should be pending if strong was already older
        else
            @test !is_pending(derived) # Should not be pending if strong was not older
        end
        @test age_weak1_after_update > age_weak1_before_update
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
        @test get_age(derived) == get_age(strong_dep)

        age_derived_before_set = get_age(derived)
        set_value!(derived, 100)
        @test !is_pending(derived)
        @test get_age(derived) > age_derived_before_set

        age_derived_before_notify = get_age(derived)
        age_strong_before_notify = get_age(strong_dep)
        set_value!(strong_dep, 101)
        @test is_pending(derived) # Should be pending as strong_dep age increases and becomes > age_derived_before_notify
        @test get_age(strong_dep) > age_strong_before_notify

        age_strong_before_set = get_age(strong_dep)
        set_value!(derived, 102)
        @test !is_pending(derived)
        @test get_age(derived) > age_strong_before_set # Derived should now be older than strong was
        age_derived_now = get_age(derived)
        age_strong_now = get_age(strong_dep)

        age_strong_before_update = get_age(strong_dep)
        set_value!(strong_dep, 103)
        # Derived should become pending again if the updated strong_dep is older than derived *was* before the update
        @test is_pending(derived)
        @test get_age(strong_dep) > age_strong_before_update
        @test get_age(strong_dep) > age_derived_now # Check the final relationship
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

@testitem "Signal Representation" begin
    import Cortex: Signal, set_value!, add_dependency!

    @testset "Uninitialized Signal" begin
        s = Signal()
        @test repr(s) == "Signal(value=#undef, pending=false)"
    end

    @testset "Initialized Signal" begin
        s_int = Signal(123)
        @test repr(s_int) == "Signal(value=123, pending=false)"

        s_str = Signal("test")
        @test repr(s_str) == "Signal(value=\"test\", pending=false)" # Check quoting
    end

    @testset "Pending Signal" begin
        s1 = Signal(1)
        s_pending = Signal()
        add_dependency!(s_pending, s1)
        # s_pending becomes pending immediately because s1 is computed
        @test repr(s_pending) == "Signal(value=#undef, pending=true)"

        # Set value, pending should become false
        set_value!(s_pending, 50)
        @test repr(s_pending) == "Signal(value=50, pending=false)"

        # Update dependency, pending should become true again
        set_value!(s1, 2)
        @test repr(s_pending) == "Signal(value=50, pending=true)"
    end
end

@testitem "Signal JET Coverage" begin
    import Cortex: Signal
    import JET

    JET.@test_opt Cortex.Signal()
    JET.@test_opt Cortex.Signal(1)
    JET.@test_opt Cortex.Signal("1")
    JET.@test_opt Cortex.is_pending(Cortex.Signal())
    JET.@test_opt Cortex.is_pending(Cortex.Signal(1))
    JET.@test_opt Cortex.is_pending(Cortex.Signal("1"))
    JET.@test_opt Cortex.is_computed(Cortex.Signal())
    JET.@test_opt Cortex.is_computed(Cortex.Signal(1))
    JET.@test_opt Cortex.is_computed(Cortex.Signal("1"))
    JET.@test_opt Cortex.get_age(Cortex.Signal())
    JET.@test_opt Cortex.get_age(Cortex.Signal(1))
    JET.@test_opt Cortex.get_age(Cortex.Signal("1"))
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

        strategy = (deps) -> sum(get_value, deps)

        compute!(strategy, s3)

        @test is_computed(s3)
        @test get_value(s3) == 3

        set_value!(s1, 10)
        set_value!(s2, 20)

        compute!(strategy, s3)

        @test is_computed(s3)
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

        strategy = (deps) -> sum(get_value, deps)

        compute!(strategy, s21)
        compute!(strategy, s22)

        @test is_pending(s3)
        @test !is_computed(s3)

        compute!(strategy, s3)

        @test is_computed(s3)
        @test get_value(s3) == 10
    end
end