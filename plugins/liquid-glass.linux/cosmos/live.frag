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
    // Tourbillon : plus on approche du centre, plus ça tourne ; deux phases fondues pour boucler sans saut.
    float t = fract(time * 0.03);
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 2; i++) {
      float ph = fract(t + float(i) * 0.5);
      float a = (ph - 0.5) * 0.22 / (r + 0.25);
      float cs = cos(a), sn = sin(a);
      vec2 q = vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs) / vec2(aspect, 1.0) + 0.5;
      acc += texture(wall, q).rgb * (1.0 - abs(ph * 2.0 - 1.0));
    }
    fragColor = vec4(acc, 1.0) * qt_Opacity;
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
