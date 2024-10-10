const std = @import("std");
const time = std.time;

pub const Action = enum(u4) {
    None, // 0
    Pause, // 1
    Resume, // 2
    Quit, // 3
    Insert, // 4
};
pub const Argument = [5]type{
    null,
    null,
    null,
    null,
    std.meta.Tuple(Pattern, u16, u16),
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
    // other
    plague,
};

pub const Client = struct {
    id: u64,
    ptr: *anyopaque, // can we use @This here?
    updateStateFn: *fn ([ROWS][COLS]u8, bool, u64) void,

    pub fn updateState(self: *Client, grid_vals: [ROWS][COLS]u8, is_paused: bool, t: u64) void {
        self.updateStateFn(grid_vals, is_paused, t);
    }
};

pub const ROWS: u16 = 256;
pub const COLS: u16 = 256;
pub const TICK_US: i64 = 100000; // 100k micro-seconds = 0.1 seconds

var client: ?Client = null;
var grid: [ROWS][COLS]u8 = undefined;
var sums: [ROWS][COLS]u8 = undefined;
var paused = true;
var tick: u64 = 0;
var dt: i64 = 0;

var viewer: *fn ([ROWS][COLS]u8, bool, u64) void = undefined;
pub fn addViewer(viewFn: *fn ([ROWS][COLS]u8, bool, u64) void) void {
    viewer = viewFn;
}

pub fn addClient(c: Client) void {
    client = c;
}

pub fn run() !void {
    while (true) {
        const tick_start = time.microTimestamp();
        const action = processRequests();
        switch (action) {
            Action.None => {},
            Action.Pause => paused = true,
            Action.Resume => paused = false,
            Action.Quit => return,
            Action.Insert => {
                // can we use the below function from std.mem to convert arguments from bytes to a tuple of the correct type?
                // bytesToValue(comptime T: type, bytes: anytype) T
                insert(Pattern.cell, 100, 100, false);
            },
        }

        if (!paused) {
            // TODO: process input
            updateState();
            publishState();
        }

        dt = time.microTimestamp() - tick_start;

        const t_delay_ns = if (dt < TICK_US) @as(u64, @intCast(TICK_US - dt)) else 0;
        time.sleep(1000 * t_delay_ns);
        tick += 1;
    }
}

// pub fn loadExample() void {
//     insert(Pattern.toad, 50, 30, false);
//     insert(Pattern.blinker, 30, 150, false);
//     insert(Pattern.glider, 20, 44, false);
//     insert(Pattern.lwss, 5, 5, false);
//     insert(Pattern.plague, 344, 144, false);
//     insert(Pattern.plague, 159, 69, true);
// }

// pub fn loadRandomSeed() void {
//     // TODO: implement this
// }

// TODO: add input (requests from clients)
// environmental rules are applied first, then input is processed
fn updateState() void {
    // compute neighbourhood sums first
    // TODO: can we somehow change the below loops so the captured i & j are u16 not u64?
    // That would allow rowSum3 to be called with u16 arguments
    for (0..ROWS) |i| {
        for (0..COLS) |j| {
            const i_above = if (i > 0) i - 1 else ROWS - 1;
            const i_below = if (i < ROWS - 1) i + 1 else 0;
            sums[i][j] = rowSum3(i, j) + rowSum3(i_above, j) + rowSum3(i_below, j);
        }
    }

    // update state only after computing all neighbourhood sums
    for (0..ROWS) |i| {
        for (0..COLS) |j| {
            grid[i][j] = switch (sums[i][j]) {
                3 => 1,
                2 => grid[i][j],
                else => 0,
            };
        }
    }

    // TODO: process players' input here
}

// TODO: add a proper implementation for a multiplayer version
// clients send requests to the game server, and they are processed later
fn processRequests() Action {
    return currentAction;
}

var currentAction: Action = Action.None;
var currentArgs: []u8 = undefined;

// TODO: It would be nice if we had a more robust way of passing arguments in here
// Can we do something that is efficient + safe?

fn publishState() void {}

fn insert(p: Pattern, i: u16, j: u16, transpose: bool) void {
    var i_offsets: []const u16 = undefined;
    var j_offsets: []const u16 = undefined;

    switch (p) {
        Pattern.cell => {
            i_offsets = &.{0};
            j_offsets = &.{0};
        },
        Pattern.block => {
            i_offsets = &.{ 0, 0, 1, 1 };
            j_offsets = &.{ 0, 1, 0, 1 };
        },
        Pattern.loaf => {
            i_offsets = &.{ 0, 0, 1, 1, 2, 2, 3 };
            j_offsets = &.{ 1, 2, 0, 3, 1, 3, 2 };
        },
        Pattern.tub => {
            i_offsets = &.{ 0, 1, 1, 2 };
            j_offsets = &.{ 1, 0, 2, 1 };
        },
        Pattern.blinker => {
            i_offsets = &.{ 0, 0, 0 };
            j_offsets = &.{ 0, 1, 2 };
        },
        Pattern.toad => {
            i_offsets = &.{ 0, 0, 0, 1, 1, 1 };
            j_offsets = &.{ 1, 2, 3, 0, 1, 2 };
        },
        Pattern.pentadecathlon => {
            i_offsets = &.{ 0, 1, 2, 2, 3, 4, 5, 6, 7, 7, 8, 9 };
            j_offsets = &.{ 1, 1, 0, 2, 1, 1, 1, 1, 0, 2, 1, 1 };
        },
        Pattern.glider => {
            i_offsets = &.{ 0, 1, 2, 2, 2 };
            j_offsets = &.{ 1, 2, 0, 1, 2 };
        },
        Pattern.lwss => {
            i_offsets = &.{ 0, 0, 0, 0, 1, 1, 2, 3, 3 };
            j_offsets = &.{ 1, 2, 3, 4, 0, 4, 4, 0, 3 };
        },
        Pattern.mwss => {
            i_offsets = &.{ 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3 };
            j_offsets = &.{ 1, 2, 0, 1, 3, 4, 5, 1, 2, 3, 4, 5, 2, 3, 4 };
        },
        Pattern.plague => {
            i_offsets = &.{ 0, 0, 0, 1, 2, 3, 3, 3, 3, 5, 5, 5, 6, 6, 6, 8, 8, 8, 9, 10, 11, 12, 12 };
            j_offsets = &.{ 0, 1, 2, 1, 1, 0, 1, 2, 3, 0, 1, 2, 0, 1, 2, 0, 1, 2, 1, 1, 0, 1, 2 };
        },
    }

    if (transpose) {
        setCellVals(1, i, j, j_offsets, i_offsets);
    } else {
        setCellVals(1, i, j, i_offsets, j_offsets);
    }
}

fn rowSum3(i: usize, j: usize) u8 {
    const j_left = if (j > 0) j - 1 else COLS - 1;
    const j_right = if (j < COLS - 1) j + 1 else 0;
    return grid[i][j] + grid[i][j_left] + grid[i][j_right];
}

fn setCellVals(val: u8, row: u16, col: u16, row_offsets: []const u16, col_offsets: []const u16) void {
    for (0..row_offsets.len) |k|
        grid[(row + row_offsets[k]) % ROWS][(col + col_offsets[k]) % COLS] = val;
}
