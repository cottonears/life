const c = @cImport({
    @cInclude("SDL3/SDL.h");
    //@cInclude("SDL3_ttf/SDL_ttf.h");
});
const std = @import("std");
const schema = @import("schema.zig");
const Request = schema.Request;
const Action = schema.Action;
const Parameters = schema.Parameters;
const Pattern = schema.Pattern;
const REQUEST_BUFFER_LENGTH = 8;
const HUD_HEIGHT = 100.0;
const HUD_MARGIN = 5.0;
const HUD_BAR_RGBA = [_]u8{ 0x20, 0x21, 0x20, 0xFF };
const DEFAULT_ACTIVE_RGBA = [_]u8{ 0xE0, 0xC0, 0x00, 0xFF };
const DEFAULT_INACTIVE_RGBA = [_]u8{ 0x40, 0x40, 0x40, 0xA0 };
const CELL_ALIVE_RGBA = [_]u8{ 0xA0, 0xB5, 0xD0, 0xFF };
const CELL_DEAD_RGBA = [_]u8{ 0x05, 0x05, 0x05, 0xFF };

const Button = struct {
    label: []const u8,
    icon_offsets: []const [2]i8 = &.{},
    active: bool = false,
    active_rgba: [4]u8 = DEFAULT_ACTIVE_RGBA,
    inactive_rgba: [4]u8 = DEFAULT_INACTIVE_RGBA,
    x_align_right: bool = false,

    pub fn getRgba(self: *const Button) [4]u8 {
        return if (self.active) self.active_rgba else self.inactive_rgba;
    }
};

pub const SdlClient = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    width: f32,
    height: f32,
    width_u32: u32,
    height_u32: u32,
    cell_size: f32,
    cell_scale_factor: f32,
    active_pattern: Pattern = Pattern.cell,
    mouse_x: f32 = 0.0,
    mouse_y: f32 = 0.0,
    buttons: [12]Button = undefined,

    pub fn init(name: []const u8, cell_size: f32) !SdlClient {
        const width = cell_size * schema.COLS;
        const height = HUD_HEIGHT + cell_size * schema.ROWS;
        const width_u32 = @as(u32, @intFromFloat(width));
        const height_u32 = @as(u32, @intFromFloat(height));

        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            c.SDL_Log("Could not initialise SDL video subsytem: %s\n", c.SDL_GetError());
            return error.SDLInitFailed;
        }
        const window = c.SDL_CreateWindow(name.ptr, @intCast(width_u32), @intCast(height_u32), 0) orelse {
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
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.block)],
            },
            Button{
                .label = "toad",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.toad)],
            },
            Button{
                .label = "pulsar",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.pulsar)],
            },
            Button{
                .label = "monogram",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.monogram)],
            },
            Button{
                .label = "pentadecathlon",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.pentadecathlon)],
            },
            Button{
                .label = "glider",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.glider)],
            },
            Button{
                .label = "mw-ship",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.mwss)],
            },
            Button{
                .label = "weekender",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.weekender)],
            },
            Button{
                .label = "unknown",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.unknown)],
            },
            Button{
                .label = "cell",
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.cell)],
            },
            Button{
                .label = "run",
                .active_rgba = [_]u8{ 0x20, 0xFF, 0x20, 0xFF },
                .x_align_right = true,
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.toad)], // TODO: fix this!
            },
            Button{
                .label = "pause",
                .active_rgba = [_]u8{ 0xFF, 0x20, 0x20, 0xFF },
                .x_align_right = true,
                .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.block)], // TODO: fix this!
            },
        };

        return SdlClient{
            .window = window,
            .renderer = renderer,
            .width = width,
            .height = height,
            .width_u32 = width_u32,
            .height_u32 = height_u32,
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
        self.setRenderRgba(CELL_DEAD_RGBA);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderFillRect(self.renderer, null);
        self.setRenderRgba(CELL_ALIVE_RGBA);

        for (0..cell_values.len) |n| {
            if (cell_values[n] == 0) continue;
            const x = @as(f32, @floatFromInt(n % schema.COLS)) * self.cell_size;
            const y = @as(f32, @floatFromInt(n / schema.COLS)) * self.cell_size;
            self.renderRect(x, y, self.cell_size, self.cell_size);
        }
        self.updateButtons(paused);
        self.renderHud(tick);
        _ = c.SDL_RenderPresent(self.renderer);
    }

    fn updateButtons(self: *SdlClient, paused: bool) void {
        for (0..10) |i| {
            self.buttons[i].active = (i + 1) % 10 == @intFromEnum(self.active_pattern);
        }
        self.buttons[11].active = paused;
        self.buttons[10].active = !paused;
    }

    fn renderHud(self: *SdlClient, tick: u64) void {
        const button_size = HUD_HEIGHT - 2.0 * HUD_MARGIN;
        const button_y = self.height - HUD_HEIGHT + HUD_MARGIN;
        self.setRenderRgba(HUD_BAR_RGBA);
        self.renderRect(0.0, button_y - HUD_MARGIN, self.width, HUD_HEIGHT);
        // render left-aligned buttons
        var current_x: f32 = HUD_MARGIN;
        for (self.buttons) |b| {
            if (b.x_align_right) continue;
            self.setRenderRgba(b.getRgba());
            self.renderRect(current_x, button_y, button_size, button_size);
            current_x += button_size + HUD_MARGIN;
        }
        // render right-aligned buttons
        current_x = self.width - HUD_MARGIN;
        for (self.buttons) |b| {
            if (!b.x_align_right) continue;
            self.setRenderRgba(b.getRgba());
            self.renderRect(current_x, button_y, -button_size, button_size);
            current_x -= button_size + HUD_MARGIN;
        }
        _ = tick + 1; // TODO: make use of this!;
    }

    fn setRenderRgba(self: *SdlClient, rgba: [4]u8) void {
        // TODO: will it speed things up to check if the rgba one matches a stored one with std.mem.eqlBytes?
        _ = c.SDL_SetRenderDrawColor(self.renderer, rgba[0], rgba[1], rgba[2], rgba[3]);
    }

    fn renderRect(self: *SdlClient, x: f32, y: f32, w: f32, h: f32) void {
        var rect: c.SDL_FRect = undefined;
        rect.x = x;
        rect.y = y;
        rect.w = w;
        rect.h = h;
        _ = c.SDL_RenderFillRect(self.renderer, &rect);
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
            const hud_y = self.height - HUD_HEIGHT;
            if (self.mouse_y < hud_y) { // TOOD: fix this!!
                action = Action.Insert;
                // TODO: centre the pattern on mouse and find the best place to put it!
                args = Parameters{ .Insert = .{
                    .pattern = self.active_pattern,
                    .x = @intFromFloat(self.mouse_x * self.cell_scale_factor),
                    .y = @intFromFloat(self.mouse_y * self.cell_scale_factor),
                } };
            }
        }

        return Request{ .action = action, .arguments = args };
    }
};
