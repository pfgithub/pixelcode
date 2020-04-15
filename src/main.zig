const std = @import("std");
const c = @cImport({
    @cInclude("glad/glad.h");
    @cDefine("GLFW_INCLUDE_NONE", "");
    @cInclude("GLFW/glfw3.h");
});
const c_float = f32;

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    std.debug.warn("GLFW Error {}: {s}\n", .{ err, description });
}

pub const Window = struct {
    glfwWindow: *c.GLFWwindow,
    pub fn init() !Window {
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        var window = c.glfwCreateWindow(640, 480, "Window", null, null);
        if (window) |w| {
            return Window{ .glfwWindow = w };
        } else {
            return error.WindowCreateFailed;
        }
    }
    pub fn deinit(window: *Window) void {
        c.glfwDestroyWindow(window.glfwWindow);
    }
};

pub fn glfwInit() !void {
    _ = c.glfwSetErrorCallback(errorCallback);
    if (c.glfwInit() == 0) return error.GlfwInitFailed;
    errdefer c.glfwTerminate();
}

pub fn glfwDeinit() void {
    c.glfwTerminate();
}

fn framebufferSizeCallback(
    window: ?*c.GLFWwindow,
    width: c_int,
    height: c_int,
) callconv(.C) void {
    c.glViewport(0, 0, width, height);
}

const Vertex = extern struct {
    x: c_float,
    y: c_float,
    r: c_float,
    g: c_float,
    b: c_float,
};
extern const vertices = [_]c_float{
    0.5,  0.5,  0.0, 1.0, 0.0, 0.0,
    0.5,  -0.5, 0.0, 0.0, 1.0, 0.0,
    -0.5, -0.5, 0.0, 0.0, 0.0, 1.0,
    -0.5, 0.5,  0.0, 1.0, 1.0, 1.0,
};
extern const indices = [_]c_uint{
    0, 1, 3,
    1, 2, 3,
};

fn compileShader(shaderSrc: []const u8, shaderType: enum { vertex, fragment }) !c_uint {
    var shader = c.glCreateShader(switch (shaderType) {
        .vertex => c.GL_VERTEX_SHADER,
        .fragment => c.GL_FRAGMENT_SHADER,
    });

    c.glShaderSource(
        shader,
        1,
        @ptrCast([*c]const [*c]const u8, &shaderSrc),
        null,
    );
    c.glCompileShader(shader);

    var success: c_int = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var infoLog: [512]u8 = undefined;
        c.glGetShaderInfoLog(shader, 512, null, &infoLog);
        std.debug.warn("Shader Compile Failed:\n{s}\n", .{&infoLog});
        return error.ShaderCompileFailed;
    }

    return shader;
}

fn processInput(window: Window) void {
    if (c.glfwGetKey(window.glfwWindow, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
        // c.glfwSetWindowShouldClose(window.glfwWindow, 1);
        std.debug.warn("Escape key pressed\n", .{});
    }
    if (c.glfwGetKey(window.glfwWindow, c.GLFW_KEY_1) == c.GLFW_PRESS) {
        c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
    }
    if (c.glfwGetKey(window.glfwWindow, c.GLFW_KEY_2) == c.GLFW_PRESS) {
        c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_FILL);
    }
}

