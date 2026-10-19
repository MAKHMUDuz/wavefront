// Per-workgroup (sum, max) of |psi|²; the CPU combines the 256 partials.

override N: u32;

const GROUP: u32 = 256u;
const GROUPS: u32 = 256u;

@group(0) @binding(0) var<storage, read> psi: array<vec2f>;
@group(0) @binding(1) var<storage, read_write> partials: array<vec2f>;

var<workgroup> scratch: array<vec2f, 256>;

@compute @workgroup_size(256)
fn main(@builtin(local_invocation_index) local: u32, @builtin(workgroup_id) group: vec3u) {
  let total = N * N;
  var acc = vec2f(0.0);
  var i = group.x * GROUP + local;
  loop {
    if (i >= total) { break; }
    let v = psi[i];
    let d = dot(v, v);
    acc = vec2f(acc.x + d, max(acc.y, d));
    i += GROUP * GROUPS;
  }
  scratch[local] = acc;
  workgroupBarrier();

  var stride = GROUP / 2u;
  loop {
    if (stride == 0u) { break; }
    if (local < stride) {
      let a = scratch[local];
      let b = scratch[local + stride];
      scratch[local] = vec2f(a.x + b.x, max(a.y, b.y));
    }
    workgroupBarrier();
    stride /= 2u;
  }

  if (local == 0u) {
    partials[group.x] = scratch[0];
  }
}
