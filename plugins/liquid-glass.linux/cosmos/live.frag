#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float time;
  float mode;      // 0 tourbillon, 1 vague, 2 respiration
  float aspect;
};
layout(binding = 1) uniform sampler2D wall;

void main() {
  vec2 uv = qt_TexCoord0;
  vec2 c = (uv - 0.5) * vec2(aspect, 1.0);
  float r = length(c);
  if (mode < 0.5) {
    // Tourbillon : le centre tourne plus que les bords, dans un sens puis dans l'autre.
    // Une seule lecture de l'image, pour que les textes et les traits ne se dédoublent pas.
    float a = 0.16 * sin(time * 0.16) / (r + 0.25);
    float cs = cos(a), sn = sin(a);
    vec2 q = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs) * 0.9 / vec2(aspect, 1.0) + 0.5;
    fragColor = vec4(texture(wall, q).rgb, 1.0) * qt_Opacity;
    return;
  }
  if (mode < 1.5) {
    vec2 d = vec2(sin(uv.y * 9.0 + time * 0.8), cos(uv.x * 7.0 + time * 0.6)) * 0.004;
    fragColor = vec4(texture(wall, uv + d).rgb, 1.0) * qt_Opacity;
    return;
  }
  float z = 0.965 + 0.02 * sin(time * 0.25);
  fragColor = vec4(texture(wall, (uv - 0.5) * z + 0.5).rgb, 1.0) * qt_Opacity;
}
