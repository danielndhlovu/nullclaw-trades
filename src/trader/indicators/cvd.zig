const std = @import("std");
const Kline = @import("../exchange.zig").Kline;

/// Calculates Cumulative Volume Delta (CVD).
/// This is a crucial metric for crypto, measuring the difference between
/// buying volume and selling volume. Binance gives us `taker_buy_base_volume`.
pub fn calculateCVD(allocator: std.mem.Allocator, klines: []const Kline) ![]f64 {
    if (klines.len == 0) {
        return try allocator.alloc(f64, 0);
    }

    var cvd = try allocator.alloc(f64, klines.len);
    var cumulative: f64 = 0;

    for (klines, 0..) |kline, i| {
        // buy volume = taker_buy_base_volume
        // sell volume = total volume - taker_buy_base_volume
        const buy_vol = kline.taker_buy_base_volume;
        const sell_vol = kline.volume - buy_vol;
        const delta = buy_vol - sell_vol;

        cumulative += delta;
        cvd[i] = cumulative;
    }

    return cvd;
}
