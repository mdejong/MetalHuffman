/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands

#import "AAPLShaderTypes.h"

// Vertex shader outputs and per-fragmeht inputs.  Includes clip-space position and vertex outputs
//  interpolated by rasterizer and fed to each fragment genterated by clip-space primitives.
typedef struct
{
    // The [[position]] attribute qualifier of this member indicates this value is the clip space
    //   position of the vertex wen this structure is returned from the vertex shader
    float4 clipSpacePosition [[position]];

    // Since this member does not have a special attribute qualifier, the rasterizer will
    //   interpolate its value with values of other vertices making up the triangle and
    //   pass that interpolated value to the fragment shader for each fragment in that triangle;
    float2 textureCoordinate;

} RasterizerData;

typedef struct {
  uint8_t symbol;
  uint8_t bitWidth;
} HuffLookupSymbol;

// Vertex Function
vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             constant AAPLVertex *vertexArray [[ buffer(AAPLVertexInputIndexVertices) ]])
{
    RasterizerData out;

    // Index into our array of positions to get the current vertex
    //   Our positons are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
    //   the origin)
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
  
    // THe output position of every vertex shader is in clip space (also known as normalized device
    //   coordinate space, or NDC).   A value of (-1.0, -1.0) in clip-space represents the
    //   lower-left corner of the viewport wheras (1.0, 1.0) represents the upper-right corner of
    //   the viewport.

    out.clipSpacePosition.xy = pixelSpacePosition;
  
    // Set the z component of our clip space position 0 (since we're only rendering in
    //   2-Dimensions for this sample)
    out.clipSpacePosition.z = 0.0;

    // Set the w component to 1.0 since we don't need a perspective divide, which is also not
    //   necessary when rendering in 2-Dimensions
    out.clipSpacePosition.w = 1.0;

    // Pass our input textureCoordinate straight to our output RasterizerData.  This value will be
    //   interpolated with the other textureCoordinate values in the vertices that make up the
    //   triangle.
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    out.textureCoordinate.y = 1.0 - out.textureCoordinate.y;
    
    return out;
}

// Fill texture with gradient from green to blue as Y axis increases from origin at top left

fragment float4
fragmentFillShader1(RasterizerData in [[stage_in]],
                   float4 framebuffer [[color(0)]])
{
  return float4(0.0, (1.0 - in.textureCoordinate.y) * framebuffer.x, in.textureCoordinate.y * framebuffer.x, 1.0);
}

fragment float4
fragmentFillShader2(RasterizerData in [[stage_in]])
{
  return float4(0.0, 1.0 - in.textureCoordinate.y, in.textureCoordinate.y, 1.0);
}

// Fragment function
fragment float4
samplingPassThroughShader(RasterizerData in [[stage_in]],
               texture2d<half, access::sample> inTexture [[ texture(AAPLTextureIndexes) ]])
{
  constexpr sampler s(mag_filter::linear, min_filter::linear);
  
  return float4(inTexture.sample(s, in.textureCoordinate));
  
}

// Fragment function that crops from the input texture while rendering
// pixels to the output texture.

fragment half4
samplingCropShader(RasterizerData in [[stage_in]],
                   texture2d<ushort, access::read> inTexture [[ texture(0) ]],
                   constant RenderTargetDimensionsUniform &rtd [[ buffer(0) ]])
{
  // Convert float coordinates to integer (X,Y) offsets
  const float2 textureSize = float2(rtd.width, rtd.height);
  float2 c = in.textureCoordinate;
  const float2 halfPixel = (1.0 / textureSize) / 2.0;
  c -= halfPixel;
  ushort2 iCoordinates = ushort2(round(c * textureSize));
  
  ushort inByte = inTexture.read(iCoordinates).x;
  half value = inByte / 255.0h;
  half4 outGrayscale = half4(value, value, value, 1.0);
  return outGrayscale;
}

// Compute kernel that crops an input width and height while copying data to an output
// texture. In addition, this implementation will convert byte data to grayscale pixels.

