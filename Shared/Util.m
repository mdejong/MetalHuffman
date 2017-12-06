//
//  Util.m
//
//  Created by Moses DeJong on 10/2/13.
///  MIT Licensed

#import "Util.h"

@implementation Util

// Given a flat array of elements, split the values up into blocks of length elements.

#if !defined(CLIENT_ONLY_IMPL) || defined(DEBUG)

+ (NSArray*) splitIntoSubArraysOfLength:(NSArray*)arr
                                 length:(int)length
{
  NSAssert(length > 0, @"length must be positive");
  
  int numElementsLeft = (int) arr.count;
  
  NSMutableArray *mArr = [NSMutableArray array];
  
  NSRange range;
  
  range.location = 0;
  range.length = length;
  
  while (numElementsLeft > 0) {
    if (numElementsLeft < range.length) {
      range.length = numElementsLeft;
    }
    
    NSArray *subrange = [arr subarrayWithRange:range];
    
    [mArr addObject:subrange];
    
    numElementsLeft -= subrange.count;
    range.location = range.location + subrange.count;
  }
  
  return mArr;
}

// Given an array of arrays, flatten so that each object in each
// array is appended to a single array.

+ (NSMutableArray*) flattenArrays:(NSArray*)arrayOfValues
{
  NSMutableArray *flatValues = [NSMutableArray array];
  
  for (NSArray *arr in arrayOfValues) {
    [flatValues addObjectsFromArray:arr];
  }
  
  return flatValues;
}

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
                         zeroValue:(NSObject*)zeroValue
{
  BOOL debugBlockOutput = FALSE;
  
  NSAssert(blockSize > 0, @"blockSize cannot be zero");
  
  // Determine the number of columns in the overflow blocks on the right side
  
  uint32_t numOverflowColumns = (width % blockSize);
  uint32_t numOverflowRows = (height % blockSize);
  
  if (numOverflowColumns == 0 && numOverflowRows == 0) {
    if (debugBlockOutput) {
      NSLog(@"no overflow rows or columns, will process with whole (not zero padded) %d x %d blocks", blockSize, blockSize);
    }
  } else {
    if (debugBlockOutput) {
      NSLog(@"numOverflowColumns %d : numOverflowRows %d : (both zero paddded) %d x %d blocks",
            numOverflowColumns, numOverflowRows,
            blockSize, blockSize);
    }
  }

  uint32_t widthPadded = blockSize * numBlocksInWidth;
  uint32_t heightPadded = blockSize * numBlocksInHeight;

  NSMutableArray *paddedRows = [NSMutableArray array];

  // Split input values into rows and process each row to pad out to the block size
  
  NSArray *rows = [self splitIntoSubArraysOfLength:values length:width];
  
  for (NSArray *row in rows) {
    uint32_t rowLen = (int) row.count;
    
    if (rowLen < widthPadded) {
      NSMutableArray *paddedRow;
      paddedRow = [NSMutableArray arrayWithArray:row];
      
      uint32_t under = widthPadded - rowLen;
      for (int i=0; i < under; i++) {
        [paddedRow addObject:zeroValue];
      }
      
      [paddedRows addObject:paddedRow];
    } else {
      [paddedRows addObject:row];
    }
  }

  // Each row that needed to be padded is now the proper width. If whole rows
  // also need to be padded, do that now.

  uint32_t numPaddedRows = (uint32_t)paddedRows.count;
  
  int32_t paddedRowsOver = (numPaddedRows % heightPadded);
  int32_t paddedRowsUnder = 0;
  if (paddedRowsOver > 0) {
    assert(heightPadded >= paddedRowsOver);
    paddedRowsUnder = heightPadded - paddedRowsOver;
  }
  
  if (debugBlockOutput) {
    NSLog(@"need to add %d zero paddded rows", paddedRowsUnder);
  }
  
  NSMutableArray *paddedRow = [NSMutableArray array];
  
  for (int i=0; i < (blockSize * numBlocksInWidth); i++) {
    [paddedRow addObject:zeroValue];
  }
  
  for (int i=0; i < paddedRowsUnder; i++) {
    [paddedRows addObject:paddedRow];
  }

  // now formatted into array of padded rows, process in terms of blocks
  // to get values at specific indexes.
  
  NSMutableArray *blocks = [NSMutableArray array];
  
  // Block order
  //
  // -----------
  // 1  2   5  6
  // 3  4   7  8
  // -- ROW ----
  // 9  10 13 14
  // 11 12 15 16
  // -----------
  
  uint32_t blocki = 0;
  
  for (uint32_t block_rowi = 0; block_rowi < numBlocksInHeight; block_rowi++) {
    for (uint32_t block_coli = 0; block_coli < numBlocksInWidth; block_coli++) {
      
      if (debugBlockOutput) {
        NSLog(@"blocki %d", blocki);
      }
      
      uint32_t block_actual_rowi = block_rowi * blockSize;
      uint32_t block_actual_coli = block_coli * blockSize;

      if (debugBlockOutput) {
        NSLog(@"for block_rowi %d, block_actual_rowi %d", block_rowi, block_actual_rowi);
        NSLog(@"for block_coli %d, block_actual_coli %d", block_coli, block_actual_coli);
      }
      
      NSMutableArray *flatBlockValues = [NSMutableArray array];
      
      uint32_t max_num_rows = blockSize;
      
      for (int i = 0; i < max_num_rows; i++) {
        uint32_t offset_rowi = block_actual_rowi + i;

        NSArray *paddedRow = [paddedRows objectAtIndex:offset_rowi];
        
        if (debugBlockOutput) {
          NSLog(@"paddedRow %@", paddedRow);
        }
        
        uint32_t starti = block_actual_coli;
        uint32_t endi = starti + blockSize;
        endi -= 1;

        if (debugBlockOutput) {
          NSLog(@"for offset row i %d : range (%d %d)", i, starti, endi);
        }
        
        NSRange subrange;
        subrange.location = starti;
        subrange.length = endi - starti + 1;
        NSArray *blockValues = [paddedRow subarrayWithRange:subrange];
        
        if (debugBlockOutput) {
          NSLog(@"for offset row i %d : blockValues %@", i, blockValues);
        }
        
        uint32_t len = (uint32_t) blockValues.count;
        NSAssert(len == blockSize, @"expected %d pixels but got %d", blockSize, len);
        
        [flatBlockValues addObjectsFromArray:blockValues];
      }
      
      [blocks addObject:flatBlockValues];
      
      blocki += 1;
    }
  }
  
  return blocks;
}

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
                     zeroValue:(uint8_t)zeroValue
{
  const BOOL debug = FALSE;
  
  // Loop over blockSize bytes at a time appending one row of block
  // values at a time to a specific block pointer.
  
  const uint32_t numBytesInOneBlock = blockSize * blockSize;
  
  const uint32_t blockMax = numBlocksInWidth * numBlocksInHeight;
  
  const uint32_t numBytesInAllBlocks = numBytesInOneBlock * blockMax;
  
  // zero out block memory to a known init value, any bytes not written
  // over in the loop below will stay the default zero padding value.
  
  memset(outBytes, zeroValue, numBytesInAllBlocks);
  
  // This array of pointers points to the next available address
  // for each block. As a block is filled in row by row this
  // address is updated to account for the row that was written.
  
  uint8_t **blockStartPtrs = (uint8_t **) malloc(numBlocksInWidth*numBlocksInHeight*sizeof(uint8_t*));
  
  for (int blocki = 0; blocki < blockMax; blocki++) {
    blockStartPtrs[blocki] = &outBytes[blocki * numBytesInOneBlock];
  }
  
  // Iterate over each row and then over a block worth of pixels
  
  uint32_t offset = 0;
  uint32_t numBlocksInThisManyRows = 0;
  uint32_t rowCountdown = blockSize;
  
  for (int rowi = 0; rowi < height; rowi++, rowCountdown--) {
    if (rowCountdown == 0) {
      numBlocksInThisManyRows++;
      rowCountdown = blockSize;
    }
    
    for (int columnBlocki = 0; columnBlocki < numBlocksInWidth; columnBlocki++) {
      // Iterate once for each block in this row
      
      uint32_t blocki = (numBlocksInThisManyRows * numBlocksInWidth) + columnBlocki;

      if (debug) {
        NSLog(@"row %d col %d = blocki %d", rowi, columnBlocki*blockSize, blocki);
      }
      
      uint8_t *blockOutPtr = blockStartPtrs[blocki];
      
      uint32_t numBytesToCopy = blockSize;
      
      if (columnBlocki == (numBlocksInWidth - 1)) {
        uint32_t over = blockSize - ((numBlocksInWidth * blockSize) - width);
        if (over != 0) {
          numBytesToCopy = over;
          
          if (debug) {
            NSLog(@"found block row %d with cropped width %d", rowi, numBytesToCopy);
          }
        }
      }
      
      memcpy(blockOutPtr, &inBytes[offset], numBytesToCopy);
     
      if (debug) {
        for (int i=0; i < numBytesToCopy; i++) {
          NSLog(@"wrote byte %d to block %d", blockOutPtr[i], blocki);
        }
      }
      
      offset += numBytesToCopy;
      
      blockOutPtr += blockSize;
      
      blockStartPtrs[blocki] = blockOutPtr;
    }
  }
  
  free(blockStartPtrs);
  
  return;
}

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
                     zeroValue:(uint32_t)zeroValue
{
  const BOOL debug = FALSE;
  
  // Loop over blockSize bytes at a time appending one row of block
  // values at a time to a specific block pointer.
  
  const uint32_t numPixelsInOneBlock = blockSize * blockSize;
  
  const uint32_t blockMax = numBlocksInWidth * numBlocksInHeight;
  
  const uint32_t numPixelsInAllBlocks = numPixelsInOneBlock * blockMax;
  
  // zero out block memory to a known init value, any bytes not written
  // over in the loop below will stay the default zero padding value.
  
  if (zeroValue == 0) {
    memset(outPixels, 0, numPixelsInAllBlocks * sizeof(uint32_t));
  } else {
    for (int i = 0; i < numPixelsInAllBlocks; i++ ) {
      outPixels[i] = zeroValue;
    }
  }
  
  // This array of pointers points to the next available address
  // for each block. As a block is filled in row by row this
  // address is updated to account for the row that was written.
  
  uint32_t *blockStartPtrs[numBlocksInWidth*numBlocksInHeight];
  
  for (int blocki = 0; blocki < blockMax; blocki++) {
    blockStartPtrs[blocki] = &outPixels[blocki * numPixelsInOneBlock];
  }
  
  // Iterate over each row and then over a block worth of pixels
  
  uint32_t offset = 0;
  uint32_t numBlocksInThisManyRows = 0;
  uint32_t rowCountdown = blockSize;
  
  for (int rowi = 0; rowi < height; rowi++, rowCountdown--) {
    if (rowCountdown == 0) {
      numBlocksInThisManyRows++;
      rowCountdown = blockSize;
    }
    
    for (int columnBlocki = 0; columnBlocki < numBlocksInWidth; columnBlocki++) {
      // Iterate once for each block in this row
      
      uint32_t blocki = (numBlocksInThisManyRows * numBlocksInWidth) + columnBlocki;
      
      if (debug) {
        NSLog(@"row %d col %d = blocki %d", rowi, columnBlocki*blockSize, blocki);
      }
      
      uint32_t *blockOutPtr = blockStartPtrs[blocki];
      
      uint32_t numPixelsToCopy = blockSize;
      
      if (columnBlocki == (numBlocksInWidth - 1)) {
        uint32_t widthWholeBlocks = numBlocksInWidth * blockSize;
        
        if (width < widthWholeBlocks) {
          numPixelsToCopy = width - (widthWholeBlocks - blockSize);
          
#if defined(DEBUG)
          assert(width < widthWholeBlocks);
          assert((width % blockSize) == numPixelsToCopy);
          assert(numPixelsToCopy < blockSize);
#endif // DEBUG
          
          if (debug) {
            NSLog(@"found block row %d with cropped width %d", rowi, numPixelsToCopy);
          }
        }
        
#if defined(DEBUG)
        assert(numPixelsToCopy <= blockSize);
#endif // DEBUG
      }
      
      memcpy(blockOutPtr, &inPixels[offset], numPixelsToCopy*sizeof(uint32_t));
      
      if (debug) {
        for (int i=0; i < numPixelsToCopy; i++) {
          NSLog(@"wrote byte %d to block %d", blockOutPtr[i], blocki);
        }
      }
      
      offset += numPixelsToCopy;
      
      blockOutPtr += blockSize;
      
      blockStartPtrs[blocki] = blockOutPtr;
    }
  }
  
  return;
}

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
                           zeroValue:(NSObject*)zeroValue
{
  NSMutableData *inPixelsData = [NSMutableData data];
  [inPixelsData setLength:width*height*sizeof(uint32_t)];
  uint32_t *inPixelsPtr = (uint32_t*)inPixelsData.bytes;
  
  for (int i = 0; i < (width*height); i++) {
    uint32_t pixel = [values[i] unsignedIntValue];
    inPixelsPtr[i] = pixel;
  }
  
  int numPixelsInOneBlock = blockSize * blockSize;
  int numPixelsInAllBlocks = numPixelsInOneBlock * (numBlocksInWidth * numBlocksInHeight);
  
  NSMutableData *outPixelsData = [NSMutableData data];
  [outPixelsData setLength:numPixelsInAllBlocks*sizeof(uint32_t)];
  uint32_t *outPixelsPtr = (uint32_t*)outPixelsData.bytes;
  
  [self splitIntoBlocksOfSize:blockSize
                     inPixels:inPixelsPtr
                    outPixels:outPixelsPtr
                        width:width
                       height:height
             numBlocksInWidth:numBlocksInWidth
            numBlocksInHeight:numBlocksInHeight
                    zeroValue:[(NSNumber*)zeroValue unsignedIntValue]];
  
  NSMutableArray *mAllBlocks = [NSMutableArray array];
  
  int pixelOffset = 0;
  
  for ( int blocki = 0; blocki < (numBlocksInWidth * numBlocksInHeight); blocki++) {
    NSMutableArray *mBlock = [NSMutableArray array];
    
    for ( int pixeli = 0; pixeli < numPixelsInOneBlock; pixeli++ ) {
      uint32_t pixel = outPixelsPtr[pixelOffset++];
      NSNumber *num = [NSNumber numberWithUnsignedInt:pixel];
      [mBlock addObject:num];
    }
    
    [mAllBlocks addObject:mBlock];
  }
  
  return mAllBlocks;
}

