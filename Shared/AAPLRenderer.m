

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of renderer class which perfoms Metal setup and per frame rendering
*/
@import simd;
@import MetalKit;

#import "AAPLRenderer.h"
#import "AAPLImage.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inpute to the shaders
#import "AAPLShaderTypes.h"

#import <CoreVideo/CoreVideo.h>

#import "Huffman.h"

#import "HuffRenderFrame.h"

#import "Util.h"

const static unsigned int blockDim = HUFF_BLOCK_DIM;

@interface AAPLRenderer ()

@property (nonatomic, retain) HuffRenderFrame *huffRenderFrame;

@end

// Main class performing the rendering
@implementation AAPLRenderer
{
    // The device (aka GPU) we're using to render
    id <MTLDevice> _device;
  
  // 12 and 16 symbol render pipelines
  id<MTLRenderPipelineState> _render12PipelineState;
  id<MTLRenderPipelineState> _render16PipelineState;
  
  // The Metal textures that will hold fragment shader output

  id<MTLTexture> _render12Zeros;
  
  id<MTLTexture> _render12C0R0;
  id<MTLTexture> _render12C1R0;
  id<MTLTexture> _render12C2R0;
  id<MTLTexture> _render12C3R0;
  
  id<MTLTexture> _render12C0R1;
  id<MTLTexture> _render12C1R1;
  id<MTLTexture> _render12C2R1;
  id<MTLTexture> _render12C3R1;
  
  id<MTLTexture> _render12C0R2;
  id<MTLTexture> _render12C1R2;
  id<MTLTexture> _render12C2R2;
  id<MTLTexture> _render12C3R2;
  
  id<MTLTexture> _render12C0R3;
  id<MTLTexture> _render12C1R3;
  id<MTLTexture> _render12C2R3;
  id<MTLTexture> _render12C3R3;

  id<MTLTexture> _render16C0;
  id<MTLTexture> _render16C1;
  id<MTLTexture> _render16C2;
  id<MTLTexture> _render16C3;
  
  // This texture will contain the output of each symbol
  // render above with a "slice" that is the height of one
  // of the render textures. The results will all be blitted
  // into this texture at known offsets that indicate a "slice".
  
  id<MTLTexture> _renderCombinedSlices;
  
    // render to texture pipeline is used to render into a texture
    id<MTLRenderPipelineState> _renderToTexturePipelineState;
  
    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
    id<MTLRenderPipelineState> _renderFromTexturePipelineState;

    // The command Queue from which we'll obtain command buffers
    id<MTLCommandQueue> _commandQueue;

    // Texture cache
    CVMetalTextureCacheRef _textureCache;
  
    id<MTLTexture> _render_texture;
  
    // The Metal buffer in which we store our vertex data
    id<MTLBuffer> _vertices;

    // The Metal buffer that will hold render dimensions
    id<MTLBuffer> _renderTargetDimensionsAndBlockDimensionsUniform;
  
  // The Metal buffer stores the number of bits into the
  // huffman codes buffer where the symbol at a given
  // block begins. This table keeps the huffman codes
  // tightly packed.

  id<MTLBuffer> _blockStartBitOffsets;
  
  // The Metal buffer where encoded huffman bits are stored
  id<MTLBuffer> _huffBuff;

  // The Metal buffer where huffman symbol lookup table is stored
  id<MTLBuffer> _huffSymbolTable1;
  id<MTLBuffer> _huffSymbolTable2;
  
    // The number of vertices in our vertex buffer
    NSUInteger _numVertices;

    // The current size of our view so we can use this in our render pipeline
    vector_uint2 _viewportSize;
  
    int isCaptureRenderedTextureEnabled;
  
  NSData *_huffData;

  NSData *_huffInputBytes;

  NSData *_blockByBlockReorder;

  NSData *_blockInitData;
  
  int renderWidth;
  int renderHeight;
  
  int renderBlockWidth;
  int renderBlockHeight;
}

// Util function that generates a texture object at a given dimension

- (id<MTLTexture>) makeBGRATexture:(CGSize)size pixels:(uint32_t*)pixels
{
  MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
  
  // Indicate that each pixel has a Blue, Green, Red, and Alpha channel,
  //    each in an 8 bit unnormalized value (0 maps 0.0 while 255 maps to 1.0)
  textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
  textureDescriptor.width = (int) size.width;
  textureDescriptor.height = (int) size.height;
  
  // Create our texture object from the device and our descriptor
  id<MTLTexture> texture = [_device newTextureWithDescriptor:textureDescriptor];
  
  if (pixels != NULL) {
    NSUInteger bytesPerRow = textureDescriptor.width * sizeof(uint32_t);
    
    MTLRegion region = {
      { 0, 0, 0 },                   // MTLOrigin
      {textureDescriptor.width, textureDescriptor.height, 1} // MTLSize
    };
    
    // Copy the bytes from our data object into the texture
    [texture replaceRegion:region
                mipmapLevel:0
                  withBytes:pixels
                bytesPerRow:bytesPerRow];
  }

  return texture;
}

// Allocate a 32 bit CoreVideo backing buffer and texture

- (id<MTLTexture>) makeBGRACoreVideoTexture:(CGSize)size
                        cvPixelBufferRefPtr:(CVPixelBufferRef*)cvPixelBufferRefPtr
{
  int width = (int) size.width;
  int height = (int) size.height;
  
  // CoreVideo pixel buffer backing the indexes texture
  
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES], kCVPixelBufferMetalCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                           nil];
  
  CVPixelBufferRef pxbuffer = NULL;
  
  CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        width,
                                        height,
                                        kCVPixelFormatType_32BGRA,
                                        (__bridge CFDictionaryRef) options,
                                        &pxbuffer);
  
  NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
  
  *cvPixelBufferRefPtr = pxbuffer;
  
  CVMetalTextureRef cvTexture = NULL;
  
  CVReturn ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _textureCache,
                                                           pxbuffer,
                                                           nil,
                                                           MTLPixelFormatBGRA8Unorm,
                                                           CVPixelBufferGetWidth(pxbuffer),
                                                           CVPixelBufferGetHeight(pxbuffer),
                                                           0,
                                                           &cvTexture);
  
  NSParameterAssert(ret == kCVReturnSuccess && cvTexture != NULL);
  
  id<MTLTexture> metalTexture = CVMetalTextureGetTexture(cvTexture);
  
  CFRelease(cvTexture);
  
  return metalTexture;
}

// Allocate 8 bit unsigned int texture

- (id<MTLTexture>) make8bitTexture:(CGSize)size bytes:(uint8_t*)bytes
{
  MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
  
  // Each value in this texture is an 8 bit integer value in the range (0,255) inclusive
  // represented by a half float
  
  textureDescriptor.pixelFormat = MTLPixelFormatR8Unorm;
  textureDescriptor.width = (int) size.width;
  textureDescriptor.height = (int) size.height;
  
  // Create our texture object from the device and our descriptor
  id<MTLTexture> texture = [_device newTextureWithDescriptor:textureDescriptor];
  
  if (bytes != NULL) {
    NSUInteger bytesPerRow = textureDescriptor.width * sizeof(uint8_t);
    
    MTLRegion region = {
      { 0, 0, 0 },                   // MTLOrigin
      {textureDescriptor.width, textureDescriptor.height, 1} // MTLSize
    };
    
    // Copy the bytes from our data object into the texture
    [texture replaceRegion:region
               mipmapLevel:0
                 withBytes:bytes
               bytesPerRow:bytesPerRow];
  }
  
  return texture;
}

+ (NSString*) getResourcePath:(NSString*)resFilename
{
  NSBundle* appBundle = [NSBundle mainBundle];
  NSString* movieFilePath = [appBundle pathForResource:resFilename ofType:nil];
  NSAssert(movieFilePath, @"movieFilePath is nil");
  return movieFilePath;
}

