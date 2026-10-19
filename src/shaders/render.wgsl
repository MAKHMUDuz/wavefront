struct View {
  n: f32,
  gain: f32,
  mode: f32,      // 0 = phase, 1 = probability
  wallV: f32,
}

@group(0) @binding(0) var<uniform> view: View;
@group(0) @binding(1) var<storage, read> psi: array<vec2f>;
@group(0) @binding(2) var<storage, read> potential: array<f32>;

struct VertexOut {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
}

@vertex
fn vs(@builtin(vertex_index) i: u32) -> VertexOut {
  // Fullscreen triangle.
  let p = vec2f(f32((i << 1u) & 2u), f32(i & 2u));
  var out: VertexOut;
  out.position = vec4f(p * 2.0 - 1.0, 0.0, 1.0);
  out.uv = vec2f(p.x, 1.0 - p.y);
  return out;
}

fn cell(x: i32, y: i32) -> u32 {
  let n = i32(view.n);
  return u32(clamp(y, 0, n - 1) * n + clamp(x, 0, n - 1));
}

fn samplePsi(g: vec2f) -> vec2f {
  let b = floor(g);
  let f = g - b;
  let x = i32(b.x);
  let y = i32(b.y);
  let top = mix(psi[cell(x, y)], psi[cell(x + 1, y)], f.x);
  let bottom = mix(psi[cell(x, y + 1)], psi[cell(x + 1, y + 1)], f.x);
  return mix(top, bottom, f.y);
}

fn samplePotential(g: vec2f) -> f32 {
  let b = floor(g);
  let f = g - b;
  let x = i32(b.x);
  let y = i32(b.y);
  let top = mix(potential[cell(x, y)], potential[cell(x + 1, y)], f.x);
  let bottom = mix(potential[cell(x, y + 1)], potential[cell(x + 1, y + 1)], f.x);
  return mix(top, bottom, f.y);
}

fn phaseColor(t: f32) -> vec3f {
  return 0.5 + 0.5 * cos(6.28318 * (t + vec3f(0.0, 0.333, 0.667)));
}

// Polynomial fit of matplotlib's inferno.
fn inferno(t: f32) -> vec3f {
  let c0 = vec3f(0.0002189403691192265, 0.001651004631001012, -0.01948089843709184);
  let c1 = vec3f(0.1065134194856116, 0.5639564367884091, 3.932712388889277);
  let c2 = vec3f(11.60249308247187, -3.972853965665698, -15.9423941062914);
  let c3 = vec3f(-41.70399613139459, 17.43639888205313, 44.35414519872813);
  let c4 = vec3f(77.162935699427, -33.40235894210092, -81.80730925738993);
  let c5 = vec3f(-71.31942824499214, 32.62606426397723, 73.20951985803202);
  let c6 = vec3f(25.13112622477341, -12.24266895238567, -23.07032500287172);
  return clamp(c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6))))), vec3f(0.0), vec3f(1.0));
}

@fragment
fn fs(in: VertexOut) -> @location(0) vec4f {
  let g = in.uv * view.n - 0.5;
  let z = samplePsi(g);
  let density = dot(z, z);
  let brightness = 1.0 - exp(-sqrt(density * view.gain));

  let background = vec3f(0.016, 0.018, 0.027);
  var color: vec3f;
  if (view.mode < 0.5) {
    let hue = atan2(z.y, z.x) / 6.28318 + 0.5;
    let lit = pow(brightness, 0.75);
    color = mix(background, phaseColor(hue) * (0.35 + 0.75 * lit), lit);
  } else {
    color = mix(background, inferno(pow(brightness, 0.8)), smoothstep(0.0, 0.02, brightness));
  }

  // Soft potentials get a faint tint, hard walls a dark fill with a light rim.
  let v = samplePotential(g);
  let soft = clamp(v / 3.0, 0.0, 1.0);
  color += vec3f(0.10, 0.15, 0.30) * sqrt(soft);
  let hard = smoothstep(0.35 * view.wallV, 0.65 * view.wallV, v);
  let rim = clamp(fwidth(hard) * 1.6, 0.0, 1.0);
  color = mix(color, vec3f(0.085, 0.095, 0.13), hard);
  color = mix(color, vec3f(0.62, 0.70, 0.85), rim);

  return vec4f(color, 1.0);
}
