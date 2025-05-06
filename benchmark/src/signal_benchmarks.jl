
SignalBenchmarks = BenchmarkGroup()
SUITE["Signal Basic Operations"] = SignalBenchmarks

# --- Benchmark Definitions ---

for n in [10, 100, 1_000]

    # --- Creation ---
    SignalBenchmarks["creation empty", n] = @benchmarkable begin
        [Cortex.Signal() for _ in 1:($n)]
    end

    SignalBenchmarks["creation integer", n] = @benchmarkable begin
        [Cortex.Signal(i) for i in 1:($n)]
    end

    SignalBenchmarks["creation type", n] = @benchmarkable begin
        [Cortex.Signal(i; type = 0x01) for i in 1:($n)]
    end

    SignalBenchmarks["creation metadata", n] = @benchmarkable begin
        [Cortex.Signal(i; metadata = :meta) for i in 1:($n)]
    end

    SignalBenchmarks["creation type_metadata", n] = @benchmarkable begin
        [Cortex.Signal(i; type = 0x01, metadata = :meta) for i in 1:($n)]
    end

    # --- Setting Value ---
    SignalBenchmarks["set_value!", n] = @benchmarkable begin
        for s in signals
            Cortex.set_value!(s, 42)
        end
    end setup = begin
        # Use signals without listeners to isolate set_value! cost itself
        signals = [Cortex.Signal() for _ in 1:($n)]
    end

    # --- Getting Value ---
    SignalBenchmarks["get_value", n] = @benchmarkable begin
        for s in signals
            Cortex.get_value(s)
        end
    end setup = begin
        signals = [Cortex.Signal(i) for i in 1:($n)]
    end

    # --- Checking Computed Status ---
    SignalBenchmarks["is_computed", n] = @benchmarkable begin
        for s in signals
            Cortex.is_computed(s)
        end
    end setup = begin
        # Mix computed and non-computed signals
        signals = [mod(i, 2) == 0 ? Cortex.Signal(i) : Cortex.Signal() for i in 1:($n)]
    end

    # --- Pending State Checks ---
    SignalBenchmarks["is_pending (no check needed)", n] = @benchmarkable begin
        for s in signals
            Cortex.is_pending(s)
        end
    end setup = begin
        signals = [Cortex.Signal(i) for i in 1:($n)]
    end
end

# --- Dense Interaction Benchmark ---

function setup_dense_signals_network(n)
    signals = [Cortex.Signal() for i in 1:n]
    derived = Cortex.Signal()
    for i in 1:n
        Cortex.add_dependency!(derived, signals[i])
        for k in 1:n
            if k != i
                Cortex.add_dependency!(signals[i], signals[k])
            end
        end
    end
    return signals, derived
end

function set_value_and_check_pending(input)
    signals, derived = input
    for i in eachindex(signals)
        Cortex.set_value!(signals[i], 1)
    end
    return Cortex.is_pending(derived)
end

DenseBenchmarks = BenchmarkGroup()
SUITE["Dense Signal Interaction"] = DenseBenchmarks

# Limit n for dense benchmarks as setup cost (n^2 dependencies) grows quickly
for n in [10, 100, 1000]
    DenseBenchmarks["setup_dense_signals_network", n] = @benchmarkable setup_dense_signals_network($n)

    DenseBenchmarks["setup_update_check", n] = @benchmarkable set_value_and_check_pending(input) setup = begin
        input = setup_dense_signals_network($n)
    end
end
