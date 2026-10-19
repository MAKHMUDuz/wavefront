// Units: hbar = m = 1, grid spacing = 1.

override N: u32;

struct Params {
  dt: f32,
  absorb: u32,         // 0 = hard walls around the border
  absorbWidth: f32,
  absorbStrength: f32,
  wallV: f32,
  _pad0: f32,
  _pad1: f32,
  _pad2: f32,
}

@group(0) @binding(0) var<uniform> params: Params;
@group(0) @binding(1) var<storage, read> potential: array<f32>;
@group(0) @binding(2) var<storage, read_write> potentialFactor: array<vec2f>;
@group(0) @binding(3) var<storage, read_write> kineticFactor: array<vec2f>;

const TAU: f32 = 6.28318530717959;

// exp(-i V dt / 2), damped near the edges so outgoing waves don't wrap around the periodic domain.
@compute @workgroup_size(64)
fn buildPotential(@builtin(global_invocation_id) gid: vec3u) {
  if (gid.x >= N || gid.y >= N) {
    return;
  }
  let i = gid.y * N + gid.x;
  let edge = f32(min(min(gid.x, gid.y), min(N - 1u - gid.x, N - 1u - gid.y)));

  var v = potential[i];
  var damping = 1.0;
  if (params.absorb == 1u) {
    let depth = clamp((params.absorbWidth - edge) / params.absorbWidth, 0.0, 1.0);
    damping = exp(-params.absorbStrength * depth * depth);
  } else if (edge < 2.0) {
    v = params.wallV;
  }

  let phase = -v * params.dt * 0.5;
  potentialFactor[i] = damping * vec2f(cos(phase), sin(phase));
}

// exp(-i k² dt / 2) / N², folding in the inverse FFT normalisation.
@compute @workgroup_size(64)
fn buildKinetic(@builtin(global_invocation_id) gid: vec3u) {
  if (gid.x >= N || gid.y >= N) {
    return;
  }
  let i = gid.y * N + gid.x;
  let half = i32(N / 2u);
  var fx = i32(gid.x);
  var fy = i32(gid.y);
  if (fx >= half) { fx -= i32(N); }
  if (fy >= half) { fy -= i32(N); }
  let kx = TAU * f32(fx) / f32(N);
  let ky = TAU * f32(fy) / f32(N);

  let phase = -(kx * kx + ky * ky) * params.dt * 0.5;
  let scale = 1.0 / f32(N * N);
  kineticFactor[i] = scale * vec2f(cos(phase), sin(phase));
}
