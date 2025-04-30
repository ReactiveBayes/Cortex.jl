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

@testitem "When a slot is updated, all dependents should be set to pending" begin
    import Cortex: Slot, AbstractDependency, add_dependency!, set_value!, is_pending, is_computed

    struct SomeCustomPendingDependency <: AbstractDependency end

    @testset "slot1 depends on slot2, setting value to slot2 should set slot1 to pending" begin
        slot1 = Slot()
        slot2 = Slot()

        dep = SomeCustomPendingDependency()
        add_dependency!(slot1, slot2, dep)

        @test !is_pending(slot1)
        @test !is_computed(slot1)

        @test !is_pending(slot2)
        @test !is_computed(slot2)

        set_value!(slot2, 1)

        @test !is_pending(slot2)
        @test is_computed(slot2)

        @test is_pending(slot1)
        @test !is_computed(slot1)
    end

    @testset "slot1 depends on slot2, setting value to slot1 should NOT set slot2 to pending" begin
        slot1 = Slot()
        slot2 = Slot()

        dep = SomeCustomPendingDependency()
        add_dependency!(slot1, slot2, dep)

        @test !is_pending(slot1)
        @test !is_computed(slot1)

        @test !is_pending(slot2)
        @test !is_computed(slot2)

        set_value!(slot1, 1)

        @test !is_pending(slot1)
        @test is_computed(slot1)
        @test !is_pending(slot2)
        @test !is_computed(slot2)
    end
end

@testitem "If a slot depends on several other slots, it should only be marked as pending if all of its dependencies are pending" begin
    import Cortex: Slot, AbstractDependency, add_dependency!, set_value!, is_pending, is_computed

    slot1 = Slot()
    slot2 = Slot()
    slot3 = Slot()

    struct SomeCustomHugeDependency <: AbstractDependency end

    dep = SomeCustomHugeDependency()
    add_dependency!(slot1, slot2, dep)
    add_dependency!(slot1, slot3, dep)

    @test !is_pending(slot1)
    @test !is_pending(slot2)
    @test !is_pending(slot3)
    @test !is_computed(slot1)
    @test !is_computed(slot2)
    @test !is_computed(slot3)

    set_value!(slot2, 1)

    @test !is_pending(slot1)
    @test !is_pending(slot2)
    @test !is_pending(slot3)

    @test !is_computed(slot1)
    @test is_computed(slot2)
    @test !is_computed(slot3)

    set_value!(slot3, 1)

    @test is_pending(slot1)
    @test is_computed(slot2)
    @test is_computed(slot3)
end
