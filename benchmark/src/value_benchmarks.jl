ValueBenchmarks = BenchmarkGroup()

SUITE["Value"] = ValueBenchmarks

for n in [10, 100, 1000, 10_000, 100_000]
    ValueBenchmarks["creation undef", n] = @benchmarkable begin 
        [Cortex.Value() for i in 1:$n]
    end

    ValueBenchmarks["creation integer", n] = @benchmarkable begin 
        [Cortex.Value(i) for i in 1:$n]
    end

    ValueBenchmarks["set/unset pending simultaneous", n] = @benchmarkable begin 
        for v in values 
            Cortex.set_pending!(v)
            Cortex.unset_pending!(v)
        end
    end setup = begin 
        values = [Cortex.Value(i) for i in 1:$n]
    end

    ValueBenchmarks["set/unset pending sequential", n] = @benchmarkable begin 
        for v in values 
            Cortex.set_pending!(v)
        end
        for v in values 
            Cortex.unset_pending!(v)
        end
    end setup = begin 
        values = [Cortex.Value(i) for i in 1:$n]
    end

    ValueBenchmarks["set_value!", n] = @benchmarkable begin
        for v in values
            Cortex.set_value!(v, 42)
        end
    end setup = begin
        values = [Cortex.Value() for _ in 1:$n]
    end
end


