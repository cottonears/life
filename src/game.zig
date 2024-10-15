const std = @import("std");
const client = @import("client.zig");
const schema = @import("schema.zig");
const math = std.math;
const rand = std.rand;
const time = std.time;
const Action = schema.Action;
const Pattern = schema.Pattern;
const K = 1000;
const ROWS = schema.ROWS;
const COLS = schema.COLS;
const FRAME_TIME_US: i32 = 10 * K;
const STATE_TIME_US = [_]u32{ 1000 * K, 500 * K, 200 * K, 100 * K, 50 * K, 20 * K, 10 * K };

var cell_values: [ROWS * COLS]u8 = undefined;
var rng = std.rand.DefaultPrng.init(0);
var sdl_client: client.SdlClient = undefined;
var speed_index: u8 = 6;
var paused = false;
var quit = false;
var state_tick: u64 = 0;
var dt_us: i64 = 0;
var dt_sum: i64 = 0;
var frames: i64 = 0;
// NOTE: pre-computing neighbourhoods improved performance and increased memory usage
//var cell_neighbours: [ROWS * COLS][8]u32 = undefined;

pub fn addClient(cl: client.SdlClient) !void {
    sdl_client = cl;
}

pub fn run(density: f32, seed: u64) !void {
    resetCells(density, seed);
    // state is updated depending on the current game speed
    // inputs + rendering are performed every frame (to make more responsive)
    var tick_start = time.microTimestamp();
    while (!quit) {
        const frame_start = time.microTimestamp();
        if (!paused and frame_start > tick_start + STATE_TIME_US[speed_index]) {
            updateState();
            tick_start = time.microTimestamp();
            state_tick = state_tick +| 1;
        }
        processRequests();
        publishState();
        dt_us = time.microTimestamp() - frame_start;
        const t_delay_us = if (dt_us < FRAME_TIME_US) @as(u64, @intCast(FRAME_TIME_US - dt_us)) else 0;
        time.sleep(t_delay_us * time.ns_per_us);
        dt_sum += dt_us;
        frames += 1;
    }
    const dt_avg: f32 = @as(f32, @floatFromInt(dt_sum)) / @as(f32, @floatFromInt(frames));
    std.debug.print("rendered {} frames; dt_avg = {:.2} us\n", .{ frames, dt_avg });
}

// can be used to clear all cells (when density = 0) or load a random seed
pub fn resetCells(density: f32, seed: u64) void {
    if (density == 0.0) {
        cell_values = [_]u8{0} ** (ROWS * COLS);
        return;
    }
    const density_factor: f32 = 1.0 / @as(f32, @floatFromInt(math.maxInt(u64)));
    const clamped_density = math.clamp(density, 0.0, 1.0);
    rng.seed(seed);
    for (0..cell_values.len) |n| {
        const x = density_factor * @as(f32, @floatFromInt(rng.next()));
        cell_values[n] = if (x > clamped_density) 1 else 0;
    }
}

// applies environmental rules
fn updateState() void {
    var neighbourhood_sums: [ROWS * COLS]u8 = undefined;
    for (0..ROWS * COLS) |n| {
        const adj_indices = getAdjacentIndices(@intCast(n));
        //const adj_indices = getAdjacentIndices(@intCast(n));
        const neighbourhood_vals = @Vector(8, u8){
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
fn processRequests() void {
    const reqs = sdl_client.getRequests();
    for (reqs) |req| {
        switch (req.action) {
            Action.Quit => quit = true,
            Action.Pause => paused = !paused,
            Action.Clear => {
                std.debug.print("reset called after tick {}\n", .{state_tick});
                resetCells(0, 0);
                state_tick = 0;
            },
            Action.AdjustSpeed => {
                const new_index = @as(i8, @intCast(speed_index)) + req.arguments.AdjustSpeed;
                if (0 <= new_index and new_index < STATE_TIME_US.len) speed_index = @as(u8, @intCast(new_index));
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
    sdl_client.drawState(cell_values[0..], paused, state_tick);
}

fn insert(p: Pattern, n: i32) void {
    const offsets = schema.pattern_offsets[@intFromEnum(p)];
    setCellVals(n, offsets, 1);
}

fn getAdjacentIndices(n: i32) [8]u32 {
    return [_]u32{
        wIndex(n, -1, -1),
        wIndex(n, -1, 0),
        wIndex(n, -1, 1),
        wIndex(n, 0, -1),
        wIndex(n, 0, 1),
        wIndex(n, 1, -1),
        wIndex(n, 1, 0),
        wIndex(n, 1, 1),
    };
}

fn setCellVals(n: i32, offsets: []const [2]i8, val: u8) void {
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
    resetCells(0, 0);
    insert(Pattern.cell, 300);
    try testing.expectEqual(1, cell_values[300]);
    try testing.expectEqual(0, cell_values[301]);

    updateState();
    try testing.expectEqual(0, cell_values[300]);
    try testing.expectEqual(0, cell_values[301]);
}
