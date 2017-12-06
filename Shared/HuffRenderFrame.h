#import <Foundation/Foundation.h>

typedef enum {
  TEST_4x4_INCREASING1 = 0,
  TEST_4x4_INCREASING2,
  TEST_4x8_INCREASING1,
  TEST_2x8_INCREASING1
} HuffRenderFrameConfig;

// Define this symbol to enable functionality that captures
// output of each render pass and compares to expected values

#if defined(DEBUG)
# define CAPTURE_RENDER_PASS_OUTPUT
#endif // DEBUG

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

#if defined(DEBUG)

// If TRUE and DEBUG is enabled then output of the render frame will
// be captured and it can then be compared to the expected output.

@property (nonatomic, copy) NSArray *render_pass_expected_symbols;
@property (nonatomic, copy) NSArray *render_pass_expected_coords;
@property (nonatomic, copy) NSArray *render_pass_expected_blocki;
@property (nonatomic, copy) NSArray *render_pass_expected_rootBitOffset;
@property (nonatomic, copy) NSArray *render_pass_expected_currentBitOffset;
@property (nonatomic, copy) NSArray *render_pass_expected_bitWidth;
@property (nonatomic, copy) NSArray *render_pass_expected_bitPattern;

@property (nonatomic, copy) NSArray *render_pass_saved_symbolsTexture;
@property (nonatomic, copy) NSArray *render_pass_saved_coordsTexture;

#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)

@property (nonatomic, copy) NSArray *render_pass_saved_debugPixelBlockiTexture;
@property (nonatomic, copy) NSArray *render_pass_saved_debugRootBitOffsetTexture;
@property (nonatomic, copy) NSArray *render_pass_saved_debugCurrentBitOffsetTexture;
@property (nonatomic, copy) NSArray *render_pass_saved_debugBitWidthTexture;
@property (nonatomic, copy) NSArray *render_pass_saved_debugBitPatternTexture;

#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES

#endif // DEBUG

// Get a specific configuration given a HuffRenderFrameConfig identifier

+ (HuffRenderFrame*) renderFrameForConfig:(HuffRenderFrameConfig)config;

@end
