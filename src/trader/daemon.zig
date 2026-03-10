const std = @import("std");
const Config = @import("../config.zig").Config;
const exchange = @import("exchange.zig");
const execution = @import("execution.zig");
const strategy = @import("strategy.zig");
const risk = @import("risk.zig");

pub const TraderDaemon = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    binance_client: exchange.BinanceClient,
    execution_engine: execution.ExecutionEngine,
    symbols: std.ArrayList([]const u8),
    thread: ?std.Thread = null,
    running: std.atomic.Value(bool),

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !TraderDaemon {
        const ex_cfg = config.trader.exchange;
        const is_testnet = std.mem.eql(u8, config.trader.mode, "paper");

        const binance_client = exchange.BinanceClient.init(
            allocator,
            ex_cfg.spot_api_key,
            ex_cfg.spot_secret_key,
            is_testnet
        );

        var execution_engine = execution.ExecutionEngine.init(allocator, config);

        var symbols = std.ArrayList([]const u8).init(allocator);
        // Default target list (in real version, this could fetch dynamically)
        try symbols.append("BTCUSDT");
        try symbols.append("ETHUSDT");
        try symbols.append("SOLUSDT");

        return TraderDaemon{
            .allocator = allocator,
            .config = config,
            .binance_client = binance_client,
            .execution_engine = execution_engine,
            .symbols = symbols,
            .running = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *TraderDaemon) void {
        self.stop();
        self.symbols.deinit();
        self.execution_engine.deinit();
    }

    pub fn start(self: *TraderDaemon) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, loop, .{self});
    }

    pub fn stop(self: *TraderDaemon) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);
        if (self.thread) |th| {
            th.join();
            self.thread = null;
        }
    }

    fn loop(self: *TraderDaemon) void {
        const interval_ms: u64 = 60_000; // 1 minute per cycle

        while (self.running.load(.acquire)) {
            const start_time = std.time.milliTimestamp();

            // Run one iteration of the entire trading logic
            self.tick() catch |err| {
                std.log.err("Trader tick error: {}", .{err});
            };

            const elapsed = std.time.milliTimestamp() - start_time;
            if (elapsed < interval_ms) {
                // Sleep until next minute tick
                const sleep_ms = interval_ms - @as(u64, @intCast(elapsed));
                std.time.sleep(sleep_ms * std.time.ns_per_ms);
            }
        }
    }

    fn tick(self: *TraderDaemon) !void {
        // Create an arena allocator for this specific tick to ensure zero fragmentation
        // and blazing fast memory resets.
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const tick_allocator = arena.allocator();

        for (self.symbols.items) |symbol| {
            // 1. Fetch Market Data
            const klines = try self.binance_client.getKlines(symbol, "1h", 100);
            defer self.allocator.free(klines); // Klines allocated with primary allocator from getKlines

            if (klines.len < 60) continue; // Not enough data for MA60

            // 2. Evaluate Strategy
            const signal = try strategy.evaluate(tick_allocator, self.config, klines);

            // 3. Risk Management & Execution
            if (signal == .Buy) {
                const position_size_usd = self.config.trader.paper.initial_usdt * self.config.trader.risk.position_ratio;
                try self.execution_engine.executeMarketOrder(symbol, .Buy, position_size_usd);
                std.log.info("Executed BUY for {s} at ~{d}", .{symbol, klines[klines.len - 1].close});
            } else if (signal == .Sell) {
                // Check if we have position to sell, etc.
                try self.execution_engine.closePosition(symbol);
                std.log.info("Executed SELL/CLOSE for {s} at ~{d}", .{symbol, klines[klines.len - 1].close});
            }
        }

        // 4. Update trailing stops and stop losses for open positions
        try self.execution_engine.manageExits();
    }
};
