const std = @import("std");
const c = @import("./c.zig");
const parser = @import("./parser.zig");

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

const HLStyle = union(enum) {
    keyword: void,
    variable: void,
    uservar: void,
    string: void,
    control: void,
    spacing: void,
    typ: void,
};

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    const alloc = std.heap.c_allocator;

    const first =
        \\const std = @import("std");
        \\pub fn main() !void {
        \\    std.debug.warn("Hi!");
        \\}
        \\
        \\\\Font test:
        \\\\ ABCDEFGHIJKLMNOPQRSTUVWXYZ
        \\\\ abcdefghijklmnopqrstuvwxyz
        \\\\ `backticks`, #hashtag, &amp;
        \\\\ 25 < 56 <= 102 > 12?
        \\\\ [one, two, three]
        \\\\ 12^45 = 54 + 26 % 18 'a'
        \\\\ one/two\three/four // comment
    ;
    const demotext_ = (first) ++
        "\\\\ unicode 👍\n";

    var filetxt = try std.ArrayList(u8).initCapacity(alloc, demotext_.len);
    filetxt.appendSlice(demotext_) catch unreachable;

    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(screenWidth, screenHeight, "raylib demo");
    defer c.CloseWindow();

    const texture = c.LoadTexture("src/font.png");
    defer c.UnloadTexture(texture);

    c.SetTargetFPS(60);

    c.HideCursor();

    var camera: c.Camera2D = std.mem.zeroes(c.Camera2D);
    camera.target = .{ .x = 0, .y = 0 };
    camera.offset = .{ .x = 0, .y = 0 };
    camera.rotation = 0;
    camera.zoom = 2;

    var tree = try parser.Tree.init(filetxt.items);

    var cursorPos: usize = 1;

    while (!c.WindowShouldClose()) {
        const mwm = c.GetMouseWheelMove();
        if (mwm > 0) {
            camera.zoom += 1;
        } else if (mwm < 0) {
            camera.zoom -= 1;
        }
        if (camera.zoom < 1) camera.zoom = 1;

        if (c.IsKeyPressed(c.KEY_LEFT) and cursorPos > 0) {
            cursorPos -= 1;
        }
        if (c.IsKeyPressed(c.KEY_RIGHT) and cursorPos < filetxt.items.len - 1) {
            cursorPos += 1;
        }
        var bkspPressed = c.IsKeyPressed(c.KEY_BACKSPACE);
        if ((bkspPressed or c.IsKeyPressed(c.KEY_DELETE)) and cursorPos < filetxt.items.len - 1) {
            if (bkspPressed) cursorPos -= 1;
            _ = filetxt.orderedRemove(cursorPos);
            const cursorPosRC = parser.RowCol.find(filetxt.items, cursorPos);
            tree.edit(
                cursorPos,
                cursorPos + 1,
                cursorPos,
                cursorPosRC,
                parser.RowCol.find(filetxt.items, cursorPos + 1),
                cursorPosRC,
            );
            tree.reparse(filetxt.items);
        }
        var keyPressed = c.GetKeyPressed();
        if (keyPressed > 0xFF) {
            std.debug.warn("Unsupported multi byte character {}\n", .{keyPressed});
            // multi byte character and I'm not sure how to decode it properly
        } else if (keyPressed != 0) {
            try filetxt.insert(cursorPos, @intCast(u8, keyPressed));
            const cursorPosRC = parser.RowCol.find(filetxt.items, cursorPos);
            tree.edit(
                cursorPos,
                cursorPos,
                cursorPos + 1,
                cursorPosRC,
                cursorPosRC,
                parser.RowCol.find(filetxt.items, cursorPos + 1),
            );
            tree.reparse(filetxt.items);
            cursorPos += 1;
        }

        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(hex(0x222034));

        c.BeginMode2D(camera);
        defer c.EndMode2D();

        var x: c_int = 0;
        var y: c_int = 0;
        var lineno: usize = 1;
        const clickStart = c.IsMouseButtonDown(0);
        const mouseposscreenspace = c.GetMousePosition();
        var mousepos: c.Vector2 = undefined;
        c.workaroundScreenToWorld2D(&mouseposscreenspace, &camera, &mousepos);
        const mx = @floatToInt(c_int, mousepos.x);
        const my = @floatToInt(c_int, mousepos.y);
        const left: c_int = 10;
        const top: c_int = 20;

        var rescursorx: c_int = 0;
        var rescursory: c_int = 0;

        var cursor = parser.TreeCursor.init(tree.root());
        defer cursor.deinit();

        for (filetxt.items) |char, index| {
            const classes = parser.getNodeAtPosition(index, &cursor).createClassesStruct(index);
            if (cursorPos > 0 and index == cursorPos - 1) {
                const text = try std.fmt.allocPrint(alloc, "Classes: {}", .{classes});
                defer alloc.free(text);

                for (text) |cchar, ttii| {
                    renderChar(texture, cchar, switch (cchar) {
                        ' ' => hex(0x313049),
                        '.', ':' => hex(0x5b597e),
                        else => hex(0xFFFFFF),
                    }, @intCast(c_int, ttii * 5) + left, 5);
                }
            }
            const renderStyle = classes.renderStyle(char);

            if (x == 0) {
                renderChar(texture, "0123456789"[lineno % 10], hex(0xFFFFFF), x + left, y + top);
                x += 20;
            }
            const style: Style = switch (renderStyle) {
                .spacing => .{ .color = hex(0x313049) },
                .control => .{ .color = hex(0x5b597e) },
                .variable => .{ .color = hex(0xFFFFFF) },
                .uservar => .{ .color = hex(0xFFFFFF), .bump = hex(0x65458f) },
                .keyword => .{ .color = hex(0x37946e) },
                .typ => .{ .color = hex(0xdf7126) },
                .string => .{ .color = hex(0x6abe30) },
                .wip => .{ .color = hex(0xFF5555) },
            };

            if (index == cursorPos) {
                rescursorx = x + left;
                rescursory = y + top;
            }

            if (clickStart and mx > x + left and my > y + top) {
                cursorPos = index;
                if (mx > x + left + 2 and char != '\n') {
                    cursorPos += 1;
                }
            }

            if (char == '\t') {
                renderChar(texture, '-', style.color, x + left, y + top);
                x += 4;
            }

            if (style.bump) |bump|
                renderChar(texture, char, bump, x + left, y + top + 1);
            renderChar(texture, char, style.color, x + left, y + top);

            if (char == '\n') {
                x = 0;
                y += 11;
                lineno += 1;
            } else if (char == '\t') {
                x += 16;
            } else {
                x += 5;
            }
        }

        c.DrawRectangle(rescursorx, rescursory, 1, 9, hex(0x5b6ee1));
        c.DrawRectangle(mx, my, 1, 1, hex(0x5b6ee1));
    }
}
