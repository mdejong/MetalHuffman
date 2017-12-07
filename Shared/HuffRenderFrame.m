#import "HuffRenderFrame.h"

#import "Util.h"

#include <stdlib.h>

@implementation HuffRenderFrame

// Convert values to a NSData that contains bytes and append to array

static void
appendSymbolBytesAsData(NSMutableArray * mArr, NSArray * values)
{
  NSData *expectedData = [Util bytesArrayToData:values];
  [mArr addObject:expectedData];
}

static void
appendPixelsAsData(NSMutableArray * mArr, NSArray * values)
{
  NSData *expectedData = [Util pixelsArrayToData:values];
  [mArr addObject:expectedData];
}

static NSData*
formatXYCoordPixelsAsData(NSArray * values)
{
  // values is an array of pairs, flatten into pixels as: X=G Y=B
  
  NSMutableArray *mPixels = [NSMutableArray array];
  
  for ( NSArray *pair in values ) {
    unsigned int X = [pair[0] unsignedIntValue];
    unsigned int Y = [pair[1] unsignedIntValue];
    unsigned int pixel = (0xFF << 24) | (X << 8) | (Y);
    NSNumber *num = [NSNumber numberWithUnsignedInt:pixel];
    [mPixels addObject:num];
  }
  
  NSData *expectedData = [Util pixelsArrayToData:mPixels];
  return expectedData;
}

static void
appendXYCoordPixelsAsData(NSMutableArray * mArr, NSArray * values)
{
  // values is an array of pairs, flatten into pixels as: X=G Y=B
  
  NSMutableArray *mPixels = [NSMutableArray array];
  
  for ( NSArray *pair in values ) {
    unsigned int X = [pair[0] unsignedIntValue];
    unsigned int Y = [pair[1] unsignedIntValue];
    unsigned int pixel = (0xFF << 24) | (X << 8) | (Y);
    NSNumber *num = [NSNumber numberWithUnsignedInt:pixel];
    [mPixels addObject:num];
  }
  
  NSData *expectedData = [Util pixelsArrayToData:mPixels];
  [mArr addObject:expectedData];
}