#endif // CLIENT_ONLY_IMPL

// Implement the tricky task of reading blocks of values
// and flattening them out into an array of values.
// This involves processing each row of blocks
// and then appending each row of flat values.

#if !defined(CLIENT_ONLY_IMPL) || defined(DEBUG)

+ (NSArray*) flattenBlocksOfSize:(uint32_t)blockSize
                          values:(NSArray*)values
                numBlocksInWidth:(uint32_t)numBlocksInWidth
{
  NSMutableData *inData = [Util pixelsArrayToData:values];
  NSMutableData *outData = [NSMutableData data];
  [outData setLength:inData.length];
  
  uint32_t *inPixelsPtr = (uint32_t *) inData.bytes;
  uint32_t *outPixelsPtr = (uint32_t *) outData.bytes;

  assert((((uint32_t)inData.length) % (numBlocksInWidth * blockSize * sizeof(uint32_t))) == 0);
  uint32_t numRows = ((uint32_t)inData.length) / (numBlocksInWidth * blockSize * sizeof(uint32_t));
  assert((numRows % blockSize) == 0);
  uint32_t numBlocksInHeight = numRows / blockSize;

  [self flattenBlocksOfSize:blockSize
                   inPixels:inPixelsPtr
                  outPixels:outPixelsPtr
           numBlocksInWidth:numBlocksInWidth
          numBlocksInHeight:numBlocksInHeight];
  
  return [Util pixelDataToArray:outData];
}

