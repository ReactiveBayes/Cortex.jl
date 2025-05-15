
@testitem "format_time_ns basic conversions" begin
    import Cortex: format_time_ns

    # Nanoseconds
    @test format_time_ns(UInt64(100)) == "100 ns"
    @test format_time_ns(UInt64(999)) == "999 ns"

    # Microseconds
    @test format_time_ns(UInt64(1_000)) == "1.0 μs"
    @test format_time_ns(UInt64(1_234)) == "1.23 μs" # Assuming rounding to 2 decimal places
    @test format_time_ns(UInt64(999_999)) == "1000.0 μs" # This will be 1000.0 due to rounding rules, or 999.99. Let's check the function's exact behavior.
    # The function uses round(ns / 1_000, digits=2), so 999999/1000 = 999.999 -> 1000.00
    # Actually, it should be 999.999 -> round to 999.99 or 1000.0. Standard rounding rounds .5 up. 999.999 rounds to 1000.00.
    # The function as written: round(999.999, digits=2) -> 1000.0. This might be unexpected. Let's test with a value that stays < 1000.
    @test format_time_ns(UInt64(999_000)) == "999.0 μs"
    @test format_time_ns(UInt64(500_500)) == "500.5 μs"

    # Milliseconds
    @test format_time_ns(UInt64(1_000_000)) == "1.0 ms"
    @test format_time_ns(UInt64(1_234_567)) == "1.23 ms"
    @test format_time_ns(UInt64(999_000_000)) == "999.0 ms"

    # Seconds
    @test format_time_ns(UInt64(1_000_000_000)) == "1.0 s"
    @test format_time_ns(UInt64(1_234_000_000)) == "1.23 s"
    @test format_time_ns(UInt64(59_000_000_000)) == "59.0 s"

    # Minutes
    @test format_time_ns(UInt64(60_000_000_000)) == "1.0 min"
    @test format_time_ns(UInt64(90_000_000_000)) == "1.5 min"
    @test format_time_ns(UInt64(3_540_000_000_000)) == "59.0 min" # 59 minutes

    # Hours
    @test format_time_ns(UInt64(3_600_000_000_000)) == "1.0 hr"
    @test format_time_ns(UInt64(5_400_000_000_000)) == "1.5 hr"
end

@testitem "format_time_ns edge cases and rounding" begin
    import Cortex: format_time_ns

    # Exact transitions
    @test format_time_ns(UInt64(999)) == "999 ns"
    @test format_time_ns(UInt64(1_000)) == "1.0 μs"
    @test format_time_ns(UInt64(999_999)) == "1000.0 μs" # round(999.999, digits=2) -> 1000.0
    @test format_time_ns(UInt64(1_000_000)) == "1.0 ms"
    @test format_time_ns(UInt64(999_999_999)) == "1000.0 ms" # round(999.999999, digits=2) -> 1000.0
    @test format_time_ns(UInt64(1_000_000_000)) == "1.0 s"
    @test format_time_ns(UInt64(59_999_999_999)) == "60.0 s"  # round(59.999..., digits=2) -> 60.0
    @test format_time_ns(UInt64(60_000_000_000)) == "1.0 min"
    @test format_time_ns(UInt64(3_599_999_999_999)) == "60.0 min" # round(59.999..., digits=2) -> 60.0
    @test format_time_ns(UInt64(3_600_000_000_000)) == "1.0 hr"

    # Rounding specifics
    @test format_time_ns(UInt64(1_234)) == "1.23 μs" # 1.234 -> 1.23
    @test format_time_ns(UInt64(1_235)) == "1.24 μs" # 1.235 -> 1.24 (round half up)
    @test format_time_ns(UInt64(1_230)) == "1.23 μs" # Should be 1.23, not 1.230

    @test format_time_ns(UInt64(1_234_000)) == "1.23 ms"
    @test format_time_ns(UInt64(1_235_000)) == "1.24 ms"

    # Zero
    @test format_time_ns(UInt64(0)) == "0 ns"
end
