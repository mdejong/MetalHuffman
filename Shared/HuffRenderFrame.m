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
                            @0,  @1,  @4,  @5,
                            @2,  @3,  @6,  @7,
                            @8,  @9, @12, @13,
                            @10,  @11, @14, @15,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }

#if defined(CAPTURE_RENDER_PASS_OUTPUT)
      
      NSMutableArray *m_render_pass_expected_symbols = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_coords = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_blocki = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_rootBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_currentBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitWidth = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitPattern = [NSMutableArray array];
      
      // pass 0
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @0,  @4,
                                @8,  @12,
                                ]
                              );

      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                              @[
                                @[@0, @0], @[@2, @0],
                                @[@0, @2], @[@2, @2],
                                ]
                              );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );

      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );

      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @0,  @0,
                           @0,  @0,
                           ]
                         );

      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x0123),  @(0x4567),
                           @(0x89AB),  @(0xCDEF),
                           ]
                         );
      
      // pass 1
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @1,  @5,
                                @9,  @13,
                                ]
                              );

      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @0], @[@3, @0],
                                  @[@1, @2], @[@3, @2],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x1234),  @(0x5678),
                           @(0x9ABC),  @(0xDEF0),
                           ]
                         );
      
      // pass 2

      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @2,  @6,
                                @10,  @14,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@0, @1], @[@2, @1],
                                  @[@0, @3], @[@2, @3],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @8,  @8,
                           @8,  @8,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x2345),  @(0x6789),
                           @(0xABCD),  @(0xEF00),
                           ]
                         );

      // pass 3
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @3,  @7,
                                @11,  @15,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @1], @[@3, @1],
                                  @[@1, @3], @[@3, @3],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @12,  @12,
                           @12,  @12,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x3456),  @(0x789A),
                           @(0xBCDE),  @(0xF000),
                           ]
                         );

      renderFrame.render_pass_expected_symbols = [NSArray arrayWithArray:m_render_pass_expected_symbols];
      renderFrame.render_pass_expected_coords = [NSArray arrayWithArray:m_render_pass_expected_coords];
      renderFrame.render_pass_expected_blocki = [NSArray arrayWithArray:m_render_pass_expected_blocki];
      renderFrame.render_pass_expected_rootBitOffset = [NSArray arrayWithArray:m_render_pass_expected_rootBitOffset];
      renderFrame.render_pass_expected_currentBitOffset = [NSArray arrayWithArray:m_render_pass_expected_currentBitOffset];
      renderFrame.render_pass_expected_bitWidth = [NSArray arrayWithArray:m_render_pass_expected_bitWidth];
      renderFrame.render_pass_expected_bitPattern = [NSArray arrayWithArray:m_render_pass_expected_bitPattern];
      
#endif // CAPTURE_RENDER_PASS_OUTPUT
      
      break;
    }
    case TEST_4x4_INCREASING2: {
      renderFrame.renderWidth = 4;
      renderFrame.renderHeight = 4;

      {
        NSArray *values = @[
                            @0,  @1,  @4,  @0,
                            @2,  @3,  @5,  @0,
                            @6,  @7, @10, @0,
                            @8,  @9, @11, @0,
                            ];

        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
#if defined(CAPTURE_RENDER_PASS_OUTPUT)
      
      // Render passes
      
      NSMutableArray *m_render_pass_expected_symbols = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_coords = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_blocki = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_rootBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_currentBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitWidth = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitPattern = [NSMutableArray array];
      
      // pass 0
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @0,  @4,
                                @6,  @10,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@0, @0], @[@2, @0],
                                  @[@0, @2], @[@2, @2],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @14,
                           @26,  @42,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @0,  @0,
                           @0,  @0,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @2,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x19E2),  @(0x928B),
                           @(0xBCDE),  @(0xF100),
                           ]
                         );
      
      // pass 1
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @1,  @0,
                                @7,  @0,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @0], @[@3, @0],
                                  @[@1, @2], @[@3, @2],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @14,
                           @26,  @42,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @2,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @2,
                           @4,  @2,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x6789),  @(0x28BC),
                           @(0xCDEF),  @(0x1000),
                           ]
                         );
      
      // pass 2
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @2,  @5,
                                @8,  @11,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@0, @1], @[@2, @1],
                                  @[@0, @3], @[@2, @3],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @14,
                           @26,  @42,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @6,  @6,
                           @8,  @6,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x7892),  @(0xA2F3),
                           @(0xDEF1),  @(0x4000),
                           ]
                         );

      // pass 3
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @3,  @0,
                                @9,  @0,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @1], @[@3, @1],
                                  @[@1, @3], @[@3, @3],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @14,
                           @26,  @42,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @10,  @10,
                           @12,  @9,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @2,
                           @4,  @2,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x8928),  @(0x2F37),
                           @(0xEF10),  @(0x0000),
                           ]
                         );

      renderFrame.render_pass_expected_symbols = [NSArray arrayWithArray:m_render_pass_expected_symbols];
      renderFrame.render_pass_expected_coords = [NSArray arrayWithArray:m_render_pass_expected_coords];
      renderFrame.render_pass_expected_blocki = [NSArray arrayWithArray:m_render_pass_expected_blocki];
      renderFrame.render_pass_expected_rootBitOffset = [NSArray arrayWithArray:m_render_pass_expected_rootBitOffset];
      renderFrame.render_pass_expected_currentBitOffset = [NSArray arrayWithArray:m_render_pass_expected_currentBitOffset];
      renderFrame.render_pass_expected_bitWidth = [NSArray arrayWithArray:m_render_pass_expected_bitWidth];
      renderFrame.render_pass_expected_bitPattern = [NSArray arrayWithArray:m_render_pass_expected_bitPattern];
      
