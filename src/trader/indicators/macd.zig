const std = @import("std");
const ema = @import("ema.zig");

pub const MacdResult = struct {
    macd: []f64,
    signal: []f64,
    histogram: []f64,
};

/// Calculates Moving Average Convergence Divergence (MACD).
pub fn calculateMACD(
    allocator: std.mem.Allocator,
    data: []const f64,
    fast_period: usize,
    slow_period: usize,
    signal_period: usize,
) !MacdResult {
    if (data.len == 0 or fast_period == 0 or slow_period == 0 or signal_period == 0) {
        return MacdResult{
            .macd = try allocator.alloc(f64, 0),
            .signal = try allocator.alloc(f64, 0),
            .histogram = try allocator.alloc(f64, 0),
        };
    }

    const fast_ema = try ema.calculateEMA(allocator, data, fast_period);
    defer allocator.free(fast_ema);

    const slow_ema = try ema.calculateEMA(allocator, data, slow_period);
    defer allocator.free(slow_ema);

    var macd_line = try allocator.alloc(f64, data.len);
    for (fast_ema, 0..) |fast_val, i| {
        macd_line[i] = fast_val - slow_ema[i];
    }

    const signal_line = try ema.calculateEMA(allocator, macd_line, signal_period);
    var histogram = try allocator.alloc(f64, data.len);

    for (macd_line, 0..) |macd_val, i| {
        histogram[i] = macd_val - signal_line[i];
    }

    return MacdResult{
        .macd = macd_line,
        .signal = signal_line,
        .histogram = histogram,
    };
}
