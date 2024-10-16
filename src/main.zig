const std = @import("std");
const game = @import("game.zig");
const client = @import("client.zig");

pub fn main() !void {
    // TODO: add command line args for hard-coded params in this module
    var sdlc = try client.SdlClient.init("Life", 4);
    defer sdlc.deinit();

    game.addClient(sdlc) catch |ie| {
        std.debug.print("Error occurred when initialising game: {}\n", .{ie});
        return;
    };
    game.run(0.21, 43712) catch |re| {
        std.debug.print("Error occured while running game: {}\n", .{re});
        return;
    };
}
