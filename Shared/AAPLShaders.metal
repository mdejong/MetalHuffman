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

// Fixed size 2048 byte table

typedef struct {
  HuffLookupSymbol table[HUFF_TABLE1_SIZE];
} HuffLookupTable1;

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
                   texture2d<half, access::read> inTexture [[ texture(0) ]],
                   constant RenderTargetDimensionsAndBlockDimensionsUniform & rtd [[ buffer(0) ]])
{
  // Convert float coordinates to integer (X,Y) offsets
  const float2 textureSize = float2(rtd.width, rtd.height);
  float2 c = in.textureCoordinate;
  const float2 halfPixel = (1.0 / textureSize) / 2.0;
  c -= halfPixel;
  ushort2 iCoordinates = ushort2(round(c * textureSize));
  
  half value = inTexture.read(iCoordinates).x;
  half4 outGrayscale = half4(value, value, value, 1.0h);
  return outGrayscale;
}

// A single huffman symbol decode step

HuffLookupSymbol
huffDecodeSymbol(
                 const device uint8_t *huffBuff,
                 constant HuffLookupTable1 & huffSymbolTable1,
                 const device HuffLookupSymbol *huffSymbolTable2,
                 const uint currentNumBits)
{
  const ushort table1BitNum = HUFF_TABLE1_NUM_BITS;
  const ushort table2BitNum = HUFF_TABLE2_NUM_BITS;
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
  
  // Split input 16 bit pattern into table1 and table2 pattern
  
  ushort table1Pattern = inputBitPattern >> (16 - table1BitNum);
  ushort table2Pattern = inputBitPattern & (0xFFFF >> (16 - table2BitNum));
  
  // Lookup 16 bit symbol in left justified table
  
  HuffLookupSymbol hls = huffSymbolTable1.table[table1Pattern];

  if (hls.bitWidth == 0) {
    const ushort table2NumElements = pow(2.0h, table2BitNum);
    ushort offset = hls.symbol * table2NumElements;
    ushort offsetPlusPattern = table2Pattern + offset;
    hls = huffSymbolTable2[offsetPlusPattern];
  }

//  const ushort table2NumElements = pow(2.0h, table2BitNum);
//  ushort offset = hls.symbol * table2NumElements;
//  ushort offsetPlusPattern = table2Pattern + offset;
//  hls = (hls.bitWidth == 0) ? huffSymbolTable2[offsetPlusPattern] : hls;
  
  return hls;
}

// Given coordinates, calculate relative coordinates in a 2d grid
// by applying a block offset. A blockOffset for a 2x2 block
// would be:
//
// [0 1]
// [2 3]

ushort2 relative_coords(const ushort2 rootCoords, const ushort blockDim, ushort blockOffset)
{
  const ushort dx = blockOffset % blockDim;
  const ushort dy = blockOffset / blockDim;
  return rootCoords + ushort2(dx, dy);
}

// Given a half precision float value that represents a normalized byte, convert
// from floating point to a byte representation and return as a ushort value.

ushort ushort_from_half(const half inHalf)
{
  return ushort(round(inHalf * 255.0h));
}

uint uint_from_half(const half inHalf)
{
  return uint(ushort_from_half(inHalf));
}

// Given 4 half values that represent normalized float byte values,
// convert each component to a BGRA uint representation

uint uint_from_half4(const half4 inHalf4)
{
  ushort b = ushort_from_half(inHalf4.b);
  ushort g = ushort_from_half(inHalf4.g);
  ushort r = ushort_from_half(inHalf4.r);
  ushort a = ushort_from_half(inHalf4.a);
  
  ushort c0 = (g << 8) | b;
  ushort c1 = (a << 8) | r;
  
  return (uint(c1) << 16) | uint(c0);
}

// FIXME: faster to calc based on constant half pixel already as float?

// Given a fragment shader coordinate (normalized) calculate an integer "gid" value
// that represents the (X,Y) as a short coordinate pair.

ushort2 calc_gid_from_frag_norm_coord(const ushort2 dims, const float2 textureCoordinate)
{
  // Convert float coordinates to integer (X,Y) offsets, aka gid
  const float2 textureSize = float2(dims.x, dims.y);
  float2 c = textureCoordinate;
  const float2 halfPixel = (1.0 / textureSize) / 2.0;
  c -= halfPixel;
  ushort2 gid = ushort2(round(c * textureSize));
  return gid;
}

// This function implements a single step of a huffman symbol decode operation

