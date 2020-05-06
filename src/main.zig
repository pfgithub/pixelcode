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

pub fn hex(comptime color: u24) c.Color {
    return c.Color{
        .r = (color >> 16),
        .g = (color >> 8) & 0xFF,
        .b = color & 0xFF,
        .a = 0xFF,
    };
}

const Style = struct {
    color: c.Color,
    bump: ?c.Color = null,
};

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    const demotxt = "const std = @import(\"std\");\n" ++
        "pub fn main() !void {\n" ++
        "\tstd.debug.warn(\"Hi!\");\n" ++
        "}\n";

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
            camera.zoom += 1;
        } else if (mwm < 0) {
            camera.zoom -= 1;
        }
        if (camera.zoom < 1) camera.zoom = 1;

        {
            c.BeginDrawing();
            defer c.EndDrawing();

            c.ClearBackground(hex(0x222034));

            c.BeginMode2D(camera);
            defer c.EndMode2D();

            var x: c_int = 0;
            var y: c_int = 0;
            var lineno: c_int = 1;
            const left: c_int = 50;
            const top: c_int = 10;
            for (demotxt) |char| {
                if (char == '\t') {
                    x += 1;
                }
                const style: Style = switch (char) {
                    '\t', ' ', '\n' => .{ .color = hex(0x313049) },
                    '(', ')', '{', '}', ';', '"' => .{ .color = hex(0x5b597e) },
                    else => .{ .color = hex(0xFFFFFF), .bump = hex(0x65458f) },
                };
                if (style.bump) |bump|
                    renderChar(texture, char, bump, x + left, y + top + 1);
                renderChar(texture, char, style.color, x + left, y + top);

                if (char == '\n') {
                    x = 0;
                    y += 11;
                    lineno += 1;
                } else if (char == '\t') {
                    x += 19;
                } else {
                    x += 5;
                }
            }
        }
    }
}
