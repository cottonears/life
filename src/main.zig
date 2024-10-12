const std = @import("std");
const game = @import("game.zig");
const client = @import("client.zig");

pub fn main() !void {
    // TODO: load some config file with basic settings
    // cell sizes
    // log-file location
    // add command line arg for initial state
    var sdlc = try client.SdlClient.init("Life", 6);
    defer sdlc.deinit();

    game.addClient(sdlc) catch |ie| {
        std.debug.print("Error occurred when initialising game: {}\n", .{ie});
        return;
    };
    game.run() catch |re| {
        std.debug.print("Error occured while running game: {}\n", .{re});
        return;
    };
}