uint8_t decode_one_huffman_symbol(
                                 const uint numBitsReadForBlockRoot,
                                 thread ushort & numBitsRead,
                                 thread ushort & prevSymbol,
                                 const device uint8_t *huffBuff,
                                 constant HuffLookupTable1 & huffSymbolTable1,
                                 const device HuffLookupSymbol *huffSymbolTable2)
{
  uint currentNumBits = numBitsReadForBlockRoot + numBitsRead;
  
  // Lookup 16 bit symbol in left justified table
  
  HuffLookupSymbol hls = huffDecodeSymbol(
                                          huffBuff,
                                          huffSymbolTable1,
                                          huffSymbolTable2,
                                          currentNumBits);
  numBitsRead += hls.bitWidth;
  
#if defined(IMPL_DELTAS_BEFORE_HUFF_ENCODING)
  ushort outSymbol = (prevSymbol + hls.symbol) & 0xFF;
  prevSymbol = outSymbol;
#else
  ushort outSymbol = hls.symbol;
#endif // IMPL_DELTAS_BEFORE_HUFF_ENCODING
  
  return outSymbol;
}

// Huffman compute kernel, this logic executes once for each
// conceptual 1x1 pixel of "input" and writes 8x8 blocks
// to the output with BGRA packing of the byte symbol values.
// For example, a 16x8 input with 8x8 blocks would generate
// a 4x8 combined BGRA output texture.

kernel void
huffB8Kernel(
             const device uint32_t *blockStartBitOffsetsPtr [[ buffer(0) ]],
             const device uint8_t *huffBuff [[ buffer(1) ]],
             constant HuffLookupTable1 & huffSymbolTable1 [[ buffer(2) ]],
             const device HuffLookupSymbol *huffSymbolTable2 [[ buffer(3) ]],
             constant RenderTargetDimensionsAndBlockDimensionsUniform & rtd [[ buffer(4) ]],
             texture2d<half, access::write> outTexture [[texture(0)]],
             ushort2                        gid         [[thread_position_in_grid]])
{
  const ushort blockDim = HUFF_BLOCK_DIM;
  const ushort numSymbolsPerPixel = 4;
  
  const ushort numPixelsInBlockWidth = HUFF_BLOCK_DIM / numSymbolsPerPixel;

  // (gidx, gidy) corresponds is the root coordinate of the output BGRA texture
  const ushort gidx = (gid.x * blockDim) / numSymbolsPerPixel;
  const ushort gidy = (gid.y * blockDim);

  // Calculate blocki in terms of the number of whole blocks in the output texture
  // where each pixel corresponds to one block.
  
  const ushort numWholeBlocksInWidth = rtd.blockWidth;
  const int blocki = (int(gid.y) * numWholeBlocksInWidth) + gid.x;
  
  // Init running bit counter for the block to zero, save starting bit offset of the block
  const uint numBitsReadForBlockRoot = blockStartBitOffsetsPtr[blocki];
  ushort numBitsRead = 0;
  ushort prevSymbol = 0;
  
  // Define a type that is the number of bytes in a row
  
  typedef struct {
    uint8_t row[4];
  } FourBytes;

  FourBytes rowCache[numPixelsInBlockWidth];
  
  for ( ushort y = 0; y < blockDim; y++ ) {
    // Decompress 4 symbols at a time and then write as a 32 bit BGRA pixel
    
    for ( ushort x = 0; x < numPixelsInBlockWidth; x++ ) {
      // Read huff code based on offset into block
      
      uint8_t B = decode_one_huffman_symbol(numBitsReadForBlockRoot, numBitsRead, prevSymbol, huffBuff, huffSymbolTable1, huffSymbolTable2);
      uint8_t G = decode_one_huffman_symbol(numBitsReadForBlockRoot, numBitsRead, prevSymbol, huffBuff, huffSymbolTable1, huffSymbolTable2);
      uint8_t R = decode_one_huffman_symbol(numBitsReadForBlockRoot, numBitsRead, prevSymbol, huffBuff, huffSymbolTable1, huffSymbolTable2);
      uint8_t A = decode_one_huffman_symbol(numBitsReadForBlockRoot, numBitsRead, prevSymbol, huffBuff, huffSymbolTable1, huffSymbolTable2);
      
      FourBytes fb;
      
      fb.row[0] = B;
      fb.row[1] = G;
      fb.row[2] = R;
      fb.row[3] = A;
      
      rowCache[x] = fb;
      
//      rowCache[x+0] = B;
//      rowCache[x+1] = G;
//      rowCache[x+2] = R;
//      rowCache[x+3] = A;
      
      // See values for (gidx, gidy)
//      half B = gidx/255.0h;
//      half G = gidy/255.0h;
//      half R = 0.0h/255.0h;
//      half A = 255.0h/255.0h;
      
//      half B = (blocki+blockOffset+0.0h)/255.0h;
//      half G = (blocki+blockOffset+1.0h)/255.0h;
//      half R = (blocki+blockOffset+2.0h)/255.0h;
//      half A = (blocki+blockOffset+3.0h)/255.0h;
      
      //half4 outPixel = half4(R, G, B, A);
      
      //rowCache[x] = outPixel;
     
      // Adjust gid to correspond to the output coordinates
      
      //outTexture.write(outPixel, ushort2(gidx+x, gidy+y));
    } // end x loop
    
    for ( ushort x = 0; x < numPixelsInBlockWidth; x++ ) {
//      half B = rowCache[x+0];
//      half G = rowCache[x+1];
//      half R = rowCache[x+2];
//      half A = rowCache[x+3];
      
      // See values for (gidx, gidy)
      //      half B = gidx/255.0h;
      //      half G = gidy/255.0h;
      //      half R = 0.0h/255.0h;
      //      half A = 255.0h/255.0h;
      
      //      half B = (blocki+blockOffset+0.0h)/255.0h;
      //      half G = (blocki+blockOffset+1.0h)/255.0h;
      //      half R = (blocki+blockOffset+2.0h)/255.0h;
      //      half A = (blocki+blockOffset+3.0h)/255.0h;
      
      //half4 outPixel = half4(R, G, B, A);
      
      FourBytes fb = rowCache[x];
      
      uint8_t B = fb.row[0];
      uint8_t G = fb.row[1];
      uint8_t R = fb.row[2];
      uint8_t A = fb.row[3];
      
      half4 outPixel = half4(R, G, B, A);
      //outPixel /= 255.0h;
      outPixel *= (1.0h / 255.0h);
      
      // Adjust gid to correspond to the output coordinates
      
      outTexture.write(outPixel, ushort2(gidx+x, gidy+y));
    } // end x loop
  }
  
  return;
}

