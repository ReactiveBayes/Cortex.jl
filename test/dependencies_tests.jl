@testitem "It should be possible to create a list of `message-to-factor` dependencies" begin
    import Cortex: Value, Dependency, MessageToFactorDependency, is_pending, is_computed
    import JET

    dependencies = [
        Dependency(MessageToFactorDependency(Value(), 1, 2)),
        Dependency(MessageToFactorDependency(Value(), 1, 3)),
        Dependency(MessageToFactorDependency(Value(), 2, 3)),
    ]
    
    @test !any(is_pending, dependencies)
    @test !any(is_computed, dependencies)

    # Check allocations free, even in a presence of Runtime dispatch
    @test @allocated(any(is_pending, dependencies)) == 0
    @test @allocated(any(is_computed, dependencies)) == 0

end

@testitem "Iteration over a list of dependencies should be allocation free even for custom dependencies" begin
    import Cortex: Dependency, MessageToFactorDependency, AbstractDependency, Value, is_pending, is_computed

    struct SomeOtherDependency <: AbstractDependency end

    Cortex.is_pending(dependency::SomeOtherDependency)::Bool = false
    Cortex.is_computed(dependency::SomeOtherDependency)::Bool = false

    dependencies = [
        Dependency(MessageToFactorDependency(Value(), 1, 2)),
        Dependency(MessageToFactorDependency(Value(), 1, 3)),
        Dependency(SomeOtherDependency()),
    ]

    @test !any(is_pending, dependencies)
    @test !any(is_computed, dependencies)

    @test @allocated(any(is_pending, dependencies)) == 0
    @test @allocated(any(is_computed, dependencies)) == 0
end
