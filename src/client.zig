const c = @cImport({
    @cInclude("SDL3/SDL.h");
});
const game = @import("game.zig");
const CELL_SIZE: u32 = 10;
const WINDOW_FLAGS = 0;

pub const SdlClient = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    width: u16,
    height: u16,
    //errorDetails: []u8 = "", // TODO: is there a better way of initialising this?

    pub fn init(name: []const u8, width: u16, height: u16) !SdlClient { // TODO: add name argument

        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            c.SDL_Log("Could not initialise SDL video subsytem: %s\n", c.SDL_GetError());
            return error.SDLInitializationFailed;
        }
        defer c.SDL_Quit();

        _ = name; // TODO: find out how to pass this string to the SDL library functions
        const window = c.SDL_CreateWindow("", width, height, WINDOW_FLAGS) orelse {
            c.SDL_Log("Could not create SDL window: %s\n", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        const renderer = c.SDL_CreateRenderer(window, null) orelse {
            c.SDL_Log("Could not create SDL renderer: %s\n", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        return SdlClient{
            .window = window,
            .renderer = renderer,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *SdlClient) void {
        c.SDL_DestroyWindow(self.window);
    }

    // TODO: doesn't compile when I try use this interface, find out why!
    // pub fn client(self: *SdlClient) game.Client {
    //     return .{
    //         .id = 1,
    //         .ptr = self,
    //         .updateStateFn = self.drawState,
    //     };
    // }

    pub fn drawState(self: *SdlClient, grid: [game.ROWS][game.COLS]u8, paused: bool, tick: u64) void {
        // first draw the background
        c.SDL_SetRenderDrawColor(self.renderer, 0x00, 0x00, 0x00, 0xFF);
        c.SDL_RenderClear(self.renderer);
        c.SDL_RenderFillRect(self.renderer, null);
        // now draw the live cells
        c.SDL_SetRenderDrawColor(self.renderer, 0xC0, 0xE0, 0xFF, 0xFF);
        for (0..grid.ROWS) |i| {
            for (0..grid.COLS) |j| {
                if (grid.cells[i][j] == 0) continue;
                var square: c.SDL_Rect = undefined;
                square.x = @as(c_int, @intCast(j * CELL_SIZE));
                square.y = @as(c_int, @intCast(i * CELL_SIZE));
                square.w = @as(c_int, CELL_SIZE);
                square.h = @as(c_int, CELL_SIZE);
                c.SDL_RenderFillRect(self.renderer, &square);
            }
        }
        c.SDL_RenderPresent(self.renderer);
        _ = paused and tick > 100; // TOOD: make use of these
    }
};