+ (HuffRenderFrame*) renderFrameForConfig:(HuffRenderFrameConfig)config
{
  
  HuffRenderFrame *renderFrame = [[HuffRenderFrame alloc] init];
  
  switch (config) {
    case TEST_4x4_INCREASING1: {
      renderFrame.renderWidth = 4;
      renderFrame.renderHeight = 4;
      
      {
        NSArray *values = @[
                            @0,   @1,  @4,  @5,
                            @2,   @3,  @6,  @7,
                            @8,   @9, @12, @13,
                            @10, @11, @14, @15,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }

#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
      
      // blocki
      
      {
        NSArray *values = @[
                            @0,   @0,  @1,  @1,
                            @0,   @0,  @1,  @1,
                            @2,   @2,  @3,  @3,
                            @2,   @2,  @3,  @3,
                            ];
        
        renderFrame.expected_blocki = [Util pixelsArrayToData:values];
      }
      
      // rootBitOffset
      
      {
        NSArray *values = @[
                            @0,   @0,  @16,  @16,
                            @0,   @0,  @16,  @16,
                            @32,  @32, @48,  @48,
                            @32,  @32, @48,  @48,
                            ];
        
        renderFrame.expected_rootBitOffset = [Util pixelsArrayToData:values];
      }
      
      // currentBitOffset
      
      {
        NSArray *values = @[
                            @0,   @4,   @0,  @4,
                            @8,   @12,  @8,  @12,
                            @0,   @4,   @0,  @4,
                            @8,   @12,  @8,  @12,
                            ];
        
        renderFrame.expected_currentBitOffset = [Util pixelsArrayToData:values];
      }
      
      // bitWidth
      
      {
        NSArray *values = @[
                            @4,   @4,  @4,  @4,
                            @4,   @4,  @4,  @4,
                            @4,   @4,  @4,  @4,
                            @4,   @4,  @4,  @4,
                            ];
        
        renderFrame.expected_bitWidth = [Util pixelsArrayToData:values];
      }
      
      // bitPattern
      
      {
        NSArray *values = @[
                            @(0x0123),   @(0x1234),  @(0x4567),  @(0x5678),
                            @(0x2345),   @(0x3456),  @(0x6789),  @(0x789A),
                            @(0x89AB),   @(0x9ABC),  @(0xCDEF),  @(0xDEF0),
                            @(0xABCD),   @(0xBCDE),  @(0xEF00),  @(0xF000),
                            ];
        
        renderFrame.expected_bitPattern = [Util pixelsArrayToData:values];
      }

      // coords
      
      {
        NSArray *values = @[
                            @[@0, @0], @[@1, @0], @[@2, @0], @[@3, @0],
                            @[@0, @1], @[@1, @1], @[@2, @1], @[@3, @1],
                            
                            @[@0, @2], @[@1, @2], @[@2, @2], @[@3, @2],
                            @[@0, @3], @[@1, @3], @[@2, @3], @[@3, @3],
                            ];
        
        renderFrame.expected_coords = formatXYCoordPixelsAsData(values);
      }
      
      renderFrame.expected_symbols = renderFrame.inputData;
      
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
      
      break;
    }
      
    case TEST_4x4_INCREASING2: {
      renderFrame.renderWidth = 4;
      renderFrame.renderHeight = 4;

      {
        NSArray *values = @[
                            @0,  @1,  @4, @0,
                            @2,  @3,  @5, @0,
                            @6,  @7, @10, @0,
                            @8,  @9, @11, @0,
                            ];

        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
      
      // blocki
      
      {
        NSArray *values = @[
                            @0,   @0,  @1,  @1,
                            @0,   @0,  @1,  @1,
                            @2,   @2,  @3,  @3,
                            @2,   @2,  @3,  @3,
                            ];
        
        renderFrame.expected_blocki = [Util pixelsArrayToData:values];
      }
      
      // rootBitOffset
      
      {
        NSArray *values = @[
                            @0,   @0,  @14,  @14,
                            @0,   @0,  @14,  @14,
                            @26,  @26, @42,  @42,
                            @26,  @26, @42,  @42,
                            ];
        
        renderFrame.expected_rootBitOffset = [Util pixelsArrayToData:values];
      }
      
      // currentBitOffset
      
      {
        NSArray *values = @[
                            @0,   @2,   @0,  @4,
                            @6,   @10,  @6,  @10,
                            @0,   @4,   @0,  @4,
                            @8,   @12,  @6,  @9,
                            ];
        
        renderFrame.expected_currentBitOffset = [Util pixelsArrayToData:values];
      }
      
      // bitWidth
      
      {
        NSArray *values = @[
                            @2,   @4,  @4,  @2,
                            @4,   @4,  @4,  @2,
                            @4,   @4,  @4,  @2,
                            @4,   @4,  @3,  @2,
                            ];
        
        renderFrame.expected_bitWidth = [Util pixelsArrayToData:values];
      }
      
      // bitPattern
      
      {
        NSArray *values = @[
                            @(0x19E2),   @(0x6789),  @(0x928B),  @(0x28BC),
                            @(0x7892),   @(0x8928),  @(0xA2F3),  @(0x2F37),
                            @(0xBCDE),   @(0xCDEF),  @(0xF100),  @(0x1000),
                            @(0xDEF1),   @(0xEF10),  @(0x4000),  @(0x0000),
                            ];
        
        renderFrame.expected_bitPattern = [Util pixelsArrayToData:values];
      }
      
      // coords
      
      {
        NSArray *values = @[
                            @[@0, @0], @[@1, @0], @[@2, @0], @[@3, @0],
                            @[@0, @1], @[@1, @1], @[@2, @1], @[@3, @1],
                            
                            @[@0, @2], @[@1, @2], @[@2, @2], @[@3, @2],
                            @[@0, @3], @[@1, @3], @[@2, @3], @[@3, @3],
                            ];
        
        renderFrame.expected_coords = formatXYCoordPixelsAsData(values);
      }
      
      renderFrame.expected_symbols = renderFrame.inputData;
      
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
      
      break;
    }

    case TEST_4x8_INCREASING1: {
      renderFrame.renderWidth = 4;
      renderFrame.renderHeight = 8;
      
      {
        NSArray *values = @[
                            @0,  @1,  @4,  @5,
                            @2,  @3,  @6,  @7,
                            @8,  @9,  @12, @13,
                            @10, @11, @14, @15,
                            
                            @0,  @1,  @4,  @5,
                            @2,  @3,  @6,  @7,
                            @8,  @8, @10, @10,
                            @9,  @9, @10, @10,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
      
      // blocki
      
      {
        NSArray *values = @[
                            @0,   @0,  @1,  @1,
                            @0,   @0,  @1,  @1,
                            @2,   @2,  @3,  @3,
                            @2,   @2,  @3,  @3,
                            
                            @4,   @4,  @5,  @5,
                            @4,   @4,  @5,  @5,
                            @6,   @6,  @7,  @7,
                            @6,   @6,  @7,  @7,
                            ];
        
        renderFrame.expected_blocki = [Util pixelsArrayToData:values];
      }
      
      // rootBitOffset
      
      {
        NSArray *values = @[
                            @0,   @0,  @16,  @16,
                            @0,   @0,  @16,  @16,
                            @32,  @32, @47,  @47,
                            @32,  @32, @47,  @47,
                            
                            @66,  @66,  @82,  @82,
                            @66,  @66,  @82,  @82,
                            @98,  @98, @112,  @112,
                            @98,  @98, @112,  @112,
                            ];
        
        renderFrame.expected_rootBitOffset = [Util pixelsArrayToData:values];
      }
      
      // currentBitOffset
      
      {
        NSArray *values = @[
                            @0,   @4,   @0,  @4,
                            @8,   @12,  @8,  @12,
                            @0,   @4,   @0,  @5,
                            @7,   @10, @10,  @15,
                            
                            @0,   @4,   @0,  @4,
                            @8,   @12,  @8,  @12,
                            @0,   @4,   @0,  @3,
                            @8,   @11,  @6,  @9,
                            ];
        
        renderFrame.expected_currentBitOffset = [Util pixelsArrayToData:values];
      }
      
      // bitWidth
      
      {
        NSArray *values = @[
                            @4,   @4,  @4,  @4,
                            @4,   @4,  @4,  @4,
                            @4,   @3,  @5,  @5,
                            @3,   @5,  @5,  @4,
                            
                            @4,   @4,  @4,  @4,
                            @4,   @4,  @4,  @4,
                            @4,   @4,  @3,  @3,
                            @3,   @3,  @3,  @3,
                            ];
        
        renderFrame.expected_bitWidth = [Util pixelsArrayToData:values];
      }
      
      // bitPattern
      
      {
        NSArray *values = @[
                            @(0x4567),   @(0x5678),  @(0x89AB),  @(0x9ABC),
                            @(0x6789),   @(0x789A),  @(0xABC0),  @(0xBC07),
                            @(0xC079),   @(0x079D),  @(0xEFBF),  @(0xF7F5),
                            @(0x3CEF),   @(0xE77D),  @(0xFEA2),  @(0xD456),
                            
                            @(0x4567),   @(0x5678),  @(0x89AB),  @(0x9ABC),
                            @(0x6789),   @(0x789A),  @(0xABCC),  @(0xBCC0),
                            @(0xCC00),   @(0xC009),  @(0x2490),  @(0x2480),
                            @(0x0092),   @(0x0492),  @(0x2400),  @(0x2000),
                            ];
        
        renderFrame.expected_bitPattern = [Util pixelsArrayToData:values];
      }
      
      // coords
      
      {
        NSArray *values = @[
                            @[@0, @0], @[@1, @0], @[@2, @0], @[@3, @0],
                            @[@0, @1], @[@1, @1], @[@2, @1], @[@3, @1],
                            
                            @[@0, @2], @[@1, @2], @[@2, @2], @[@3, @2],
                            @[@0, @3], @[@1, @3], @[@2, @3], @[@3, @3],
                            
                            @[@0, @4], @[@1, @4], @[@2, @4], @[@3, @4],
                            @[@0, @5], @[@1, @5], @[@2, @5], @[@3, @5],
                            
                            @[@0, @6], @[@1, @6], @[@2, @6], @[@3, @6],
                            @[@0, @7], @[@1, @7], @[@2, @7], @[@3, @7],
                            ];
        
        renderFrame.expected_coords = formatXYCoordPixelsAsData(values);
      }
      
      renderFrame.expected_symbols = renderFrame.inputData;
      
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
      
      break;
    }

    case TEST_2x8_INCREASING1: {
      renderFrame.renderWidth = 2;
      renderFrame.renderHeight = 8;
      
      {
        NSArray *values = @[
                            @0,  @1,
                            @2,  @3,
                            
                            @4,  @5,
                            @6,  @7,
                            
                            @8,  @9,
                            @10, @11,
                            
                            @12, @13,
                            @14, @15,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
      
      // blocki
      
      {
        NSArray *values = @[
                            @0,   @0,
                            @0,   @0,
                            @1,   @1,
                            @1,   @1,
                            
                            @2,   @2,
                            @2,   @2,
                            @3,   @3,
                            @3,   @3,
                            ];
        
        renderFrame.expected_blocki = [Util pixelsArrayToData:values];
      }
      
      // rootBitOffset
      
      {
        NSArray *values = @[
                            @0,   @0,
                            @0,   @0,
                            @16,  @16,
                            @16,  @16,
                            
                            @32,   @32,
                            @32,   @32,
                            @48,   @48,
                            @48,   @48,
                            ];
        
        renderFrame.expected_rootBitOffset = [Util pixelsArrayToData:values];
      }
      
      // currentBitOffset
      
      {
        NSArray *values = @[
                            @0,   @4,
                            @8,   @12,
                            @0,   @4,
                            @8,   @12,

                            @0,   @4,
                            @8,   @12,
                            @0,   @4,
                            @8,   @12,
                            ];
        
        renderFrame.expected_currentBitOffset = [Util pixelsArrayToData:values];
      }
      
      // bitWidth
      
      {
        NSArray *values = @[
                            @4,   @4,
                            @4,   @4,
                            @4,   @4,
                            @4,   @4,

                            @4,   @4,
                            @4,   @4,
                            @4,   @4,
                            @4,   @4,
                            ];
        
        renderFrame.expected_bitWidth = [Util pixelsArrayToData:values];
      }
      
      // bitPattern
      
      {
        NSArray *values = @[
                            @(0x0123),   @(0x1234),
                            @(0x2345),   @(0x3456),
                            @(0x4567),   @(0x5678),
                            @(0x6789),   @(0x789A),
                            
                            @(0x89AB),   @(0x9ABC),
                            @(0xABCD),   @(0xBCDE),
                            @(0xCDEF),   @(0xDEF0),
                            @(0xEF00),   @(0xF000),
                            ];
        
        renderFrame.expected_bitPattern = [Util pixelsArrayToData:values];
      }
      
      // coords
      
      {
        NSArray *values = @[
                            @[@0, @0], @[@1, @0],
                            @[@0, @1], @[@1, @1],
                            
                            @[@0, @2], @[@1, @2],
                            @[@0, @3], @[@1, @3],
                            
                            @[@0, @4], @[@1, @4],
                            @[@0, @5], @[@1, @5],
                            
                            @[@0, @6], @[@1, @6],
                            @[@0, @7], @[@1, @7],
                            ];
        
        renderFrame.expected_coords = formatXYCoordPixelsAsData(values);
      }
      
      renderFrame.expected_symbols = renderFrame.inputData;
      
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
      
      break;
    }
      
    case TEST_6x4_NOT_SQUARE: {
      renderFrame.renderWidth = 6;
      renderFrame.renderHeight = 4;
      
      {
        NSArray *values = @[
                            @0,     @1,     @2,     @3,     @4,     @5,
                            @3,     @3,     @1,     @1,     @2,     @2,
                            
                            @5,     @4,     @3,     @2,     @1,     @0,
                            @2,     @2,     @1,     @1,     @3,     @3,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
      
      // blocki
      
      {
        NSArray *values = @[
                            @0,   @0,  @1,  @1,  @2,   @2,
                            @0,   @0,  @1,  @1,  @2,   @2,
                            @3,   @3,  @4,  @4,  @5,   @5,
                            @3,   @3,  @4,  @4,  @5,   @5,
                            ];
        
        renderFrame.expected_blocki = [Util pixelsArrayToData:values];
      }
      
      // rootBitOffset
      
      {
        NSArray *values = @[
                            @0,   @0,  @10,  @10,  @18,  @18,
                            @0,   @0,  @10,  @10,  @18,  @18,
                            @29,  @29, @40,  @40,  @48,  @48,
                            @29,  @29, @40,  @40,  @48,  @48,
                            ];
        
        renderFrame.expected_rootBitOffset = [Util pixelsArrayToData:values];
      }
      
      // currentBitOffset
      
      {
        NSArray *values = @[
                            @0,   @4,  @0,  @2,  @0,  @4,
                            @6,   @8,  @4,  @6,  @7,  @9,
                            @0,   @3,  @0,  @2,  @0,  @2,
                            @7,   @9,  @4,  @6,  @6,  @8,
                            ];
        
        renderFrame.expected_currentBitOffset = [Util pixelsArrayToData:values];
      }
      
      // bitWidth
      
      {
        NSArray *values = @[
                            @4,   @2,  @2,  @2,  @4,  @3,
                            @2,   @2,  @2,  @2,  @2,  @2,
                            @3,   @4,  @2,  @2,  @2,  @4,
                            @2,   @2,  @2,  @2,  @2,  @2,
                            ];
        
        renderFrame.expected_bitWidth = [Util pixelsArrayToData:values];
      }
      
      // bitPattern
      
      {
        NSArray *values = @[
                            @(0xE298),   @(0x2983),  @(0x60FC),  @(0x83F2),   @(0xFCBB),  @(0xCBBD),
                            @(0xA60F),   @(0x983F),  @(0x0FCB),  @(0x3F2E),   @(0x5DEB),  @(0x77AC),
                            @(0xDEB2),   @(0xF590),  @(0x903A),  @(0x40EA),   @(0x3A80),  @(0xEA00),
                            @(0x5903),   @(0x640E),  @(0x03A8),  @(0x0EA0),   @(0xA000),  @(0x8000),
                            ];
        
        renderFrame.expected_bitPattern = [Util pixelsArrayToData:values];
      }
      
      // coords
      
      {
        NSArray *values = @[
                            @[@0, @0], @[@1, @0], @[@2, @0], @[@3, @0], @[@4, @0], @[@5, @0],
                            @[@0, @1], @[@1, @1], @[@2, @1], @[@3, @1], @[@4, @1], @[@5, @1],
                            
                            @[@0, @2], @[@1, @2], @[@2, @2], @[@3, @2], @[@4, @2], @[@5, @2],
                            @[@0, @3], @[@1, @3], @[@2, @3], @[@3, @3], @[@4, @3], @[@5, @3],
                            ];
        
        renderFrame.expected_coords = formatXYCoordPixelsAsData(values);
      }
      
      renderFrame.expected_symbols = renderFrame.inputData;
      
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
      
      break;
    }
      
    case TEST_LARGE_RANDOM: {
//      renderFrame.renderWidth = 2048;
//      renderFrame.renderHeight = 1536;
      
// Too large, causes runtime error
      renderFrame.renderWidth = 1024;
      renderFrame.renderHeight = 1024;

//      renderFrame.renderWidth = 512;
//      renderFrame.renderHeight = 512;
      
      sranddev();
      
      NSMutableArray *mValues = [NSMutableArray array];
      
      for ( int row = 0; row < renderFrame.renderHeight; row++ ) {
        for ( int col = 0; col < renderFrame.renderWidth; col++ ) {
          // Range (0, RAND_MAX)
          int r = rand();
          float normalized = r / (float) RAND_MAX;
          
          int byteVal = round(normalized * 255);
          
          [mValues addObject:@(byteVal)];
        }
      }
      
      renderFrame.inputData = [Util bytesArrayToData:mValues];
      
      break;
    }
  }
  
  assert(renderFrame.inputData);
  
  renderFrame.capture = TRUE;
  //renderFrame.capture = FALSE;
  
# if defined(DEBUG)
  if (renderFrame.capture) {
# if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
    assert(renderFrame.expected_symbols != nil);
# endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
  }
# endif // DEBUG
  
  return renderFrame;
}

@end
