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
    -0.5, -0.5, 0,
    0.5,  -0.5, 0,
    0.0,  0.5,  0,
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
}

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

    var shaderProgram = blk: {
        var shaderProgram = c.glCreateProgram();
        var vertexShader: c_uint = try compileShader(@embedFile("shader.vert"), .vertex);
        defer c.glDeleteShader(vertexShader);
        var fragmentShader: c_uint = try compileShader(@embedFile("shader.frag"), .fragment);
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

        break :blk shaderProgram;
    };
    c.glUseProgram(shaderProgram);

    var vao: c_uint = undefined;
    c.glGenVertexArrays(1, &vao);

    c.glBindVertexArray(vao);

    var VBO: c_uint = undefined;
    c.glGenBuffers(1, &VBO);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), @ptrCast(*const c_void, &vertices), c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(c_float), null);
    c.glEnableVertexAttribArray(0);

    while (c.glfwWindowShouldClose(window.glfwWindow) == 0) {
        processInput(window);

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(shaderProgram);
        c.glBindVertexArray(vao);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window.glfwWindow);
        // c.glfwPollEvents();
        c.glfwWaitEvents(); // there is also waitEventsTimeout(sec: c_float) which could be nice. also another thread can glfwPostEmptyEvent() to wake this
    }
}