#endif // CAPTURE_RENDER_PASS_OUTPUT
      
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
      
#if defined(CAPTURE_RENDER_PASS_OUTPUT)
      
      // Render passes
      
      NSMutableArray *m_render_pass_expected_symbols = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_coords = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_blocki = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_rootBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_currentBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitWidth = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitPattern = [NSMutableArray array];
      
      // pass 0
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @0,  @4,
                                @8,  @12,
                                
                                @0,  @4,
                                @8,  @10,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@0, @0], @[@2, @0],
                                  @[@0, @2], @[@2, @2],
                                  
                                  @[@0, @4], @[@2, @4],
                                  @[@0, @6], @[@2, @6],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           
                           @4,  @5,
                           @6,  @7,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @47,
                           
                           @66,  @82,
                           @98,  @112,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @0,  @0,
                           @0,  @0,
                           
                           @0,  @0,
                           @0,  @0,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @5,
                           
                           @4,  @4,
                           @4,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x4567),  @(0x89AB),
                           @(0xC079),  @(0xEFBF),
                           
                           @(0x4567),  @(0x89AB),
                           @(0xCC00),  @(0x2490),
                           ]
                         );
      
      // pass 1

      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @1,  @5,
                                @9,  @13,
                                
                                @1,  @5,
                                @8,  @10,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @0], @[@3, @0],
                                  @[@1, @2], @[@3, @2],
                                  
                                  @[@1, @4], @[@3, @4],
                                  @[@1, @6], @[@3, @6],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           
                           @4,  @5,
                           @6,  @7,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @47,
                           
                           @66,  @82,
                           @98,  @112,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @4,  @4,
                           @4,  @5,
                           
                           @4,  @4,
                           @4,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @3,  @5,
                           
                           @4,  @4,
                           @4,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x5678),  @(0x9ABC),
                           @(0x079D),  @(0xF7F5),
                           
                           @(0x5678),  @(0x9ABC),
                           @(0xC009),  @(0x2480),
                           ]
                         );
      
      // pass 2
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @2,  @6,
                                @10, @14,
                                
                                @2,  @6,
                                @9,  @10,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@0, @1], @[@2, @1],
                                  @[@0, @3], @[@2, @3],
                                  
                                  @[@0, @5], @[@2, @5],
                                  @[@0, @7], @[@2, @7],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           
                           @4,  @5,
                           @6,  @7,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @47,
                           
                           @66,  @82,
                           @98,  @112,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @8,  @8,
                           @7,  @10,
                           
                           @8,  @8,
                           @8,  @6,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @3,  @5,
                           
                           @4,  @4,
                           @3,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x6789),  @(0xABC0),
                           @(0x3CEF),  @(0xFEA2),
                           
                           @(0x6789),  @(0xABCC),
                           @(0x0092),  @(0x2400),
                           ]
                         );
      
      // pass 3
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @3,  @7,
                                @11, @15,
                                
                                @3,  @7,
                                @9,  @10,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @1], @[@3, @1],
                                  @[@1, @3], @[@3, @3],
                                  
                                  @[@1, @5], @[@3, @5],
                                  @[@1, @7], @[@3, @7],
                                  ]
                                );

      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           
                           @4,  @5,
                           @6,  @7,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @47,
                           
                           @66,  @82,
                           @98,  @112,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @12,  @12,
                           @10,  @15,
                           
                           @12,  @12,
                           @11,  @9,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @5,  @4,
                           
                           @4,  @4,
                           @3,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x789A),  @(0xBC07),
                           @(0xE77D),  @(0xD456),
                           
                           @(0x789A),  @(0xBCC0),
                           @(0x0492),  @(0x2000),
                           ]
                         );
      
      renderFrame.render_pass_expected_symbols = [NSArray arrayWithArray:m_render_pass_expected_symbols];
      renderFrame.render_pass_expected_coords = [NSArray arrayWithArray:m_render_pass_expected_coords];
      renderFrame.render_pass_expected_blocki = [NSArray arrayWithArray:m_render_pass_expected_blocki];
      renderFrame.render_pass_expected_rootBitOffset = [NSArray arrayWithArray:m_render_pass_expected_rootBitOffset];
      renderFrame.render_pass_expected_currentBitOffset = [NSArray arrayWithArray:m_render_pass_expected_currentBitOffset];
      renderFrame.render_pass_expected_bitWidth = [NSArray arrayWithArray:m_render_pass_expected_bitWidth];
      renderFrame.render_pass_expected_bitPattern = [NSArray arrayWithArray:m_render_pass_expected_bitPattern];
      
