import PlaygroundSupport
import MetalKit

// guard 后面接一个true false判断，如果是false，就会走else里面的逻辑
guard let device = MTLCreateSystemDefaultDevice() else {
  fatalError("GPU is not supported")
}

let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1,
  green: 1, blue: 0.8, alpha: 1)


// 1
let allocator = MTKMeshBufferAllocator(device: device)
// 2
//let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75],
//                      segments: [100, 100],
//                      inwardNormals: false,
//                      geometryType: .triangles,
//                      allocator: allocator)
//let mdlMesh = MDLMesh(
//  coneWithExtent: [1,1,1],
//  segments: [10, 10],
//  inwardNormals: false,
//  cap: true,
//  geometryType: .triangles,
//  allocator: allocator)




//// begin export code
//// 1
//let asset = MDLAsset()
//asset.add(mdlMesh)
//// 2
//let fileExtension = "obj"
//guard MDLAsset.canExportFileExtension(fileExtension) else {
//  fatalError("Can't export a .\(fileExtension) format")
//}
//// 3
//do {
//  let url = playgroundSharedDataDirectory
//    .appendingPathComponent("primitive.\(fileExtension)")
//  try asset.export(to: url)
//} catch {
//  fatalError("Error \(error.localizedDescription)")
//}
//// end export code


guard let testURL = Bundle.main.url(
  forResource: "train",
  withExtension: "obj") else {
  fatalError()
}

// 1
let vertexDescriptor = MTLVertexDescriptor()
// 2
vertexDescriptor.attributes[0].format = .float3
// 3
vertexDescriptor.attributes[0].offset = 0
// 4
vertexDescriptor.attributes[0].bufferIndex = 0

// 1
vertexDescriptor.layouts[0].stride =
  MemoryLayout<SIMD3<Float>>.stride
// 2
let meshDescriptor =
  MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
// 3
(meshDescriptor.attributes[0] as! MDLVertexAttribute).name =
  MDLVertexAttributePosition

let asset = MDLAsset(
  url: testURL,
  vertexDescriptor: meshDescriptor,
  bufferAllocator: allocator)
let mdlMesh =
  asset.childObjects(of: MDLMesh.self).first as! MDLMesh

// 3
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float4 position [[attribute(0)]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[stage_in]]) {
  return vertex_in.position;
}

fragment float4 fragment_main() {
  return float4(1, 0, 0, 1);
}
"""



guard let commandQueue = device.makeCommandQueue() else {
  fatalError("Could not create a command queue")
}

let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
pipelineDescriptor.vertexFunction = vertexFunction
pipelineDescriptor.fragmentFunction = fragmentFunction


pipelineDescriptor.vertexDescriptor =
  MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

let pipelineState =
  try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

// 1
guard let commandBuffer = commandQueue.makeCommandBuffer(),
// 2
  let renderPassDescriptor = view.currentRenderPassDescriptor,
// 3
  let renderEncoder = commandBuffer.makeRenderCommandEncoder(
    descriptor:    renderPassDescriptor)
else { fatalError() }


renderEncoder.setRenderPipelineState(pipelineState)

renderEncoder.setVertexBuffer(
  mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

//guard let submesh = mesh.submeshes.first else {
//  fatalError()
//}
renderEncoder.setTriangleFillMode(.lines)
//renderEncoder.drawIndexedPrimitives(
//  type: .triangle,
//  indexCount: submesh.indexCount,
//  indexType: submesh.indexType,
//  indexBuffer: submesh.indexBuffer.buffer,
//  indexBufferOffset: 0)

for submesh in mesh.submeshes {
  renderEncoder.drawIndexedPrimitives(
    type: .triangle,
    indexCount: submesh.indexCount,
    indexType: submesh.indexType,
    indexBuffer: submesh.indexBuffer.buffer,
    indexBufferOffset: submesh.indexBuffer.offset
  )
}


// 1
renderEncoder.endEncoding()
// 2
guard let drawable = view.currentDrawable else {
  fatalError()
}
// 3
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view

	