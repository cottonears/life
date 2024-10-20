const std = @import("std");
const schema = @import("schema.zig");
const math = std.math;
const rand = std.rand;
const time = std.time;
const Action = schema.Action;
const Request = schema.Request;
const Parameters = schema.Parameters;
const State = schema.State;

pub var state: State = undefined;
pub var grid_rows: i32 = 0;
pub var grid_cols: i32 = 0;
var num_cells: u64 = undefined;
var rng: rand.Xoshiro256 = undefined;
var sums: []u8 = undefined;

pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !void {
    if (rows == 0 or cols == 0) return error.InvalidGridDimensions;
    grid_rows = rows;
    grid_cols = cols;
    num_cells = @intCast(grid_rows * grid_cols);
    rng = rand.DefaultPrng.init(0);
    state = State{ .cell_values = try allocator.alloc(u8, num_cells) };
    sums = try allocator.alloc(u8, num_cells);
}

pub fn deinit(alloc: std.mem.Allocator) void {
    alloc.free(state.cell_values);
    alloc.free(sums);
}

// randomly sets the cell values with P(alive) = density
pub fn loadSeed(density: f32, seed: u64) void {
    std.debug.print("loadSeed({d:.3}, {}) called at t = {}\n", .{ density, seed, state.t });
    const density_factor: f32 = 1.0 / @as(f32, @floatFromInt(math.maxInt(u64)));
    const clamped_density = math.clamp(density, 0.0, 1.0);
    rng.seed(seed);
    for (0..state.cell_values.len) |n| {
        const x = density_factor * @as(f32, @floatFromInt(rng.next()));
        state.cell_values[n] = if (x < clamped_density) 1 else 0;
    }
}

pub fn insert(x: i32, y: i32, offsets: []const [2]i8) void {
    const n: i32 = y * grid_cols + x;
    setCellVals(n, offsets, 1);
}

pub fn togglePause() void {
    state.paused = !state.paused;
}

// applies environmental rules and updates the cells
pub fn updateGrid() void {
    if (state.paused) return;
    for (0..num_cells) |n| {
        const adj_indices = getAdjacentIndices(@intCast(n));
        const neighbourhood_vals = @Vector(8, u8){
            state.cell_values[adj_indices[0]],
            state.cell_values[adj_indices[1]],
            state.cell_values[adj_indices[2]],
            state.cell_values[adj_indices[3]],
            state.cell_values[adj_indices[4]],
            state.cell_values[adj_indices[5]],
            state.cell_values[adj_indices[6]],
            state.cell_values[adj_indices[7]],
        };
        sums[n] = @reduce(.Add, neighbourhood_vals);
    }

    for (0..state.cell_values.len) |n| {
        state.cell_values[n] = switch (sums[n]) {
            3 => 1,
            2 => state.cell_values[n],
            else => 0,
        };
    }
    state.t += 1;
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
        state.cell_values[cell_index] = val;
    }
}

fn wIndex(n: i32, row_offset: i8, col_offset: i8) u32 {
    const index = n + row_offset * @as(i32, @intCast(grid_cols)) + col_offset;
    return @intCast(@mod(index, grid_rows * grid_cols));
}

// tests
const testing = std.testing;

test "test index wrapping" {
    grid_rows = 10;
    grid_cols = 10;
    const p_000 = wIndex(0, 0, 0);
    try testing.expectEqual(0, p_000);
    const p_001 = wIndex(0, 0, 1);
    try testing.expectEqual(1, p_001);
    const p_010 = wIndex(0, 1, 0);
    try testing.expectEqual(@as(u32, @intCast(grid_cols)), p_010);
}

test "test load" {
    try init(testing.allocator, 100, 100);
    defer deinit(testing.allocator);
    // expect a sum of zero after initialising with density = 0
    loadSeed(0, 0);
    var sum_zero: u32 = 0;
    for (state.cell_values) |v| sum_zero += v;
    try testing.expectEqual(0, sum_zero);
    // expect a sum of 10k (rows * cols) after loading with density 1
    loadSeed(1, 0);
    var sum_one: u32 = 0;
    for (state.cell_values) |v| sum_one += v;
    try testing.expectEqual(10000, sum_one);
    // expect a sum of roughly 5k after loading withing density 0.5
    loadSeed(0.5, 58312);
    var sum_half: f32 = 0;
    for (state.cell_values) |v| sum_half += @floatFromInt(v);
    try testing.expectApproxEqAbs(5000.0, sum_half, 100);
}

test "test set vals" {
    try init(testing.allocator, 10, 10);
    defer deinit(testing.allocator);
    loadSeed(0, 0);
    // check 8 adjacent indices are returned
    const adj_indices = getAdjacentIndices(42);
    try testing.expectEqual(adj_indices.len, 8);
    // check they sum to zero
    var init_sum: u8 = 0;
    for (adj_indices) |n| init_sum += state.cell_values[n];
    try testing.expectEqual(0, init_sum);
    // insert some 1s & check the values are adjusted as expected
    const offsets = [_][2]i8{ [_]i8{ -1, -1 }, [_]i8{ -1, 0 }, [_]i8{ 0, -1 } };
    setCellVals(42, offsets[0..], 1);
    var final_sum: u8 = 0;
    for (adj_indices) |n| final_sum += state.cell_values[n];
    try testing.expectEqual(3, final_sum);
}

test "test state update" {
    try init(testing.allocator, 3, 3);
    defer deinit(testing.allocator);

    loadSeed(0, 0);
    const cell_offset = [_][2]i8{[_]i8{ 0, 0 }};
    setCellVals(4, &cell_offset, 1);
    try testing.expectEqual(0, state.cell_values[3]);
    try testing.expectEqual(1, state.cell_values[4]);
    try testing.expectEqual(0, state.cell_values[5]);

    std.debug.print("values[0] = {any}\n", .{state.cell_values});
    std.debug.print("sums[0] = {any}\n", .{sums});
    updateGrid();
    std.debug.print("values[1] = {any}\n", .{state.cell_values});
    std.debug.print("sums[1] = {any}\n", .{sums});

    try testing.expectEqual(0, state.cell_values[3]);
    try testing.expectEqual(0, state.cell_values[4]);
    try testing.expectEqual(0, state.cell_values[5]);

    try testing.expectEqual(1, sums[3]);
    try testing.expectEqual(0, sums[4]);
    try testing.expectEqual(1, sums[5]);

    updateGrid();
    std.debug.print("values[2] = {any}\n", .{state.cell_values});
    std.debug.print("sums[2] = {any}\n", .{sums});
}
