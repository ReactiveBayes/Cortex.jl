@testitem "An empty slot can be created" begin
    import Cortex: Slot
    import JET

    @test Slot() isa Slot

    JET.@test_opt Slot()
end

@testitem "A slot should mirror functions of the value" begin
    import Cortex: Slot, Value, is_pending, is_computed, set_value!, set_pending!, unset_pending!
    import JET

    slot = Slot()

    # Empty state
    @test !is_pending(slot)
    @test !is_computed(slot)

    JET.@test_opt is_pending(slot)
    JET.@test_opt is_computed(slot)

    # After setting pending the value should be pending
    set_pending!(slot)

    @test is_pending(slot)
    @test !is_computed(slot)

    JET.@test_opt set_pending!(slot)

    # After unsetting pending the pending state should be unset
    unset_pending!(slot)

    @test !is_pending(slot)
    @test !is_computed(slot)

    JET.@test_opt unset_pending!(slot)

    # Setting value marks the underlying value as computed
    set_value!(slot, 1)

    @test !is_pending(slot)
    @test is_computed(slot)

    JET.@test_opt set_value!(slot, 1)
    
    @test slot.value.value == 1

    set_pending!(slot)

    @test is_pending(slot)
    @test !is_computed(slot)

    set_value!(slot, 2)

    @test !is_pending(slot)
    @test is_computed(slot)

    @test slot.value.value == 2
end

@testitem "Depenencies can be added to a slot" begin
    import Cortex: Slot, AbstractDependency, add_dependency!

    slot = Slot()

    struct SomeCustomDependency <: AbstractDependency end

    dep = SomeCustomDependency()
    add_dependency!(slot, dep)

    @test length(slot.dependencies) == 1
    @test slot.dependencies[1].type == Cortex.DependencyType.RuntimeDispatch
    @test slot.dependencies[1].wrapped == dep

    struct AnotherCustomDependency <: AbstractDependency end

    dep2 = AnotherCustomDependency()
    add_dependency!(slot, dep2)

    @test length(slot.dependencies) == 2
    @test slot.dependencies[2].type == Cortex.DependencyType.RuntimeDispatch
    @test slot.dependencies[2].wrapped == dep2
end

