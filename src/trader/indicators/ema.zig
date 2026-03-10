const std = @import("std");

/// Calculates the Exponential Moving Average (EMA) for a series of values.
pub fn calculateEMA(allocator: std.mem.Allocator, data: []const f64, period: usize) ![]f64 {
    if (data.len == 0 or period == 0) {
        return try allocator.alloc(f64, 0);
    }

    var ema = try allocator.alloc(f64, data.len);
    const multiplier: f64 = 2.0 / (@as(f64, @floatFromInt(period)) + 1.0);

    // Initialize the first value with a simple SMA of the first 'period' elements if possible,
    // otherwise just use the first data point.
    var sum: f64 = 0;
    const initial_period = @min(period, data.len);
    for (data[0..initial_period]) |val| {
        sum += val;
    }
    ema[0] = sum / @as(f64, @floatFromInt(initial_period));

    for (data[1..], 1..) |val, i| {
        ema[i] = (val - ema[i - 1]) * multiplier + ema[i - 1];
    }

    return ema;
}