- (void) copyInto32bitCoreVideoTexture:(CVPixelBufferRef)cvPixelBufferRef
                                pixels:(uint32_t*)pixels
{
  size_t width = CVPixelBufferGetWidth(cvPixelBufferRef);
  size_t height = CVPixelBufferGetHeight(cvPixelBufferRef);
  
  CVPixelBufferLockBaseAddress(cvPixelBufferRef, 0);
  
  void *baseAddress = CVPixelBufferGetBaseAddress(cvPixelBufferRef);
  
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(cvPixelBufferRef);
  assert(bytesPerRow >= (width * sizeof(uint32_t)));
  
  for ( int row = 0; row < height; row++ ) {
    uint32_t *ptr = baseAddress + (row * bytesPerRow);
    memcpy(ptr, (void*) (pixels + (row * width)), width * sizeof(uint32_t));
  }

  if ((0)) {
    for ( int row = 0; row < height; row++ ) {
      uint32_t *rowPtr = baseAddress + (row * bytesPerRow);
      for ( int col = 0; col < width; col++ ) {
        fprintf(stdout, "0x%08X ", rowPtr[col]);
      }
      fprintf(stdout, "\n");
    }
  }
  
  CVPixelBufferUnlockBaseAddress(cvPixelBufferRef, 0);
  
  return;
}

// Query a texture that contains byte values and return in
// a buffer of uint8_t typed values.

+ (NSData*) getTextureBytes:(id<MTLTexture>)texture
{
  int width = (int) texture.width;
  int height = (int) texture.height;
  
  NSMutableData *mFramebuffer = [NSMutableData dataWithLength:width*height*sizeof(uint8_t)];
  
  [texture getBytes:(void*)mFramebuffer.mutableBytes
           bytesPerRow:width*sizeof(uint8_t)
         bytesPerImage:width*height*sizeof(uint8_t)
            fromRegion:MTLRegionMake2D(0, 0, width, height)
           mipmapLevel:0
                 slice:0];
  
  return [NSData dataWithData:mFramebuffer];
}

// Query pixel contents of a texture and return as uint32_t
// values in a NSData*.

+ (NSData*) getTexturePixels:(id<MTLTexture>)texture
{
  // Copy texture data into debug framebuffer, note that this include 2x scale
  
  int width = (int) texture.width;
  int height = (int) texture.height;
  
  NSMutableData *mFramebuffer = [NSMutableData dataWithLength:width*height*sizeof(uint32_t)];
  
  [texture getBytes:(void*)mFramebuffer.mutableBytes
        bytesPerRow:width*sizeof(uint32_t)
      bytesPerImage:width*height*sizeof(uint32_t)
         fromRegion:MTLRegionMake2D(0, 0, width, height)
        mipmapLevel:0
              slice:0];
  
  return [NSData dataWithData:mFramebuffer];
}


+ (void) calculateThreadgroup:(CGSize)inSize
                     blockDim:(int)blockDim
                      sizePtr:(MTLSize*)sizePtr
                     countPtr:(MTLSize*)countPtr
{
  MTLSize mSize;
  MTLSize mCount;
  
  mSize = MTLSizeMake(blockDim, blockDim, 1);

  // Calculate the number of rows and columns of thread groups given the width of our input image.
  //   Ensure we cover the entire image (or more) so we process every pixel.
  
  //int width = (inSize.width  + mSize.width -  1) / mSize.width;
  //int height = (inSize.height + mSize.height - 1) / mSize.height;
  
  int width = inSize.width;
  int height = inSize.height;
  
  mCount = MTLSizeMake(width, height, 1);
  mCount.depth = 1; // 2D only
  
  *sizePtr = mSize;
  *countPtr = mCount;
  
  return;
}

