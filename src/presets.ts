import type { Packet } from './sim';

export interface Scene {
  id: string;
  name: string;
  blurb: string;
  /** Hard border walls instead of absorbing edges. */
  closed?: boolean;
  potential(v: Float32Array, n: number, wall: number): void;
  packet(n: number): Packet;
}

function fill(v: Float32Array, n: number, f: (x: number, y: number) => number) {
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) v[y * n + x] = f(x, y);
}

function slitWall(v: Float32Array, n: number, wall: number, x0: number, thickness: number, slits: number[], width: number) {
  fill(v, n, (x, y) => {
    if (Math.abs(x - x0) > thickness / 2) return 0;
    return slits.some((c) => Math.abs(y - c) < width / 2) ? 0 : wall;
  });
}

export const scenes: Scene[] = [
  {
    id: 'double-slit',
    name: 'Double slit',
    blurb:
      'A single particle passes through both slits at once and interferes with itself. Press M to measure where it lands.',
    potential(v, n, wall) {
      const s = n / 512;
      slitWall(v, n, wall, n * 0.4, 4 * s, [n / 2 - 20 * s, n / 2 + 20 * s], 12 * s);
    },
    packet: (n) => ({ x: n * 0.16, y: n / 2, kx: 0.95, ky: 0, sx: 14 * (n / 512), sy: 34 * (n / 512) }),
  },
  {
    id: 'single-slit',
    name: 'Single slit',
    blurb: 'Squeeze the wave through a narrow gap and it fans out. The narrower the slit, the wider the spread.',
    potential(v, n, wall) {
      const s = n / 512;
      slitWall(v, n, wall, n * 0.4, 4 * s, [n / 2], 18 * s);
    },
    packet: (n) => ({ x: n * 0.16, y: n / 2, kx: 0.95, ky: 0, sx: 14 * (n / 512), sy: 34 * (n / 512) }),
  },
  {
    id: 'tunneling',
    name: 'Tunneling',
    blurb:
      'The barrier is taller than the particle has energy to climb, yet part of the wave leaks through to the other side.',
    potential(v, n) {
      const s = n / 512;
      fill(v, n, (x) => (Math.abs(x - n * 0.5) < 1.5 * s ? 0.6 : 0));
    },
    packet: (n) => ({ x: n * 0.25, y: n / 2, kx: 1.05, ky: 0, sx: 20 * (n / 512), sy: 30 * (n / 512) }),
  },
  {
    id: 'harmonic',
    name: 'Harmonic trap',
    blurb:
      'A coherent state in a parabolic well orbits like a classical ball on a spring, without spreading out.',
    closed: true,
    potential(v, n) {
      const w = harmonicOmega(n);
      fill(v, n, (x, y) => {
        const dx = x - n / 2;
        const dy = y - n / 2;
        return 0.5 * w * w * (dx * dx + dy * dy);
      });
    },
    packet(n) {
      const w = harmonicOmega(n);
      const r = n * 0.25;
      // Ground-state width 1/sqrt(2ω), and v = ωr for a circular orbit.
      const sigma = 1 / Math.sqrt(2 * w);
      return { x: n / 2 + r, y: n / 2, kx: 0, ky: w * r, sx: sigma, sy: sigma };
    },
  },
  {
    id: 'stadium',
    name: 'Stadium billiard',
    blurb:
      'A packet bouncing inside a stadium, a shape whose classical paths are chaotic. The wave soon fills it with a speckled pattern.',
    closed: true,
    potential(v, n, wall) {
      const a = n * 0.17; // half-length of the straight section
      const r = n * 0.25; // radius of the end caps
      fill(v, n, (x, y) => {
        const dx = Math.max(Math.abs(x - n / 2) - a, 0);
        const dy = y - n / 2;
        return dx * dx + dy * dy > r * r ? wall : 0;
      });
    },
    packet: (n) => ({ x: n * 0.38, y: n * 0.42, kx: 0.9, ky: 0.55, sx: 12 * (n / 512), sy: 12 * (n / 512) }),
  },
  {
    id: 'scatter',
    name: 'Scattering',
    blurb: 'A wave hits a round obstacle and bends around it, filling in the shadow behind with interference.',
    potential(v, n, wall) {
      const r = n * 0.055;
      fill(v, n, (x, y) => ((x - n / 2) ** 2 + (y - n / 2) ** 2 < r * r ? wall : 0));
    },
    packet: (n) => ({ x: n * 0.2, y: n / 2, kx: 1.1, ky: 0, sx: 22 * (n / 512), sy: 30 * (n / 512) }),
  },
  {
    id: 'crystal',
    name: 'Crystal lattice',
    blurb:
      'A grid of atoms acts as a diffraction grating, splitting the wave into beams at sharp angles (Bragg diffraction).',
    potential(v, n, wall) {
      const s = n / 512;
      const spacing = 22 * s;
      const r = 4 * s;
      const x0 = n * 0.5;
      const x1 = n * 0.62;
      fill(v, n, (x, y) => {
        if (x < x0 - r || x > x1 + r) return 0;
        const gx = x0 + Math.round((x - x0) / spacing) * spacing;
        const gy = n / 2 + Math.round((y - n / 2) / spacing) * spacing;
        if (gx > x1 + 0.5) return 0;
        return (x - gx) ** 2 + (y - gy) ** 2 < r * r ? wall : 0;
      });
    },
    packet: (n) => ({ x: n * 0.2, y: n / 2, kx: 1.15, ky: 0, sx: 18 * (n / 512), sy: 60 * (n / 512) }),
  },
  {
    id: 'sandbox',
    name: 'Empty sandbox',
    blurb: 'Nothing but free space. Draw walls, then drag to fire particles at them. Hold Shift to add a second one.',
    potential(v) {
      v.fill(0);
    },
    packet: (n) => ({ x: n * 0.3, y: n / 2, kx: 0.8, ky: 0, sx: 16 * (n / 512), sy: 16 * (n / 512) }),
  },
];

function harmonicOmega(n: number) {
  return 0.004 * (512 / n);
}
