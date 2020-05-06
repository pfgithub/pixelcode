const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("workaround.h");
});

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

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
            c.workaroundDrawTextureRec(
                texture,
                &c.Rectangle{ .x = 0, .y = 0, .width = 10, .height = 10 },
                @divFloor(screenWidth, 2) - @divFloor(texture.width, 2),
                @divFloor(screenHeight, 2) - @divFloor(texture.height, 2),
                &c.Color{ .r = 0, .g = 255, .b = 255, .a = 255 },
            );
        }
    }
}