- (void) setupHuffmanEncoding
{
  unsigned int width = self->renderWidth;
  unsigned int height = self->renderHeight;
  
  unsigned int blockWidth = self->renderBlockWidth;
  unsigned int blockHeight = self->renderBlockHeight;
  
  NSMutableData *outFileHeader = [NSMutableData data];
  NSMutableData *outCanonHeader = [NSMutableData data];
  NSMutableData *outHuffCodes = [NSMutableData data];
  NSMutableData *outBlockBitOffsets = [NSMutableData data];
  
  // To encode symbols with huffman block encoding, the order of the symbols
  // needs to be broken up so that the input ordering is in terms of blocks and
  // the partial blocks are handled in a way that makes it possible to process
  // the data with the shader. Note that this logic will split into fixed block
  // size with zero padding, so the output would need to be reordered back to
  // image order and then trimmed to width and height in order to match.
  
  int outBlockOrderSymbolsNumBytes = (blockDim * blockDim) * (blockWidth * blockHeight);
  
  // Generate input that is zero padded out to the number of blocks needed
  NSMutableData *outBlockOrderSymbolsData = [NSMutableData dataWithLength:outBlockOrderSymbolsNumBytes];
  uint8_t *outBlockOrderSymbolsPtr = (uint8_t *) outBlockOrderSymbolsData.bytes;
  
  [Util splitIntoBlocksOfSize:blockDim
                      inBytes:(uint8_t*)_huffInputBytes.bytes
                     outBytes:outBlockOrderSymbolsPtr
                        width:width
                       height:height
             numBlocksInWidth:blockWidth
            numBlocksInHeight:blockHeight
                    zeroValue:0];
  
  // Deal with the case where there are not enough total blocks to zero pad
  
  if ((0)) {
    //        for (int i = 0; i < outBlockOrderSymbolsNumBytes; i++) {
    //          printf("outBlockOrderSymbolsPtr[%5i] = %d\n", i, outBlockOrderSymbolsPtr[i]);
    //        }
    
    printf("block order\n");
    
    for ( int blocki = 0; blocki < (blockWidth * blockHeight); blocki++ ) {
      printf("block %5d : ", blocki);
      
      uint8_t *blockStartPtr = outBlockOrderSymbolsPtr + (blocki * (blockDim * blockDim));
      
      for (int i = 0; i < (blockDim * blockDim); i++) {
        printf("%5d ", blockStartPtr[i]);
      }
      printf("\n");
    }
    
    printf("block order done\n");
  }
  
#if defined(IMPL_DELTAS_BEFORE_HUFF_ENCODING)
  if ((1)) {
    // byte deltas
    
    NSMutableArray *mBlocks = [NSMutableArray array];
    
    for ( int blocki = 0; blocki < (blockWidth * blockHeight); blocki++ ) {
      NSMutableData *mRowData = [NSMutableData data];
      uint8_t *blockStartPtr = outBlockOrderSymbolsPtr + (blocki * (blockDim * blockDim));
      [mRowData appendBytes:blockStartPtr length:(blockDim * blockDim)];
      [mBlocks addObject:mRowData];
    }
    
    // Convert blocks to deltas
    
    NSMutableArray *mRowsOfDeltas = [NSMutableArray array];
    
#if defined(IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING)
    NSMutableData *mBlockInitData = [NSMutableData dataWithCapacity:(blockWidth * blockHeight)];
#endif
    
    for ( NSMutableData *blockData in mBlocks ) {
      NSData *deltasData = [Huffman encodeSignedByteDeltas:blockData];
      
#if defined(IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING)
      // When saving the first element of a block, do the deltas
      // first and then pull out the first delta and set the delta
      // byte to zero. This increases the count of the zero delta
      // value and reduces the size of the generated tree while
      // storing the block init value wo a huffman code.
      {
        NSMutableData *mDeltasData = [NSMutableData dataWithData:deltasData];
        
        uint8_t *bytePtr = mDeltasData.mutableBytes;
        uint8_t firstByte = bytePtr[0];
        bytePtr[0] = 0;
        
        [mBlockInitData appendBytes:&firstByte length:1];
        
        deltasData = [NSData dataWithData:mDeltasData];
      }
#endif // IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING
      
      [mRowsOfDeltas addObject:deltasData];
      
#if defined(DEBUG)
      // Check that decoding generates the original input
      
# if defined(IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING)
      // Undo setting of the first element to zero.
      {
        uint8_t *initBytePtr = mBlockInitData.mutableBytes;
        uint8_t firstByte = initBytePtr[mBlockInitData.length-1];
        
        NSMutableData *mDeltasData = [NSMutableData dataWithData:deltasData];
        uint8_t *deltasBytePtr = mDeltasData.mutableBytes;
        
        deltasBytePtr[0] = firstByte;
        
        deltasData = [NSData dataWithData:mDeltasData];
      }
# endif // IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING
      
      NSData *decodedDeltas = [Huffman decodeSignedByteDeltas:deltasData];
      NSAssert([decodedDeltas isEqualToData:blockData], @"decoded deltas");
#endif // DEBUG
    }
    
    // Write delta values back over outBlockOrderSymbolsPtr
    
    int outWritei = 0;
    
    for ( NSData *deltaRow in mRowsOfDeltas ) {
      uint8_t *ptr = (uint8_t *) deltaRow.bytes;
      const int len = (int) deltaRow.length;
      for ( int i = 0; i < len; i++) {
        outBlockOrderSymbolsPtr[outWritei++] = ptr[i];
      }
    }
    
#if defined(IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING)
    _blockInitData = [NSData dataWithData:mBlockInitData];
#endif
  }
#else
  // Store init data as all zeros
  NSMutableData *mBlockInitData = [NSMutableData dataWithCapacity:(blockWidth * blockHeight)];
  for ( int blocki = 0; blocki < (blockWidth * blockHeight); blocki++ ) {
    uint8_t zeroByte = 0;
    [mBlockInitData appendBytes:&zeroByte length:1];
  }
  _blockInitData = [NSData dataWithData:mBlockInitData];
#endif // IMPL_DELTAS_BEFORE_HUFF_ENCODING
  
  if ((0)) {
    //        for (int i = 0; i < outBlockOrderSymbolsNumBytes; i++) {
    //          printf("outBlockOrderSymbolsPtr[%5i] = %d\n", i, outBlockOrderSymbolsPtr[i]);
    //        }
    
    printf("block order\n");
    
    for ( int blocki = 0; blocki < (blockWidth * blockHeight); blocki++ ) {
      printf("block %5d : ", blocki);
      
      uint8_t *blockStartPtr = outBlockOrderSymbolsPtr + (blocki * (blockDim * blockDim));
      
      for (int i = 0; i < (blockDim * blockDim); i++) {
        printf("%5d ", blockStartPtr[i]);
      }
      printf("\n");
    }
    
    printf("block order done\n");
  }
  
  // number of blocks must be an exact multiple of the block dimension
  
  assert((outBlockOrderSymbolsNumBytes % (blockDim * blockDim)) == 0);
  
  [Huffman encodeHuffman:outBlockOrderSymbolsPtr
              inNumBytes:outBlockOrderSymbolsNumBytes
           outFileHeader:outFileHeader
          outCanonHeader:outCanonHeader
            outHuffCodes:outHuffCodes
      outBlockBitOffsets:outBlockBitOffsets
                   width:width
                  height:height
                blockDim:blockDim];
  
  if ((1)) {
    printf("inNumBytes   %8d\n", outBlockOrderSymbolsNumBytes);
    printf("outNumBytes  %8d\n", (int)outHuffCodes.length);
  }
  
  // Reparse the canonical header to load symbol table info
  
  [Huffman parseCanonicalHeader:outCanonHeader];
  
  // FIXME: allocate huffman encoded bytes with no copy option to share existing mem?
  // Otherise allocate and provide way to read bytes directly into allocated buffer.
  
  uint8_t *encodedSymbolsPtr = outHuffCodes.mutableBytes;
  int encodedSymbolsNumBytes = (int) outHuffCodes.length;
  
  // Add 2 more empty bytes to account for read ahead
  encodedSymbolsNumBytes += 2;
  
  // Allocate a new buffer that accounts for read ahead space
  // and copy huffman encoded symbols into the allocated buffer.
  
  _huffBuff = [_device newBufferWithLength:encodedSymbolsNumBytes
                                   options:MTLResourceStorageModeShared];
  
  memcpy(_huffBuff.contents, encodedSymbolsPtr, encodedSymbolsNumBytes-2);
  
  if ((0)) {
    // Encoded huffman symbols as hex?
    
    fprintf(stdout, "encodedSymbols\n");
    
    for (int i = 0; i < encodedSymbolsNumBytes; i++) {
      int symbol = encodedSymbolsPtr[i];
      
      fprintf(stdout, "%2X \n", symbol);
    }
    
    fprintf(stdout, "done encodedSymbols\n");
  }
  
  {
    const int table1BitNum = HUFF_TABLE1_NUM_BITS;
    const int table2BitNum = HUFF_TABLE2_NUM_BITS;
    
    NSMutableData *table1 = [NSMutableData data];
    NSMutableData *table2 = [NSMutableData data];
    
    [Huffman generateSplitLookupTables:table1BitNum
                         table2NumBits:table2BitNum
                                table1:table1
                                table2:table2];
    
    // Invoke split table decoding logic to check that the generated tables
    // can be read to regenerate the original input.
    
#if defined(DEBUG)
    
    HuffLookupSymbol *codeLookupTablePtr1 = (HuffLookupSymbol *) table1.bytes;
    assert(codeLookupTablePtr1);
    HuffLookupSymbol *codeLookupTablePtr2 = (HuffLookupSymbol *) table2.bytes;
    assert(codeLookupTablePtr1);
    
    NSMutableData *mDecodedBlockOrderSymbols = [NSMutableData data];
    [mDecodedBlockOrderSymbols setLength:outBlockOrderSymbolsNumBytes];
    uint8_t *decodedBlockOrderSymbolsPtr = (uint8_t *) mDecodedBlockOrderSymbols.mutableBytes;
    
    uint8_t *huffSymbolsWithPadding = (uint8_t *) _huffBuff.contents;
    int huffSymbolsWithPaddingNumBytes = encodedSymbolsNumBytes;
    
    NSMutableData *mDecodedBitOffsetData = [NSMutableData data];
    [mDecodedBitOffsetData setLength:(outBlockOrderSymbolsNumBytes * sizeof(uint32_t))];
    uint32_t *decodedBitOffsetPtr = (uint32_t *) mDecodedBitOffsetData.mutableBytes;
    
    [Huffman decodeHuffmanBitsFromTables:codeLookupTablePtr1
                        huffSymbolTable2:codeLookupTablePtr2
                            table1BitNum:table1BitNum
                            table2BitNum:table2BitNum
                      numSymbolsToDecode:outBlockOrderSymbolsNumBytes
                                huffBuff:huffSymbolsWithPadding
                               huffBuffN:huffSymbolsWithPaddingNumBytes
                               outBuffer:decodedBlockOrderSymbolsPtr
                          bitOffsetTable:decodedBitOffsetPtr
#if defined(DecodeHuffmanBitsFromTablesCompareToOriginal)
                           originalBytes:outBlockOrderSymbolsPtr
#endif // DecodeHuffmanBitsFromTablesCompareToOriginal
     ];
    
    int cmp = memcmp(decodedBlockOrderSymbolsPtr, outBlockOrderSymbolsPtr, outBlockOrderSymbolsNumBytes);
    assert(cmp == 0);
#endif // DEBUG
    
    // Allocate Metal buffers that hold symbol table 1 and 2
    
    const int table1Size = HUFF_TABLE1_SIZE; // aka pow(2, table1BitNum)
    const int table2Size = (int)table2.length / sizeof(HuffLookupSymbol);
    
    _huffSymbolTable1 = [_device newBufferWithLength:table1Size*sizeof(HuffLookupSymbol)
                                             options:MTLResourceStorageModeShared];
    
    _huffSymbolTable2 = [_device newBufferWithLength:table2Size*sizeof(HuffLookupSymbol)
                                             options:MTLResourceStorageModeShared];
    
    assert(_huffSymbolTable1.length == table1.length);
    assert(_huffSymbolTable2.length == table2.length);
    
    memcpy(_huffSymbolTable1.contents, table1.bytes, table1.length);
    memcpy(_huffSymbolTable2.contents, table2.bytes, table2.length);
  }
  
  // Init memory buffer that holds bit offsets for each block
  
  uint32_t *blockInPtr = (uint32_t *) outBlockBitOffsets.bytes;
  uint32_t *blockOutPtr = (uint32_t *) _blockStartBitOffsets.contents;
  int numBlocks = (int)outBlockBitOffsets.length / sizeof(uint32_t);
  
  for (int blocki = 0; blocki < numBlocks; blocki++) {
    int blockiOffset = blockInPtr[blocki];
    blockOutPtr[blocki] = blockiOffset;
    
    if ((0)) {
#if defined(DEBUG)
      fprintf(stdout, "block[%5d] = %5d (bitOffsetsPtr[%5d])\n", blocki, blockOutPtr[blocki], blockiOffset);
#endif // DEBUG
    }
  }
  
  return;
}

