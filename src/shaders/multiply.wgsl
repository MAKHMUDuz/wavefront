override N: u32;

@group(0) @binding(0) var<storage, read_write> psi: array<vec2f>;
@group(0) @binding(1) var<storage, read> factor: array<vec2f>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) gid: vec3u) {
  if (gid.x >= N || gid.y >= N) {
    return;
  }
  let i = gid.y * N + gid.x;
  let a = psi[i];
  let b = factor[i];
  psi[i] = vec2f(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}
