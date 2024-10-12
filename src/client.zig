const c = @cImport(@cInclude("SDL3/SDL.h"));
const std = @import("std");
const schema = @import("schema.zig");
const Request = schema.Request;
const Action = schema.Action;
const Parameters = schema.Parameters;
const Pattern = schema.Pattern;
const REQUEST_BUFFER_LENGTH = 16;
const SIDE_BAR_WIDTH = 200.0;
const SIDE_BAR_MARGIN = 10.0;

pub const SdlClient = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    width: u32,
    height: u32,
    cell_size: f32,
    cell_scale_factor: f32,
    active_pattern: Pattern = Pattern.cell,
    mouse_x: f32 = 0.0,
    mouse_y: f32 = 0.0,

    pub fn init(name: []const u8, cell_size: f32) !SdlClient {
        const width = @as(u32, @intFromFloat(SIDE_BAR_WIDTH + cell_size * schema.COLS));
        const height = @as(u32, @intFromFloat(cell_size * schema.ROWS));
        const w: c_int = @intCast(width);
        const h: c_int = @intCast(width);
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            c.SDL_Log("Could not initialise SDL video subsytem: %s\n", c.SDL_GetError());
            return error.SDLInitFailed;
        }
        const window = c.SDL_CreateWindow(name.ptr, w, h, 0) orelse {
            c.SDL_Log("Could not create SDL window: %s\n", c.SDL_GetError());
            return error.SDLInitFailed;
        };
        const renderer = c.SDL_CreateRenderer(window, null) orelse {
            c.SDL_Log("Could not create SDL renderer: %s\n", c.SDL_GetError());
            return error.SDLInitFailed;
        };

        return SdlClient{
            .window = window,
            .renderer = renderer,
            .width = width,
            .height = height,
            .cell_size = cell_size,
            .cell_scale_factor = 1.0 / cell_size,
        };
    }

    pub fn deinit(self: *SdlClient) void {
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn drawState(self: *SdlClient, cell_values: []const u1, paused: bool, tick: u64) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0xFF);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderFillRect(self.renderer, null);
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0x90, 0xA5, 0xC0, 0xFF);

        for (0..cell_values.len) |n| {
            if (cell_values[n] == 0) continue;
            var square: c.SDL_FRect = undefined;
            const i = n / schema.COLS;
            const j = n % schema.COLS;
            square.x = @as(f32, @floatFromInt(j)) * self.cell_size;
            square.y = @as(f32, @floatFromInt(i)) * self.cell_size;
            square.w = self.cell_size;
            square.h = self.cell_size;
            _ = c.SDL_RenderFillRect(self.renderer, &square);
        }

        // TODO:  flesh this out
        const sidebar_x = @as(f32, @floatFromInt(self.width)) - SIDE_BAR_WIDTH;
        var play_light: c.SDL_FRect = undefined;
        play_light.x = sidebar_x + SIDE_BAR_MARGIN;
        play_light.y = SIDE_BAR_MARGIN;
        play_light.w = SIDE_BAR_WIDTH - 2.0 * SIDE_BAR_MARGIN;
        play_light.h = SIDE_BAR_WIDTH - 2.0 * SIDE_BAR_MARGIN;
        if (paused) {
            _ = c.SDL_SetRenderDrawColor(self.renderer, 0xA0, 0x20, 0x20, 0xFF);
        } else {
            _ = c.SDL_SetRenderDrawColor(self.renderer, 0x20, 0xA0, 0x20, 0xFF);
        }
        _ = c.SDL_RenderFillRect(self.renderer, &play_light);

        _ = tick > 100; // TODO: make use of this!
        _ = c.SDL_RenderPresent(self.renderer);
    }

    pub fn getRequests(self: *SdlClient) []Request {
        var request_buffer: [REQUEST_BUFFER_LENGTH]Request = undefined;
        var buff_index: u8 = 0;
        var e: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&e) and buff_index < REQUEST_BUFFER_LENGTH) {
            const req = self.processEvent(e);
            if (req.action == Action.None) continue;
            request_buffer[buff_index] = req;
            buff_index += 1;
        }
        return request_buffer[0..buff_index];
    }

    fn processEvent(self: *SdlClient, e: c.SDL_Event) Request {
        var action = Action.None;
        var args: Parameters = undefined;
        if (e.type == c.SDL_EVENT_QUIT)
            action = Action.Quit
        else if (e.type == c.SDL_EVENT_KEY_DOWN) {
            switch (e.key.key) {
                c.SDLK_0 => self.active_pattern = Pattern.cell,
                c.SDLK_1 => self.active_pattern = Pattern.block,
                c.SDLK_2 => self.active_pattern = Pattern.loaf,
                c.SDLK_3 => self.active_pattern = Pattern.tub,
                c.SDLK_4 => self.active_pattern = Pattern.blinker,
                c.SDLK_5 => self.active_pattern = Pattern.toad,
                c.SDLK_6 => self.active_pattern = Pattern.pentadecathlon,
                c.SDLK_7 => self.active_pattern = Pattern.glider,
                c.SDLK_8 => self.active_pattern = Pattern.lwss,
                c.SDLK_9 => self.active_pattern = Pattern.mwss,
                c.SDLK_SPACE => action = Action.Pause,
                c.SDLK_ESCAPE => action = Action.Quit,
                c.SDLK_BACKSPACE => action = Action.Clear,
                c.SDLK_MINUS => {
                    action = Action.AdjustSpeed;
                    args = Parameters{ .AdjustSpeed = -1 };
                },
                c.SDLK_EQUALS => {
                    action = Action.AdjustSpeed;
                    args = Parameters{ .AdjustSpeed = 1 };
                },
                else => {},
            }
        } else if (e.type == c.SDL_EVENT_MOUSE_MOTION) {
            _ = c.SDL_GetMouseState(&self.mouse_x, &self.mouse_y);
        } else if (e.type == c.SDL_EVENT_MOUSE_BUTTON_DOWN) {
            const sidebar_x = @as(f32, @floatFromInt(self.width)) - SIDE_BAR_WIDTH;
            if (self.mouse_x < sidebar_x) { // TOOD: fix this!!
                action = Action.Insert;
                args = Parameters{ .Insert = .{
                    .pattern = self.active_pattern,
                    .x = @intFromFloat(self.mouse_x * self.cell_scale_factor),
                    .y = @intFromFloat(self.mouse_y * self.cell_scale_factor),
                } };
            }
        }
        // || e->type == SDL_MOUSEBUTTONDOWN || e->type == SDL_MOUSEBUTTONUP )
        //else if (e.type == c.SDL_MOUSEBUTTONDOWN)

        return Request{ .action = action, .arguments = args };
    }
};