// Initialize with the MetalKit view from which we'll obtain our metal device

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
      isCaptureRenderedTextureEnabled = 0;
      
      mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
      
      mtkView.preferredFramesPerSecond = 30;
      
      _device = mtkView.device;

      if (isCaptureRenderedTextureEnabled) {
        mtkView.framebufferOnly = false;
      }
      
      // Texture Cache
      
      {
        // Disable flushing of textures
        
        NSDictionary *cacheAttributes = @{
                                          (NSString*)kCVMetalTextureCacheMaximumTextureAgeKey: @(0),
                                          };
        
//        NSDictionary *cacheAttributes = nil;
        
        CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, (__bridge CFDictionaryRef)cacheAttributes, _device, nil, &_textureCache);
        NSParameterAssert(status == kCVReturnSuccess && _textureCache != NULL);
      }
      
      // Query size and byte data for input frame that will be rendered
      
//      HuffRenderFrameConfig hcfg = TEST_4x4_INCREASING1;
//      HuffRenderFrameConfig hcfg = TEST_4x4_INCREASING2;
//      HuffRenderFrameConfig hcfg = TEST_4x8_INCREASING1;
//      HuffRenderFrameConfig hcfg = TEST_2x8_INCREASING1;
//      HuffRenderFrameConfig hcfg = TEST_6x4_NOT_SQUARE;
//      HuffRenderFrameConfig hcfg = TEST_8x8_IDENT;
//      HuffRenderFrameConfig hcfg = TEST_16x8_IDENT;
//      HuffRenderFrameConfig hcfg = TEST_16x16_IDENT;
//      HuffRenderFrameConfig hcfg = TEST_16x16_IDENT2;
//      HuffRenderFrameConfig hcfg = TEST_16x16_IDENT3;
      
//        HuffRenderFrameConfig hcfg = TEST_8x8_IDENT_2048;
//        HuffRenderFrameConfig hcfg = TEST_8x8_IDENT_4096;

      //HuffRenderFrameConfig hcfg = TEST_LARGE_RANDOM;
      //HuffRenderFrameConfig hcfg = TEST_IMAGE1;
      //HuffRenderFrameConfig hcfg = TEST_IMAGE2;
      //HuffRenderFrameConfig hcfg = TEST_IMAGE3;
      HuffRenderFrameConfig hcfg = TEST_IMAGE4;
      
      HuffRenderFrame *renderFrame = [HuffRenderFrame renderFrameForConfig:hcfg];
      
      self.huffRenderFrame = renderFrame;
      
      unsigned int width = renderFrame.renderWidth;
      unsigned int height = renderFrame.renderHeight;
      
      unsigned int blockWidth = width / blockDim;
      if ((width % blockDim) != 0) {
        blockWidth += 1;
      }
      
      unsigned int blockHeight = height / blockDim;
      if ((height % blockDim) != 0) {
        blockHeight += 1;
      }
      
      self->renderWidth = width;
      self->renderHeight = height;
      
      renderFrame.renderBlockWidth = blockWidth;
      renderFrame.renderBlockHeight = blockHeight;
      
      self->renderBlockWidth = blockWidth;
      self->renderBlockHeight = blockHeight;
      
      _renderTargetDimensionsAndBlockDimensionsUniform = [_device newBufferWithLength:sizeof(RenderTargetDimensionsAndBlockDimensionsUniform)
                                                     options:MTLResourceStorageModeShared];
      
      {
        RenderTargetDimensionsAndBlockDimensionsUniform *ptr = _renderTargetDimensionsAndBlockDimensionsUniform.contents;
        ptr->width = width;
        ptr->height = height;
        ptr->blockWidth = blockWidth;
        ptr->blockHeight = blockHeight;
      }
      
      _render_texture = [self makeBGRATexture:CGSizeMake(width,height) pixels:NULL];

      // Render stages
      
      if ((1)) {
        // Dummy input that is all zeros
        _render12Zeros = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        
        _render12C0R0 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C1R0 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C2R0 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C3R0 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];

        _render12C0R1 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C1R1 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C2R1 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C3R1 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];

        _render12C0R2 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C1R2 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C2R2 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C3R2 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];

        _render12C0R3 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C1R3 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C2R3 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render12C3R3 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];

        _render16C0 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render16C1 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render16C2 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];
        _render16C3 = [self makeBGRATexture:CGSizeMake(blockWidth, blockHeight) pixels:NULL];

        // Render into texture that is a multiple of (blockWidth, blockHeight)
        
        int combinedNumElemsWidth = 4096 / 512;
        int maxLineWidth = blockWidth * combinedNumElemsWidth;
        
        int combinedNumElemsHeight = (blockWidth * 16) / maxLineWidth;
        if (((blockWidth * 16) % maxLineWidth) != 0) {
          combinedNumElemsHeight++;
        }

        int combinedWidth = blockWidth * combinedNumElemsWidth;
        int combinedHeight = blockHeight * combinedNumElemsHeight;
        
        _renderCombinedSlices = [self makeBGRATexture:CGSizeMake(combinedWidth, combinedHeight) pixels:NULL];
      }
      
        // Set up a simple MTLBuffer with our vertices which include texture coordinates
      
        static const AAPLVertex quadVertices[] =
        {
            // Positions, Texture Coordinates
            { {  1,  -1 }, { 1.f, 0.f } },
            { { -1,  -1 }, { 0.f, 0.f } },
            { { -1,   1 }, { 0.f, 1.f } },

            { {  1,  -1 }, { 1.f, 0.f } },
            { { -1,   1 }, { 0.f, 1.f } },
            { {  1,   1 }, { 1.f, 1.f } },
        };

        NSError *error = NULL;
      
      // FIXME: Would allocating with private storage mode make any diff here?
      // What about putting a known fixed size buffer into constant memory space?
      
        // Create our vertex buffer, and initialize it with our quadVertices array
        _vertices = [_device newBufferWithBytes:quadVertices
                                         length:sizeof(quadVertices)
                                        options:MTLResourceStorageModeShared];

      // Calculate the number of vertices by dividing the byte length by the size of each vertex
      _numVertices = sizeof(quadVertices) / sizeof(AAPLVertex);
      
      // For each block, there is one 32 bit number that stores the next bit
      // offset into the huffman code buffer. Each successful code write operation
      // will read from 1 to 16 bits and increment the counter for a specific block.
      
      _blockStartBitOffsets = [_device newBufferWithLength:sizeof(uint32_t)*(blockWidth*blockHeight)
                                      options:MTLResourceStorageModeShared];
      
      // Load all the shader files with a metal file extension in the project
      id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

      {
        // Load the vertex function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"huffFragmentShaderB8W12"];
        assert(fragmentFunction);
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Huffman Decode 12 Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[1].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[2].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[3].pixelFormat = mtkView.colorPixelFormat;
        
        //pipelineStateDescriptor.stencilAttachmentPixelFormat =  mtkView.depthStencilPixelFormat; // MTLPixelFormatStencil8
        
        _render12PipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                                  error:&error];
        if (!_render12PipelineState)
        {
          // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
          //  If the Metal API validation is enabled, we can find out more information about what
          //  went wrong.  (Metal API validation is enabled by default when a debug build is run
          //  from Xcode)
          NSLog(@"Failed to created pipeline state, error %@", error);
        }
      }

      {
        // Load the vertex function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        assert(vertexFunction);
        
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"huffFragmentShaderB8W16"];
        assert(fragmentFunction);
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Huffman Decode 16 Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[1].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[2].pixelFormat = mtkView.colorPixelFormat;
        pipelineStateDescriptor.colorAttachments[3].pixelFormat = mtkView.colorPixelFormat;
        
        //pipelineStateDescriptor.stencilAttachmentPixelFormat =  mtkView.depthStencilPixelFormat; // MTLPixelFormatStencil8
        
        _render16PipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                         error:&error];
        if (!_render16PipelineState)
        {
          // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
          //  If the Metal API validation is enabled, we can find out more information about what
          //  went wrong.  (Metal API validation is enabled by default when a debug build is run
          //  from Xcode)
          NSLog(@"Failed to created pipeline state, error %@", error);
        }
      }
      
      {
        // Render to texture pipeline
        
        // Load the vertex function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

        // Load the fragment function from the library
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingPassThroughShader"];
      
      {
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Render From Texture Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        //pipelineStateDescriptor.stencilAttachmentPixelFormat =  mtkView.depthStencilPixelFormat; // MTLPixelFormatStencil8
        
        _renderFromTexturePipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
        if (!_renderFromTexturePipelineState)
        {
          // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
          //  If the Metal API validation is enabled, we can find out more information about what
          //  went wrong.  (Metal API validation is enabled by default when a debug build is run
          //  from Xcode)
          NSLog(@"Failed to created pipeline state, error %@", error);
        }
      }
      }
      
      {
        // Load the vertex function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        
        // Load the fragment function from the library
        
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"cropAndGrayscaleFromTexturesFragmentShader"];
        assert(fragmentFunction);
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Render To Texture Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        //pipelineStateDescriptor.stencilAttachmentPixelFormat =  mtkView.depthStencilPixelFormat; // MTLPixelFormatStencil8
        
        _renderToTexturePipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
        if (!_renderToTexturePipelineState)
        {
          // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
          //  If the Metal API validation is enabled, we can find out more information about what
          //  went wrong.  (Metal API validation is enabled by default when a debug build is run
          //  from Xcode)
          NSLog(@"Failed to created pipeline state, error %@", error);
        }
        
      }
      
        // Create the command queue
        _commandQueue = [_device newCommandQueue];
      
      // Read input data and encode to huffman
      
