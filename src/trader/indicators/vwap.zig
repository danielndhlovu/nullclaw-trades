const std = @import("std");
const Kline = @import("../exchange.zig").Kline;

/// Calculates Volume Weighted Average Price (VWAP).
/// Typically VWAP is calculated intraday (resetting every day). For simplicity
/// across generic timeframes, this calculates a rolling VWAP over a specific period.
pub fn calculateVWAP(allocator: std.mem.Allocator, klines: []const Kline, period: usize) ![]f64 {
    if (klines.len == 0 or period == 0) {
        return try allocator.alloc(f64, 0);
    }

    var vwap = try allocator.alloc(f64, klines.len);

    // We maintain a rolling sum of (Typical Price * Volume) and a rolling sum of Volume.
    for (klines, 0..) |_, i| {
        var start_idx: usize = 0;
        if (i >= period) {
            start_idx = i - period + 1;
        }

        var cumulative_tp_vol: f64 = 0;
        var cumulative_vol: f64 = 0;

        for (klines[start_idx .. i + 1]) |kline| {
            const typical_price = (kline.high + kline.low + kline.close) / 3.0;
            cumulative_tp_vol += typical_price * kline.volume;
            cumulative_vol += kline.volume;
        }

        if (cumulative_vol == 0) {
            vwap[i] = klines[i].close; // Fallback if no volume
        } else {
            vwap[i] = cumulative_tp_vol / cumulative_vol;
        }
    }

    return vwap;
}
