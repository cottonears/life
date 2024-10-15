const c = @cImport({
    @cInclude("SDL3/SDL.h");
    //@cInclude("SDL3_ttf/SDL_ttf.h");
});
const std = @import("std");
const schema = @import("schema.zig");
const math = std.math;
const Request = schema.Request;
const Action = schema.Action;
const Parameters = schema.Parameters;
const Pattern = schema.Pattern;
const pattern_offsets = schema.pattern_offsets;
const HUD_BAR_RGBA = [_]u8{ 0x20, 0x21, 0x20, 0xFF };
const DEFAULT_ACTIVE_RGBA = [_]u8{ 0xE0, 0xC0, 0x00, 0xFF };
const DEFAULT_INACTIVE_RGBA = [_]u8{ 0x40, 0x40, 0x40, 0xA0 };
const PLAY_ACTIVE_RGBA = [_]u8{ 0x20, 0xFF, 0x20, 0xFF };
const PAUSE_ACTIVE_RGBA = [_]u8{ 0xFF, 0x20, 0x20, 0xFF };
const CELL_ALIVE_RGBA = [_]u8{ 0xA0, 0xB5, 0xD0, 0xFF };
const CELL_DEAD_RGBA = [_]u8{ 0x05, 0x05, 0x05, 0xFF };
const REQUEST_BUFFER_LENGTH = 8;
const HUD_HEIGHT = 100.0;
const HUD_MARGIN = 5.0;
const button_size = HUD_HEIGHT - 2.0 * HUD_MARGIN;

const Button = struct {
    label: []const u8,
    icon_offsets: []const [2]i8 = &.{},
    active_rgba: [4]u8 = DEFAULT_ACTIVE_RGBA,
    inactive_rgba: [4]u8 = DEFAULT_INACTIVE_RGBA,
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
    pattern_buttons: [10]Button = [10]Button{
        Button{ .label = "block", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.block)] },
        Button{ .label = "toad", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.toad)] },
        Button{ .label = "pulsar", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.pulsar)] },
        Button{ .label = "monogram", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.monogram)] },
        Button{ .label = "pentadecathlon", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.pentadecathlon)] },
        Button{ .label = "glider", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.glider)] },
        Button{ .label = "mid-weight spaceship", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.mwss)] },
        Button{ .label = "weekender", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.weekender)] },
        Button{ .label = "unknown", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.unknown)] },
        Button{ .label = "cell", .icon_offsets = pattern_offsets[@intFromEnum(Pattern.cell)] },
    },
    pause_button: Button = Button{
        .label = "pause",
        .active_rgba = PAUSE_ACTIVE_RGBA,
        .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.block)], // TODO: fix this!
    },
    play_button: Button = Button{
        .label = "play",
        .active_rgba = PLAY_ACTIVE_RGBA,
        .icon_offsets = schema.pattern_offsets[@intFromEnum(Pattern.toad)], // TODO: fix this!
    },

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

        return SdlClient{
            .window = window,
            .renderer = renderer,
            .width = width,
            .height = height,
            .width_u32 = width_u32,
            .height_u32 = height_u32,
            .cell_size = cell_size,
            .cell_scale_factor = 1.0 / cell_size,
        };
    }

    pub fn deinit(self: *SdlClient) void {
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn drawState(self: *SdlClient, cell_values: []const u8, paused: bool, tick: u64) void {
        // render background + cells
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
        // render HUD
        const button_y = self.height - HUD_HEIGHT + HUD_MARGIN;
        self.setRenderRgba(HUD_BAR_RGBA);
        self.renderRect(0.0, button_y - HUD_MARGIN, self.width, HUD_HEIGHT);
        var current_x: f32 = HUD_MARGIN;
        for (self.pattern_buttons, 0..) |b, i| {
            const b_active = (i + 1) % 10 == @intFromEnum(self.active_pattern);
            const rgba = if (b_active) b.active_rgba else b.inactive_rgba;
            self.setRenderRgba(rgba);
            self.renderRect(current_x, button_y, button_size, button_size);
            current_x += button_size + HUD_MARGIN;
        }
        const pause_rgba = if (paused) self.play_button.active_rgba else self.play_button.inactive_rgba;
        self.setRenderRgba(pause_rgba);
        self.renderRect(self.width - 2.0 * (button_size + HUD_MARGIN), button_y, button_size, button_size);
        const play_rgba = if (!paused) self.play_button.active_rgba else self.play_button.inactive_rgba;
        self.setRenderRgba(play_rgba);
        self.renderRect(self.width - (button_size + HUD_MARGIN), button_y, button_size, button_size);
        _ = tick + 1; // TODO: make use of this!;
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
            if (self.mouse_y < hud_y) {
                // TODO: centre the pattern on mouse and find the best place to put it!
                action = Action.Insert;
                args = Parameters{ .Insert = .{
                    .pattern = self.active_pattern,
                    .x = @intFromFloat(self.mouse_x * self.cell_scale_factor),
                    .y = @intFromFloat(self.mouse_y * self.cell_scale_factor),
                } };
            }
        }

        return Request{ .action = action, .arguments = args };
    }

    // fn renderButton(self: *SdlClient, x: f32, y: f32, b: Button, active: bool) void {
    //     const rgba = if (active) b.active_rgba else b.active_rgba;
    //     self.setRenderRgba(rgba);
    //     self.renderRect(x, y, button_size, button_size);
    //     var min_x: f32 = math.floatMax(f32);
    //     var max_x: f32 = math.floatMin(f32);
    //     var min_y: f32 = math.floatMax(f32);
    //     var max_y: f32 = math.floatMin(f32);
    //     for (b.icon_offsets) |offsets| {
    //         const pixel_x: f32 = @floatFromInt(offsets[0]);
    //         const pixel_y: f32 = @floatFromInt(offsets[1]);
    //         min_x = @min(min_x, pixel_x);
    //         max_x = @max(max_x, pixel_x);
    //         min_y = @min(min_y, pixel_y);
    //         max_y = @max(max_y, pixel_y);
    //     }
    //     const icon_size = @max(max_y - min_y, max_x - min_x);
    //     const scale_factor = 0.8 * button_size / icon_size;
    //     const icon_rgba = if (!active) b.active_rgba else b.active_rgba;
    //     self.setRenderRgba(icon_rgba);
    //     for (b.icon_offsets) |offsets| {
    //         const b_x = 0.1 * button_size + scale_factor * @as(f32, @floatFromInt(offsets[0]));
    //         const b_y = 0.1 * button_size + scale_factor * @as(f32, @floatFromInt(offsets[1]));
    //         self.renderRect(b_x, b_y, scale_factor, scale_factor);
    //     }
    // }

    fn setRenderRgba(self: *SdlClient, rgba: [4]u8) void {
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
};
