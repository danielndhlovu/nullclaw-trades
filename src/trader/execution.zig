const std = @import("std");
const Config = @import("../config.zig").Config;
const exchange = @import("exchange.zig");

pub const OrderSide = enum { Buy, Sell };

pub const Position = struct {
    symbol: []const u8,
    side: OrderSide,
    entry_price: f64,
    size: f64,
    stop_loss: f64,
    take_profit: f64,
};

pub const ExecutionEngine = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    positions: std.StringHashMap(Position),

    pub fn init(allocator: std.mem.Allocator, config: *const Config) ExecutionEngine {
        return .{
            .allocator = allocator,
            .config = config,
            .positions = std.StringHashMap(Position).init(allocator),
        };
    }

    pub fn deinit(self: *ExecutionEngine) void {
        self.positions.deinit();
    }

    pub fn executeMarketOrder(self: *ExecutionEngine, symbol: []const u8, side: OrderSide, size_usd: f64) !void {
        if (std.mem.eql(u8, self.config.trader.mode, "paper")) {
            // Paper trading simulation
            // In a real implementation we would fetch the exact current ticker price here
            // For now, this is a stub for the architecture demonstration

            // Assume price is $100,000 for BTC just to simulate position
            const simulated_price: f64 = 100000.0;
            const coin_qty = size_usd / simulated_price;

            const risk_cfg = self.config.trader.risk;
            const sl_price = if (side == .Buy)
                simulated_price * (1.0 - (risk_cfg.stop_loss_percent / 100.0))
            else
                simulated_price * (1.0 + (risk_cfg.stop_loss_percent / 100.0));

            const tp_price = if (side == .Buy)
                simulated_price * (1.0 + (risk_cfg.take_profit_percent / 100.0))
            else
                simulated_price * (1.0 - (risk_cfg.take_profit_percent / 100.0));

            try self.positions.put(symbol, .{
                .symbol = symbol,
                .side = side,
                .entry_price = simulated_price,
                .size = coin_qty,
                .stop_loss = sl_price,
                .take_profit = tp_price,
            });
        } else {
            // Live execution via Binance Client HTTP POST
            // try self.binance.createOrder(symbol, side, "MARKET", ...);
        }
    }

    pub fn closePosition(self: *ExecutionEngine, symbol: []const u8) !void {
        if (self.positions.fetchRemove(symbol)) |kv| {
            // Close the position
            _ = kv;
            if (!std.mem.eql(u8, self.config.trader.mode, "paper")) {
                // Send closing market order to Binance
            }
        }
    }

    pub fn manageExits(self: *ExecutionEngine) !void {
        // Here we loop through all open positions and compare them against
        // the current market ticker price to execute stop losses, take profits,
        // and update trailing stops.

        var iter = self.positions.iterator();
        while (iter.next()) |entry| {
            // const current_price = try self.binance.getTickerPrice(entry.key_ptr.*);
            // evaluate SL / TP
            _ = entry;
        }
    }
};
