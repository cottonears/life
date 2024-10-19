const std = @import("std");
const game = @import("game.zig");
const client = @import("client.zig");

const MAX_SIZE = 4096;

pub fn main() !void {
    // TODO: add command line args for hard-coded params in this module
    const rows = 360;
    const cols = 640;
    const cell_size = 4.0;

    var buff: [2 * MAX_SIZE * MAX_SIZE]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buff);
    const allocator = fba.allocator();

    try game.init(allocator, rows, cols, 0.22, 0);
    defer game.deinit(allocator) catch |e| {
        std.debug.print("Error occurred when de-initialising game: {}\n", .{e});
    };

    var sdlc = try client.SdlClient.init("Life", cell_size);
    defer sdlc.deinit();
    game.subscribe(sdlc.getSubscription()) catch |ie| {
        std.debug.print("Error occurred when initialising game: {}\n", .{ie});
        return;
    };
    game.init(allocator, rows, cols, 0.21, 43712) catch |re| {
        std.debug.print("Error occured while running game: {}\n", .{re});
        return;
    };
}