#endif

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
           numBlocksInHeight:(uint32_t)numBlocksInHeight
{
  const BOOL debugBlockOutput = FALSE;
  
  // Iterate over each block and write the output to one row at a time.
  
  const int numBlocksTotal = numBlocksInWidth * numBlocksInHeight;
  const int numPixelsInBlock = blockSize * blockSize;
  
  if (debugBlockOutput) {
    NSLog(@"numBlocksInWidth x numBlocksInHeight : %d x %d", numBlocksInWidth, numBlocksInHeight);
    NSLog(@"numBlocksTotal = %d", numBlocksTotal);
    NSLog(@"pixels per row %d", (int)(numBlocksInWidth * blockSize));
  }
  
  uint32_t *inPixelsPtr = inPixels;
  
  int rowOfBlocksi = 0;
  
  for (int blocki = 0; blocki < numBlocksTotal; ) {
    
    if (debugBlockOutput) {
      NSLog(@"blocki %d with rowOfBlocksi %d", blocki, rowOfBlocksi);
    }
    
    // The start of a block in inPixels means that next ( blockSize * blockSize )
    // pixels contain the block pixels. Each row of input pixels contains
    // blockSize pixels and these rows are written to different offsets in
    // the output.
    
    for (int rowi = 0; rowi < blockSize; rowi++) {
      uint32_t blockRootOffset = ((blocki % numBlocksInWidth) * blockSize) + (rowOfBlocksi * (numPixelsInBlock * numBlocksInWidth));
      uint32_t *outPixelsBlockRootPtr = &outPixels[blockRootOffset];
      
      uint32_t *outPixelsRowPtr = outPixelsBlockRootPtr + (rowi * blockSize * numBlocksInWidth);
      
      if (debugBlockOutput) {
        NSLog(@"copy %d pixels from input offset %d to output offset %d",
              (int)blockSize, (int)(inPixelsPtr - inPixels), (int)(outPixelsRowPtr - outPixels));
        NSLog(@"numBlocksTotal = %d", numBlocksTotal);
        NSLog(@"pixels per row %d", (int)(numBlocksInWidth * blockSize));
      }
      
      // Copy the next blockSize for this specific row
      
      if ((0)) {
        for (int i = 0; i < blockSize; i++) {
          uint32_t pixel = *inPixelsPtr++;
          *outPixelsRowPtr++ = pixel;
          
          if (debugBlockOutput) {
            NSLog(@"row[%d] = %d", i, pixel);
          }
        }
      } else {
        memcpy(outPixelsRowPtr, inPixelsPtr, blockSize * sizeof(uint32_t));
        inPixelsPtr += blockSize;
      }
    }
    
    blocki++;
    
    if ((blocki > 0) && ((blocki % numBlocksInWidth) == 0)) {
      rowOfBlocksi++;
    }
  }

  return;
}

