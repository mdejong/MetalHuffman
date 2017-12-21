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


// Convert an image to grayscale byte values and return as a NSData

+ (NSData*) convertImageToGrayScale:(UIImage *)image
{
  // Create image rectangle with current image width/height
  CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
  
  // Grayscale color space
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  
  // Create bitmap content with current image size and grayscale colorspace
  CGContextRef context = CGBitmapContextCreate(nil, image.size.width, image.size.height, 8, 0, colorSpace, kCGImageAlphaNone);
  
  // Draw image into current context, with specified rectangle
  // using previously defined context (with grayscale colorspace)
  CGContextDrawImage(context, imageRect, [image CGImage]);
  
  // Create bitmap image info from pixel data in current context
  //CGImageRef imageRef = CGBitmapContextCreateImage(context);
  
  // Create a new UIImage object
  //UIImage *newImage = [UIImage imageWithCGImage:imageRef];
  
  NSMutableData *mData = [NSMutableData dataWithBytes:CGBitmapContextGetData(context) length:image.size.width*image.size.height];
  
  // Release colorspace, context and bitmap information
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  //CFRelease(imageRef);
  
  // Return the new grayscale image
  //return newImage;
  
  return [NSData dataWithData:mData];
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
      
    case TEST_8x8_IDENT: {
      renderFrame.renderWidth = 8;
      renderFrame.renderHeight = 8;
      
      {
        NSArray *values = @[
                            @0,  @1,  @4,  @5,   @10, @11, @14, @15,
                            @2,  @3,  @6,  @7,   @12, @13, @16, @17,
                            @8,  @9,  @12, @13,  @18, @19, @22, @23,
                            @10, @11, @14, @15,  @20, @21, @24, @25,
                            
                            @30, @31, @34, @35,  @40, @41, @44, @45,
                            @32, @33, @36, @37,  @42, @43, @46, @47,
                            @38, @39, @42, @43,  @48, @49, @52, @53,
                            @40, @41, @44, @45,  @50, @51, @54, @55,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
      break;
    }

    case TEST_16x8_IDENT: {
      renderFrame.renderWidth = 16;
      renderFrame.renderHeight = 8;
      
      {
        NSArray *values = @[
                            @0,  @1,  @2,  @3,   @4,  @5,  @6,  @7,    @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            @8,  @9,  @10, @11,  @12, @13, @14, @15,   @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            @16, @17, @18, @19,  @20, @21, @22, @23,   @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            @24, @25, @26, @27,  @28, @29, @30, @31,   @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            
                            @0,  @1,  @2,  @3,   @4,  @5,  @6,  @7,    @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            @8,  @9,  @10, @11,  @12, @13, @14, @15,   @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            @16, @17, @18, @19,  @20, @21, @22, @23,   @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            @24, @25, @26, @27,  @28, @29, @30, @31,   @2,  @4,  @6,  @8,  @10,  @12,  @14,  @16,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
      break;
    }

    case TEST_16x16_IDENT: {
      renderFrame.renderWidth  = 16;
      renderFrame.renderHeight = 16;
      
      {
        NSArray *values = @[
                            @0,  @1,  @2,  @3,   @4,  @5,  @6,  @7,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            @10, @9,  @8,  @7,   @6,  @5,  @4,  @3,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            @0,  @1,  @2,  @3,   @4,  @5,  @6,  @7,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            @10, @9,  @8,  @7,   @6,  @5,  @4,  @3,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            
                            @50, @51, @52, @53,  @54, @55, @56, @57,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            @58, @57, @56, @55,  @54, @53, @52, @51,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            @50, @51, @52, @53,  @54, @55, @56, @57,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            @58, @57, @56, @55,  @54, @53, @52, @51,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            
                            @0,  @1,  @2,  @3,   @4,  @5,  @6,  @7,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            @10, @9,  @8,  @7,   @6,  @5,  @4,  @3,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            @0,  @1,  @2,  @3,   @4,  @5,  @6,  @7,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            @10, @9,  @8,  @7,   @6,  @5,  @4,  @3,    @102,  @104,  @106,  @108,  @110, @112, @114, @116,
                            
                            @50, @51, @52, @53,  @54, @55, @56, @57,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            @58, @57, @56, @55,  @54, @53, @52, @51,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            @50, @51, @52, @53,  @54, @55, @56, @57,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            @58, @57, @56, @55,  @54, @53, @52, @51,   @3,  @5,  @6,  @3,  @1,  @2,  @1,  @1,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
      break;
    }

    case TEST_16x16_IDENT2: {
      renderFrame.renderWidth  = 16;
      renderFrame.renderHeight = 16;
      
      {
        NSArray *values = @[
                            @228, @228, @228, @ 44, @  2, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            ];

        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
      break;
    }
      
    case TEST_16x16_IDENT3: {
      renderFrame.renderWidth  = 16;
      renderFrame.renderHeight = 16;
      
      {
        NSArray *values = @[
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @228, @228, @228, @ 44, @  2, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0, @  0,
                            ];
        
        renderFrame.inputData = [Util bytesArrayToData:values];
      }
      
      break;
    }

    case TEST_8x8_IDENT_2048: {
      renderFrame.renderWidth  = 2048;
      renderFrame.renderHeight = 2048;
      
      {
        NSMutableArray *mValues = [NSMutableArray array];
        
        for ( int i = 0; i < (2048 * 2048); i++ ) {
          [mValues addObject:@(i % 256)];
        }
        
        renderFrame.inputData = [Util bytesArrayToData:mValues];
      }
      
      break;
    }

    case TEST_8x8_IDENT_4096: {
      renderFrame.renderWidth  = 4096;
      renderFrame.renderHeight = 4096;
      
      {
        NSMutableArray *mValues = [NSMutableArray array];
        
        for ( int i = 0; i < (4096 * 4096); i++ ) {
          [mValues addObject:@(i % 256)];
        }
        
        renderFrame.inputData = [Util bytesArrayToData:mValues];
      }
      
      break;
    }
    
    case TEST_LARGE_RANDOM: {
//      renderFrame.renderWidth = 2048;
//      renderFrame.renderHeight = 1536;
      
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
      
    case TEST_IMAGE1: {
      // Load PNG image, convert to grayscale, load bytes
      
      NSString *resFilename = @"Image.png";
      NSString* path = [[NSBundle mainBundle] pathForResource:resFilename ofType:nil];
      NSAssert(path, @"path is nil");
      
      UIImage *img = [UIImage imageWithContentsOfFile:path];
      assert(img);
      
      // Convert PNG image
      
      renderFrame.renderWidth = img.size.width;
      renderFrame.renderHeight = img.size.height;
      
      renderFrame.inputData = [self convertImageToGrayScale:img];
      
      break;
    }

    case TEST_IMAGE2: {
      // Load PNG image, convert to grayscale, load bytes
      
      NSString *resFilename = @"ImageHuge.png";
      NSString* path = [[NSBundle mainBundle] pathForResource:resFilename ofType:nil];
      NSAssert(path, @"path is nil");
      
      UIImage *img = [UIImage imageWithContentsOfFile:path];
      assert(img);
      
      // Convert PNG image
      
      renderFrame.renderWidth = img.size.width;
      renderFrame.renderHeight = img.size.height;
      
      renderFrame.inputData = [self convertImageToGrayScale:img];
      
      break;
    }

    case TEST_IMAGE3: {
      // Load PNG image, convert to grayscale, load bytes
      
      NSString *resFilename = @"ImageIpadSize.png";
      NSString* path = [[NSBundle mainBundle] pathForResource:resFilename ofType:nil];
      NSAssert(path, @"path is nil");
      
      UIImage *img = [UIImage imageWithContentsOfFile:path];
      assert(img);
      
      // Convert PNG image
      
      renderFrame.renderWidth = img.size.width;
      renderFrame.renderHeight = img.size.height;
      
      renderFrame.inputData = [self convertImageToGrayScale:img];
      
      break;
    }

    case TEST_IMAGE4: {
      // Load 8bit grayscale image that is 2048x1536, the max iPad screen size
      
      NSString *resFilename = @"BigBridge.png";
      NSString* path = [[NSBundle mainBundle] pathForResource:resFilename ofType:nil];
      NSAssert(path, @"path is nil");
      
      UIImage *img = [UIImage imageWithContentsOfFile:path];
      assert(img);
      
      // Convert PNG image
      
      renderFrame.renderWidth = img.size.width;
      renderFrame.renderHeight = img.size.height;
      
      renderFrame.inputData = [self convertImageToGrayScale:img];
      
      break;
    }
  }
  
  assert(renderFrame.inputData);
  
  renderFrame.capture = TRUE;
  //renderFrame.capture = FALSE;
  
  return renderFrame;
}

@end
