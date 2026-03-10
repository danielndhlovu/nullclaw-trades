const std = @import("std");

/// Calculates the Relative Strength Index (RSI) for a series of values.
pub fn calculateRSI(allocator: std.mem.Allocator, data: []const f64, period: usize) ![]f64 {
    if (data.len <= period or period == 0) {
        return try allocator.alloc(f64, data.len); // Return uninitialized/empty for not enough data
    }

    var rsi = try allocator.alloc(f64, data.len);
    @memset(rsi[0..period], 0.0); // No RSI for the first 'period' elements

    var gain: f64 = 0;
    var loss: f64 = 0;

    // Calculate initial average gain/loss over the first period
    for (0..period) |i| {
        const diff = data[i + 1] - data[i];
        if (diff > 0) {
            gain += diff;
        } else {
            loss -= diff;
        }
    }

    var avg_gain = gain / @as(f64, @floatFromInt(period));
    var avg_loss = loss / @as(f64, @floatFromInt(period));

    if (avg_loss == 0) {
        rsi[period] = 100.0;
    } else {
        const rs = avg_gain / avg_loss;
        rsi[period] = 100.0 - (100.0 / (1.0 + rs));
    }

    // Smoothed moving average for the rest
    for (data[period + 1 ..], period + 1..) |val, i| {
        const diff = val - data[i - 1];
        var current_gain: f64 = 0;
        var current_loss: f64 = 0;

        if (diff > 0) {
            current_gain = diff;
        } else {
            current_loss = -diff;
        }

        avg_gain = (avg_gain * @as(f64, @floatFromInt(period - 1)) + current_gain) / @as(f64, @floatFromInt(period));
        avg_loss = (avg_loss * @as(f64, @floatFromInt(period - 1)) + current_loss) / @as(f64, @floatFromInt(period));

        if (avg_loss == 0) {
            rsi[i] = 100.0;
        } else {
            const rs = avg_gain / avg_loss;
            rsi[i] = 100.0 - (100.0 / (1.0 + rs));
        }
    }

    return rsi;
}
