//
//  Util.h
//
//  Created by Moses DeJong on 10/2/13.
//  MIT Licensed

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

//#import "misc.h"

float min2f(float f1, float f2);
float min3f(float f1, float f2, float f3);

double min2d(double f1, double f2);
double min3d(double f1, double f2, double f3);

float max2f(float f1, float f2);
float max3f(float f1, float f2, float f3);

double max2d(double f1, double f2);
double max3d(double f1, double f2, double f3);

// Inlined integer min() and max() methods, should be as efficient as macros

static inline
uint32_t min2ui(uint32_t v1, uint32_t v2) {
  if (v1 <= v2) {
    return v1;
  } else {
    return v2;
  }
}

static inline
uint32_t min3ui(uint32_t v1, uint32_t v2, uint32_t v3) {
  uint32_t min = min2ui(v1, v2);
  return min2ui(min, v3);
}

static inline
uint32_t max2ui(uint32_t v1, uint32_t v2) {
  if (v1 >= v2) {
    return v1;
  } else {
    return v2;
  }
}

static inline
uint32_t max3ui(uint32_t v1, uint32_t v2, uint32_t v3) {
  uint32_t max = max2ui(v1, v2);
  return max2ui(max, v3);
}

// Clamp an integer value to a min and max range.
// This method operates only on unsigned integer
// values.

static inline
uint32_t clampui(uint32_t val, uint32_t min, uint32_t max) {
  if (val < min) {
    return min;
  } else if (val > max) {
    return max;
  } else {
    return val;
  }
}

// Clamp an integer value to a min and max range.
// This method operates only on signed integer
// values.

static inline
int32_t clampi(int32_t val, int32_t min, int32_t max) {
  if (val < min) {
    return min;
  } else if (val > max) {
    return max;
  } else {
    return val;
  }
}

// This pair of values is sorted together such that the
// floating point value and the data pointed to remain
// associated. This is critically important when sorting
// an element by a linear floating point value. When
// the original data is needed again, the values from
// the original pointer or data can be read again.

typedef
union {
  uint32_t value;
  void *ptr;
} QuicksortPointerOrIntegerValue;

typedef
struct
{
  double d;
  QuicksortPointerOrIntegerValue ptrOrValue;
} QuicksortDoublePair;

typedef
struct
{
  float f;
  QuicksortPointerOrIntegerValue ptrOrValue;
} QuicksortFloatPair;

// Binary search result constant

#define BINARY_SEARCH_VALUE_NOT_FOUND 0xFFFFFFFF

// Block subdivision type constants

typedef enum {
  BLOCK_SUBDIVISION_TYPE_NONE = 0,
  BLOCK_SUBDIVISION_TYPE_TOPBOTTOM,
  BLOCK_SUBDIVISION_TYPE_LEFTRIGHT,
  BLOCK_SUBDIVISION_TYPE_4UP,
  BLOCK_SUBDIVISION_TYPE_LEFTRIGHTHALF,
  BLOCK_SUBDIVISION_TYPE_LEFTHALFRIGHT,
  BLOCK_SUBDIVISION_TYPE_TOPBOTTOMHALF,
  BLOCK_SUBDIVISION_TYPE_TOPHALFBOTTOM,
  // L where 3 blocks are in one LUT
  BLOCK_SUBDIVISION_TYPE_L1,
  // L rotated 90 degrees clockwise
  BLOCK_SUBDIVISION_TYPE_L2,
  // L rotated 180 degrees clockwise (like a 7)
  BLOCK_SUBDIVISION_TYPE_L3,
  // L rotated 270 degrees clockwise (backward L)
  BLOCK_SUBDIVISION_TYPE_L4,
  // Final value is invalid
  BLOCK_SUBDIVISION_TYPE_END,
  // Checkerboard patterns
  BLOCK_SUBDIVISION_TYPE_CHECKERBOARD_BW_WB,
  BLOCK_SUBDIVISION_TYPE_CHECKERBOARD_WB_BW,
} BlockSubdivisionType;

static inline
uint8_t block_subdivision_type_to_byte(BlockSubdivisionType type) {
  uint8_t byte = (uint8_t) type;
  return byte;
}

