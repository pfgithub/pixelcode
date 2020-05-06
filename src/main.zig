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
        &c.Rectangle{ .x = 6 * col + 1, .y = 12 * row + 1, .width = 6, .height = 12 },
        x,
        y,
        &color,
    );
}

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    const demotxt = "pub fn main() !void {\n    @import(\"std\").debug.warn(\"Hello, {}!\", .{\"World\"});\n}\n";

    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(screenWidth, screenHeight, "raylib demo");
    defer c.CloseWindow();

    const texture = c.LoadTexture("src/font.png");
    defer c.UnloadTexture(texture);

    c.SetTargetFPS(60);

    var camera: c.Camera2D = std.mem.zeroes(c.Camera2D);
    camera.target = .{ .x = 0, .y = 0 };
    camera.offset = .{ .x = 0, .y = 0 };
    camera.rotation = 0;
    camera.zoom = 2;

    while (!c.WindowShouldClose()) {
        const mwm = c.GetMouseWheelMove();
        if (mwm > 0) {
            camera.zoom *= 2;
        } else if (mwm < 0) {
            camera.zoom /= 2;
        }
        if (camera.zoom < 1) camera.zoom = 1;

        {
            c.BeginDrawing();
            defer c.EndDrawing();

            c.ClearBackground(.{ .r = 46, .g = 52, .b = 64, .a = 255 });

            c.BeginMode2D(camera);
            defer c.EndMode2D();

            var x: c_int = 10;
            var y: c_int = 10;
            for (demotxt) |char| {
                renderChar(texture, char, switch (char) {
                    ' ', '\n' => c.Color{ .r = 80, .g = 80, .b = 80, .a = 255 },
                    '(', ')', '{', '}', ';', '"' => c.Color{ .r = 128, .g = 128, .b = 128, .a = 255 },
                    else => c.Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
                }, x, y);

                if (char == '\n') {
                    x = 10;
                    y += 11;
                } else {
                    x += 5;
                }
            }
        }
    }
}