// Return the size of an image in terms of blocks given the block
// side dimension and the pixel width and height of the image.

+ (CGSize) blockSizeForSize:(CGSize)pixelSize
             blockDimension:(int)blockDimension
{
  uint32_t width = (uint32_t)pixelSize.width;
  uint32_t height = (uint32_t)pixelSize.height;
  
  uint32_t numBlocksInWidth = width / blockDimension;
  if ((width % blockDimension) != 0) {
    numBlocksInWidth += 1;
  }
  uint32_t numBlocksInHeight = height / blockDimension;
  if ((height % blockDimension) != 0) {
    numBlocksInHeight += 1;
  }

  return CGSizeMake(numBlocksInWidth, numBlocksInHeight);
}

// Given an array of pixel values, convert to an array of pixels values
// that contain a NSNumber of unsigned 32 bit type.

+ (NSArray*) pixelDataToArray:(NSData*)pixelData
{
  const uint32_t numPixels = (uint32_t) (pixelData.length / sizeof(uint32_t));
  uint32_t *pixelsPtr = (uint32_t*) pixelData.bytes;
  
  NSMutableArray *mArr = [NSMutableArray array];
  
  uint32_t lastPixel = 0;
  NSNumber *zeroPixelNum = [NSNumber numberWithUnsignedInt:0];
  NSNumber *lastPixelNum = zeroPixelNum;
  
  for (int i = 0; i < numPixels; i++) {
    uint32_t pixel = pixelsPtr[i];
    NSNumber *pixelNum;
    if (pixel == 0) {
      pixelNum = zeroPixelNum;
    } else if (pixel == lastPixel) {
      pixelNum = lastPixelNum;
    } else {
      pixelNum = [NSNumber numberWithUnsignedInt:pixel];
      lastPixel = pixel;
      lastPixelNum = pixelNum;
    }
    [mArr addObject:pixelNum];
  }
  
  return [NSArray arrayWithArray:mArr];
}

