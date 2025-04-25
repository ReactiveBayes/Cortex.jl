@testitem "Value can be created" begin
    import Cortex: Value, is_computed, is_pending

    @testset "An empty Value can be created" begin
        value = Value()
        @test !is_computed(value)
        @test !is_pending(value)
    end

    @testset "A Value can be created with a scalar" begin
        value = Value(1)
        @test is_computed(value)
        @test !is_pending(value)
    end

    @testset "A Value can be created with a vector" begin
        value = Value([1, 2, 3])
        @test is_computed(value)
        @test !is_pending(value)
    end
end

@testitem "Value can be updated" begin
    import Cortex: Value, is_computed, is_pending, set_value!

    value = Value()
    @test !is_computed(value)
    @test !is_pending(value)
    set_value!(value, 1)
    @test is_computed(value)
    @test !is_pending(value)
end

@testitem "Value can be set to pending" begin
    import Cortex: Value, is_computed, is_pending, set_pending!, set_value!

    value = Value()
    @test !is_computed(value)
    @test !is_pending(value)

    set_pending!(value)
    @test !is_computed(value)
    @test is_pending(value)

    set_value!(value, 1)
    @test is_computed(value)
    @test !is_pending(value)
end

@testitem "The pending status of a Value can be unset" begin
    import Cortex: Value, is_computed, is_pending, set_pending!, unset_pending!

    value = Value()
    @test !is_computed(value)
    @test !is_pending(value)

    set_pending!(value)
    @test is_pending(value)

    unset_pending!(value)
    @test !is_pending(value)
end

@testitem "Value can be pretty-printed" begin
    import Cortex: Value, is_computed, is_pending

    @test repr(Value()) == "Value(#undef, pending=false, computed=false)"
    @test repr(Value(1)) == "Value(1, pending=false, computed=true)"
end

@testitem "DualPendingGroup can be created" begin
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out

    ns = [2, 3, 10, 100, 1000]

    # Test that the length of the DualPendingGroup is correct
    for n in ns
        dpg = DualPendingGroup(n)
        @test length(dpg) == n
    end

    # Test that the inbound and outbound pending states are correct
    for n in ns
        dpg = DualPendingGroup(n)
        @test !is_pending_in(dpg, 1)
        @test !is_pending_out(dpg, 1)
    end
end

# Internal implementational detail test
@testitem "Group index and offsets are correct" begin 
    import Cortex: dpg_index, dpg_offset

    @test dpg_index(1) == 1
    @test dpg_offset(1) == 0

    @test dpg_index(2) == 1
    @test dpg_offset(2) == 4

    @test dpg_index(16) == 1
    @test dpg_offset(16) == 60

    @test dpg_index(17) == 2
    @test dpg_offset(17) == 0

    @test dpg_index(18) == 2
    @test dpg_offset(18) == 4

    @test dpg_index(32) == 2
    @test dpg_offset(32) == 60
    
    @test dpg_index(33) == 3
    @test dpg_offset(33) == 0
    
end

@testitem "DualPendingGroup handles inbound pending states" begin
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out, set_pending!

    dpg = DualPendingGroup(3)

    # Set first value as inbound pending
    set_pending!(dpg, 1)
    @test is_pending_in(dpg, 1)
    @test !is_pending_out(dpg, 1)

    # Other values should not be affected
    @test !is_pending_in(dpg, 2)
    @test !is_pending_out(dpg, 2)
    @test !is_pending_in(dpg, 3)
    @test !is_pending_out(dpg, 3)
end

@testitem "DualPendingGroup triggers outbound pending correctly" begin
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out, set_pending!

    dpg = DualPendingGroup(3)

    # Set first two values as inbound pending
    set_pending!(dpg, 1)
    set_pending!(dpg, 2)

    # Third value should become outbound pending
    @test !is_pending_in(dpg, 3)
    @test is_pending_out(dpg, 3)

    # First two values should remain only inbound pending
    @test is_pending_in(dpg, 1)
    @test !is_pending_out(dpg, 1)
    @test is_pending_in(dpg, 2)
    @test !is_pending_out(dpg, 2)
end

@testitem "DualPendingGroup reaches full pending state" begin
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out, set_pending!

    dpg = DualPendingGroup(3)

    # Set all values as inbound pending
    for i in 1:3
        set_pending!(dpg, i)
    end

    # All values should be both inbound and outbound pending
    for i in 1:3
        @test is_pending_in(dpg, i)
        @test is_pending_out(dpg, i)
    end
end

@testitem "DualPendingGroup handles redundant pending operations" begin
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out, set_pending!

    dpg = DualPendingGroup(3)

    # Set first value as pending multiple times
    set_pending!(dpg, 1)
    set_pending!(dpg, 1)

    # Should maintain correct state
    @test is_pending_in(dpg, 1)
    @test !is_pending_out(dpg, 1)

    # Others should be unaffected
    @test !is_pending_in(dpg, 2)
    @test !is_pending_out(dpg, 2)
    @test !is_pending_in(dpg, 3)
    @test !is_pending_out(dpg, 3)
end

@testitem "DualPendingGroup works with large vectors #1" begin
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out, set_pending!

    n = 100 # Large enough to exceed standard sizes of packed bits

    # For each index, verify that setting all other indices to pending
    # makes this index outbound pending
    for target_idx in 1:n
        dpg = DualPendingGroup(n)

        # Set all indices except target_idx to inbound pending
        for i in 1:n
            if i != target_idx
                set_pending!(dpg, i)
            end
        end

        # Target index should be outbound pending but not inbound pending
        @test !is_pending_in(dpg, target_idx)
        @test is_pending_out(dpg, target_idx)

        # All other indices should be inbound pending but not outbound pending
        for i in 1:n
            if i != target_idx
                @test is_pending_in(dpg, i)
                @test !is_pending_out(dpg, i)
            end
        end
    end
end

@testitem "DualPendingGroup works with large vectors #2" begin
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out, set_pending!

    n = 100
    dpg = DualPendingGroup(n)

    for i in 2:(n - 1)
        @test !is_pending_in(dpg, 1)
        @test !is_pending_in(dpg, i)

        set_pending!(dpg, i)

        @test is_pending_in(dpg, i)
        @test !is_pending_out(dpg, i)

        # We skip the first value for testing purposes
        @test !is_pending_out(dpg, 1)
    end

    @test !is_pending_in(dpg, 1)
    @test !is_pending_out(dpg, 1)

    # After this line the first value should be outbound pending
    set_pending!(dpg, n)

    @test is_pending_in(dpg, n)  # n is in-pending
    @test is_pending_out(dpg, 1) # all values from 2:n are in-pending
    @test !is_pending_in(dpg, 1) # 1 is not in-pending

    # All other values should be inbound pending but not outbound pending
    for i in 2:n
        @test is_pending_in(dpg, i)
        @test !is_pending_out(dpg, i)
    end

    # If now, we set the first value to pending, all values should be outbound pending
    set_pending!(dpg, 1)
    for i in 1:n
        @test is_pending_in(dpg, i)
        @test is_pending_out(dpg, i)
    end
end
