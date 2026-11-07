#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float spin;
  float cloudSpin;
  float tilt;
  float sunX;
  float sunY;
  float sunZ;
  float cloudAmount;
  float glow;
  vec4 rim;
};
layout(binding = 1) uniform sampler2D surface;
layout(binding = 2) uniform sampler2D clouds;

const float PI = 3.14159265;

vec2 equirect(vec3 n, float rot) {
  return vec2(fract(atan(n.x, n.z) / (2.0 * PI) + 0.5 + rot), 0.5 - asin(clamp(n.y, -1.0, 1.0)) / PI);
}

void main() {
  // La sphère occupe 1/1.08 du carré : le reste reçoit le halo d'atmosphère.
  vec2 p = (qt_TexCoord0 * 2.0 - 1.0) * 1.08;
  float r = length(p);
  vec3 sun = normalize(vec3(sunX, sunY, sunZ));
  if (r > 1.0) {
    float a = glow * exp(-(r - 1.0) * 34.0);
    float lit = 0.25 + 0.75 * max(dot(normalize(vec3(p.x, -p.y, 0.0)), sun), 0.0);
    fragColor = vec4(rim.rgb * a * lit, a * lit) * qt_Opacity;
    return;
  }
  vec3 v = vec3(p.x, -p.y, sqrt(max(0.0, 1.0 - r * r)));
  float c = cos(tilt), s = sin(tilt);
  vec3 n = vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
  vec3 col = texture(surface, equirect(n, spin)).rgb;
  float cl = cloudAmount * texture(clouds, equirect(n, cloudSpin)).r;
  float d = max(dot(v, sun), 0.0);
  float light = smoothstep(0.0, 0.5, d) * 0.92 + 0.03;
  col = mix(col, vec3(1.0), cl * 0.85) * light;
  // Lueur d'atmosphère sur le limbe, du côté du soleil.
  float limb = pow(1.0 - v.z, 3.0);
  col += rim.rgb * limb * glow * (0.15 + d);
  float edge = smoothstep(1.0, 0.992, r);
  fragColor = vec4(col, 1.0) * edge * qt_Opacity;
}
