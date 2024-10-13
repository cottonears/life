pub const ROWS: u32 = 300;
pub const COLS: u32 = 512;

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
    cell, // 0
    block, // 1
    toad, // 2
    pulsar, // 3
    monogram, // 4
    pentadecathlon, // 5
    glider, // 6
    mwss, // 7

    weekender, // 8
    unknown, // 9
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
    // toad
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
        [2]i8{ 0, 3 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 1 },
        [2]i8{ 1, 2 },
    },
    // pulsar
    &.{
        [2]i8{ 0, 2 },
        [2]i8{ 0, 3 },
        [2]i8{ 0, 4 },
        [2]i8{ 0, 8 },
        [2]i8{ 0, 9 },
        [2]i8{ 0, 10 },
        [2]i8{ 2, 0 },
        [2]i8{ 2, 5 },
        [2]i8{ 2, 7 },
        [2]i8{ 2, 12 },
        [2]i8{ 3, 0 },
        [2]i8{ 3, 5 },
        [2]i8{ 3, 7 },
        [2]i8{ 3, 12 },
        [2]i8{ 4, 0 },
        [2]i8{ 4, 5 },
        [2]i8{ 4, 7 },
        [2]i8{ 4, 12 },
        [2]i8{ 5, 2 },
        [2]i8{ 5, 3 },
        [2]i8{ 5, 4 },
        [2]i8{ 5, 8 },
        [2]i8{ 5, 9 },
        [2]i8{ 5, 10 },
        [2]i8{ 7, 2 },
        [2]i8{ 7, 3 },
        [2]i8{ 7, 4 },
        [2]i8{ 7, 8 },
        [2]i8{ 7, 9 },
        [2]i8{ 7, 10 },
        [2]i8{ 8, 0 },
        [2]i8{ 8, 5 },
        [2]i8{ 8, 7 },
        [2]i8{ 8, 12 },
        [2]i8{ 9, 0 },
        [2]i8{ 9, 5 },
        [2]i8{ 9, 7 },
        [2]i8{ 9, 12 },
        [2]i8{ 10, 0 },
        [2]i8{ 10, 5 },
        [2]i8{ 10, 7 },
        [2]i8{ 10, 12 },
        [2]i8{ 12, 2 },
        [2]i8{ 12, 3 },
        [2]i8{ 12, 4 },
        [2]i8{ 12, 8 },
        [2]i8{ 12, 9 },
        [2]i8{ 12, 10 },
    },
    // monogram
    &.{
        [2]i8{ 0, 0 },
        [2]i8{ 0, 1 },
        [2]i8{ 0, 5 },
        [2]i8{ 0, 6 },
        [2]i8{ 1, 1 },
        [2]i8{ 1, 3 },
        [2]i8{ 1, 5 },
        [2]i8{ 2, 1 },
        [2]i8{ 2, 2 },
        [2]i8{ 2, 4 },
        [2]i8{ 2, 5 },
        [2]i8{ 3, 1 },
        [2]i8{ 3, 3 },
        [2]i8{ 3, 5 },
        [2]i8{ 4, 0 },
        [2]i8{ 4, 1 },
        [2]i8{ 4, 5 },
        [2]i8{ 4, 6 },
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
    // weekender
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 14 },
        [2]i8{ 1, 1 },
        [2]i8{ 1, 14 },
        [2]i8{ 2, 0 },
        [2]i8{ 2, 2 },
        [2]i8{ 2, 13 },
        [2]i8{ 2, 15 },
        [2]i8{ 3, 1 },
        [2]i8{ 3, 14 },
        [2]i8{ 4, 1 },
        [2]i8{ 4, 14 },
        [2]i8{ 5, 2 },
        [2]i8{ 5, 6 },
        [2]i8{ 5, 7 },
        [2]i8{ 5, 8 },
        [2]i8{ 5, 9 },
        [2]i8{ 5, 13 },
        [2]i8{ 6, 6 },
        [2]i8{ 6, 7 },
        [2]i8{ 6, 8 },
        [2]i8{ 6, 9 },
        [2]i8{ 7, 2 },
        [2]i8{ 7, 3 },
        [2]i8{ 7, 4 },
        [2]i8{ 7, 5 },
        [2]i8{ 7, 10 },
        [2]i8{ 7, 11 },
        [2]i8{ 7, 12 },
        [2]i8{ 7, 13 },
        [2]i8{ 9, 4 },
        [2]i8{ 9, 11 },
        [2]i8{ 10, 5 },
        [2]i8{ 10, 6 },
        [2]i8{ 10, 9 },
        [2]i8{ 10, 10 },
    },
    // unknown
    &.{},
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
