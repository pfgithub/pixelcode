#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec2 aTexCoord;

uniform float offset;
// out vec2 TexCoord;

void main()
{
    gl_Position = vec4(aPos.x + offset, aPos.y + offset, aPos.z, 1.0);
    // TexCoord = aTexCoord;
}