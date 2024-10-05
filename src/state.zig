pub const Pattern = enum {
    // still lifes
    block,
    beehive,
    loaf,
    tub,
    // oscillators
    blinker,
    toad,
    pulsar,
    pentadecathlon,
    // spaceships
    glider,
    lwss,
    mwss,
    hwss,
    // other
    plague,
};

pub const ROWS: u16 = 200;
pub const COLS: u16 = 200;
pub var t: u64 = 0;
pub var cells: [ROWS][COLS]u8 = undefined;
pub var sums: [ROWS][COLS]u8 = undefined;

fn set_cell_values(val: u8, row: u16, col: u16, row_offsets: []const u16, col_offsets: []const u16) !void {
    if (val != 0 and val != 1)
        return error.InvalidValue;
    if (row_offsets.len != col_offsets.len)
        return error.MismatchedArrayLengths;

    for (0..row_offsets.len) |k|
        cells[(row + row_offsets[k]) % ROWS][(col + col_offsets[k]) % COLS] = val;
}

// TODO: allow adding patterns with different more rotations!
pub fn add_pattern(p: Pattern, i: u16, j: u16, rotate: bool) !void {
    var i_offsets: []const u16 = undefined;
    var j_offsets: []const u16 = undefined;
    switch (p) {
        Pattern.block => {
            i_offsets = &.{ 0, 0, 1, 1 };
            j_offsets = &.{ 0, 1, 0, 1 };
        },
        Pattern.beehive => {
            i_offsets = &.{ 0, 0, 1, 1, 2, 2 };
            j_offsets = &.{ 1, 2, 0, 3, 1, 2 };
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
        Pattern.pulsar => {
            i_offsets = &.{ 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9, 10, 10, 10, 10, 12, 12, 12, 12, 12, 12 };
            j_offsets = &.{ 2, 3, 4, 8, 9, 10, 0, 5, 7, 12, 0, 5, 7, 12, 0, 5, 7, 12, 2, 3, 4, 8, 9, 10, 2, 3, 4, 8, 9, 10, 0, 5, 7, 12, 0, 5, 7, 12, 0, 5, 7, 12, 2, 3, 4, 8, 9, 10 };
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

        Pattern.plague => {
            i_offsets = &.{ 0, 0, 0, 1, 2, 3, 3, 3, 3, 5, 5, 5, 6, 6, 6, 8, 8, 8, 9, 10, 11, 12, 12 };
            j_offsets = &.{ 0, 1, 2, 1, 1, 0, 1, 2, 3, 0, 1, 2, 0, 1, 2, 0, 1, 2, 1, 1, 0, 1, 2 };
        },

        else => {
            return error.UnrecognisedPattern;
        },
    }
    if (rotate) {
        try set_cell_values(1, i, j, j_offsets, i_offsets);
    } else {
        try set_cell_values(1, i, j, i_offsets, j_offsets);
    }
}

pub fn update_cells() void {
    for (0..ROWS) |i| {
        for (0..COLS) |j| {
            const im = if (i > 0) i - 1 else ROWS - 1;
            const ip = if (i < ROWS - 1) i + 1 else 0;
            const jm = if (j > 0) j - 1 else COLS - 1;
            const jp = if (j < COLS - 1) j + 1 else 0;
            sums[i][j] = cells[im][jm] + cells[im][j] + cells[im][jp] + cells[i][jm] + cells[i][jp] + cells[ip][jm] + cells[ip][j] + cells[ip][jp];
        }
    }

    for (0..ROWS) |i| {
        for (0..COLS) |j| {
            cells[i][j] = switch (sums[i][j]) {
                3 => 1,
                2 => cells[i][j],
                else => 0,
            };
        }
    }
    t += 1;
}
