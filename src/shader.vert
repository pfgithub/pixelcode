#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

uniform float offset;
out vec4 vertexColor;

void main()
{
    gl_Position = vec4(aPos.x + offset, aPos.y + offset, aPos.z, 1.0);
    vertexColor = vec4(aColor, 1.0);
}