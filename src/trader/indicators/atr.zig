const std = @import("std");
const Kline = @import("../exchange.zig").Kline;

/// Calculates Average True Range (ATR).
pub fn calculateATR(allocator: std.mem.Allocator, klines: []const Kline, period: usize) ![]f64 {
    if (klines.len <= period or period == 0) {
        return try allocator.alloc(f64, klines.len);
    }

    var atr = try allocator.alloc(f64, klines.len);
    @memset(atr[0..period], 0.0);

    var tr = try allocator.alloc(f64, klines.len);
    defer allocator.free(tr);

    // True Range calculation
    tr[0] = klines[0].high - klines[0].low; // First element has no previous close
    for (klines[1..], 1..) |kline, i| {
        const tr1 = kline.high - kline.low;
        const tr2 = @abs(kline.high - klines[i - 1].close);
        const tr3 = @abs(kline.low - klines[i - 1].close);
        tr[i] = @max(tr1, @max(tr2, tr3));
    }

    // Initial ATR is simple moving average of TR
    var sum: f64 = 0;
    for (tr[1 .. period + 1]) |val| {
        sum += val;
    }
    atr[period] = sum / @as(f64, @floatFromInt(period));

    // Smoothed Moving Average for subsequent ATRs
    for (tr[period + 1 ..], period + 1..) |val, i| {
        atr[i] = (atr[i - 1] * @as(f64, @floatFromInt(period - 1)) + val) / @as(f64, @floatFromInt(period));
    }

    return atr;
}
