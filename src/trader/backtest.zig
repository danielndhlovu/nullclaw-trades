const std = @import("std");
const exchange = @import("exchange.zig");
const strategy = @import("strategy.zig");
const Config = @import("../config.zig").Config;

pub const BacktestResult = struct {
    total_trades: u32,
    winning_trades: u32,
    losing_trades: u32,
    net_profit_pct: f64,
    max_drawdown_pct: f64,
    sharpe_ratio: f64,

    pub fn winRate(self: BacktestResult) f64 {
        if (self.total_trades == 0) return 0;
        return @as(f64, @floatFromInt(self.winning_trades)) / @as(f64, @floatFromInt(self.total_trades));
    }
};

pub const BacktestEngine = struct {
    allocator: std.mem.Allocator,
    config: *const Config,

    pub fn run(self: *BacktestEngine, historical_data: []const exchange.Kline) !BacktestResult {
        var result = BacktestResult{
            .total_trades = 0,
            .winning_trades = 0,
            .losing_trades = 0,
            .net_profit_pct = 0.0,
            .max_drawdown_pct = 0.0,
            .sharpe_ratio = 0.0,
        };

        var in_position = false;
        var entry_price: f64 = 0;
        var peak_equity: f64 = 1.0;
        var current_equity: f64 = 1.0;

        // Walk forward candle by candle
        for (historical_data, 0..) |kline, i| {
            if (i < 60) continue; // Warmup period for indicators

            // In a real implementation we would slice historical_data[0..i]
            // and feed it to the strategy evaluator.
            const signal = try strategy.evaluate(self.allocator, self.config, historical_data[0..i+1]);

            if (!in_position and signal == .Buy) {
                in_position = true;
                entry_price = kline.close;
            } else if (in_position and signal == .Sell) {
                in_position = false;
                result.total_trades += 1;

                const trade_return = (kline.close - entry_price) / entry_price;
                if (trade_return > 0) {
                    result.winning_trades += 1;
                } else {
                    result.losing_trades += 1;
                }

                current_equity *= (1.0 + trade_return);

                if (current_equity > peak_equity) {
                    peak_equity = current_equity;
                } else {
                    const drawdown = (peak_equity - current_equity) / peak_equity;
                    if (drawdown > result.max_drawdown_pct) {
                        result.max_drawdown_pct = drawdown;
                    }
                }
            }
        }

        result.net_profit_pct = (current_equity - 1.0) * 100.0;

        return result;
    }
};
