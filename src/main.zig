const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const std = @import("std");
const mem = std.mem;
const time = std.time;
const state = @import("state.zig");
const Pattern = state.Pattern;

// TODO: move SDL code into separate module and hide behind generic interface(s)

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("SDL init failed: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Life", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, W, H, c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("SDL create window failed: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const surface = c.SDL_GetWindowSurface(window) orelse {
        c.SDL_Log("SDL get window surface failed: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_FreeSurface(surface);

    try state.add_pattern(Pattern.toad, 50, 30, false);
    try state.add_pattern(Pattern.blinker, 30, 150, false);
    try state.add_pattern(Pattern.pulsar, 96, 96, false);
    try state.add_pattern(Pattern.pentadecathlon, 110, 19, false);
    try state.add_pattern(Pattern.glider, 20, 44, false);
    try state.add_pattern(Pattern.lwss, 5, 5, false);
    try state.add_pattern(Pattern.plague, 344, 144, false);
    try state.add_pattern(Pattern.plague, 159, 69, true);

    var loop = true;

    while (loop) {
        const t_0 = time.milliTimestamp();
        loop = processEvents();
        state.update_cells();
        draw_state(window, surface);
        const t_1 = time.milliTimestamp() - t_0;
        const t_delay = if (t_1 < frame_time) @as(u32, @intCast(frame_time - t_1)) else 0;
        c.SDL_Delay(t_delay);
    }
}

// TODO: move below interaction code into separate module
var frame_time: u32 = 100;
fn processEvents() bool {
    var e: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&e) != 0) {
        if (e.type == c.SDL_QUIT)
            return false;
        //else if (e.type == c.SDL_KEYDOWN)
    }

    return true;
}

// TODO: move rendering code into separate module
const W = 1600;
const H = 1600;
fn draw_state(window: *c.SDL_Window, surface: *c.SDL_Surface) void {
    const CELL_SIZE: u8 = 8;

    // NOTE: slightly weird syntax when referencing a C-struct's fields with '.*.'
    // apparently this is hacky (see https://ziglang.org/documentation/0.13.0/#C-Pointers)
    // TODO: find a better way!
    const col_0 = c.SDL_MapRGB(surface.*.format, 0x00, 0x00, 0x00);
    _ = c.SDL_FillRect(surface, null, col_0);
    const col_1 = c.SDL_MapRGB(surface.*.format, 0xD0, 0xE0, 0xF0);

    for (0..state.ROWS) |i| {
        for (0..state.COLS) |j| {
            if (state.cells[i][j] == 0) continue;
            var square: c.SDL_Rect = undefined;
            square.x = @as(c_int, @intCast(j * CELL_SIZE));
            square.y = @as(c_int, @intCast(i * CELL_SIZE));
            square.w = @as(c_int, CELL_SIZE);
            square.h = @as(c_int, CELL_SIZE);
            _ = c.SDL_FillRect(surface, &square, col_1); // square
        }
    }

    _ = c.SDL_UpdateWindowSurface(window);
}
