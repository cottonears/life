pub const ROWS: u32 = 256;
pub const COLS: u32 = 400;

pub const Request = struct {
    action: Action,
    arguments: Parameters,
};

pub const Action = enum(u4) {
    None,
    Pause,
    Quit,
    Clear,
    AdjustSpeed,
    Insert,
};

pub const Parameters = union(Action) {
    None: void,
    Pause: void,
    Quit: void,
    Clear: void,
    AdjustSpeed: i4,
    Insert: struct { pattern: Pattern, x: i32, y: i32 },
};

pub const Pattern = enum(u8) {
    cell,
    // still lifes
    block,
    loaf,
    tub,
    // oscillators
    blinker,
    toad,
    pentadecathlon,
    // spaceships
    glider,
    lwss,
    mwss,
};

pub const pattern_offsets: [10][]const [2]i8 = .{
    // cell
    &.{
        [2]i8{ 0, 0 },
    },
    // block
    &.{
        [2]i8{ 0, 0 },
        [2]i8{ 0, 1 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 1 },
    },
    // loaf
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 3 },
        [2]i8{ 2, 1 },
        [2]i8{ 2, 3 },
        [2]i8{ 3, 2 },
    },
    // tub
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 2 },
        [2]i8{ 2, 1 },
    },
    // blinker
    &.{
        [2]i8{ 0, 0 },
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
    },
    // toad
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
        [2]i8{ 0, 3 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 1 },
        [2]i8{ 1, 2 },
    },
    // pentadecathlon
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 1, 1 },
        [2]i8{ 2, 0 },
        [2]i8{ 2, 2 },
        [2]i8{ 3, 1 },
        [2]i8{ 4, 1 },
        [2]i8{ 5, 1 },
        [2]i8{ 6, 1 },
        [2]i8{ 7, 0 },
        [2]i8{ 7, 2 },
        [2]i8{ 8, 1 },
        [2]i8{ 9, 1 },
    },
    // glider
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 1, 2 },
        [2]i8{ 2, 0 },
        [2]i8{ 2, 1 },
        [2]i8{ 2, 2 },
    },
    // lwss
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
        [2]i8{ 0, 3 },
        [2]i8{ 0, 4 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 4 },
        [2]i8{ 2, 4 },
        [2]i8{ 3, 0 },
        [2]i8{ 3, 3 },
    },
    // mwss
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 1 },
        [2]i8{ 1, 3 },
        [2]i8{ 1, 4 },
        [2]i8{ 1, 5 },
        [2]i8{ 2, 1 },
        [2]i8{ 2, 2 },
        [2]i8{ 2, 3 },
        [2]i8{ 2, 4 },
        [2]i8{ 2, 5 },
        [2]i8{ 3, 2 },
        [2]i8{ 3, 3 },
        [2]i8{ 3, 4 },
    },
};

const std = @import("std");
const testing = std.testing;

test "request test" {
    const req1 = Request{
        .action = Action.None,
        .arguments = Parameters{ .None = {} },
    };
    try testing.expectEqual(Action.None, req1.action);
    std.debug.print("req1 = {}({})\n", .{ req1.action, req1.arguments });

    const req2 = Request{
        .action = Action.Insert,
        .arguments = Parameters{ .Insert = .{ .pattern = Pattern.glider, .x = 100, .y = 200 } },
    };
    try testing.expectEqual(Action.Insert, req2.action);
    try testing.expectEqual(Pattern.glider, req2.arguments.Insert.pattern);
    try testing.expectEqual(100, req2.arguments.Insert.x);
    try testing.expectEqual(200, req2.arguments.Insert.y);
    std.debug.print("req2 = {}({})\n", .{ req2.action, req2.arguments });
}
