const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    c.InitWindow(screenWidth, screenHeight, "raylib demo");
    defer c.CloseWindow();

    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        {
            c.BeginDrawing();
            defer c.EndDrawing();

            c.ClearBackground(.{ .r = 240, .g = 240, .b = 240, .a = 240 });
            c.DrawText("Raylib!", 190, 200, 20, .{ .r = 120, .g = 120, .b = 120, .a = 120 });
        }
    }
}
