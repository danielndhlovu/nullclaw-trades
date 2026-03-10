const std = @import("std");
const Config = @import("../config.zig").Config;
const ExecutionEngine = @import("execution.zig").ExecutionEngine;
const http_util = @import("../http_util.zig");

/// Simple HTTP Server to expose real-time Trading State
/// This acts as a replacement for the Express.js Web Dashboard.
pub const TraderWebDashboard = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    engine: *const ExecutionEngine,
    server: ?std.net.Server = null,
    thread: ?std.Thread = null,
    running: std.atomic.Value(bool),

    pub fn init(allocator: std.mem.Allocator, config: *const Config, engine: *const ExecutionEngine) TraderWebDashboard {
        return .{
            .allocator = allocator,
            .config = config,
            .engine = engine,
            .running = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *TraderWebDashboard) void {
        self.stop();
    }

    pub fn start(self: *TraderWebDashboard, port: u16) !void {
        if (self.running.load(.acquire)) return;

        const address = try std.net.Address.parseIp4("127.0.0.1", port);
        self.server = try address.listen(.{ .reuse_address = true });

        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, serveLoop, .{self});

        std.log.info("Trader Web Dashboard running at http://127.0.0.1:{d}", .{port});
    }

    pub fn stop(self: *TraderWebDashboard) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);
        if (self.server) |*srv| {
            // Unblocking the accept loop by connecting to it once, or just closing
            srv.deinit();
            self.server = null;
        }

        if (self.thread) |th| {
            th.join();
            self.thread = null;
        }
    }

    fn serveLoop(self: *TraderWebDashboard) void {
        while (self.running.load(.acquire)) {
            var srv = self.server orelse break;

            // Accept incoming HTTP connection
            const connection = srv.accept() catch |err| {
                if (err == error.SocketNotListening) break;
                continue;
            };

            self.handleConnection(connection) catch |err| {
                std.log.err("Dashboard connection error: {}", .{err});
            };
        }
    }

    fn handleConnection(self: *TraderWebDashboard, connection: std.net.Server.Connection) !void {
        defer connection.stream.close();

        var read_buf: [1024]u8 = undefined;
        const bytes_read = try connection.stream.read(&read_buf);
        if (bytes_read == 0) return;

        // Extremely basic HTTP routing just for /api/positions
        if (std.mem.indexOf(u8, read_buf[0..bytes_read], "GET /api/positions")) |_| {
            try self.sendPositionsJson(connection.stream);
        } else {
            // Default 404
            const not_found = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n";
            try connection.stream.writeAll(not_found);
        }
    }

    fn sendPositionsJson(self: *TraderWebDashboard, stream: std.net.Stream) !void {
        var response_body = std.ArrayList(u8).init(self.allocator);
        defer response_body.deinit();

        try response_body.appendSlice("[");

        var iter = self.engine.positions.iterator();
        var first = true;
        while (iter.next()) |entry| {
            if (!first) try response_body.appendSlice(",");
            first = false;

            const pos = entry.value_ptr.*;
            const side_str = if (pos.side == .Buy) "Buy" else "Sell";

            try std.fmt.format(response_body.writer(),
                \\{{"symbol":"{s}","side":"{s}","entry_price":{d},"size":{d},"stop_loss":{d},"take_profit":{d}}}
            , .{
                pos.symbol, side_str, pos.entry_price, pos.size, pos.stop_loss, pos.take_profit
            });
        }

        try response_body.appendSlice("]");

        var header_buf: [256]u8 = undefined;
        const header = try std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Connection: close\r\n\r\n",
            .{response_body.items.len}
        );

        try stream.writeAll(header);
        try stream.writeAll(response_body.items);
    }
};