//      renderFrame.renderBlockWidth = blockWidth;
//      renderFrame.renderBlockHeight = blockHeight;
      
//      int allocatedSymbolsPtr = 0;
//
//      uint8_t inputSymbolsPtr[] = {
//        0,  1,  4, 0,
//        2,  3,  5, 0,
//        6,  7, 10, 0,
//        8,  9, 11, 0
//      };
  
//#if defined(DEBUG)
//      _render_pass_saved_expected = renderFrame.render_pass_saved_expected;
//#endif // DEBUG
      
//      int inputSymbolsNumBytes = sizeof(inputSymbolsPtr) / sizeof(uint8_t);
      
      /*
      
       int allocatedSymbolsPtr = 1;
      const int inputSymbolsNumBytes = 8 * 8;
      uint8_t *inputSymbolsPtr = malloc(inputSymbolsNumBytes);
      
      for ( int i = 0; i < inputSymbolsNumBytes; i++ ) {
        int val = i & 0xFF;
        inputSymbolsPtr[i] = val;
      }
       
      */
       
      //assert(inputSymbolsNumBytes == (width * height));
      
      //_huffInputBytes = [NSData dataWithBytes:inputSymbolsPtr length:inputSymbolsNumBytes];
      
      _huffInputBytes = renderFrame.inputData;
      
//      if (allocatedSymbolsPtr) {
//      free(inputSymbolsPtr);
//      }

      [self setupHuffmanEncoding];
      
      // Zero out pixels / set to known init state
      
      if ((1))
      {
        int numBytes = (int) (_render12Zeros.width * _render12Zeros.height * sizeof(uint32_t));
        uint32_t *pixels = malloc(numBytes);
        
#if defined(IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING)
        int numBytesBlockData = (int) _blockInitData.length;
        int numPixelsInInitBlock = (int) (_render12Zeros.width * _render12Zeros.height);
        assert(numBytesBlockData == numPixelsInInitBlock);
        
        // Each output pixel is written as BGRA where R stores the previous pixel value
        // and the BG 16 bit value is zero.
        
        uint8_t *blockValPtr = (uint8_t *) _blockInitData.bytes;
        
        for ( int i = 0; i < numPixelsInInitBlock; i++ ) {
          uint8_t blockInitVal = blockValPtr[i];
          uint32_t pixel = (blockInitVal << 16) | (0);
          pixels[i] = pixel;
        }
#else
        // Init all lanes to zero
        memset(pixels, 0, numBytes);
#endif // IMPL_DELTAS_AND_INIT_ZERO_DELTA_BEFORE_HUFF_ENCODING
        
        {
          NSUInteger bytesPerRow = _render12Zeros.width * sizeof(uint32_t);
          
          MTLRegion region = {
            { 0, 0, 0 },                   // MTLOrigin
            {_render12Zeros.width, _render12Zeros.height, 1} // MTLSize
          };
          
          // Copy the bytes from our data object into the texture
          [_render12Zeros replaceRegion:region
                            mipmapLevel:0
                              withBytes:pixels
                            bytesPerRow:bytesPerRow];
        }
        
        free(pixels);
      }
      
    } // end of init if block
  
    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable as we'll pass these
    //   values to our vertex shader when we draw
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

- (NSString*) codeBitsAsString:(uint32_t)code width:(int)width
{
  NSMutableString *mStr = [NSMutableString string];
  int c4 = 1;
  for ( int i = 0; i < width; i++ ) {
    bool isOn = ((code & (0x1 << i)) != 0);
    if (isOn) {
      [mStr insertString:@"1" atIndex:0];
    } else {
      [mStr insertString:@"0" atIndex:0];
    }
    
    if ((c4 == 4) && (i != (width - 1))) {
      [mStr insertString:@"-" atIndex:0];
      c4 = 1;
    } else {
      c4++;
    }
  }
  return [NSString stringWithString:mStr];
}

// Dump texture that contains a 4 byte values in each BGRA pixel

