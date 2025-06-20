@testitem "Basic Signal Operations" begin
    import Cortex: Signal, set_value!, get_value

    # Create a signal with initial value
    s = Signal(42)
    @test get_value(s) == 42

    # Update signal value using set_value!
    set_value!(s, 100)
    @test get_value(s) == 100

    # Create a signal with a custom value type
    s = Signal(Int, Int, 42, 1)
    @test get_value(s) == 42

    set_value!(s, 100)
    @test get_value(s) == 100

    @test_throws Exception set_value!(s, "100")
    @test_throws Exception set_value!(s, 100.1)
end

@testitem "Signal Variant" begin
    import Cortex: Signal, get_value, get_variant, set_variant!, UndefVariant, isa_variant

    @testset "Default Values" begin
        s = Signal(42)
        @test get_variant(s) === UndefVariant()
        s_empty = Signal()
        @test get_variant(s_empty) === UndefVariant()

        set_variant!(s, 1)
        @test get_variant(s) === 1
        @test isa_variant(s, Int)
        @test !isa_variant(s, String)

        set_variant!(s, "2")
        @test get_variant(s) === "2"
        @test isa_variant(s, String)
        @test !isa_variant(s, Int)
    end

    @testset "Custom Variant" begin
        s = Signal(42; variant = 1)
        @test get_variant(s) === 1

        set_variant!(s, 2)
        @test get_variant(s) === 2

        set_variant!(s, "3")
        @test get_variant(s) === "3"
    end

    @testset "Custom Variant with a Specified Type" begin
        s = Signal(Int, Int, 42, 1)
        @test get_variant(s) === 1
        @test get_value(s) === 42
        @test isa_variant(s, Int)
        @test !isa_variant(s, String)

        set_variant!(s, 2)
        @test get_variant(s) === 2

        @test_throws Exception set_variant!(s, "1")
        @test_throws Exception set_variant!(s, 1.1)
    end
end

@testitem "Empty Signal Creation" begin
    import Cortex:
        Signal,
        UndefValue,
        UndefVariant,
        get_value,
        get_dependencies,
        get_listeners,
        get_variant,
        is_pending,
        is_computed

    s = Signal()
    @test get_value(s) === UndefValue()
    @test get_variant(s) === UndefVariant()
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

@testitem "Add Dependency of Different Variant" begin
    import Cortex: Signal, add_dependency!

    sig_a = Signal(Int, Int, 1, 1)
    sig_b = Signal(Int, String, 2, "2")

    @test_throws Exception add_dependency!(sig_a, sig_b)
    @test_throws Exception add_dependency!(sig_a, sig_b; weak = true)
    @test_throws Exception add_dependency!(sig_a, sig_b; weak = false)
    @test_throws Exception add_dependency!(sig_a, sig_b; listen = true)
    @test_throws Exception add_dependency!(sig_a, sig_b; listen = false)
    @test_throws Exception add_dependency!(sig_a, sig_b; check_computed = false)
    @test_throws Exception add_dependency!(sig_a, sig_b; check_computed = true)
    @test_throws Exception add_dependency!(sig_a, sig_b; intermediate = true)
    @test_throws Exception add_dependency!(sig_a, sig_b; intermediate = false)

    @test_throws Exception add_dependency!(sig_b, sig_a)
    @test_throws Exception add_dependency!(sig_b, sig_a; weak = true)
    @test_throws Exception add_dependency!(sig_b, sig_a; weak = false)
    @test_throws Exception add_dependency!(sig_b, sig_a; listen = true)
    @test_throws Exception add_dependency!(sig_b, sig_a; listen = false)
    @test_throws Exception add_dependency!(sig_b, sig_a; check_computed = false)
    @test_throws Exception add_dependency!(sig_b, sig_a; check_computed = true)
    @test_throws Exception add_dependency!(sig_b, sig_a; intermediate = true)
    @test_throws Exception add_dependency!(sig_b, sig_a; intermediate = false)
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

@testitem "Edge Case: Duplicate Dependencies Are Not Allowed - Leads to Weird Behaviour" begin
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

    # We expect the signal to not be pending because the second duplicate dependency was not notified
    # this is not ideal, but it allows to short circuit when notifiying the listeners
    # this means that the second duplicate dependency is ignored and never notified
    # this edge case should be documented in the docs strings
    @test !is_pending(s1)
end

@testitem "Edge Case: Circular Dependencies" begin
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, set_value!, is_pending

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
    import Cortex: Signal, add_dependency!, get_dependencies, get_listeners, set_value!, is_pending

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
    import Cortex: Signal, set_value!, add_dependency!, get_variant, set_variant!

    @testset "Uninitialized Signal" begin
        s_no_meta = Signal()
        @test repr(s_no_meta) == "Signal(value=#undef, pending=false)"

        s_meta = Signal(variant = (test = 1,))
        @test repr(s_meta) == "Signal(value=#undef, pending=false, variant=(test = 1,))"

        s_type = Signal(variant = 0x01)
        @test repr(s_type) == "Signal(value=#undef, pending=false, variant=0x01)"

        s_both = Signal(variant = 2.3)
        @test repr(s_both) == "Signal(value=#undef, pending=false, variant=2.3)"
    end

    @testset "Initialized Signal" begin
        s_int = Signal(123)
        @test repr(s_int) == "Signal(value=123, pending=false)"

        s_str_meta = Signal("test"; variant = "some info")
        @test repr(s_str_meta) == "Signal(value=\"test\", pending=false, variant=\"some info\")"
    end

    @testset "Pending Signal" begin
        s1 = Signal(1)
        s_pending = Signal(variant = 0x1f)
        add_dependency!(s_pending, s1)
        @test repr(s_pending) == "Signal(value=#undef, pending=true, variant=0x1f)"

        set_value!(s_pending, 50)
        @test repr(s_pending) == "Signal(value=50, pending=false, variant=0x1f)"

        set_value!(s1, 2)
        @test repr(s_pending) == "Signal(value=50, pending=true, variant=0x1f)"
    end
end

@testitem "Signal JET Coverage" begin
    import Cortex: Signal
    import JET

    # Test default constructors
    JET.@test_opt Cortex.Signal()
    JET.@test_opt Cortex.Signal(1)
    JET.@test_opt Cortex.Signal("1")
    # Test constructors with keywords
    JET.@test_opt Cortex.Signal(variant = 0x01)
    JET.@test_opt Cortex.Signal(variant = :meta)
    JET.@test_opt Cortex.Signal(variant = Dict{Symbol, Any}())
    JET.@test_opt Cortex.Signal(1; variant = "meta")
    JET.@test_opt Cortex.Signal(1; variant = Dict{Symbol, Any}())

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
    JET.@test_opt Cortex.get_variant(Cortex.Signal())
    JET.@test_opt Cortex.get_variant(Cortex.Signal(variant = Dict{Symbol, Any}(:a => 1)))
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

@testitem "The `compute!` function should not update the value of a signal if it does not have listeners" begin
    import Cortex: Signal, compute!, get_value

    s = Signal(1)

    compute!(s; skip_if_no_listeners = true) do signal, dependencies
        return 2
    end

    @test get_value(s) == 1

    compute!(s; force = true, skip_if_no_listeners = false) do signal, dependencies
        @test length(dependencies) == 0
        return 2
    end

    @test get_value(s) == 2
end
