pub const ROWS: i32 = 256;
pub const COLS: i32 = 256;

pub const Request = struct {
    action: Action,
    arguments: Parameters,
};

pub const Action = enum(u4) {
    None, // 0
    Pause, // 1
    Unpause, // 2
    Quit, // 3
    Insert, // 4
};

pub const Parameters = union(Action) {
    None: null,
    Pause: null,
    Unpause: null,
    Quit: null,
    Insert: .{ Pattern, i32 },
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
    &.{
        [2]i8{ 0, 0 },
    },
    &.{
        [2]i8{ 0, 0 },
        [2]i8{ 0, 1 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 1 },
    },
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 3 },
        [2]i8{ 2, 1 },
        [2]i8{ 2, 3 },
        [2]i8{ 3, 2 },
    },
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 2 },
        [2]i8{ 2, 1 },
    },
    &.{
        [2]i8{ 0, 0 },
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
    },
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 0, 2 },
        [2]i8{ 0, 3 },
        [2]i8{ 1, 0 },
        [2]i8{ 1, 1 },
        [2]i8{ 1, 2 },
    },
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
    &.{
        [2]i8{ 0, 1 },
        [2]i8{ 1, 2 },
        [2]i8{ 2, 0 },
        [2]i8{ 2, 2 },
        [2]i8{ 2, 2 },
    },
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
