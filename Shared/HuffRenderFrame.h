#import <Foundation/Foundation.h>

@import MetalKit;

typedef enum {
  TEST_4x4_INCREASING1 = 0,
  TEST_4x4_INCREASING2,
  TEST_4x8_INCREASING1,
  TEST_2x8_INCREASING1,
  TEST_6x4_NOT_SQUARE,
  TEST_LARGE_RANDOM
} HuffRenderFrameConfig;

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inpute to the shaders
#import "AAPLShaderTypes.h"

@interface HuffRenderFrame : NSObject

@property (nonatomic, assign) int renderWidth;
@property (nonatomic, assign) int renderHeight;

@property (nonatomic, assign) int renderBlockWidth;
@property (nonatomic, assign) int renderBlockHeight;

@property (nonatomic, copy) NSData *inputData;

@property (nonatomic, assign) BOOL capture;

// If TRUE and DEBUG is enabled then output of the render frame will
// be captured and it can then be compared to the expected output.

#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
// Debug capture textures, these are same dimensions as _render_pass

@property (nonatomic, retain) id<MTLTexture> debugPixelBlockiTexture;
@property (nonatomic, retain) id<MTLTexture> debugRootBitOffsetTexture;
@property (nonatomic, retain) id<MTLTexture> debugCurrentBitOffsetTexture;
@property (nonatomic, retain) id<MTLTexture> debugBitWidthTexture;
@property (nonatomic, retain) id<MTLTexture> debugBitPatternTexture;
@property (nonatomic, retain) id<MTLTexture> debugSymbolsTexture;
@property (nonatomic, retain) id<MTLTexture> debugCoordsTexture;

@property (nonatomic, copy) NSData *expected_blocki;
@property (nonatomic, copy) NSData *expected_rootBitOffset;
@property (nonatomic, copy) NSData *expected_currentBitOffset;
@property (nonatomic, copy) NSData *expected_bitWidth;
@property (nonatomic, copy) NSData *expected_bitPattern;
@property (nonatomic, copy) NSData *expected_coords;
@property (nonatomic, copy) NSData *expected_symbols;

#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES

// Get a specific configuration given a HuffRenderFrameConfig identifier

+ (HuffRenderFrame*) renderFrameForConfig:(HuffRenderFrameConfig)config;

@end