static inline
BlockSubdivisionType block_subdivision_byte_to_type(uint8_t byteVal) {
  if (byteVal >= BLOCK_SUBDIVISION_TYPE_END) {
    assert(0);
  }
  return (BlockSubdivisionType)byteVal;
}

static inline
NSString* block_subdivision_type_to_str(BlockSubdivisionType type) {
  if (type == BLOCK_SUBDIVISION_TYPE_NONE) {
    return @"BLOCK_SUBDIVISION_TYPE_NONE";
  } else if (type == BLOCK_SUBDIVISION_TYPE_TOPBOTTOM) {
    return @"BLOCK_SUBDIVISION_TYPE_TOPBOTTOM";
  } else if (type == BLOCK_SUBDIVISION_TYPE_LEFTRIGHT) {
    return @"BLOCK_SUBDIVISION_TYPE_LEFTRIGHT";
  } else if (type == BLOCK_SUBDIVISION_TYPE_4UP) {
    return @"BLOCK_SUBDIVISION_TYPE_4UP";
  } else if (type == BLOCK_SUBDIVISION_TYPE_LEFTRIGHTHALF) {
    return @"BLOCK_SUBDIVISION_TYPE_LEFTRIGHTHALF";
  } else if (type == BLOCK_SUBDIVISION_TYPE_LEFTHALFRIGHT) {
    return @"BLOCK_SUBDIVISION_TYPE_LEFTHALFRIGHT";
  } else if (type == BLOCK_SUBDIVISION_TYPE_TOPBOTTOMHALF) {
    return @"BLOCK_SUBDIVISION_TYPE_TOPBOTTOMHALF";
  } else if (type == BLOCK_SUBDIVISION_TYPE_TOPHALFBOTTOM) {
    return @"BLOCK_SUBDIVISION_TYPE_TOPHALFBOTTOM";
  } else if (type == BLOCK_SUBDIVISION_TYPE_L1) {
    return @"BLOCK_SUBDIVISION_TYPE_L1";
  } else if (type == BLOCK_SUBDIVISION_TYPE_L2) {
    return @"BLOCK_SUBDIVISION_TYPE_L2";
  } else if (type == BLOCK_SUBDIVISION_TYPE_L3) {
    return @"BLOCK_SUBDIVISION_TYPE_L3";
  } else if (type == BLOCK_SUBDIVISION_TYPE_L4) {
    return @"BLOCK_SUBDIVISION_TYPE_L4";
  } else if (type == BLOCK_SUBDIVISION_TYPE_CHECKERBOARD_BW_WB) {
    return @"BLOCK_SUBDIVISION_TYPE_CHECKERBOARD_BW_WB";
  } else if (type == BLOCK_SUBDIVISION_TYPE_CHECKERBOARD_WB_BW) {
    return @"BLOCK_SUBDIVISION_TYPE_CHECKERBOARD_WB_BW";    
  } else {
    assert(0);
  }
}

NSArray*
block_subdivision_type_join(BlockSubdivisionType type, NSArray *quarterBlocks);

// class Util

@interface Util : NSObject

// Given a flat array of elements, split the values up into blocks of length elements.

#if !defined(CLIENT_ONLY_IMPL) || defined(DEBUG)

+ (NSArray*) splitIntoSubArraysOfLength:(NSArray*)arr
                                 length:(int)length;

// Given an array of arrays, flatten so that each object in each
// array is appended to a single array.

+ (NSMutableArray*) flattenArrays:(NSArray*)arrayOfValues;

#endif // CLIENT_ONLY_IMPL

// Implement the complex task of block zero padding and
// segmentation into squares of size blockSize.
// The return value is an array of rows where
// each row is an array of values.

#if !defined(CLIENT_ONLY_IMPL)

+ (NSArray*) splitIntoBlocksOfSize:(uint32_t)blockSize
                            values:(NSArray*)values
                             width:(uint32_t)width
                            height:(uint32_t)height
                  numBlocksInWidth:(uint32_t)numBlocksInWidth
                 numBlocksInHeight:(uint32_t)numBlocksInHeight
                         zeroValue:(NSObject*)zeroValue;