// Read pixels from multiple textures and zip results back together

fragment half4
cropAndGrayscaleFromTexturesFragmentShader(RasterizerData in [[stage_in]],
                                           texture2d<half, access::read> inTexture [[ texture(0) ]],
                                           constant RenderTargetDimensionsAndBlockDimensionsUniform & rtd [[ buffer(0) ]])
{
  const ushort blockDim = HUFF_BLOCK_DIM;
  
  ushort2 gid = calc_gid_from_frag_norm_coord(ushort2(rtd.width, rtd.height), in.textureCoordinate);
  
//  ushort gidx = gid.x / 4;
//  ushort gidy = gid.y;
  
  // Calculate blocki in terms of the number of whole blocks in the input texture.
  
//  ushort2 blockRoot = gid / blockDim;
//  ushort2 blockRootCoords = blockRoot * blockDim;
//  ushort2 offsetFromBlockRootCoords = gid - blockRootCoords;
//  ushort offsetFromBlockRoot = (offsetFromBlockRootCoords.y * blockDim) + offsetFromBlockRootCoords.x;
//  ushort slice = (offsetFromBlockRoot / 4) % 16;

//  const ushort blockWidth = rtd.blockWidth;
//  const ushort blockHeight = rtd.blockHeight;
  //const ushort maxNumBlocksInColumn = 8;
  //ushort2 sliceCoord = ushort2(slice % maxNumBlocksInColumn, slice / maxNumBlocksInColumn);
  
  //ushort2 sliceCoord = ushort2(slice % maxNumBlocksInColumn, slice / maxNumBlocksInColumn);
  //ushort2 inCoords = blockRoot + ushort2(sliceCoord.x * blockWidth, sliceCoord.y * blockHeight);
  
  ushort2 inCoords = ushort2(gid.x / 4, gid.y);
  half4 inHalf4 = inTexture.read(inCoords);
  
  // For (0, 1, 2, 3, 0, 1, 2, 3, ...) choose (R, G, B, A)
  
  ushort remXOf4 = gid.x % 4;
  
//  This logic shows a range bug on A7
//  half4 reorder4 = half4(inHalf4.b, inHalf4.g, inHalf4.r, inHalf4.a);
//  uint bgraPixel = pack_half_to_unorm4x8(reorder4);
//  ushort bValue = (bgraPixel >> (remXOf4 * 8)) & 0xFF;
//  half value = bValue / 255.0h;

  //  This logic shows a range bug on A7
//  uint bgraPixel = uint_from_half4(inHalf4);
//  ushort bValue = (bgraPixel >> (remXOf4 * 8)) & 0xFF;
//  //half value = bValue / 255.0h;
//  return half4(bValue / 255.0h, bValue / 255.0h, bValue / 255.0h, 1.0h);

  // On A7, this array assign logic does not seem to have the bug and it
  // is faster than the if below.
  
  half hArr4[4];
  hArr4[0] = inHalf4.b;
  hArr4[1] = inHalf4.g;
  hArr4[2] = inHalf4.r;
  hArr4[3] = inHalf4.a;
  half value = hArr4[remXOf4];
  
  // This works and does not show the conversion bug, but seems slower than the array impl

  /*
  half value;

  if (remXOf4 == 0) {
    value = inHalf4.b;
  } else if (remXOf4 == 1) {
    value = inHalf4.g;
  } else if (remXOf4 == 2) {
    value = inHalf4.r;
  } else {
    value = inHalf4.a;
  }
  */
  
  half4 outGrayscale = half4(value, value, value, 1.0h);
  return outGrayscale;
}
