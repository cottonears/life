const std = @import("std");
const schema = @import("schema.zig");
const math = std.math;
const rand = std.rand;
const time = std.time;

pub const Request = struct {
    action: Action,
    arguments: Parameters,
};

pub const Subscriber = struct {
    ptr: *anyopaque,
    frequency: u8 = 1,
    state_handler: *const fn (ptr: *anyopaque, t: u64) void,
};

pub const Action = enum(u8) {
    None,
    Pause,
    Quit,
    AdjustSpeed,
    LoadSeed,
    Insert,
};

pub const Parameters = union(Action) {
    None: void,
    Pause: void,
    Quit: void,
    AdjustSpeed: i4,
    LoadSeed: struct { density: f32, seed: usize },
    Insert: struct { offsets: [][2]i8, x: i32, y: i32 },
};

const K = 1000;
const MAX_SUBSCRIBERS: u8 = 2;
const STATE_TIMES_US = [_]u32{ 1000 * K, 500 * K, 200 * K, 100 * K, 50 * K, 20 * K, 10 * K, 5 * K, 2 * K, 1 * K };
const INITAL_SPEED: u8 = 6;
// NOTE: By convention, the public variables below should not be mutated by other modules.
//       This allows state to be 'broadcast' without copying these variables' values.
pub var cell_values: [grid_rows * grid_cols]u8 = [_]u8{0} ** (grid_rows * grid_cols); // TODO: make slice!
pub const grid_rows: u32 = 360; // TODO: make var
pub const grid_cols: u32 = 640; // TODO: make var
pub var paused = false;
pub var quit = false;
pub var speed: u8 = INITAL_SPEED;
pub var t: u64 = 0;

var dt_us: i64 = 0;
var dt_sum: i64 = 0;
var frames: i64 = 0;
var rng = std.rand.DefaultPrng.init(0);
var request_queue: [8]Request = undefined;
var rq_index: u8 = 0;
var subscribers: [MAX_SUBSCRIBERS]Subscriber = undefined;
var sub_index: u8 = 0;
var tick_us: i64 = @intCast(STATE_TIMES_US[INITAL_SPEED]);

pub fn start(rows: u16, cols: u16, density: f32, seed: u64) !void {
    // grid_rows = grid_rows;
    // grid_cols = grid_cols;
    _ = rows;
    _ = cols;
    //cell_values = &[_]u8{0} ** (rows * cols);
    loadSeed(density, seed);

    while (!quit) {
        const tick_start = time.microTimestamp();
        if (!paused) {
            updateGrid();
            processRequests(false);
        }
        dt_us = time.microTimestamp() - tick_start;
        const t_delay_us = if (dt_us < tick_us) @as(u64, @intCast(tick_us - dt_us)) else 0;
        time.sleep(t_delay_us * time.ns_per_us);
        dt_sum += dt_us;
        frames += 1;
    }
    const dt_avg: f32 = @as(f32, @floatFromInt(dt_sum)) / @as(f32, @floatFromInt(frames));
    std.debug.print("rendered {} frames; dt_avg = {:.2} us\n", .{ frames, dt_avg });
}

// randomly sets the cell values with P(alive) = density
// can be used to clear all cells (use density 0)
pub fn loadSeed(density: f32, seed: u64) void {
    std.debug.print("loadSeed({}, {}) called at t = {}\n", .{ density, seed, t });
    if (density == 0.0) {
        cell_values = ([_]u8{0} ** (grid_rows * grid_cols));
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

pub fn makeRequest(req: Request) bool {
    if (rq_index >= request_queue.len) return false;
    request_queue[rq_index] = req;
    rq_index += 1;
    // single-player hack that ensures all requests are processed immediately and subscribers are notified
    processRequests(true);
    return true;
}

pub fn subscribe(sub: Subscriber) !void {
    if (sub_index >= subscribers.len) return error.Oversubscribed;
    subscribers[sub_index] = sub;
    sub_index += 1;
}

// applies environmental rules and updates the cells
fn updateGrid() void {
    var neighbourhood_sums: [grid_rows * grid_cols]u8 = undefined;
    for (0..grid_rows * grid_cols) |n| {
        const adj_indices = getAdjacentIndices(@intCast(n));
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

    for (0..grid_rows * grid_cols) |n| {
        cell_values[n] = switch (neighbourhood_sums[n]) {
            3 => 1,
            2 => cell_values[n],
            else => 0,
        };
    }
}

// processes input requests and publishes state updates to subscribers
// all subscribers are notified if force_publish is true
// otherwise subscribers are notified depending on their subscription frequency
fn processRequests(force_publish: bool) void {
    for (0..rq_index) |i| {
        const req = request_queue[i];
        switch (req.action) {
            Action.Quit => quit = true,
            Action.Pause => paused = !paused,
            Action.LoadSeed => {
                loadSeed(0, 0);
                t = 0;
            },
            Action.AdjustSpeed => {
                const new_index = @as(i8, @intCast(speed)) + req.arguments.AdjustSpeed;
                if (0 <= new_index and new_index < STATE_TIMES_US.len) {
                    speed = @as(u8, @intCast(new_index));
                    tick_us = @intCast(STATE_TIMES_US[speed]);
                }
            },
            Action.Insert => {
                const n = req.arguments.Insert.y * grid_cols + req.arguments.Insert.x;
                setCellVals(n, req.arguments.Insert.offsets, 1);
            },
            Action.None => {},
        }
    }

    rq_index = 0;
    publishState(force_publish);
}

//  publishes state to subscribers
fn publishState(force: bool) void {
    for (0..sub_index) |i| {
        const sub = subscribers[i];
        if (force or t % sub.frequency == 0)
            sub.state_handler(sub.ptr, t);
    }
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
    const index = n + row_offset * @as(i32, @intCast(grid_cols)) + col_offset;
    return @intCast(@mod(index, grid_rows * grid_cols));
}

// tests
const testing = std.testing;

test "test index wrapping" {
    const p_000 = wIndex(0, 0, 0);
    try testing.expectEqual(0, p_000);
    const p_001 = wIndex(0, 0, 1);
    try testing.expectEqual(1, p_001);
    const p_010 = wIndex(0, 1, 0);
    try testing.expectEqual(@as(u32, @intCast(grid_cols)), p_010);
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
    var adj_sum: u8 = 0;
    for (adj_indices) |n|
        adj_sum += cell_values[n];

    try testing.expectEqual(3, adj_sum);
}

test "test state update" {
    const cell_offset = [_][2]i8{[_]i8{ 0, 0 }};
    loadSeed(0, 0);
    setCellVals(300, &cell_offset, 1);
    try testing.expectEqual(1, cell_values[300]);
    try testing.expectEqual(0, cell_values[301]);

    updateGrid();
    try testing.expectEqual(0, cell_values[300]);
    try testing.expectEqual(0, cell_values[301]);
}
