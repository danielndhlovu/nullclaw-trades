const std = @import("std");
const Config = @import("../config.zig").Config;
const Position = @import("execution.zig").Position;

/// Calculates the optimal position size based on the Kelly Criterion.
pub fn calculateKellySize(win_rate: f64, win_loss_ratio: f64, max_risk: f64) f64 {
    // Kelly Formula: f* = W - ((1 - W) / R)
    // W = Win probability
    // R = Win/Loss ratio (average win / average loss)

    if (win_loss_ratio <= 0) return 0;

    const kelly_pct = win_rate - ((1.0 - win_rate) / win_loss_ratio);

    // Half-Kelly is generally safer for crypto due to fat tails
    const safe_kelly = kelly_pct / 2.0;

    // Cap at max risk threshold
    return @max(0.0, @min(safe_kelly, max_risk));
}

/// Evaluates if a position should trigger the break-even mechanism (moving SL to entry)
pub fn checkBreakEven(position: *Position, current_price: f64, break_even_threshold_pct: f64) bool {
    if (position.side == .Buy) {
        const profit_pct = (current_price - position.entry_price) / position.entry_price;
        if (profit_pct >= break_even_threshold_pct) {
            position.stop_loss = position.entry_price; // Move SL to entry
            return true;
        }
    } else {
        const profit_pct = (position.entry_price - current_price) / position.entry_price;
        if (profit_pct >= break_even_threshold_pct) {
            position.stop_loss = position.entry_price; // Move SL to entry
            return true;
        }
    }
    return false;
}