// Given an array of pixels inside NSNumber objects,
// append each pixel word to a mutable data and return.

+ (NSMutableData*) pixelsArrayToData:(NSArray*)pixels
{
  NSMutableData *mData = [NSMutableData data];

  for (NSNumber *pixelNum in pixels) {
    uint32_t pixel = [pixelNum unsignedIntValue];
    [mData appendBytes:&pixel length:sizeof(uint32_t)];
  }
  
  return mData;
}

// Given a buffer of bytes, convert to an array of NSNumbers
// that contain and unsigned byte.

+ (NSArray*) byteDataToArray:(NSData*)byteData
{
  const uint32_t numBytes = (uint32_t)byteData.length;
  uint8_t *bytesPtr = (uint8_t*) byteData.bytes;
  
  NSMutableArray *mArr = [NSMutableArray array];
  
  uint8_t lastByte = 0;
  NSNumber *zeroNum = [NSNumber numberWithUnsignedChar:0];
  NSNumber *lastNum = zeroNum;
  
  for (int i = 0; i < numBytes; i++) {
    uint8_t byte = bytesPtr[i];
    NSNumber *byteNum;
    if (byte == 0) {
      byteNum = zeroNum;
    } else if (byte == lastByte) {
      byteNum = lastNum;
    } else {
      byteNum = [NSNumber numberWithUnsignedChar:byte];
      lastByte = byte;
      lastNum = byteNum;
    }
    [mArr addObject:byteNum];
  }
  
  return [NSArray arrayWithArray:mArr];
}

