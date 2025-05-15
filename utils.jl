"""
    format_time_ns(ns::UInt64)

Convert a UInt64 nanosecond timestamp into a human-readable string.
"""
function format_time_ns(ns::UInt64)
    if ns < 1_000 # Nanoseconds
        return string(ns, " ns")
    elseif ns < 1_000_000 # Microseconds
        return string(round(ns / 1_000, digits = 2), " μs")
    elseif ns < 1_000_000_000 # Milliseconds
        return string(round(ns / 1_000_000, digits = 2), " ms")
    elseif ns < 60_000_000_000 # Seconds
        return string(round(ns / 1_000_000_000, digits = 2), " s")
    elseif ns < 3_600_000_000_000 # Minutes
        return string(round(ns / 60_000_000_000, digits = 2), " min")
    else # Hours
        return string(round(ns / 3_600_000_000_000, digits = 2), " hr")
    end
end
