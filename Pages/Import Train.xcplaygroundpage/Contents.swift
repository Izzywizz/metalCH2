import PlaygroundSupport
import MetalKit

guard let device = MTLCreateSystemDefaultDevice() else {
  fatalError("GPU is not supported")
}

let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)
view.device = device

guard let commandQueue = device.makeCommandQueue() else {
  fatalError("Could not create a command queue")
}

let allocator = MTKMeshBufferAllocator(device: device)
/// Sets up the URL for the model
guard let assetURL = Bundle.main.url(forResource: "train", withExtension: "obj") else {
    fatalError()
}

//1 - Create a descriptor, config the properties
let vertexDescriptor = MTLVertexDescriptor()
//2 - obj file holds the data as a float3 (xyz)
vertexDescriptor.attributes[0].format = .float3
//3 - the offset specifies where this buffer thjis paticular data will start
vertexDescriptor.attributes[0].offset = 0
//4 - Recall that you send vertex data to the GPU via render encoder which via MTLBuffer can identify tthe buffer by an index. MEtal has 31 buffers available and keeps track of them. Use buffer 0 so that the vertex shader func will match incoming vertex data with this layout.
vertexDescriptor.attributes[0].bufferIndex = 0

//1 - setting the stride to float3 ensures that you get the next vertex info, normally you would have to add the Normal and texture Coords (which are float 3 + float2) but you are only doing position data, so to get to the next postion, you jump by a stride of float3
//The stride is the number of bytes between each set of vertex information. (rfere to diagram page 51)
vertexDescriptor.layouts[0].stride = MemoryLayout<float3>.stride
//2 - Metal IO requires a slightly different format vertex descriptor, a MEtal IO one if you will
let meshDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
//3 - Assign the string name "position" to the attribute, we are only interested in position data (not normal. texture)
(meshDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition

let asset = MDLAsset(url: assetURL, vertexDescriptor: meshDescriptor, bufferAllocator: allocator)
let mesh = try MTKMesh(mesh: asset.object(at: 0) as! MDLMesh, device: device)

let shader = """
#include <metal_stdlib> \n
using namespace metal;

struct VertexIn {
float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
return vertex_in.position;
}

fragment float4 fragment_main() {
return float4(1, 0, 0, 1);
}
"""

let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

let descriptor = MTLRenderPipelineDescriptor()
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
descriptor.vertexFunction = vertexFunction
descriptor.fragmentFunction = fragmentFunction
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)

guard let commandBuffer = commandQueue.makeCommandBuffer(),
  let descriptor = view.currentRenderPassDescriptor,
  let renderEncoder =
  commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
  else { fatalError() }

renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer,
                              offset: 0, index: 0)

renderEncoder.setTriangleFillMode(.lines)

guard let submesh = mesh.submeshes.first else {
  fatalError()
}
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0)

renderEncoder.endEncoding()
guard let drawable = view.currentDrawable else {
  fatalError()
}
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view
