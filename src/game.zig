const std = @import("std");
const client = @import("client.zig");
const schema = @import("schema.zig");
const rand = std.rand;
const time = std.time;
const Action = schema.Action;
const Pattern = schema.Pattern;
const ROWS = schema.ROWS;
const COLS = schema.COLS;
const MAX_TICK_MS: u32 = 1000;
const GAME_SPEEDS = [_]u8{ 1, 2, 5, 10, 20, 50, 100, 200 };

var cell_values: [ROWS * COLS]u1 = undefined; // is there any point using u1 here?
var rng = std.rand.DefaultPrng.init(0);
var sdl_client: client.SdlClient = undefined;
var speed_index: u8 = 3;
var paused = false;
var quit = false;
var tick: u64 = 0;
var dt: i64 = 0;

pub fn addClient(cl: client.SdlClient) !void {
    sdl_client = cl;
}

pub fn run() !void {
    while (!quit) {
        const t_frame_us = 1000 * MAX_TICK_MS / GAME_SPEEDS[speed_index];
        const tick_start = time.microTimestamp();
        if (!paused) updateState();
        processInputs();
        publishState();
        dt = time.microTimestamp() - tick_start;
        // sleep for a moment to achieve desired frame time
        const t_delay_us = if (dt < t_frame_us) @as(u64, @intCast(t_frame_us - dt)) else 0;
        time.sleep(t_delay_us * time.ns_per_us);
        tick = tick +| 1; // we'll all be dead before this saturates lol
    }
}

pub fn loadRandomSeed(seed: u64, density: f32) !void {
    if (density < 0.0 or density > 1.0)
        return error.InvalidDensity;

    const density_factor: f32 = 1.0 / @as(f32, @floatFromInt(std.math.maxInt(u64)));
    rng.seed(seed);

    for (0..cell_values.len) |n| {
        const x = density_factor * @as(f32, @floatFromInt(rng.next()));
        cell_values[n] = if (x > density) 1 else 0;
    }
}

// applies environmental rules
fn updateState() void {
    var neighbourhood_sums: [ROWS * COLS]u3 = undefined;
    for (0..ROWS * COLS) |n| {
        const adj_indices = getAdjacentIndices(@intCast(n));
        const neighbourhood_vals = @Vector(8, u3){
            cell_values[adj_indices[0]],
            cell_values[adj_indices[1]],
            cell_values[adj_indices[2]],
            cell_values[adj_indices[3]],
            cell_values[adj_indices[4]],
            cell_values[adj_indices[5]],
            cell_values[adj_indices[6]],
            cell_values[adj_indices[7]],
        };
        neighbourhood_sums[n] = @reduce(.Add, neighbourhood_vals);
    }

    for (0..ROWS * COLS) |n| {
        cell_values[n] = switch (neighbourhood_sums[n]) {
            3 => 1,
            2 => cell_values[n],
            else => 0,
        };
    }
}

// applies player inputs
fn processInputs() void {
    const inputs = sdl_client.getRequests();

    for (inputs) |req| {
        switch (req.action) {
            Action.Quit => quit = true,
            Action.Pause => paused = !paused,
            Action.AdjustSpeed => {
                const new_index = @as(i8, @intCast(speed_index)) + req.arguments.AdjustSpeed;
                if (0 <= new_index and new_index < GAME_SPEEDS.len) speed_index = @as(u8, @intCast(new_index));
            },
            Action.Insert => {
                const n = req.arguments.Insert.y * COLS + req.arguments.Insert.x;
                insert(req.arguments.Insert.pattern, n);
            },
            Action.None => {},
        }
    }
}

fn publishState() void {
    sdl_client.drawState(cell_values[0..], paused, tick);
}

fn insert(p: Pattern, n: i32) void {
    const offsets = schema.pattern_offsets[@intFromEnum(p)];
    setCellVals(n, offsets, 1);
}

fn getAdjacentIndices(n: i32) [8]u32 {
    const row_0 = [3]u32{ wIndex(n, -1, -1), wIndex(n, -1, 0), wIndex(n, -1, 1) };
    const row_1 = [2]u32{ wIndex(n, 0, -1), wIndex(n, 0, 1) };
    const row_2 = [3]u32{ wIndex(n, 1, -1), wIndex(n, 1, 0), wIndex(n, 1, 1) };
    return row_0 ++ row_1 ++ row_2;
}

fn setCellVals(n: i32, offsets: []const [2]i8, val: u1) void {
    for (offsets) |offset| {
        const cell_index = wIndex(n, offset[0], offset[1]);
        cell_values[cell_index] = val;
    }
}

fn wIndex(n: i32, row_offset: i8, col_offset: i8) u32 {
    const index = n + row_offset * @as(i32, @intCast(COLS)) + col_offset;
    return @intCast(@mod(index, ROWS * COLS));
}

// tests
const testing = std.testing;

test "test index wrapping" {
    const p_000 = wIndex(0, 0, 0);
    try testing.expectEqual(0, p_000);
    const p_001 = wIndex(0, 0, 1);
    try testing.expectEqual(1, p_001);
    const p_010 = wIndex(0, 1, 0);
    try testing.expectEqual(@as(u32, @intCast(COLS)), p_010);
}

test "test set vals" {
    const offsets = [_][2]i8{
        [_]i8{ -1, -1 },
        [_]i8{ -1, 0 },
        [_]i8{ 0, -1 },
    };
    setCellVals(401, offsets[0..], 1);

    const adj_indices = getAdjacentIndices(401);
    try testing.expectEqual(adj_indices.len, 8);
    var adj_sum: u3 = 0;
    for (adj_indices) |n|
        adj_sum += cell_values[n];

    try testing.expectEqual(3, adj_sum);
}

test "test state update" {
    insert(Pattern.cell, 300);
    try testing.expectEqual(1, cell_values[300]);
    try testing.expectEqual(0, cell_values[301]);

    updateState();
    try testing.expectEqual(0, cell_values[300]);
    try testing.expectEqual(0, cell_values[301]);
}
