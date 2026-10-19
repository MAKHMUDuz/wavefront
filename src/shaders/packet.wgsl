// psi <- keep * psi + amp * exp(-dx²/4σx² - dy²/4σy²) * exp(i (kx dx + ky dy))

override N: u32;

struct Params {
  center: vec2f,
  momentum: vec2f,
  sigma: vec2f,
  amp: f32,
  keep: f32,
}

@group(0) @binding(0) var<uniform> params: Params;
@group(0) @binding(1) var<storage, read_write> psi: array<vec2f>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) gid: vec3u) {
  if (gid.x >= N || gid.y >= N) {
    return;
  }
  let i = gid.y * N + gid.x;
  let d = vec2f(gid.xy) - params.center;
  let s = d / params.sigma;
  let envelope = params.amp * exp(-0.25 * dot(s, s));
  let phase = dot(params.momentum, d);
  psi[i] = params.keep * psi[i] + envelope * vec2f(cos(phase), sin(phase));
}
