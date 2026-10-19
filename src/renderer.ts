import renderSource from './shaders/render.wgsl?raw';
import type { Simulation } from './sim';

export type ColorMode = 'phase' | 'probability';

export class Renderer {
  private readonly device: GPUDevice;
  private readonly context: GPUCanvasContext;
  private readonly pipeline: GPURenderPipeline;
  private readonly uniform: GPUBuffer;
  private readonly bindGroup: GPUBindGroup;
  private readonly n: number;
  private readonly wallV: number;

  constructor(device: GPUDevice, canvas: HTMLCanvasElement, sim: Simulation) {
    this.device = device;
    this.n = sim.n;
    this.wallV = sim.wallV;
    const context = canvas.getContext('webgpu');
    if (!context) throw new Error('Could not create a WebGPU canvas context');
    this.context = context;
    const format = navigator.gpu.getPreferredCanvasFormat();
    context.configure({ device, format, alphaMode: 'opaque' });

    const module = device.createShaderModule({ label: 'render', code: renderSource });
    const F = GPUShaderStage.FRAGMENT;
    const layout = device.createBindGroupLayout({
      entries: [
        { binding: 0, visibility: F, buffer: { type: 'uniform' } },
        { binding: 1, visibility: F, buffer: { type: 'read-only-storage' } },
        { binding: 2, visibility: F, buffer: { type: 'read-only-storage' } },
      ],
    });
    this.pipeline = device.createRenderPipeline({
      label: 'render',
      layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }),
      vertex: { module, entryPoint: 'vs' },
      fragment: { module, entryPoint: 'fs', targets: [{ format }] },
      primitive: { topology: 'triangle-list' },
    });
    this.uniform = device.createBuffer({ size: 16, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST });
    this.bindGroup = device.createBindGroup({
      layout,
      entries: [
        { binding: 0, resource: { buffer: this.uniform } },
        { binding: 1, resource: { buffer: sim.psi } },
        { binding: 2, resource: { buffer: sim.potentialBuffer } },
      ],
    });
  }

  draw(encoder: GPUCommandEncoder, gain: number, mode: ColorMode) {
    this.device.queue.writeBuffer(this.uniform, 0, new Float32Array([this.n, gain, mode === 'phase' ? 0 : 1, this.wallV]));
    const pass = encoder.beginRenderPass({
      colorAttachments: [
        {
          view: this.context.getCurrentTexture().createView(),
          loadOp: 'clear',
          storeOp: 'store',
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(this.pipeline);
    pass.setBindGroup(0, this.bindGroup);
    pass.draw(3);
    pass.end();
  }
}
