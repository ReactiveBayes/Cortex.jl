@testmodule DualPendingGroupTestUtils begin
    export with_dual_pending_group_of_length

    import Cortex: DualPendingGroup, add_element!

    # There are two ways to create a DualPendingGroup
    # 1. DualPendingGroup(n)
    # 2. DualPendingGroup(0) and then append elements to it one by one with the `add_element!` function
    function with_dual_pending_group_of_length(fn::Function, n::Int)
        dpg1 = DualPendingGroup(n)
        fn(dpg1)

        dpg2 = DualPendingGroup(0)
        for _ in 1:n
            add_element!(dpg2)
        end
        fn(dpg2)
    end

    function with_dual_pending_group_of_length(fn::Function, ns)
        for n in ns
            with_dual_pending_group_of_length((dpg) -> fn(dpg, n), n)
        end
    end
end

@testitem "DualPendingGroup can be created" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: DualPendingGroup, is_pending_in, is_pending_out

    ns = [2, 3, 10, 100, 1000]

    # Test that the length of the DualPendingGroup is correct
    with_dual_pending_group_of_length(ns) do dpg, n
        @test length(dpg) == n
    end

    # Test that the inbound and outbound pending states are correct
    with_dual_pending_group_of_length(ns) do dpg, n
        @test !is_pending_in(dpg, 1)
        @test !is_pending_out(dpg, 1)
    end
end

@testitem "Group index and offsets are correct" begin
    # This is an internal test and might be safely removed if the implementation changes.
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

@testitem "DualPendingGroup handles inbound pending states" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: is_pending_in, is_pending_out, set_pending!

    with_dual_pending_group_of_length(3) do dpg
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
end

@testitem "DualPendingGroup triggers outbound pending correctly" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: is_pending_in, is_pending_out, set_pending!

    with_dual_pending_group_of_length(3) do dpg
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
end

@testitem "DualPendingGroup reaches full pending state" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: is_pending_in, is_pending_out, set_pending!

    with_dual_pending_group_of_length(3) do dpg
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
end

@testitem "DualPendingGroup handles redundant pending operations #1" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: is_pending_in, is_pending_out, set_pending!

    with_dual_pending_group_of_length(3) do dpg
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
end

@testitem "DualPendingGroup handles redundant pending operations #2" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: is_pending_in, is_pending_out, set_pending!

    # This test verifies that DualPendingGroup correctly handles redundant pending operations
    # across different group sizes (3, 17, and 100). It tests several scenarios:
    # 1. Setting elements 3:n as pending should not affect outbound pending state of elements 1-2
    # 2. Repeatedly setting elements as pending in different patterns shouldn't change the state
    # 3. When element 1 is set pending, element 2 becomes outbound pending
    # 4. When both elements 1 and 2 are pending, both become outbound pending
    # 5. The test ensures that redundant pending operations don't corrupt the internal state
    #    by testing with both forward and reverse iteration patterns
    with_dual_pending_group_of_length([3, 17, 100]) do dpg, n
        @test !is_pending_out(dpg, 1)
        @test !is_pending_out(dpg, 2)

        for i in 3:n
            set_pending!(dpg, i)
        end

        @test !is_pending_out(dpg, 1)
        @test !is_pending_out(dpg, 2)

        # Forward iteration pattern, 3:n are pending
        for i in 3:n
            for k in i:n
                set_pending!(dpg, k)
            end
        end

        # Since 1 and 2 are not pending, the pending state should not change
        @test !is_pending_out(dpg, 1)
        @test !is_pending_out(dpg, 2)

        # Reverse iteration pattern, n:-1:3 are pending
        for i in n:-1:3
            for k in n:-1:i
                set_pending!(dpg, k)
            end
        end

        # Since 1 and 2 are not pending, the pending state should not change
        @test !is_pending_out(dpg, 1)
        @test !is_pending_out(dpg, 2)

        # Set element 1 as pending
        set_pending!(dpg, 1)

        # Element 1 should remain outbound pending, element 2 should become outbound pending
        @test !is_pending_out(dpg, 1)
        @test is_pending_out(dpg, 2)

        # Set element 2 as pending
        set_pending!(dpg, 2)

        # Both elements should be outbound pending
        @test is_pending_out(dpg, 1)
        @test is_pending_out(dpg, 2)

        # Set all elements as pending
        for i in 1:n
            for k in i:n
                set_pending!(dpg, k)
            end
        end

        # All elements should be outbound pending
        for i in 1:n
            @test is_pending_out(dpg, i)
        end

        # Reverse iteration pattern, n:-1:1 are pending
        for i in n:-1:1
            for k in n:-1:i
                set_pending!(dpg, k)
            end
        end

        # All elements should still be outbound pending
        for i in 1:n
            @test is_pending_out(dpg, i)
        end
    end
end

@testitem "DualPendingGroup works with large vectors #1" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: is_pending_in, is_pending_out, set_pending!

    n = 200 # Large enough to exceed standard sizes of packed bits

    # For each index, verify that setting all other indices to pending
    # makes this index outbound pending
    for target_idx in 1:n
        with_dual_pending_group_of_length(n) do dpg
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
end

@testitem "DualPendingGroup works with large vectors #2" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: is_pending_in, is_pending_out, set_pending!

    n = 100
    with_dual_pending_group_of_length(n) do dpg
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
end

@testitem "DualPendingGroup should implement is_pending_in_all" setup = [DualPendingGroupTestUtils] begin
    using .DualPendingGroupTestUtils
    import Cortex: DualPendingGroup, is_pending_in_all, set_pending!

    ns = [2, 3, 10, 100, 1000]

    @testset for n in ns, k in 1:n
        with_dual_pending_group_of_length(n) do dpg
            @test !is_pending_in_all(dpg)

            for i in 1:n
                if i != k
                    set_pending!(dpg, i)
                    @test !is_pending_in_all(dpg)
                end
            end

            set_pending!(dpg, k)
            @test is_pending_in_all(dpg)
        end
    end
end

@testitem "It should not be possible to add an element to DualPendingGroup if it has been touched with `set_pending!`" setup = [
    DualPendingGroupTestUtils
] begin
    using .DualPendingGroupTestUtils
    import Cortex: DualPendingGroup, add_element!, set_pending!

    with_dual_pending_group_of_length([3, 17, 100]) do dpg, _
        set_pending!(dpg, 1)
        @test_throws "Cannot add an element to a DualPendingGroup since some elements have non-zero pending states. Make sure to add elements before using `set_pending!`." add_element!(
            dpg
        )
    end
end

@testitem "It should be possible to resize! a DualPendingGroup after creation before adding elements" setup = [
    DualPendingGroupTestUtils
] begin
    using .DualPendingGroupTestUtils
    import Cortex: DualPendingGroup, resize!, set_pending!, is_pending_in, is_pending_out

    dpg = DualPendingGroup(0)
    resize!(dpg, 10)

    @test length(dpg) == 10

    for i in 1:9
        set_pending!(dpg, i)
        @test is_pending_in(dpg, i)
        @test !is_pending_out(dpg, i)
    end

    @test is_pending_out(dpg, 10)
    set_pending!(dpg, 10)
    @test is_pending_in(dpg, 10)

    for i in 1:9
        @test is_pending_out(dpg, i)
    end
end