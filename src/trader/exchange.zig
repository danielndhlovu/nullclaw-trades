const std = @import("std");
const http_util = @import("../http_util.zig");
const json_util = @import("../json_util.zig");

pub const BinanceClientError = error{
    InvalidApiKey,
    NetworkError,
    ApiError,
    ParseError,
};

pub const Kline = struct {
    open_time: u64,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: f64,
    close_time: u64,
    quote_volume: f64,
    trades: u64,
    taker_buy_base_volume: f64,
    taker_buy_quote_volume: f64,
};

pub const BinanceClient = struct {
    allocator: std.mem.Allocator,
    api_key: ?[]const u8,
    secret_key: ?[]const u8,
    base_url: []const u8,

    pub fn init(allocator: std.mem.Allocator, api_key: ?[]const u8, secret_key: ?[]const u8, is_testnet: bool) BinanceClient {
        return .{
            .allocator = allocator,
            .api_key = api_key,
            .secret_key = secret_key,
            .base_url = if (is_testnet) "https://testnet.binance.vision" else "https://api.binance.com",
        };
    }

    pub fn getKlines(self: *BinanceClient, symbol: []const u8, interval: []const u8, limit: u32) ![]Kline {
        var url_buf: [256]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "{s}/api/v3/klines?symbol={s}&interval={s}&limit={d}", .{ self.base_url, symbol, interval, limit });

        const body = http_util.get(self.allocator, url, null) catch return BinanceClientError.NetworkError;
        defer self.allocator.free(body);

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch return BinanceClientError.ParseError;
        defer parsed.deinit();

        if (parsed.value != .array) {
            // Likely an error object returned by Binance
            return BinanceClientError.ApiError;
        }

        const root = parsed.value.array;
        var klines = try self.allocator.alloc(Kline, root.items.len);

        for (root.items, 0..) |item, i| {
            if (item != .array) return BinanceClientError.ParseError;
            const arr = item.array;
            if (arr.items.len < 11) return BinanceClientError.ParseError;

            klines[i] = .{
                .open_time = if (arr.items[0] == .integer) @intCast(arr.items[0].integer) else return BinanceClientError.ParseError,
                .open = try std.fmt.parseFloat(f64, arr.items[1].string),
                .high = try std.fmt.parseFloat(f64, arr.items[2].string),
                .low = try std.fmt.parseFloat(f64, arr.items[3].string),
                .close = try std.fmt.parseFloat(f64, arr.items[4].string),
                .volume = try std.fmt.parseFloat(f64, arr.items[5].string),
                .close_time = if (arr.items[6] == .integer) @intCast(arr.items[6].integer) else return BinanceClientError.ParseError,
                .quote_volume = try std.fmt.parseFloat(f64, arr.items[7].string),
                .trades = if (arr.items[8] == .integer) @intCast(arr.items[8].integer) else return BinanceClientError.ParseError,
                .taker_buy_base_volume = try std.fmt.parseFloat(f64, arr.items[9].string),
                .taker_buy_quote_volume = try std.fmt.parseFloat(f64, arr.items[10].string),
            };
        }

        return klines;
    }
};
