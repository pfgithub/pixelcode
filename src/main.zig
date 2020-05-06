const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    const screenWidth = 800.0;
    const screenHeight = 450.0;

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
            c.DrawTextureRec(
                texture,
                .{ .x = 0, .y = 0, .width = 10, .height = 10 },
                .{
                    .x = (screenWidth / 2.0) - (@intToFloat(f32, texture.width) / 2.0),
                    .y = (screenHeight / 2.0) - (@intToFloat(f32, texture.height) / 2.0),
                },
                .{ .r = 0, .g = 255, .b = 255, .a = 255 },
            );
        }
    }
}
