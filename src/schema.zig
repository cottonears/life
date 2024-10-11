pub const ROWS: i32 = 400;
pub const COLS: i32 = 512;

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
    // tub,
    // oscillators
    blinker,
    toad,
    pentadecathlon,
    // spaceships
    glider,
    lwss,
    mwss,
};
const o = [2]i8;
pub const pattern_offsets: [10][]const [2]i8 = .{
    &.{o{ 0, 0 }},
    &.{ o{ 0, 0 }, o{ 0, 1 }, o{ 1, 0 }, o{ 1, 1 } },
    &.{ o{ 0, 1 }, o{ 0, 2 }, o{ 1, 0 }, o{ 1, 3 }, o{ 2, 1 }, o{ 2, 3 }, o{ 3, 2 } },
    &.{ o{ 0, 1 }, o{ 1, 0 }, o{ 1, 2 }, o{ 2, 1 } },
    &.{ o{ 0, 0 }, o{ 0, 1 }, o{ 0, 2 } },
    &.{ o{ 0, 1 }, o{ 0, 2 }, o{ 0, 3 }, o{ 1, 0 }, o{ 1, 1 }, o{ 1, 2 } },
    &.{ o{ 0, 1 }, o{ 1, 1 }, o{ 2, 0 }, o{ 2, 2 }, o{ 3, 1 }, o{ 4, 1 }, o{ 5, 1 }, o{ 6, 1 }, o{ 7, 0 }, o{ 7, 2 }, o{ 8, 1 }, o{ 9, 1 } },
    &.{ o{ 0, 1 }, o{ 1, 2 }, o{ 2, 0 }, o{ 2, 2 }, o{ 2, 2 } },
    &.{ o{ 0, 1 }, o{ 0, 2 }, o{ 0, 3 }, o{ 0, 4 }, o{ 1, 0 }, o{ 1, 4 }, o{ 2, 4 }, o{ 3, 0 }, o{ 3, 3 } },
    &.{ o{ 0, 1 }, o{ 0, 2 }, o{ 1, 0 }, o{ 1, 1 }, o{ 1, 3 }, o{ 1, 4 }, o{ 1, 5 }, o{ 2, 1 }, o{ 2, 2 }, o{ 2, 3 }, o{ 2, 4 }, o{ 2, 5 }, o{ 3, 2 }, o{ 3, 3 }, o{ 3, 4 } },
};
