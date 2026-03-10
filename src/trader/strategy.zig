const std = @import("std");
const Config = @import("../config.zig").Config;
const exchange = @import("exchange.zig");
const ema = @import("indicators/ema.zig");
const rsi = @import("indicators/rsi.zig");

pub const Signal = enum {
    None,
    Buy,
    Sell,
};

/// Evaluates a multi-factor strategy to determine entry signals.
pub fn evaluate(allocator: std.mem.Allocator, config: *const Config, klines: []const exchange.Kline) !Signal {
    const closes = try allocator.alloc(f64, klines.len);
    for (klines, 0..) |k, i| {
        closes[i] = k.close;
    }

    const cfg = config.trader.strategy;

    // Calculate Indicators
    const ema_short = try ema.calculateEMA(allocator, closes, cfg.ma_short);
    const ema_long = try ema.calculateEMA(allocator, closes, cfg.ma_long);
    const rsi_arr = try rsi.calculateRSI(allocator, closes, 14);

    const latest_idx = klines.len - 1;
    const current_close = closes[latest_idx];

    // Safety check - need enough data
    if (ema_short.len <= latest_idx or ema_long.len <= latest_idx or rsi_arr.len <= latest_idx) {
        return Signal.None;
    }

    const current_ema_short = ema_short[latest_idx];
    const current_ema_long = ema_long[latest_idx];
    const current_rsi = rsi_arr[latest_idx];

    // Basic Strategy Logic
    // BUY: Price > Long EMA, Short EMA > Long EMA, RSI < Oversold (Dips in uptrend)
    if (current_close > current_ema_long and
        current_ema_short > current_ema_long and
        current_rsi < cfg.rsi_oversold)
    {
        return Signal.Buy;
    }

    // SELL: Price < Long EMA, Short EMA < Long EMA, RSI > Overbought (Rallies in downtrend)
    if (current_close < current_ema_long and
        current_ema_short < current_ema_long and
        current_rsi > cfg.rsi_overbought)
    {
        return Signal.Sell;
    }

    return Signal.None;
}
