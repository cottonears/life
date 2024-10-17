const std = @import("std");
const game = @import("game.zig");
const client = @import("client.zig");

pub fn main() !void {
    // TODO: add command line args for hard-coded params in this module
    const rows = 360;
    const cols = 640;
    const cell_size = 4;

    var sdlc = try client.SdlClient.init("Life", cell_size);
    defer sdlc.deinit();
    game.subscribe(sdlc.getSubscriptionHandler()) catch |ie| {
        std.debug.print("Error occurred when initialising game: {}\n", .{ie});
        return;
    };
    game.start(rows, cols, 0.21, 43712) catch |re| {
        std.debug.print("Error occured while running game: {}\n", .{re});
        return;
    };
}