#endif // CAPTURE_RENDER_PASS_OUTPUT
      
      break;
    }
      
    case TEST_2x8_INCREASING1: {
      renderFrame.renderWidth = 2;
      renderFrame.renderHeight = 8;
      
      {
        // a total of 4 blocks where input is in terms
        // of 2x2 blocks and the rewrite texture has
        // a width of 2. This is 16 values much like
        // a 4x4 texture would look except that the
        // rewrite coords need to account for the
        // output texture width for easy cropping.
        
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
      
#if defined(CAPTURE_RENDER_PASS_OUTPUT)
      
      NSMutableArray *m_render_pass_expected_symbols = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_coords = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_blocki = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_rootBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_currentBitOffset = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitWidth = [NSMutableArray array];
      NSMutableArray *m_render_pass_expected_bitPattern = [NSMutableArray array];
      
      // pass 0
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @0,  @4,
                                @8,  @12,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@0, @0], @[@0, @2],
                                  @[@0, @4], @[@0, @6],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @0,  @0,
                           @0,  @0,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x0123),  @(0x4567),
                           @(0x89AB),  @(0xCDEF),
                           ]
                         );
      
      // pass 1
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @1,  @5,
                                @9,  @13,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @0], @[@1, @2],
                                  @[@1, @4], @[@1, @6],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x1234),  @(0x5678),
                           @(0x9ABC),  @(0xDEF0),
                           ]
                         );
      
      // pass 2
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @2,  @6,
                                @10,  @14,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@0, @1], @[@0, @3],
                                  @[@0, @5], @[@0, @7],
                                  ]
                                );

      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @8,  @8,
                           @8,  @8,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x2345),  @(0x6789),
                           @(0xABCD),  @(0xEF00),
                           ]
                         );
      
      // pass 3
      
      appendSymbolBytesAsData(m_render_pass_expected_symbols,
                              @[
                                @3,  @7,
                                @11,  @15,
                                ]
                              );
      
      appendXYCoordPixelsAsData(m_render_pass_expected_coords,
                                @[
                                  @[@1, @1], @[@1, @3],
                                  @[@1, @5], @[@1, @7],
                                  ]
                                );
      
      appendPixelsAsData(m_render_pass_expected_blocki,
                         @[
                           @0,  @1,
                           @2,  @3,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_rootBitOffset,
                         @[
                           @0,  @16,
                           @32,  @48,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_currentBitOffset,
                         @[
                           @12,  @12,
                           @12,  @12,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitWidth,
                         @[
                           @4,  @4,
                           @4,  @4,
                           ]
                         );
      
      appendPixelsAsData(m_render_pass_expected_bitPattern,
                         @[
                           @(0x3456),  @(0x789A),
                           @(0xBCDE),  @(0xF000),
                           ]
                         );
      
      renderFrame.render_pass_expected_symbols = [NSArray arrayWithArray:m_render_pass_expected_symbols];
      renderFrame.render_pass_expected_coords = [NSArray arrayWithArray:m_render_pass_expected_coords];
      renderFrame.render_pass_expected_blocki = [NSArray arrayWithArray:m_render_pass_expected_blocki];
      renderFrame.render_pass_expected_rootBitOffset = [NSArray arrayWithArray:m_render_pass_expected_rootBitOffset];
      renderFrame.render_pass_expected_currentBitOffset = [NSArray arrayWithArray:m_render_pass_expected_currentBitOffset];
      renderFrame.render_pass_expected_bitWidth = [NSArray arrayWithArray:m_render_pass_expected_bitWidth];
      renderFrame.render_pass_expected_bitPattern = [NSArray arrayWithArray:m_render_pass_expected_bitPattern];
      
#endif // CAPTURE_RENDER_PASS_OUTPUT
      
      break;
    }
      
    case TEST_LARGE_RANDOM: {
      renderFrame.renderWidth = 256;
      renderFrame.renderHeight = 256;
      
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
  
  //renderFrame.capture = TRUE;
  renderFrame.capture = FALSE;
  
# if defined(DEBUG)
  if (renderFrame.capture) {
    assert(renderFrame.render_pass_expected_symbols != nil);
  }
# endif // DEBUG
  
  return renderFrame;
}

@end
