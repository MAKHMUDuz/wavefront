// One radix-2 Stockham pass over every row or column. log2(N) passes with p = 1, 2, ..., N/2
// give the transform in natural order, no bit reversal needed.

override N: u32;

struct Params {
  p: u32,
  axis: u32,   // 0 = rows, 1 = columns
  sign: f32,   // -1 forward, +1 inverse (unscaled)
  _pad: f32,
}

@group(0) @binding(0) var<uniform> params: Params;
@group(0) @binding(1) var<storage, read> src: array<vec2f>;
@group(0) @binding(2) var<storage, read_write> dst: array<vec2f>;

const PI: f32 = 3.14159265358979;

fn index(t: u32, line: u32) -> u32 {
  if (params.axis == 0u) {
    return line * N + t;
  }
  return t * N + line;
}

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) gid: vec3u) {
  let half = N / 2u;
  let i = gid.x;
  let line = gid.y;
  if (i >= half || line >= N) {
    return;
  }

  let p = params.p;
  let k = i & (p - 1u);

  let a = src[index(i, line)];
  let b = src[index(i + half, line)];

  let angle = params.sign * PI * f32(k) / f32(p);
  let w = vec2f(cos(angle), sin(angle));
  let bw = vec2f(b.x * w.x - b.y * w.y, b.x * w.y + b.y * w.x);

  let j = ((i - k) << 1u) + k;
  dst[index(j, line)] = a + bw;
  dst[index(j + p, line)] = a - bw;
}