const ShaderProgram = struct {
    id: c_uint,
    pub fn init(src: struct {
        vert: [:0]const u8,
        frag: [:0]const u8,
    }) !ShaderProgram {
        var shaderProgram = c.glCreateProgram();
        var vertexShader: c_uint = try compileShader(src.vert, .vertex);
        defer c.glDeleteShader(vertexShader);
        var fragmentShader: c_uint = try compileShader(src.frag, .fragment);
        defer c.glDeleteShader(fragmentShader);

        c.glAttachShader(shaderProgram, vertexShader);
        c.glAttachShader(shaderProgram, fragmentShader);
        c.glLinkProgram(shaderProgram);
        var success: c_int = undefined;
        c.glGetProgramiv(shaderProgram, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            c.glGetProgramInfoLog(shaderProgram, 512, null, &infoLog);
            std.debug.warn("Program Link Failed:\n{s}\n", .{&infoLog});
            return error.ShaderProgramLinkFailed;
        }

        return ShaderProgram{ .id = shaderProgram };
    }
    pub fn deinit(shaderProgram: ShaderProgram) void {}
    fn use(shaderProgram: ShaderProgram) void {
        c.glUseProgram(shaderProgram.id);
    }
    pub const Prop = struct {
        uniformLocation: c.GLint,
        fn setBool(prop: Prop, value: bool) void {
            prop.setInt(if (value) 1 else 0);
        }
        fn setInt(prop: Prop, value: c_int) void {
            c.glUniform1i(prop.uniformLocation, value);
        }
        fn setFloat(prop: Prop, value: c_float) void {
            c.glUniform1f(prop.uniformLocation, value);
        }
        fn setVec4(prop: Prop, v1: c_float, v2: c_float, v3: c_float, v4: c_float) void {
            c.glUniform4f(prop.uniformLocation, v1, v2, v3, v4);
        }
    };
    fn get(program: ShaderProgram, prop: [:0]const u8) Prop {
        return Prop{
            .uniformLocation = c.glGetUniformLocation(program.id, prop),
        };
    }
};

pub fn main() !void {
    try glfwInit();
    defer glfwDeinit();

    var window = try Window.init();
    defer window.deinit();

    c.glfwMakeContextCurrent(window.glfwWindow);
    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, c.glfwGetProcAddress)) == 0)
        return error.GladInitFailed;

    c.glViewport(0, 0, 800, 600);
    _ = c.glfwSetFramebufferSizeCallback(window.glfwWindow, framebufferSizeCallback);

    var shaderProgram = try ShaderProgram.init(.{
        .vert = @embedFile("shader.vert"),
        .frag = @embedFile("shader.frag"),
    });
    defer shaderProgram.deinit();

    var vao: c_uint = undefined;
    c.glGenVertexArrays(1, &vao);
    defer c.glDeleteVertexArrays(1, &vao);

    c.glBindVertexArray(vao);

    var vertexBufferObjects: c_uint = undefined;
    c.glGenBuffers(1, &vertexBufferObjects);
    defer c.glDeleteBuffers(1, &vertexBufferObjects);

    var elementBufferObjects: c_uint = undefined;
    c.glGenBuffers(1, &elementBufferObjects);
    defer c.glDeleteBuffers(1, &elementBufferObjects);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vertexBufferObjects);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), @ptrCast(*const c_void, &vertices), c.GL_STATIC_DRAW);

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, elementBufferObjects);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), @ptrCast(*const c_void, &indices), c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(c_float), @intToPtr(?*c_void, 0)); // that last arg should be a size_t but is a void* for some reason
    c.glEnableVertexAttribArray(0);

    c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(c_float), @intToPtr(?*c_void, 3 * @sizeOf(c_float)));
    c.glEnableVertexAttribArray(1);

    var vertexColor = shaderProgram.get("ourColor");

    while (c.glfwWindowShouldClose(window.glfwWindow) == 0) {
        processInput(window);

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        shaderProgram.use();

        var timeValue: f32 = @floatCast(f32, c.glfwGetTime());
        var greenValue = std.math.sin(timeValue) / 2.0 + 0.5;
        vertexColor.setVec4(1.0, greenValue, 1.0, 1.0);

        c.glBindVertexArray(vao);
        c.glDrawElements(c.GL_TRIANGLES, indices.len, c.GL_UNSIGNED_INT, null);

        c.glfwSwapBuffers(window.glfwWindow);
        c.glfwPollEvents();
        // c.glfwWaitEvents(); // there is also waitEventsTimeout(sec: c_float) which could be nice. also another thread can glfwPostEmptyEvent() to wake this
    }
}
