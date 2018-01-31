/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enum constants shared between Metal shaders and C/ObjC source
*/
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum AAPLVertexInputIndex
{
    AAPLVertexInputIndexVertices     = 0,
} AAPLVertexInputIndex;

typedef enum AAPLFragmentInputIndex
{
  AAPLFragmentInputIndexViewportSize = 0,
  AAPLFragmentInputIndexIterateState = 1,
} AAPLFragmentInputIndex;

typedef enum AAPLComputeInputIndex
{
  AAPLComputeInputIterateState = 0,
} AAPLComputeInputIndex;

// Buffer input values for compute shader logic

typedef enum AAPLComputeBufferIndex
{
  AAPLComputeBlockStartBitOffsets = 0,
  AAPLComputeHuffBuff = 1,
  AAPLComputeHuffSymbolTable1 = 2,
  AAPLComputeHuffSymbolTable2 = 3
} AAPLComputeBufferIndex;

// Texture index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API texture set calls
typedef enum AAPLTextureIndex
{
  AAPLTextureIndexBaseColor = 0,
  AAPLTextureIndexes = 1,
  AAPLTextureLutOffsets = 2,
  AAPLTextureLuts = 3,
} AAPLTextureIndex;

//  This structre devines the layout of each vertex in the array of vertices set as an input to our
//    Metal vertex shader.  Since this header is shared between our .metal shader and C code,
//    we can be sure that the layout of the vertex array in the Ccode matches the layour that
//    our vertex shader expects
typedef struct
{
    //  Positions in pixel space (i.e. a value of 100 indicates 100 pixels from the origin/center)
    vector_float2 position;

    // 2D texture coordinate
    vector_float2 textureCoordinate;
} AAPLVertex;

// Constant argument struct

typedef struct {
  uint16_t outWidthInBlocks;
  uint8_t renderStep;
  uint8_t _dummy1;
} RenderStepConst;

/*
typedef struct
{
  uint16_t width;
  uint16_t height;
} RenderTargetDimensionsUniform;

typedef struct
{
  uint16_t width;
  uint16_t height;
  //uint16_t xRootOffset;
  //uint16_t yRootOffset;
  uint16_t offset;
  uint16_t _dummy;
} RenderPassDimensionsAndOffsetUniform;
*/

typedef struct
{
  uint16_t width;
  uint16_t height;
  uint16_t blockWidth;
  uint16_t blockHeight;
} RenderTargetDimensionsAndBlockDimensionsUniform;

typedef enum AAPLHuffmanTextureIndex
{
  AAPLTexturePaddedOut = 0,
  AAPLTextureBlocki = 1,
  AAPLTextureRootBitOffset = 2,
  AAPLTextureCurrentBitOffset = 3,
  AAPLTextureBitWidth = 4,
  AAPLTextureBitPattern = 5,
  AAPLTextureSymbols = 6,
  AAPLTextureCoords = 7,
} AAPLHuffmanTextureIndex;

#define IMPL_DELTAS_BEFORE_HUFF_ENCODING
//#define IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING

#define HUFF_BLOCK_DIM 8

// On both an A7 and A10 device, a primary table of 8 bits
// and a secondary table that is 8 bits seems to result
// in the best performance. T1 table sizes of 7,9,10,11
// were all tested and did not perform as well. The performance
// on A7 is quite poor with other table sizes.

#define HUFF_TABLE1_NUM_BITS (8)
#define HUFF_TABLE2_NUM_BITS (8)
#define HUFF_TABLE1_SIZE ((0xFFFF >> (16 - HUFF_TABLE1_NUM_BITS)) + 1)
#define HUFF_TABLE2_SIZE ((0xFFFF >> (16 - HUFF_TABLE2_NUM_BITS)) + 1)

#endif /* ShaderTypes_h */