#endif // CLIENT_ONLY_IMPL

// This optimized version of splitIntoBlocksOfSize operates
// only on byte values. The input buffer is not padded with
// zeros while the output buffer is.

+ (void) splitIntoBlocksOfSize:(uint32_t)blockSize
                       inBytes:(uint8_t*)inBytes
                      outBytes:(uint8_t*)outBytes
                         width:(uint32_t)width
                        height:(uint32_t)height
              numBlocksInWidth:(uint32_t)numBlocksInWidth
             numBlocksInHeight:(uint32_t)numBlocksInHeight
                     zeroValue:(uint8_t)zeroValue;

// This optimized version of splitIntoBlocksOfSize operates
// only on word values. The input buffer is not padded with
// zeros while the output buffer is.

+ (void) splitIntoBlocksOfSize:(uint32_t)blockSize
                      inPixels:(uint32_t*)inPixels
                     outPixels:(uint32_t*)outPixels
                         width:(uint32_t)width
                        height:(uint32_t)height
              numBlocksInWidth:(uint32_t)numBlocksInWidth
             numBlocksInHeight:(uint32_t)numBlocksInHeight
                     zeroValue:(uint32_t)zeroValue;

#if !defined(CLIENT_ONLY_IMPL) || defined(DEBUG)

// Phony wrapper function that calls optimized splitIntoBlocksOfSize
// for word arguments but with NSObject inputs and outputs. This
// is useful only for test cases already written for the non-optimzied
// version of this code.

+ (NSArray*) splitIntoBlocksOfSizeWP:(uint32_t)blockSize
                              values:(NSArray*)values
                               width:(uint32_t)width
                              height:(uint32_t)height
                    numBlocksInWidth:(uint32_t)numBlocksInWidth
                   numBlocksInHeight:(uint32_t)numBlocksInHeight
                           zeroValue:(NSObject*)zeroValue;

// Implement the tricky task of reading blocks of values
// and flattening them out into an array of values.
// This involves processing each row of blocks
// and then appending each row of flat values.

+ (NSArray*) flattenBlocksOfSize:(uint32_t)blockSize
                          values:(NSArray*)values
                numBlocksInWidth:(uint32_t)numBlocksInWidth;

#endif // CLIENT_ONLY_IMPL

// This optimized version of flattenBlocksOfSize reads 32bit pixels
// from inPixels and writes the flattened blocks to the passed in
// outPixels buffer. This implementation is significantly more
// optimal when compared to flattenBlocksOfSize and it does not allocate
// intermediate objects in the tight loop. The buffers pointed to
// by inPixels and outPixels must be the same length as defined by
// the passed in width and height.

+ (void) flattenBlocksOfSize:(uint32_t)blockSize
                    inPixels:(uint32_t*)inPixels
                   outPixels:(uint32_t*)outPixels
            numBlocksInWidth:(uint32_t)numBlocksInWidth
           numBlocksInHeight:(uint32_t)numBlocksInHeight;

// Return the size of an image in terms of blocks given the block
// side dimension and the pixel width and height of the image.

+ (CGSize) blockSizeForSize:(CGSize)pixelSize
             blockDimension:(int)blockDimension;

// Given an array of pixel values, convert to an array of pixels values
// that contain a NSNumber of unsigned 32 bit type.

+ (NSArray*) pixelDataToArray:(NSData*)pixelData;

// Given an array of pixels inside NSNumber objects,
// append each pixel word to a mutable data and return.

+ (NSMutableData*) pixelsArrayToData:(NSArray*)pixels;

// Given a buffer of bytes, convert to an array of NSNumbers
// that contain and unsigned byte.

+ (NSArray*) byteDataToArray:(NSData*)byteData;

// Given an array of byte inside NSNumber objects,
// append each byte to a mutable data and return.

+ (NSMutableData*) bytesArrayToData:(NSArray*)bytes;

// Return the size of the file in bytes

+ (uint32_t) filesize:(NSString*)filepath;

// Format numbers into as comma separated string

+ (NSString*) formatNumbersAsString:(NSArray*)numbers;

@end