kernel void crop_copy_and_grayscale(
                                    texture2d<ushort, access::read> inTexture [[texture(0)]],
                                    texture2d<half, access::write> outTexture [[texture(1)]],
                                    uint2 gid [[thread_position_in_grid]])
{
  if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
    return;
  }

  ushort inByte = inTexture.read(gid).x;
  half value = inByte / 255.0h;
  half4 outGrayscale = half4(value, value, value, 1.0);
  outTexture.write(outGrayscale, gid);
}

// huffman decoding kernel

// 4x4 with dim = 2
//
// 0 1 4 5
// 2 3 6 7
// 8 9 C D
// A B E F

// Encoded as streams:
//
// s0: 0 4 8 C
// s1: 1 5 9 D
// s2: 2 6 A E
// s3: 3 7 B F

// Each block will then be processed by a compute shader
// configured to execute 1 compute thread for each block.
// For example, the values (0, 1, 2, 3) will all be decoded
// by a single thread that corresponds to block at (0,0)
// in block coordinates. Output values are written to
// block0 one byte at a time.

kernel void
huffComputeKernel(texture2d<ushort, access::write>  wTexture  [[texture(AAPLTexturePaddedOut)]],
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
                  texture2d<half, access::write>  debugPixelBlockiTexture  [[texture(AAPLTextureBlocki)]],
                  texture2d<half, access::write>  debugRootBitOffsetTexture  [[texture(AAPLTextureRootBitOffset)]],
                  texture2d<half, access::write>  debugCurrentBitOffsetTexture  [[texture(AAPLTextureCurrentBitOffset)]],
                  texture2d<half, access::write>  debugBitWidthTexture  [[texture(AAPLTextureBitWidth)]],
                  texture2d<half, access::write>  debugBitPatternTexture  [[texture(AAPLTextureBitPattern)]],
                  texture2d<half, access::write>  debugSymbolsTexture  [[texture(AAPLTextureSymbols)]],
                  texture2d<half, access::write>  debugCoordTexture  [[texture(AAPLTextureCoords)]],
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
                  const device uint32_t *blockStartBitOffsetsPtr [[ buffer(AAPLComputeBlockStartBitOffsets) ]],
                  const device uint8_t *huffBuff [[ buffer(AAPLComputeHuffBuff) ]],
                  const device HuffLookupSymbol *huffSymbolTable [[ buffer(AAPLComputeHuffSymbolTable) ]],
                  const ushort2 gid [[thread_position_in_grid]])
{
  const ushort blockDim = BLOCK_DIM;

  // Calculate blocki in terms of the number of whole blocks in the output texture.
  
  const ushort numWholeBlocksInWidth = (wTexture.get_width() / blockDim);
  const int blocki = (int(gid.y) * numWholeBlocksInWidth) + gid.x;
  
  // Lookup the starting number of bits offset for each pixel in this block
  
  const uint numBitsReadForBlockRoot = blockStartBitOffsetsPtr[blocki];
  
  // Init running bit counter for the block
  
  ushort numBitsRead = 0;
  
  // For input (X,Y) in terms of block coordinates, determine the block root (upper left hand corner)
  // in pixel coordinates where the (blockDim*blockDim) symbols will be written to.

  const ushort2 blockRootCoords = gid * blockDim;
  
  for ( ushort renderStep = 0; renderStep < (blockDim * blockDim); renderStep++ ) {
    
    // Read starting at the number of bits indicated for this symbol in the block
    
    uint currentNumBits = numBitsReadForBlockRoot + numBitsRead;
    
    const ushort numBitsInByte = 8;
    int numBytesRead = int(currentNumBits / numBitsInByte);
    ushort numBitsReadMod8 = (currentNumBits % numBitsInByte);
    
    ushort inputBitPattern = 0;
    ushort b0 = huffBuff[numBytesRead];
    ushort b1 = huffBuff[numBytesRead+1];
    ushort b2 = huffBuff[numBytesRead+2];
    
    // Left shift the already consumed bits off left side of b0
    b0 <<= numBitsReadMod8;
    b0 &= 0xFF;
    inputBitPattern = b0 << 8;
    
    // Left shift the 8 bits in b1 then OR into inputBitPattern
    inputBitPattern |= b1 << numBitsReadMod8;
    
    // Right shift b2 to throw out unused bits
    b2 >>= (8 - numBitsReadMod8);
    inputBitPattern |= b2;
    
    // Lookup 16 bit symbol in left justified table
    
    HuffLookupSymbol hls = huffSymbolTable[inputBitPattern];
    
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
    ushort numBitsReadBeforeRenderStep = numBitsRead;
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
    
    numBitsRead += hls.bitWidth;
    
    // Map renderStep to (dx, dy) in terms of root coords, since blockDim is a compile
    // time constant this should be optimized by the compiler into bit operations.
    
    ushort dx = renderStep % blockDim;
    ushort dy = renderStep / blockDim;
    ushort2 outCoords = blockRootCoords + ushort2(dx, dy);
    
    // FIXME: emit a single byte at a time via shader write as opposed to 32 bit pixels
    
    //half4 outSymbolColor  = half4(0.0h, 0.0h, hls.symbol/255.0h, 1.0h);
    ushort outSymbol = hls.symbol;
    wTexture.write(outSymbol, outCoords);
    
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
    // Each debug value save operation will write to the block location but
    // offset by renderStep each time
    
    ushort2 debugBlockOutCoords = outCoords;
    
    // blocki value that the output pixel (x,y) corresponds to
    {
      half4 color4  = half4(((blocki >> 16) & 0xFF)/255.0h, ((blocki >> 8) & 0xFF)/255.0h, (blocki & 0xFF)/255.0h, 1.0h);
      debugPixelBlockiTexture.write(color4, debugBlockOutCoords);
    }
    
    // Absolute offset in bits into the huffman buffer based on blocki for each pixel in current block
    {
      const uint numBits = numBitsReadForBlockRoot;
      half4 color4  = half4(((numBits >> 16) & 0xFF)/255.0h, ((numBits >> 8) & 0xFF)/255.0h, (numBits & 0xFF)/255.0h, 1.0h);
      debugRootBitOffsetTexture.write(color4, debugBlockOutCoords);
    }
    
    // Number of bits read from current block before this symbol decode (depends on render step)
    {
      const uint numBits = numBitsReadBeforeRenderStep;
      half4 color4  = half4(((numBits >> 16) & 0xFF)/255.0h, ((numBits >> 8) & 0xFF)/255.0h, (numBits & 0xFF)/255.0h, 1.0h);
      debugCurrentBitOffsetTexture.write(color4, debugBlockOutCoords);
    }
    
    // Number of bits wide the currently decode symbol is (depends on render step)
    {
      const uint numBits = hls.bitWidth;
      half4 color4  = half4(((numBits >> 16) & 0xFF)/255.0h, ((numBits >> 8) & 0xFF)/255.0h, (numBits & 0xFF)/255.0h, 1.0h);
      debugBitWidthTexture.write(color4, debugBlockOutCoords);
    }
    
    // 16 bit bit pattern used as input to the match (depends on render step)
    
    {
      const uint pattern = inputBitPattern;
      half4 color4  = half4(0.0h, ((pattern >> 8) & 0xFF)/255.0h, (pattern & 0xFF)/255.0h, 1.0h);
      debugBitPatternTexture.write(color4, debugBlockOutCoords);
    }
    
    // Symbol in render pass layout as BGRA
    
    {
      half4 color4  = half4(0.0h, 0.0h, hls.symbol/255.0h, 1.0h);
      debugSymbolsTexture.write(color4, debugBlockOutCoords);
    }
    
    // Coord where symbol will be written to in render pass layout
    
    // FIXME: These (X,Y) values are represented here as 8 bit values bit they
    // will need to be 12 bit values to fully represent 4096 max size!
    
    {
      half4 color4  = half4(0/255.0h, outCoords.x/255.0h, outCoords.y/255.0h, 1.0h);
      debugCoordTexture.write(color4, debugBlockOutCoords);
    }
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
  }
}

// Given coordinates, calculate relative coordinates in a 2d grid
// by applying a block offset. A blockOffset for a 2x2 block
// would be:
//
// [0 1]
// [2 3]

ushort2 relative_coords(const ushort2 rootCoords, const ushort blockDim, ushort blockOffset);

ushort2 relative_coords(const ushort2 rootCoords, const ushort blockDim, ushort blockOffset)
{
  const ushort dx = blockOffset % blockDim;
  const ushort dy = blockOffset / blockDim;
  return rootCoords + ushort2(dx, dy);
}
