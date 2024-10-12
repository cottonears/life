const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const std = @import("std");
const schema = @import("schema.zig");
const Request = schema.Request;
const Action = schema.Action;
const Parameters = schema.Parameters;
const Pattern = schema.Pattern;
const REQUEST_BUFFER_LENGTH = 16;

pub const SdlClient = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    width: u16,
    height: u16,
    cell_size: u8,
    active_pattern: Pattern = Pattern.cell,

    pub fn init(name: []const u8, cell_size: u8) !SdlClient {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            c.SDL_Log("Could not initialise SDL video subsytem: %s\n", c.SDL_GetError());
            return error.SDLInitFailed;
        }

        const width = cell_size * schema.COLS;
        const height = cell_size * schema.ROWS;
        _ = name; // TODO: find out how to pass this string to the SDL library functions
        const window = c.SDL_CreateWindow("", width, height, 0) orelse {
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
            .width = schema.COLS,
            .height = schema.ROWS,
            .cell_size = cell_size,
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
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0xC0, 0xE0, 0xFF, 0xFF);

        for (0..cell_values.len) |n| {
            if (cell_values[n] == 0) continue;
            var square: c.SDL_FRect = undefined;
            const i = n / self.width;
            const j = n % self.width;
            square.x = @as(f32, @floatFromInt(j * self.cell_size));
            square.y = @as(f32, @floatFromInt(i * self.cell_size));
            square.w = @as(f32, @floatFromInt(self.cell_size));
            square.h = @as(f32, @floatFromInt(self.cell_size));
            _ = c.SDL_RenderFillRect(self.renderer, &square);
        }

        _ = paused and tick > 100; // TODO: make use of these
        _ = c.SDL_RenderPresent(self.renderer);
    }

    pub fn getRequests(self: *SdlClient) []Action {
        var request_buffer: [REQUEST_BUFFER_LENGTH]Action = undefined;
        var buff_index: u8 = 0;
        var e: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&e) and buff_index < REQUEST_BUFFER_LENGTH) {
            const action = self.processEvent(e);
            if (action == Action.None) continue;
            request_buffer[buff_index] = action;
            buff_index += 1;
        }
        return request_buffer[0..buff_index];
    }

    fn processEvent(self: *SdlClient, e: c.SDL_Event) Action {
        var action = Action.None;
        if (e.type == c.SDL_EVENT_QUIT)
            action = Action.Quit
        else if (e.type == c.SDL_EVENT_KEY_DOWN) {
            switch (e.key.key) {
                c.SDLK_ESCAPE => action = Action.Quit,
                c.SDLK_SPACE => action = Action.Insert,
                c.SDLK_1 => self.active_pattern = Pattern.cell,
                c.SDLK_2 => self.active_pattern = Pattern.block,
                c.SDLK_3 => self.active_pattern = Pattern.loaf,
                c.SDLK_4 => self.active_pattern = Pattern.blinker,
                c.SDLK_5 => self.active_pattern = Pattern.toad,
                c.SDLK_6 => self.active_pattern = Pattern.pentadecathlon,
                c.SDLK_7 => self.active_pattern = Pattern.glider,
                c.SDLK_8 => self.active_pattern = Pattern.lwss,
                c.SDLK_9 => self.active_pattern = Pattern.mwss,
                else => {},
            }
        }
        //else if (e.type == c.SDL_MOUSEBUTTONDOWN)

        return action;
    }
};
