const std = @import("std");
const Config = @import("../config.zig").Config;
const agent = @import("../agent.zig"); // Interface into nullclaw's core LLM agent
const Session = @import("../session.zig").Session;

pub const AiSentimentResult = enum {
    Bullish,
    Bearish,
    Neutral,
    ExtremePanic, // Trigger circuit breaker
};

pub const AiAnalyst = struct {
    allocator: std.mem.Allocator,
    config: *const Config,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) AiAnalyst {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Feeds news headlines or Reddit text to the configured LLM to gauge market sentiment.
    pub fn analyzeSentiment(self: *AiAnalyst, market_data_context: []const u8) !AiSentimentResult {
        // Create an ephemeral session for the trading daemon to query the LLM
        var session = try Session.init(self.allocator, "trader_daemon", "trader_daemon", null, null);
        defer session.deinit();

        const prompt = try std.fmt.allocPrint(self.allocator,
            \\You are a highly analytical crypto trading engine.
            \\Analyze the following recent market context, news, and indicators.
            \\Respond with EXACTLY ONE WORD from the following list indicating the current sentiment:
            \\[BULLISH, BEARISH, NEUTRAL, PANIC]
            \\
            \\Context:
            \\{s}
        , .{market_data_context});
        defer self.allocator.free(prompt);

        try session.addUserMessage(prompt, null, null);

        // This invokes nullclaw's powerful agent routing and multi-provider system!
        // We use an empty Tools list to force a direct text response.
        const response_text = try agent.runInference(self.allocator, self.config, &session, &.{});
        defer self.allocator.free(response_text);

        if (std.mem.indexOf(u8, response_text, "BULLISH") != null) return .Bullish;
        if (std.mem.indexOf(u8, response_text, "BEARISH") != null) return .Bearish;
        if (std.mem.indexOf(u8, response_text, "PANIC") != null) return .ExtremePanic;

        return .Neutral;
    }
};
