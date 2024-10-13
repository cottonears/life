const c = @cImport(@cInclude("SDL3/SDL.h"));
const std = @import("std");
const schema = @import("schema.zig");
const Request = schema.Request;
const Action = schema.Action;
const Parameters = schema.Parameters;
const Pattern = schema.Pattern;
const REQUEST_BUFFER_LENGTH = 16;
const HUD_HEIGHT = 200.0;
const HUD_MARGIN = 10.0;

const Button = struct {
    label: []const u8,
    active: bool,
    inactive_rgb: [3]u8,
    active_rgb: [3]u8,
};

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
    buttons: [12]Button = undefined,

    pub fn init(name: []const u8, cell_size: f32) !SdlClient {
        const grid_height = @as(u32, @intFromFloat(cell_size * schema.ROWS));
        const height = grid_height + @as(u32, @intFromFloat(HUD_HEIGHT));
        const width = @as(u32, @intFromFloat(cell_size * schema.COLS));
        const w: c_int = @intCast(width);
        const h: c_int = @intCast(height);
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

        const buttons = [12]Button{
            Button{
                .label = "block",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "toad",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "pulsar",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "monogram",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "pentadecathlon",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "glider",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "mw-ship",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "weekender",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "unknown",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "cell",
                .active = true,
                .active_rgb = [_]u8{ 0xE0, 0xC0, 0x00 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "Pause",
                .active = true,
                .active_rgb = [_]u8{ 0xFF, 0x20, 0x20 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
            Button{
                .label = "Run",
                .active = false,
                .active_rgb = [_]u8{ 0x20, 0xFF, 0x20 },
                .inactive_rgb = [_]u8{ 0x20, 0x20, 0x20 },
            },
        };

        return SdlClient{
            .window = window,
            .renderer = renderer,
            .width = width,
            .height = height,
            .cell_size = cell_size,
            .cell_scale_factor = 1.0 / cell_size,
            .buttons = buttons,
        };
    }

    pub fn deinit(self: *SdlClient) void {
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn drawState(self: *SdlClient, cell_values: []const u1, paused: bool, tick: u64) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0x10, 0x10, 0x10, 0xFF);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderFillRect(self.renderer, null);
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0xA0, 0xB5, 0xD0, 0xFF);

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
        self.updateButtons(paused);
        self.renderHud(tick);
        _ = c.SDL_RenderPresent(self.renderer);
    }

    fn updateButtons(self: *SdlClient, paused: bool) void {
        for (0..10) |i| {
            self.buttons[i].active = (i + 1) % 10 == @intFromEnum(self.active_pattern);
        }
        self.buttons[10].active = paused;
        self.buttons[11].active = !paused;
    }

    fn renderHud(self: *SdlClient, tick: u64) void {
        const hud_y = @as(f32, @floatFromInt(self.height)) - HUD_HEIGHT;
        // render bar
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0x40, 0x40, 0x30, 0xA0);
        var bar_rect: c.SDL_FRect = undefined;
        bar_rect.x = @as(f32, @floatFromInt(self.width)) - HUD_MARGIN;
        bar_rect.y = hud_y;
        bar_rect.w = @as(f32, @floatFromInt(self.width));
        bar_rect.h = HUD_HEIGHT;
        _ = c.SDL_RenderFillRect(self.renderer, &bar_rect);
        // render buttons
        const button_size = HUD_HEIGHT - 2.0 * HUD_MARGIN;
        for (self.buttons, 0..self.buttons.len) |b, index| {
            const rgb = if (b.active) b.active_rgb else b.inactive_rgb;
            _ = c.SDL_SetRenderDrawColor(self.renderer, rgb[0], rgb[1], rgb[2], 0xFF);
            var rect: c.SDL_FRect = undefined;
            rect.x = HUD_MARGIN + @as(f32, @floatFromInt(index)) * (button_size + HUD_MARGIN);
            rect.y = hud_y + HUD_MARGIN;
            rect.w = button_size;
            rect.h = button_size;
            _ = c.SDL_RenderFillRect(self.renderer, &rect);
        }
        _ = tick + 1; // TODO: make use of this!;
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
                c.SDLK_2 => self.active_pattern = Pattern.toad,
                c.SDLK_3 => self.active_pattern = Pattern.pulsar,
                c.SDLK_4 => self.active_pattern = Pattern.monogram,
                c.SDLK_5 => self.active_pattern = Pattern.pentadecathlon,
                c.SDLK_6 => self.active_pattern = Pattern.glider,
                c.SDLK_7 => self.active_pattern = Pattern.mwss,
                c.SDLK_8 => self.active_pattern = Pattern.weekender,
                c.SDLK_9 => self.active_pattern = Pattern.unknown,
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
            const sidebar_x = @as(f32, @floatFromInt(self.width)) - HUD_HEIGHT;
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