// Given an array of byte inside NSNumber objects,
// append each byte to a mutable data and return.

+ (NSMutableData*) bytesArrayToData:(NSArray*)bytes
{
  NSMutableData *mData = [NSMutableData data];
  
  for (NSNumber *byteNum in bytes) {
    uint8_t byte = [byteNum unsignedCharValue];
    [mData appendBytes:&byte length:sizeof(uint8_t)];
  }
  
  return mData;
}

// Return the size of the file in bytes

+ (uint32_t) filesize:(NSString*)filepath
{
  FILE *file = fopen([filepath UTF8String], "rb");
  
  int status = fseek(file, 0, SEEK_END);
  assert(status == 0);
  uint32_t endOffset = (uint32_t)ftell(file);
  fclose(file);
  
  return endOffset;
}

// Format numbers into as comma separated string

+ (NSString*) formatNumbersAsString:(NSArray*)numbers
{
  return [numbers componentsJoinedByString:@","];
}

@end


// C methods

float min2f(float f1, float f2)
{
  if (f1 < f2) {
    return f1;
  } else {
    return f2;
  }
}

float min3f(float f1, float f2, float f3)
{
  float min = min2f(f1, f2);
  return min2f(min, f3);
}

double min2d(double f1, double f2)
{
  if (f1 < f2) {
    return f1;
  } else {
    return f2;
  }
}

double min3d(double f1, double f2, double f3)
{
  double min = min2d(f1, f2);
  return min2d(min, f3);
}

float max2f(float f1, float f2)
{
  if (f1 > f2) {
    return f1;
  } else {
    return f2;
  }
}

float max3f(float f1, float f2, float f3)
{
  float max = max2f(f1, f2);
  return max2f(max, f3);
}

double max2d(double f1, double f2)
{
  if (f1 > f2) {
    return f1;
  } else {
    return f2;
  }
}

double max3d(double f1, double f2, double f3)
{
  double max = max2d(f1, f2);
  return max2d(max, f3);
}
