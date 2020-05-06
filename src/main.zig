const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("workaround.h");
});

pub fn renderChar(texture: c.Texture2D, char: u8, color: c.Color, x: c_int, y: c_int) void {
    const row = @intToFloat(f32, @divFloor(char, 16));
    const col = @intToFloat(f32, char % 16);

    c.workaroundDrawTextureRec(
        texture,
        &c.Rectangle{ .x = 6 * col, .y = 12 * row, .width = 6, .height = 12 },
        x,
        y,
        &color,
    );
}

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    const demotxt = "pub fn main() !void {\n    @import(\"std\").debug.warn(\"Hello, {}!\", .{\"World\"})\n}";

    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(screenWidth, screenHeight, "raylib demo");
    defer c.CloseWindow();

    const texture = c.LoadTexture("src/font.png");
    defer c.UnloadTexture(texture);

    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        {
            c.BeginDrawing();
            defer c.EndDrawing();

            c.ClearBackground(.{ .r = 46, .g = 52, .b = 64, .a = 255 });
            var x: c_int = 10;
            var y: c_int = 10;
            for (demotxt) |char| {
                if (char == '\n') {
                    x = 10;
                    y += 11;
                    continue;
                }
                renderChar(texture, char, c.Color{ .r = 0, .g = 255, .b = 255, .a = 255 }, x, y);
                x += 5;
            }
        }
    }
}
