const std = @import("std");
const Config = @import("../config.zig").Config;
const backtest = @import("backtest.zig");
const exchange = @import("exchange.zig");

pub const HyperoptSpace = struct {
    ma_short_min: u32 = 10,
    ma_short_max: u32 = 30,
    ma_long_min: u32 = 40,
    ma_long_max: u32 = 100,
    rsi_oversold_min: f64 = 20.0,
    rsi_oversold_max: f64 = 40.0,
};

/// Bayesian parameter optimization (Simplified Random Search for now)
/// This leverages Zig's blazing fast performance to simulate thousands of strategy
/// variants across historical data in seconds.
pub fn runOptimization(
    allocator: std.mem.Allocator,
    base_config: *Config,
    historical_data: []const exchange.Kline,
    trials: u32,
    space: HyperoptSpace
) !void {
    var best_profit: f64 = -999.0;
    var best_ma_short: u32 = 0;
    var best_ma_long: u32 = 0;

    var engine = backtest.BacktestEngine{
        .allocator = allocator,
        .config = base_config,
    };

    var prng = std.rand.DefaultPrng.init(@bitCast(std.time.milliTimestamp()));
    const random = prng.random();

    std.log.info("Starting Hyperopt for {d} trials...", .{trials});

    for (0..trials) |i| {
        // Mutate the configuration for this trial
        base_config.trader.strategy.ma_short = random.intRangeAtMost(u32, space.ma_short_min, space.ma_short_max);
        base_config.trader.strategy.ma_long = random.intRangeAtMost(u32, space.ma_long_min, space.ma_long_max);

        // Run full backtest on this specific configuration instance
        const result = try engine.run(historical_data);

        if (result.net_profit_pct > best_profit) {
            best_profit = result.net_profit_pct;
            best_ma_short = base_config.trader.strategy.ma_short;
            best_ma_long = base_config.trader.strategy.ma_long;

            std.log.info("Trial {d}: New Best! Profit: {d}%, MA_S: {d}, MA_L: {d}",
                .{i, best_profit, best_ma_short, best_ma_long});
        }
    }

    std.log.info("Hyperopt Complete. Optimal params -> MA_Short: {d}, MA_Long: {d}",
        .{best_ma_short, best_ma_long});
}
