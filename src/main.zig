const std = @import("std");
const game = @import("game.zig");
const client = @import("client.zig");
const schema = @import("schema.zig");
const math = std.math;
const time = std.time;
const Action = schema.Action;
const Request = schema.Request;
const Paramters = schema.Parameters;
const State = schema.State;
const K = 1000;
const MAX_GRID_SIZE = 2048;
const FRAME_TIME_US = 10 * K; // 100 FPS
const STATE_TIMES_US = [_]u32{ 1000 * K, 500 * K, 200 * K, 100 * K, 50 * K, 20 * K, 10 * K };
var sdlc: client.SdlClient = undefined;
var quit = false;
var speed: u8 = 6;
var tick_time_us: i32 = 0;

pub fn main() !void {
    // TODO: load a config file to set the hard-coded variables below
    const cell_size = 3;
    const rows = 400;
    const cols = 720;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try game.init(allocator, rows, cols);
    defer game.deinit(allocator);

    std.debug.print("Initialising sdl-client...\n", .{});
    sdlc = try client.SdlClient.init("Life", rows, cols, cell_size);
    defer sdlc.deinit();

    const seed = time.microTimestamp();
    game.loadSeed(0.07, @intCast(seed));
    run();
}

fn run() void {
    tick_time_us = @intCast(STATE_TIMES_US[speed]);
    game.state.paused = false;
    var total_update_time_us: f64 = 0;
    var total_process_time_us: f64 = 0;
    var total_render_time_us: f64 = 0;
    var total_frame_time_us: f64 = 0;
    var frames: u64 = 0;
    var last_tick = time.microTimestamp();

    while (!quit) {
        const frame_start = time.microTimestamp();
        if (frame_start - last_tick > tick_time_us) {
            game.updateGrid();
            last_tick = time.microTimestamp();
        }
        const update_end = time.microTimestamp();
        processRequests();
        const process_end = time.microTimestamp();
        sdlc.handleStateUpdate(game.state);
        const render_end = time.microTimestamp();
        const frame_us = render_end - frame_start;
        const t_delay_us = if (frame_us < FRAME_TIME_US) @as(u64, @intCast(FRAME_TIME_US - frame_us)) else 0;
        time.sleep(t_delay_us * time.ns_per_us);

        total_update_time_us += @floatFromInt(update_end - frame_start);
        total_process_time_us += @floatFromInt(process_end - update_end);
        total_render_time_us += @floatFromInt(render_end - process_end);
        total_frame_time_us += @floatFromInt(frame_us);
        frames += 1;
    }
    const frame_time_avg_us = 0.001 * total_frame_time_us / @as(f64, @floatFromInt(frames));
    const update_frac = total_update_time_us / total_frame_time_us;
    const process_frac = total_process_time_us / total_frame_time_us;
    const render_frac = total_render_time_us / total_frame_time_us;
    std.debug.print("Rendered {} frames; average frame time = {d:.1} ms.\n", .{
        frames,
        frame_time_avg_us,
    });
    std.debug.print("Time breakdown: update = {d:.3}, process = {d:.3}, render = {d:.3}\n", .{
        update_frac,
        process_frac,
        render_frac,
    });
}

fn processRequests() void {
    const requests = sdlc.getRequests();
    for (requests) |req| {
        switch (req.action) {
            Action.Quit => quit = true,
            Action.Pause => game.togglePause(),
            Action.LoadSeed => game.loadSeed(
                req.arguments.LoadSeed.density,
                req.arguments.LoadSeed.seed,
            ),
            Action.Insert => game.insert(
                req.arguments.Insert.x,
                req.arguments.Insert.y,
                req.arguments.Insert.offsets,
            ),
            Action.AdjustSpeed => {
                const new_speed = @as(i8, @intCast(speed)) + req.arguments.AdjustSpeed;
                speed = @intCast(math.clamp(new_speed, 0, @as(i8, @intCast(STATE_TIMES_US.len)) - 1));
                tick_time_us = @intCast(STATE_TIMES_US[speed]);
            },
            Action.None => {},
        }
    }
}