- (void) dump4ByteTexture:(id<MTLTexture>)outTexture
                    label:(NSString*)label
{
  // Copy texture data into debug framebuffer, note that this include 2x scale
  
  int width = (int) outTexture.width;
  int height = (int) outTexture.height;
  
  NSData *pixelsData = [self.class getTexturePixels:outTexture];
  uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
  
  // Dump output words as bytes
  
  if ((1)) {
    fprintf(stdout, "%s\n", [label UTF8String]);
    
    // Dump output words as BGRA
    
    for ( int row = 0; row < height; row++ ) {
      for ( int col = 0; col < width; col++ ) {
        int offset = (row * width) + col;
        uint32_t v = pixelsPtr[offset];
        //fprintf(stdout, "%5d ", v);
        fprintf(stdout, "0x%08X ", v);
      }
      fprintf(stdout, "\n");
    }
    
    fprintf(stdout, "done\n");
  }
  
  if ((1)) {
    fprintf(stdout, "%s as bytes\n", [label UTF8String]);
    
    for ( int row = 0; row < height; row++ ) {
      for ( int col = 0; col < width; col++ ) {
        int offset = (row * width) + col;
        uint32_t v = pixelsPtr[offset];
        
        for (int i = 0; i < 4; i++) {
          uint32_t bVal = (v >> (i * 8)) & 0xFF;
          fprintf(stdout, "%d ", bVal);
        }
      }
      fprintf(stdout, "\n");
    }
    
    fprintf(stdout, "done\n");
  }
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
  // Create a new command buffer
  
  id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
  commandBuffer.label = @"RenderBGRACommand";
  
  // --------------------------------------------------------------------------

  int blockWidth = self->renderBlockWidth;
  int blockHeight = self->renderBlockHeight;
  
  // Render 0, write 12 symbols into 3 textures along with a bits consumed halfword
  
  {
  MTLRenderPassDescriptor *huffRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
  
  if (huffRenderPassDescriptor != nil)
  {
    huffRenderPassDescriptor.colorAttachments[0].texture = _render12C0R0;
    huffRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    huffRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    huffRenderPassDescriptor.colorAttachments[1].texture = _render12C1R0;
    huffRenderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionDontCare;
    huffRenderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;

    huffRenderPassDescriptor.colorAttachments[2].texture = _render12C2R0;
    huffRenderPassDescriptor.colorAttachments[2].loadAction = MTLLoadActionDontCare;
    huffRenderPassDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;

    huffRenderPassDescriptor.colorAttachments[3].texture = _render12C3R0;
    huffRenderPassDescriptor.colorAttachments[3].loadAction = MTLLoadActionDontCare;
    huffRenderPassDescriptor.colorAttachments[3].storeAction = MTLStoreActionStore;
    
    id <MTLRenderCommandEncoder> renderEncoder =
    [commandBuffer renderCommandEncoderWithDescriptor:huffRenderPassDescriptor];
    renderEncoder.label = @"Huff12R0";
    
    [renderEncoder pushDebugGroup: @"Huff12R0"];
    
    // Set the region of the drawable to which we'll draw.
    
    MTLViewport mtlvp = {0.0, 0.0, blockWidth, blockHeight, -1.0, 1.0 };
    [renderEncoder setViewport:mtlvp];
    
    [renderEncoder setRenderPipelineState:_render12PipelineState];
    
    [renderEncoder setVertexBuffer:_vertices
                            offset:0
                           atIndex:AAPLVertexInputIndexVertices];
    
    [renderEncoder setFragmentTexture:_render12Zeros
                              atIndex:0];
    
    [renderEncoder setFragmentBuffer:_blockStartBitOffsets
                       offset:0
                      atIndex:0];
    
    // Read only buffer for huffman symbols and huffman lookup table
    
    [renderEncoder setFragmentBuffer:_huffBuff
                       offset:0
                      atIndex:1];
    
    [renderEncoder setFragmentBuffer:_huffSymbolTable1
                       offset:0
                      atIndex:2];

    [renderEncoder setFragmentBuffer:_huffSymbolTable2
                              offset:0
                             atIndex:3];
    
    [renderEncoder setFragmentBuffer:_renderTargetDimensionsAndBlockDimensionsUniform
                              offset:0
                             atIndex:4];

    // Draw the 3 vertices of our triangle
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:_numVertices];
    
    [renderEncoder popDebugGroup]; // RenderToTexture
    
    [renderEncoder endEncoding];
  }
    
  }

  // Render 1, write 12 symbols into 3 textures along with a bits consumed halfword
  
  {
    MTLRenderPassDescriptor *huffRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    if (huffRenderPassDescriptor != nil)
    {
      huffRenderPassDescriptor.colorAttachments[0].texture = _render12C0R1;
      huffRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[1].texture = _render12C1R1;
      huffRenderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[2].texture = _render12C2R1;
      huffRenderPassDescriptor.colorAttachments[2].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[3].texture = _render12C3R1;
      huffRenderPassDescriptor.colorAttachments[3].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[3].storeAction = MTLStoreActionStore;
      
      id <MTLRenderCommandEncoder> renderEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:huffRenderPassDescriptor];
      renderEncoder.label = @"Huff12R1";
      
      [renderEncoder pushDebugGroup: @"Huff12R1"];
      
      // Set the region of the drawable to which we'll draw.
      
      MTLViewport mtlvp = {0.0, 0.0, blockWidth, blockHeight, -1.0, 1.0 };
      [renderEncoder setViewport:mtlvp];
      
      [renderEncoder setRenderPipelineState:_render12PipelineState];
      
      [renderEncoder setVertexBuffer:_vertices
                              offset:0
                             atIndex:AAPLVertexInputIndexVertices];
      
      [renderEncoder setFragmentTexture:_render12C3R0
                                atIndex:0];
      
      [renderEncoder setFragmentBuffer:_blockStartBitOffsets
                                offset:0
                               atIndex:0];
      
      // Read only buffer for huffman symbols and huffman lookup table
      
      [renderEncoder setFragmentBuffer:_huffBuff
                                offset:0
                               atIndex:1];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable1
                                offset:0
                               atIndex:2];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable2
                                offset:0
                               atIndex:3];
      
      [renderEncoder setFragmentBuffer:_renderTargetDimensionsAndBlockDimensionsUniform
                                offset:0
                               atIndex:4];
      
      // Draw the 3 vertices of our triangle
      [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                        vertexStart:0
                        vertexCount:_numVertices];
      
      [renderEncoder popDebugGroup]; // RenderToTexture
      
      [renderEncoder endEncoding];
    }
  }

  // render 2
  
  {
    MTLRenderPassDescriptor *huffRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    if (huffRenderPassDescriptor != nil)
    {
      huffRenderPassDescriptor.colorAttachments[0].texture = _render12C0R2;
      huffRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[1].texture = _render12C1R2;
      huffRenderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[2].texture = _render12C2R2;
      huffRenderPassDescriptor.colorAttachments[2].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[3].texture = _render12C3R2;
      huffRenderPassDescriptor.colorAttachments[3].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[3].storeAction = MTLStoreActionStore;
      
      id <MTLRenderCommandEncoder> renderEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:huffRenderPassDescriptor];
      renderEncoder.label = @"Huff12R2";
      
      [renderEncoder pushDebugGroup: @"Huff12R2"];
      
      // Set the region of the drawable to which we'll draw.
      
      MTLViewport mtlvp = {0.0, 0.0, blockWidth, blockHeight, -1.0, 1.0 };
      [renderEncoder setViewport:mtlvp];
      
      [renderEncoder setRenderPipelineState:_render12PipelineState];
      
      [renderEncoder setVertexBuffer:_vertices
                              offset:0
                             atIndex:AAPLVertexInputIndexVertices];
      
      [renderEncoder setFragmentTexture:_render12C3R1
                                atIndex:0];
      
      [renderEncoder setFragmentBuffer:_blockStartBitOffsets
                                offset:0
                               atIndex:0];
      
      // Read only buffer for huffman symbols and huffman lookup table
      
      [renderEncoder setFragmentBuffer:_huffBuff
                                offset:0
                               atIndex:1];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable1
                                offset:0
                               atIndex:2];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable2
                                offset:0
                               atIndex:3];
      
      [renderEncoder setFragmentBuffer:_renderTargetDimensionsAndBlockDimensionsUniform
                                offset:0
                               atIndex:4];
      
      // Draw the 3 vertices of our triangle
      [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                        vertexStart:0
                        vertexCount:_numVertices];
      
      [renderEncoder popDebugGroup]; // RenderToTexture
      
      [renderEncoder endEncoding];
    }
  }

  // render 3
  
  {
    MTLRenderPassDescriptor *huffRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    if (huffRenderPassDescriptor != nil)
    {
      huffRenderPassDescriptor.colorAttachments[0].texture = _render12C0R3;
      huffRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[1].texture = _render12C1R3;
      huffRenderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[2].texture = _render12C2R3;
      huffRenderPassDescriptor.colorAttachments[2].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[3].texture = _render12C3R3;
      huffRenderPassDescriptor.colorAttachments[3].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[3].storeAction = MTLStoreActionStore;
      
      id <MTLRenderCommandEncoder> renderEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:huffRenderPassDescriptor];
      renderEncoder.label = @"Huff12R3";
      
      [renderEncoder pushDebugGroup: @"Huff12R3"];
      
      // Set the region of the drawable to which we'll draw.
      
      MTLViewport mtlvp = {0.0, 0.0, blockWidth, blockHeight, -1.0, 1.0 };
      [renderEncoder setViewport:mtlvp];
      
      [renderEncoder setRenderPipelineState:_render12PipelineState];
      
      [renderEncoder setVertexBuffer:_vertices
                              offset:0
                             atIndex:AAPLVertexInputIndexVertices];
      
      [renderEncoder setFragmentTexture:_render12C3R2
                                atIndex:0];
      
      [renderEncoder setFragmentBuffer:_blockStartBitOffsets
                                offset:0
                               atIndex:0];
      
      // Read only buffer for huffman symbols and huffman lookup table
      
      [renderEncoder setFragmentBuffer:_huffBuff
                                offset:0
                               atIndex:1];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable1
                                offset:0
                               atIndex:2];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable2
                                offset:0
                               atIndex:3];
      
      [renderEncoder setFragmentBuffer:_renderTargetDimensionsAndBlockDimensionsUniform
                                offset:0
                               atIndex:4];
      
      // Draw the 3 vertices of our triangle
      [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                        vertexStart:0
                        vertexCount:_numVertices];
      
      [renderEncoder popDebugGroup]; // RenderToTexture
      
      [renderEncoder endEncoding];
    }
  }
  
  // final render of 16 values
  
  {
    MTLRenderPassDescriptor *huffRenderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    if (huffRenderPassDescriptor != nil)
    {
      huffRenderPassDescriptor.colorAttachments[0].texture = _render16C0;
      huffRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[1].texture = _render16C1;
      huffRenderPassDescriptor.colorAttachments[1].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[2].texture = _render16C2;
      huffRenderPassDescriptor.colorAttachments[2].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
      
      huffRenderPassDescriptor.colorAttachments[3].texture = _render16C3;
      huffRenderPassDescriptor.colorAttachments[3].loadAction = MTLLoadActionDontCare;
      huffRenderPassDescriptor.colorAttachments[3].storeAction = MTLStoreActionStore;
      
      id <MTLRenderCommandEncoder> renderEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:huffRenderPassDescriptor];
      renderEncoder.label = @"Huff16R4";
      
      [renderEncoder pushDebugGroup: @"Huff16R4"];
      
      // Set the region of the drawable to which we'll draw.
      
      MTLViewport mtlvp = {0.0, 0.0, blockWidth, blockHeight, -1.0, 1.0 };
      [renderEncoder setViewport:mtlvp];
      
      [renderEncoder setRenderPipelineState:_render16PipelineState];
      
      [renderEncoder setVertexBuffer:_vertices
                              offset:0
                             atIndex:AAPLVertexInputIndexVertices];
      
      [renderEncoder setFragmentTexture:_render12C3R3
                                atIndex:0];
      
      [renderEncoder setFragmentBuffer:_blockStartBitOffsets
                                offset:0
                               atIndex:0];
      
      // Read only buffer for huffman symbols and huffman lookup table
      
      [renderEncoder setFragmentBuffer:_huffBuff
                                offset:0
                               atIndex:1];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable1
                                offset:0
                               atIndex:2];
      
      [renderEncoder setFragmentBuffer:_huffSymbolTable2
                                offset:0
                               atIndex:3];
      
      [renderEncoder setFragmentBuffer:_renderTargetDimensionsAndBlockDimensionsUniform
                                offset:0
                               atIndex:4];
      
      // Draw the 3 vertices of our triangle
      [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                        vertexStart:0
                        vertexCount:_numVertices];
      
      [renderEncoder popDebugGroup]; // RenderToTexture
      
      [renderEncoder endEncoding];
    }
  }
  
  // blit the results from the previous shaders into a "slices" texture that is
  // as tall as each block buffer.
  
  {
    NSArray *inRenderedSymbolsTextures = @[
                                           _render12C0R0,
                                           _render12C1R0,
                                           _render12C2R0,
                                           _render12C0R1,
                                           _render12C1R1,
                                           _render12C2R1,
                                           _render12C0R2,
                                           _render12C1R2,
                                           _render12C2R2,
                                           _render12C0R3,
                                           _render12C1R3,
                                           _render12C2R3,
                                           _render16C0,
                                           _render16C1,
                                           _render16C2,
                                           _render16C3,
                                           ];
    
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    
    MTLSize inTxtSize = MTLSizeMake(blockWidth, blockHeight, 1);
    MTLOrigin inTxtOrigin = MTLOriginMake(0, 0, 0);
    
    const int maxCol = 4096 / 512; // max 8 blocks in one row
    
    int outCol = 0;
    int outRow = 0;
    
    int slice = 0;
    for ( id<MTLTexture> blockTxt in inRenderedSymbolsTextures ) {
      // Blit a block of pixels to (X,Y) location that is a multiple of (blockWidth,blockHeight)
      MTLOrigin outTxtOrigin = MTLOriginMake(outCol * blockWidth, outRow * blockHeight, 0);
      
      [blitEncoder copyFromTexture:blockTxt
                       sourceSlice:0
                       sourceLevel:0
                      sourceOrigin:inTxtOrigin
                        sourceSize:inTxtSize
                         toTexture:_renderCombinedSlices
                  destinationSlice:0
                  destinationLevel:0
                 destinationOrigin:outTxtOrigin];
      
      //NSLog(@"blit for slice %2d : write to (%5d, %5d) %4d x %4d in _renderCombinedSlices", slice, (int)outTxtOrigin.x, (int)outTxtOrigin.y, (int)inTxtSize.width, (int)inTxtSize.height);
      
      slice += 1;
      outCol += 1;
      
      if (outCol == maxCol) {
        outCol = 0;
        outRow += 1;
      }
    }
    assert(slice == 16);
    
    [blitEncoder endEncoding];
  }
  
  // Cropping copy operation from _renderToTexturePipelineState which is unsigned int values
  // to _render_texture which contains pixel values. This copy operation will expand single
  // byte values emitted by the huffman decoder as grayscale pixels.

  MTLRenderPassDescriptor *renderToTexturePassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
  
  if (renderToTexturePassDescriptor != nil)
  {
    renderToTexturePassDescriptor.colorAttachments[0].texture = _render_texture;
    renderToTexturePassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    renderToTexturePassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    id <MTLRenderCommandEncoder> renderEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:renderToTexturePassDescriptor];
    renderEncoder.label = @"RenderToTextureCommandEncoder";

    [renderEncoder pushDebugGroup: @"RenderToTexture"];
    
    // Set the region of the drawable to which we'll draw.
    
    MTLViewport mtlvp = {0.0, 0.0, _render_texture.width, _render_texture.height, -1.0, 1.0 };
    [renderEncoder setViewport:mtlvp];
    
    [renderEncoder setRenderPipelineState:_renderToTexturePipelineState];
    
    [renderEncoder setVertexBuffer:_vertices
                            offset:0
                           atIndex:AAPLVertexInputIndexVertices];
    
    [renderEncoder setFragmentTexture:_renderCombinedSlices
                              atIndex:0];
    
    [renderEncoder setFragmentBuffer:_renderTargetDimensionsAndBlockDimensionsUniform
                              offset:0
                             atIndex:0];
    
    // Draw the 3 vertices of our triangle
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:_numVertices];
    
    [renderEncoder popDebugGroup]; // RenderToTexture
    
    [renderEncoder endEncoding];
  }
    
  // --------------------------------------------------------------------------
  
  // Obtain a renderPassDescriptor generated from the view's drawable textures
  MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
  
  if(renderPassDescriptor != nil)
  {
    // Create a render command encoder so we can render into something
    id <MTLRenderCommandEncoder> renderEncoder =
    [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    renderEncoder.label = @"RenderBGRACommandEncoder";
    
    [renderEncoder pushDebugGroup: @"RenderFromTexture"];
    
    // Set the region of the drawable to which we'll draw.
    MTLViewport mtlvp = {0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 };
    [renderEncoder setViewport:mtlvp];
    
    [renderEncoder setRenderPipelineState:_renderFromTexturePipelineState];
    
    [renderEncoder setVertexBuffer:_vertices
                            offset:0
                           atIndex:AAPLVertexInputIndexVertices];
    
    [renderEncoder setFragmentTexture:_render_texture
                              atIndex:AAPLTextureIndexes];
    
    // Draw the 3 vertices of our triangle
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:_numVertices];
    
    [renderEncoder popDebugGroup]; // RenderFromTexture
    
    [renderEncoder endEncoding];
    
    // Schedule a present once the framebuffer is complete using the current drawable
    [commandBuffer presentDrawable:view.currentDrawable];
    
    if (isCaptureRenderedTextureEnabled) {
      // Finalize rendering here & push the command buffer to the GPU
      [commandBuffer commit];
      [commandBuffer waitUntilCompleted];
    }

    // Print output of render pass in stages
    
    const int assertOnValueDiff = 1;
    
    if (isCaptureRenderedTextureEnabled && 0) {
      
      //[self dump4ByteTexture:_render12Zeros label:@"_render12Zeros"];
      
      [self dump4ByteTexture:_render12C0R0 label:@"_render12C0R0"];
      [self dump4ByteTexture:_render12C1R0 label:@"_render12C1R0"];
      [self dump4ByteTexture:_render12C2R0 label:@"_render12C2R0"];
      [self dump4ByteTexture:_render12C3R0 label:@"_render12C3R0 (bits used)"];
      
      [self dump4ByteTexture:_render12C0R1 label:@"_render12C0R1"];
      [self dump4ByteTexture:_render12C1R1 label:@"_render12C1R1"];
      [self dump4ByteTexture:_render12C2R1 label:@"_render12C2R1"];
      [self dump4ByteTexture:_render12C3R1 label:@"_render12C3R1 (bits used)"];
      
      [self dump4ByteTexture:_render12C0R2 label:@"_render12C0R2"];
      [self dump4ByteTexture:_render12C1R2 label:@"_render12C1R2"];
      [self dump4ByteTexture:_render12C2R2 label:@"_render12C2R2"];
      [self dump4ByteTexture:_render12C3R2 label:@"_render12C3R2 (bits used)"];
      
      [self dump4ByteTexture:_render12C0R2 label:@"_render12C0R3"];
      [self dump4ByteTexture:_render12C1R2 label:@"_render12C1R3"];
      [self dump4ByteTexture:_render12C2R2 label:@"_render12C2R3"];
      [self dump4ByteTexture:_render12C3R2 label:@"_render12C3R3 (bits used)"];
      
      [self dump4ByteTexture:_render16C0 label:@"_render16C0"];
      [self dump4ByteTexture:_render16C1 label:@"_render16C1"];
      [self dump4ByteTexture:_render16C2 label:@"_render16C2"];
      [self dump4ByteTexture:_render16C3 label:@"_render16C3"];
    }
    
    // Output of block padded shader write operation
    
    if (isCaptureRenderedTextureEnabled && self.huffRenderFrame.capture && 0) {
      [self dump4ByteTexture:_renderCombinedSlices label:@"_renderCombinedSlices"];
    }
    
    // Capture the render to texture state at the render to size
    if (isCaptureRenderedTextureEnabled) {
      // Query output texture
      
      id<MTLTexture> outTexture = _render_texture;
      
      // Copy texture data into debug framebuffer, note that this include 2x scale
      
      int width = (int) outTexture.width;
      int height = (int) outTexture.height;
      
      NSData *pixelsData = [self.class getTexturePixels:outTexture];
      uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
      
      // Dump output words as BGRA
      
      if ((0)) {
        // Dump 24 bit values as int
        
        fprintf(stdout, "_render_texture\n");
        
        for ( int row = 0; row < height; row++ ) {
          for ( int col = 0; col < width; col++ ) {
            int offset = (row * width) + col;
            //uint32_t v = pixelsPtr[offset] & 0x00FFFFFF;
            //fprintf(stdout, "%5d ", v);
            //fprintf(stdout, "%6X ", v);
            uint32_t v = pixelsPtr[offset];
            fprintf(stdout, "0x%08X ", v);
          }
          fprintf(stdout, "\n");
        }
        
        fprintf(stdout, "done\n");
      }

      if ((0)) {
        // Dump 8bit B comp as int
        
        fprintf(stdout, "_render_texture\n");
        
        for ( int row = 0; row < height; row++ ) {
          for ( int col = 0; col < width; col++ ) {
            int offset = (row * width) + col;
            //uint32_t v = pixelsPtr[offset] & 0x00FFFFFF;
            //fprintf(stdout, "%5d ", v);
            //fprintf(stdout, "%6X ", v);
            uint32_t v = pixelsPtr[offset] & 0xFF;
            //fprintf(stdout, "0x%08X ", v);
            fprintf(stdout, "%3d ", v);
          }
          fprintf(stdout, "\n");
        }
        
        fprintf(stdout, "done\n");
      }
      
      if ((0)) {
        // Dump 24 bit values as int
        
        fprintf(stdout, "expected symbols\n");
        
        NSData *expectedData = _huffInputBytes;
        assert(expectedData);
        uint8_t *expectedDataPtr = (uint8_t *) expectedData.bytes;
        //const int numBytes = (int)expectedData.length * sizeof(uint8_t);
        
        for ( int row = 0; row < height; row++ ) {
          for ( int col = 0; col < width; col++ ) {
            int offset = (row * width) + col;
            //int v = expectedDataPtr[offset];
            //fprintf(stdout, "%6X ", v);
            
            uint32_t v = expectedDataPtr[offset] & 0xFF;
            fprintf(stdout, "%3d ", v);
          }
          fprintf(stdout, "\n");
        }
        
        fprintf(stdout, "done\n");
      }
      
      // Compare output to expected output
      
      if ((1)) {
        NSData *expectedData = _huffInputBytes;
        assert(expectedData);
        uint8_t *expectedDataPtr = (uint8_t *) expectedData.bytes;
        const int numBytes = (int)expectedData.length * sizeof(uint8_t);
        
        uint32_t *renderedPixelPtr = pixelsPtr;
        
        for ( int row = 0; row < height; row++ ) {
          for ( int col = 0; col < width; col++ ) {
            int offset = (row * width) + col;
            
            int expectedSymbol = expectedDataPtr[offset]; // read byte
            int renderedSymbol = renderedPixelPtr[offset] & 0xFF; // compare to just the B component
            
            if (renderedSymbol != expectedSymbol) {
              printf("renderedSymbol != expectedSymbol : %3d != %3d at (X,Y) (%3d,%3d) offset %d\n", renderedSymbol, expectedSymbol, col, row, offset);
              
              if (assertOnValueDiff) {
                assert(0);
              }

            }
          }
        }
        
        assert(numBytes == (width * height));
      }
      
      // end of capture logic
    }
    
    // Get pixel out of outTexture ?
    
    if (isCaptureRenderedTextureEnabled) {
      // Query output texture after resize
      
      id<MTLTexture> outTexture = renderPassDescriptor.colorAttachments[0].texture;
      
      // Copy texture data into debug framebuffer, note that this include 2x scale
      
      int width = _viewportSize.x;
      int height = _viewportSize.y;
      
      NSMutableData *mFramebuffer = [NSMutableData dataWithLength:width*height*sizeof(uint32_t)];
      
      [outTexture getBytes:(void*)mFramebuffer.mutableBytes
               bytesPerRow:width*sizeof(uint32_t)
             bytesPerImage:width*height*sizeof(uint32_t)
                fromRegion:MTLRegionMake2D(0, 0, width, height)
               mipmapLevel:0
                     slice:0];
      
      // Dump output words as BGRA
      
      if ((0)) {
        for ( int row = 0; row < height; row++ ) {
          uint32_t *rowPtr = ((uint32_t*) mFramebuffer.mutableBytes) + (row * width);
          for ( int col = 0; col < width; col++ ) {
            fprintf(stdout, "0x%08X ", rowPtr[col]);
          }
          fprintf(stdout, "\n");
        }
      }
    }
    
    // end of render
  }
  
  // Finalize rendering here & push the command buffer to the GPU
  if (!isCaptureRenderedTextureEnabled) {
    [commandBuffer commit];
  }
  
  return;
}

@end

