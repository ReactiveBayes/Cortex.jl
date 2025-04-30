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

@testitem "Depenencies can be created between slots" begin
    import Cortex: Slot, AbstractDependency, add_dependency!

    slot1 = Slot()
    slot2 = Slot()

    struct SomeCustomDependency <: AbstractDependency end

    dep = SomeCustomDependency()
    add_dependency!(slot1, slot2, dep)

    @test length(slot1.dependencies) == 1
    @test slot1.dependencies[1][1] == slot2
    @test slot1.dependencies[1][2].type == Cortex.DependencyType.RuntimeDispatch
    @test slot1.dependencies[1][2].wrapped == dep

    @test length(slot2.dependents) == 1
    @test slot2.dependents[1] == slot1

    struct AnotherCustomDependency <: AbstractDependency end

    dep2 = AnotherCustomDependency()
    add_dependency!(slot1, slot2, dep2)

    @test length(slot1.dependencies) == 2
    @test slot1.dependencies[2][1] == slot2
    @test slot1.dependencies[2][2].type == Cortex.DependencyType.RuntimeDispatch
    @test slot1.dependencies[2][2].wrapped == dep2
end

@testitem "The same slot cannot be a dependency of itself" begin
    import Cortex: Slot, AbstractDependency, add_dependency!

    struct SomeCustomCircularDependency <: AbstractDependency end

    slot = Slot()
    
    @test_throws "A slot cannot be a dependency of itself" add_dependency!(slot, slot, SomeCustomCircularDependency())
end
