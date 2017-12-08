

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

const static unsigned int blockDim = BLOCK_DIM;

@interface AAPLRenderer ()

@property (nonatomic, retain) HuffRenderFrame *huffRenderFrame;

@end

// Main class performing the rendering
@implementation AAPLRenderer
{
    // The device (aka GPU) we're using to render
    id <MTLDevice> _device;

  // Our compute pipeline composed of our kernal defined in the .metal shader file
  id <MTLComputePipelineState> _computePipelineState;
  
  // Render size at original width and height in terms of blocks
  MTLSize _threadgroupSize;
  MTLSize _threadgroupCount;

  // Render size when each block is reduced to a single render pixel (thread)
  MTLSize _threadgroupRenderPassSize;
  MTLSize _threadgroupRenderPassCount;
  
    // render to texture pipeline is used to render into a texture
    id<MTLRenderPipelineState> _renderToTexturePipelineState;
  
    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
    id<MTLRenderPipelineState> _renderFromTexturePipelineState;

    // The command Queue from which we'll obtain command buffers
    id<MTLCommandQueue> _commandQueue;

    // Texture cache
    CVMetalTextureCacheRef _textureCache;
  
    CVPixelBufferRef _render_cv_buffer;
    id<MTLTexture> _render_texture;

    id<MTLTexture> _render_block_padded_texture;
  
    // The Metal buffer in which we store our vertex data
    id<MTLBuffer> _vertices;

    // The Metal buffer that will hold render dimensions
    id<MTLBuffer> _renderTargetDimensions;
  
  // The Metal buffer stores the number of bits into the
  // huffman codes buffer where the symbol at a given
  // block begins. This table keeps the huffman codes
  // tightly packed.

  id<MTLBuffer> _blockStartBitOffsets;
  
  // The Metal buffer where encoded huffman bits are stored
  id<MTLBuffer> _huffBuff;

  // The Metal buffer where huffman symbol lookup table is stored
  id<MTLBuffer> _huffSymbolTable;
  
    // The number of vertices in our vertex buffer
    NSUInteger _numVertices;

    // The current size of our view so we can use this in our render pipeline
    vector_uint2 _viewportSize;
  
    int isCaptureRenderedTextureEnabled;
  
  NSData *_huffData;

  NSData *_huffInputBytes;

  NSData *_blockByBlockReorder;
  
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
  
  textureDescriptor.pixelFormat = MTLPixelFormatR8Uint;
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

// Initialize with the MetalKit view from which we'll obtain our metal device

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
      isCaptureRenderedTextureEnabled = 1;
      
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
      
      HuffRenderFrameConfig hcfg = TEST_4x4_INCREASING1;
//      HuffRenderFrameConfig hcfg = TEST_4x4_INCREASING2;
//      HuffRenderFrameConfig hcfg = TEST_4x8_INCREASING1;
//      HuffRenderFrameConfig hcfg = TEST_2x8_INCREASING1;
//      HuffRenderFrameConfig hcfg = TEST_6x4_NOT_SQUARE;
//      HuffRenderFrameConfig hcfg = TEST_LARGE_RANDOM;
//      HuffRenderFrameConfig hcfg = TEST_IMAGE1;
      
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
      
      _renderTargetDimensions = [_device newBufferWithLength:sizeof(RenderTargetDimensionsUniform)
                                                     options:MTLResourceStorageModeShared];
      
      RenderTargetDimensionsUniform *ptr = _renderTargetDimensions.contents;
      ptr->width = width;
      ptr->height = height;
      
      _render_texture = [self makeBGRACoreVideoTexture:CGSizeMake(width,height)
                                    cvPixelBufferRefPtr:&_render_cv_buffer];
      
      // One render pass processed 1/(N*N) the number of total blocks, note that this output
      // texture is byte oriented, not 32 bit pixels.
      
      //_render_block_padded_texture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
      
      _render_block_padded_texture = [self make8bitTexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) bytes:NULL];
      
      // Debug capture textures, these are same dimensions as _render_pass
      
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
      renderFrame.debugPixelBlockiTexture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
      renderFrame.debugRootBitOffsetTexture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
      renderFrame.debugCurrentBitOffsetTexture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
      renderFrame.debugBitWidthTexture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
      renderFrame.debugBitPatternTexture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
      renderFrame.debugSymbolsTexture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
      renderFrame.debugCoordsTexture = [self makeBGRATexture:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) pixels:NULL];
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
      
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

      id <MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:@"huffComputeKernel"];
      
      _computePipelineState = [_device newComputePipelineStateWithFunction:kernelFunction
                                                                     error:&error];

      if(!_computePipelineState)
      {
        // Compute pipeline State creation could fail if kernelFunction failed to load from the
        //   library.  If the Metal API validation is enabled, we automatically be given more
        //   information about what went wrong.  (Metal API validation is enabled by default
        //   when a debug build is run from Xcode)
        NSLog(@"Failed to create compute pipeline state, error %@", error);
        return nil;
      }
      
      // The kernel's render size is in terms of blocks where each pixel in each
      // block is represented.

      [self.class calculateThreadgroup:CGSizeMake(blockWidth * blockDim, blockHeight * blockDim) blockDim:blockDim sizePtr:&_threadgroupSize countPtr:&_threadgroupCount];
      
      // Calc compute kernel parameter for one render pass where 1/(N*N) worth of pixels
      // are rendered in each iteration.
      
      CGSize renderSize;
      
      {
        renderSize.width = blockWidth;
        renderSize.height = blockHeight;
      }
      
      // 1 pixel in thread group represents 1 block to be decoded (1 thread)
      
      [self.class calculateThreadgroup:renderSize blockDim:1 sizePtr:&_threadgroupRenderPassSize countPtr:&_threadgroupRenderPassCount];
      
        /// Create our render pipeline

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
      
      {
        // Load the vertex function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        
        // Load the fragment function from the library
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingCropShader"];
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
  
      // Reparse the canonical header to load symbol table info
      
      [Huffman parseCanonicalHeader:outCanonHeader
                       originalSize:(int)renderFrame.inputData.length];
      
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
      
  // FIXME: set _iter offsets so that the starting bit offset for each block is initialized
  // as a 16 bit value correctly
  
  const int maxTableSize = 0xFFFF + 1;
  
  _huffSymbolTable = [_device newBufferWithLength:maxTableSize*sizeof(HuffLookupSymbol)
                                   options:MTLResourceStorageModeShared];
  
  HuffLookupSymbol *codeLookupTablePtr = (HuffLookupSymbol *) _huffSymbolTable.contents;
  assert(codeLookupTablePtr);
  
  [Huffman generateLookupTable:codeLookupTablePtr lookupTableSize:maxTableSize];
  
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
  
  // Decode the generated huffman stream one at a time to make sure nothing went wrong
  // at the most basic encode/decode stage.
  
#if defined(DEBUG)
      NSMutableData *mDecodedBlockOrderSymbols = [NSMutableData data];
      [mDecodedBlockOrderSymbols setLength:outBlockOrderSymbolsNumBytes];
      uint8_t *decodedBlockOrderSymbolsPtr = (uint8_t *) mDecodedBlockOrderSymbols.mutableBytes;
      
      uint8_t *huffSymbolsWithPadding = (uint8_t *) _huffBuff.contents;
      int huffSymbolsWithPaddingNumBytes = encodedSymbolsNumBytes;
      
      NSMutableData *mDecodedBitOffsetData = [NSMutableData data];
      [mDecodedBitOffsetData setLength:(outBlockOrderSymbolsNumBytes * sizeof(uint32_t))];
      uint32_t *decodedBitOffsetPtr = (uint32_t *) mDecodedBitOffsetData.mutableBytes;
      
      [Huffman decodeHuffmanBits:codeLookupTablePtr
              numSymbolsToDecode:outBlockOrderSymbolsNumBytes
                        huffBuff:huffSymbolsWithPadding
                       huffBuffN:huffSymbolsWithPaddingNumBytes
                       outBuffer:decodedBlockOrderSymbolsPtr
                  bitOffsetTable:decodedBitOffsetPtr];

      // FIXME: copy decoded bit widths for each position, can be determined by offsets
      
      // Check that decoded block order symbols matches input to huffman encoder
      
      for (int codei = 0; codei < outBlockOrderSymbolsNumBytes; codei++) {
        uint8_t origCode = outBlockOrderSymbolsPtr[codei];
        uint8_t decodedCode = decodedBlockOrderSymbolsPtr[codei];
        
        if (decodedCode != origCode) {
          printf("%3d != %3d for block huffman offset %d\n", decodedCode, origCode, codei);
          assert(0);
        } else {
          //printf("match %3d for block huffman offset %d\n", decodedCode, codei);
        }
      }
      
      int cmp = memcmp(decodedBlockOrderSymbolsPtr, outBlockOrderSymbolsPtr, outBlockOrderSymbolsNumBytes);
      assert(cmp == 0);
#endif // DEBUG
      
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

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
  // Create a new command buffer
  
  id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
  commandBuffer.label = @"RenderBGRACommand";

  // --------------------------------------------------------------------------
  
  // Possible: create a hard coded render step that reads from the previous
  // pixel to the left is (x > 0) && (arr[x-1] > 0) so that a previous
  // render being done means that the number of bits is copied into next 16 bit slot.
  // Might also just have 63 render cycles hard coded so that each is done and
  // the offsets for each thing are constant and it moves the render along.
  
  // Compute shader

  {
    {
    
    id <MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    
    [computeEncoder setComputePipelineState:_computePipelineState];
    
    // output texture
    
    [computeEncoder setTexture:_render_block_padded_texture
                       atIndex:AAPLTexturePaddedOut];
    
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
      // 4 more textures to debug decode state

      [computeEncoder setTexture:self.huffRenderFrame.debugPixelBlockiTexture
                         atIndex:AAPLTextureBlocki];
      [computeEncoder setTexture:self.huffRenderFrame.debugRootBitOffsetTexture
                         atIndex:AAPLTextureRootBitOffset];
      [computeEncoder setTexture:self.huffRenderFrame.debugCurrentBitOffsetTexture
                         atIndex:AAPLTextureCurrentBitOffset];
      [computeEncoder setTexture:self.huffRenderFrame.debugBitWidthTexture
                         atIndex:AAPLTextureBitWidth];
      [computeEncoder setTexture:self.huffRenderFrame.debugBitPatternTexture
                         atIndex:AAPLTextureBitPattern];
      [computeEncoder setTexture:self.huffRenderFrame.debugSymbolsTexture
                         atIndex:AAPLTextureSymbols];
      [computeEncoder setTexture:self.huffRenderFrame.debugCoordsTexture
                         atIndex:AAPLTextureCoords];
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
    
    [computeEncoder setBuffer:_blockStartBitOffsets
                       offset:0
                      atIndex:AAPLComputeBlockStartBitOffsets];
    
    // Read only buffer for huffman symbols and huffman lookup table
    
    [computeEncoder setBuffer:_huffBuff
                       offset:0
                      atIndex:AAPLComputeHuffBuff];
    
    [computeEncoder setBuffer:_huffSymbolTable
                       offset:0
                      atIndex:AAPLComputeHuffSymbolTable];

    [computeEncoder dispatchThreadgroups:_threadgroupRenderPassCount
                     threadsPerThreadgroup:_threadgroupRenderPassSize];
    
    [computeEncoder endEncoding];
    
    }
  }
  
  // Cropping copy operation from _render_block_padded_texture which is unsigned int values
  // to _render_texture which contains pixel values. This copy operation will expand single
  // byte values emitted by the huffman decoder as grayscale pixels.

  MTLRenderPassDescriptor *renderToTexturePassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
  
  if (renderToTexturePassDescriptor != nil)
  {
    renderToTexturePassDescriptor.colorAttachments[0].texture = _render_texture;
    //renderToTexturePassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    //renderToTexturePassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
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
    
    [renderEncoder setFragmentTexture:_render_block_padded_texture
                              atIndex:0];
    
    [renderEncoder setFragmentBuffer:_renderTargetDimensions
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
    
    // Debug stages from each render cycle
    
#if defined(HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES)
    if (isCaptureRenderedTextureEnabled && self.huffRenderFrame.capture) {
      // Query output texture
      
      {
        
        // blocki
        
        {
          id<MTLTexture> txt = self.huffRenderFrame.debugPixelBlockiTexture;
          
          NSData *pixelsData = [self.class getTexturePixels:txt];
          
          int width = (int) txt.width;
          int height = (int) txt.height;
          
          // Dump output words as BGRA
          
          fprintf(stdout, "blocki output\n");
          
          if ((1)) {
            // Dump 24 bit number
            
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                int v = pixelsPtr[offset] & 0x00FFFFFF;
                fprintf(stdout, "%5d ", v);
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
          
          // Compare to expected blocki value
          
          {
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            NSData *expectedData = self.huffRenderFrame.expected_blocki;
            uint32_t *expectedDataPtr = (uint32_t*) expectedData.bytes;
            
            assert(expectedData.length == pixelsData.length);

            if ((1)) {
              // Dump 24 bit output
              fprintf(stdout, "(blocki)\n");
              
              for ( int row = 0; row < height; row++ ) {
                for ( int col = 0; col < width; col++ ) {
                  int offset = (row * width) + col;
                  uint32_t pixel = pixelsPtr[offset];
                  int blocki = pixel & 0xFFFFFF;
                  uint32_t expectedPixel = expectedDataPtr[offset];
                  int exBlocki = expectedPixel & 0xFFFFFF;
                  fprintf(stdout, "%d ?= %d, ", blocki, exBlocki);
                  
                  if (blocki != exBlocki) {
                    if (assertOnValueDiff) {
                      assert(0);
                    }
                  }
                }
                fprintf(stdout, "\n");
              }
              
              fprintf(stdout, "done\n");
            }

          }

        }
        
        {
          id<MTLTexture> txt = self.huffRenderFrame.debugRootBitOffsetTexture;
          
          NSData *pixelsData = [self.class getTexturePixels:txt];
          
          int width = (int) txt.width;
          int height = (int) txt.height;
          
          // Dump output words as BGRA
          
          fprintf(stdout, "root bit offset\n");
          
          if ((1)) {
            // Dump 24 bit number
            
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                int v = pixelsPtr[offset] & 0x00FFFFFF;
                fprintf(stdout, "%5d ", v);
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
          
          uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
          
          NSData *expectedData = self.huffRenderFrame.expected_rootBitOffset;
          uint32_t *expectedDataPtr = (uint32_t*) expectedData.bytes;
          
          assert(expectedData.length == pixelsData.length);
          
          if ((1)) {
            // Dump 24 bit output
            fprintf(stdout, "(root bit offset)\n");
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                uint32_t pixel = pixelsPtr[offset];
                int v = pixel & 0xFFFFFF;
                uint32_t expectedPixel = expectedDataPtr[offset];
                int exV = expectedPixel & 0xFFFFFF;
                fprintf(stdout, "%5d ?= %5d, ", v, exV);
                
                if (v != exV) {
                  if (assertOnValueDiff) {
                    assert(0);
                  }
                }
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }

        }
        
        {
          id<MTLTexture> txt = self.huffRenderFrame.debugCurrentBitOffsetTexture;
          
          NSData *pixelsData = [self.class getTexturePixels:txt];
          
          int width = (int) txt.width;
          int height = (int) txt.height;
          
          // Dump output words as BGRA
          
          fprintf(stdout, "current bit offset\n");
          
          if ((1)) {
            // Dump 24 bit number
            
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                int v = pixelsPtr[offset] & 0x00FFFFFF;
                fprintf(stdout, "%5d ", v);
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
          
          uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
          
          NSData *expectedData = self.huffRenderFrame.expected_currentBitOffset;
          uint32_t *expectedDataPtr = (uint32_t*) expectedData.bytes;
          
          assert(expectedData.length == pixelsData.length);
          
          if ((1)) {
            // Dump 24 bit output
            fprintf(stdout, "(current bit offset)\n");
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                uint32_t pixel = pixelsPtr[offset];
                int v = pixel & 0xFFFFFF;
                uint32_t expectedPixel = expectedDataPtr[offset];
                int exV = expectedPixel & 0xFFFFFF;
                fprintf(stdout, "%5d ?= %5d, ", v, exV);
                
                if (v != exV) {
                  if (assertOnValueDiff) {
                    assert(0);
                  }
                }
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }

        }
        
        // bit width
        
        {
          id<MTLTexture> txt = self.huffRenderFrame.debugBitWidthTexture;
          
          NSData *pixelsData = [self.class getTexturePixels:txt];
          
          int width = (int) txt.width;
          int height = (int) txt.height;
          
          // Dump output words as BGRA
          
          fprintf(stdout, "current bit width\n");
          
          if ((1)) {
            // Dump 24 bit number
            
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                int v = pixelsPtr[offset] & 0x00FFFFFF;
                fprintf(stdout, "%5d ", v);
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
          
          uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
          
          NSData *expectedData = self.huffRenderFrame.expected_bitWidth;
          uint32_t *expectedDataPtr = (uint32_t*) expectedData.bytes;
          
          assert(expectedData.length == pixelsData.length);
          
          if ((1)) {
            // Dump 24 bit output
            fprintf(stdout, "(bit width)\n");
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                uint32_t pixel = pixelsPtr[offset];
                int v = pixel & 0xFFFFFF;
                uint32_t expectedPixel = expectedDataPtr[offset];
                int exV = expectedPixel & 0xFFFFFF;
                fprintf(stdout, "%5d ?= %5d, ", v, exV);
                
                if (v != exV) {
                  if (assertOnValueDiff) {
                    assert(0);
                  }
                }
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
        }

        // symbol bit pattern
        
        {
          id<MTLTexture> txt = self.huffRenderFrame.debugBitPatternTexture;
          
          NSData *pixelsData = [self.class getTexturePixels:txt];
          
          int width = (int) txt.width;
          int height = (int) txt.height;
          
          // Dump output words as BGRA
          
          fprintf(stdout, "bit pattern\n");
          
          if ((1)) {
            // Dump 24 bit number
            
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                uint16_t code = pixelsPtr[offset] & 0x0000FFFF;

                if ((1)) {
                  fprintf(stdout, "\ncode 0x%04X\n", code);
                }
                
                NSString *bitString = [self codeBitsAsString:code width:16];

                fprintf(stdout, "%s ", [bitString UTF8String]);
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
          
          
          uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
          
          NSData *expectedData = self.huffRenderFrame.expected_bitPattern;
          uint32_t *expectedDataPtr = (uint32_t*) expectedData.bytes;
          
          assert(expectedData.length == pixelsData.length);
          
          if ((1)) {
            // Dump 24 bit output
            fprintf(stdout, "(bit pattern)\n");
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                uint32_t pixel = pixelsPtr[offset];
                uint32_t expectedPixel = expectedDataPtr[offset];
                
                uint32_t code = pixel & 0xFFFFFF;
                uint32_t exCode = expectedPixel & 0xFFFFFF;
                
                if (code != exCode) {
                  NSString *bitString = [self codeBitsAsString:code width:16];
                  NSString *expectedBitString = [self codeBitsAsString:exCode width:16];
                  
                  fprintf(stdout, "for (X,Y) (%5d, %5d) : %s != %s\n", col, row, [bitString UTF8String], [expectedBitString UTF8String]);
                  if (assertOnValueDiff) {
                    assert(0);
                  }
                }
              }
            }
            
            fprintf(stdout, "done\n");
          }
        }
        
        // emitted symbol
        
        {
          id<MTLTexture> txt = self.huffRenderFrame.debugSymbolsTexture;
          
          NSData *pixelsData = [self.class getTexturePixels:txt];
          
          int width = (int) txt.width;
          int height = (int) txt.height;
          
          // Dump output words as BGRA
          
          fprintf(stdout, "rendered symbol\n");
          
          if ((1)) {
            // Dump 24 bit number
            
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                int v = pixelsPtr[offset] & 0x00FFFFFF;
                fprintf(stdout, "%5d ", v);
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
          
          uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
          
          NSData *expectedData = self.huffRenderFrame.expected_symbols;
          uint8_t *expectedDataPtr = (uint8_t*) expectedData.bytes;
          
          //assert(expectedData.length == pixelsData.length);
          
          if ((1)) {
            // Dump 24 bit output
            fprintf(stdout, "(symbols)\n");
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                uint32_t pixel = pixelsPtr[offset];
                int v = pixel & 0xFFFFFF;
                uint32_t expectedPixel = expectedDataPtr[offset];
                int exV = expectedPixel & 0xFFFFFF;
                fprintf(stdout, "%5d ?= %5d, ", v, exV);
                fflush(stdout);
                
                if (v != exV) {
                  if (assertOnValueDiff) {
                    assert(0);
                  }
                }
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
        }
        
        // coords
        
        {
          id<MTLTexture> txt = self.huffRenderFrame.debugCoordsTexture;
          
          NSData *pixelsData = [self.class getTexturePixels:txt];
          
          int width = (int) txt.width;
          int height = (int) txt.height;
          
          // Dump output words as BGRA
          
          fprintf(stdout, "render coord\n");
          
          if ((1)) {
            // FIXME: represent X,Y as 2 12 bit values
            
            // Dump (X,Y) from 16 bit output
            
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            fprintf(stdout, "(X,Y)\n");
            
            for ( int row = 0; row < height; row++ ) {
              for ( int col = 0; col < width; col++ ) {
                int offset = (row * width) + col;
                int X = (pixelsPtr[offset] >> 8) & 0xFF;
                int Y = pixelsPtr[offset] & 0xFF;
                fprintf(stdout, "(%2d %2d) ", X, Y);
              }
              fprintf(stdout, "\n");
            }
            
            fprintf(stdout, "done\n");
          }
          
          // Compare to expected
          
          {
            uint32_t *pixelsPtr = ((uint32_t*) pixelsData.bytes);
            
            NSData *expectedData = self.huffRenderFrame.expected_coords;
            uint32_t *expectedDataPtr = (uint32_t*) expectedData.bytes;
            
            assert(expectedData.length == pixelsData.length);
            
            if ((1)) {
              fprintf(stdout, "(X,Y)\n");
              
              for ( int row = 0; row < height; row++ ) {
                for ( int col = 0; col < width; col++ ) {
                  int offset = (row * width) + col;
                  uint32_t pixel = pixelsPtr[offset];
                  int X = (pixel >> 8) & 0xFF;
                  int Y = pixel & 0xFF;
                  uint32_t expectedPixel = expectedDataPtr[offset];
                  int exX = (expectedPixel >> 8) & 0xFF;
                  int exY = expectedPixel & 0xFF;
                  fprintf(stdout, "(%2d %2d) ?= (%2d %2d), ", X, Y, exX, exY);
                  
                  if ((X != exX) || (Y != exY)) {
                    if (assertOnValueDiff) {
                      assert(0);
                    }
                  }
                }
                fprintf(stdout, "\n");
              }
              
              fprintf(stdout, "done\n");
            }
          }
        }
        
      }
      
      fprintf(stdout, "done all passes\n");
    }
#endif // HUFF_EMIT_MULTIPLE_DEBUG_TEXTURES
    
    // Output of block padded shader write operation
    
    if (isCaptureRenderedTextureEnabled && self.huffRenderFrame.capture) {
      // Query output texture
      
      //id<MTLTexture> outTexture = _render_texture;
      id<MTLTexture> outTexture = _render_block_padded_texture;
      
      // Copy texture data into debug framebuffer, note that this include 2x scale
      
      int width = (int) outTexture.width;
      int height = (int) outTexture.height;
      
      NSMutableData *mFramebuffer = [NSMutableData dataWithLength:width*height*sizeof(uint32_t)];
      
      [outTexture getBytes:(void*)mFramebuffer.mutableBytes
               bytesPerRow:width*sizeof(uint32_t)
             bytesPerImage:width*height*sizeof(uint32_t)
                fromRegion:MTLRegionMake2D(0, 0, width, height)
               mipmapLevel:0
                     slice:0];
      
      // Dump output words as BGRA
      
      if ((0)) {
        fprintf(stdout, "_render_block_padded_texture\n");
        
        // Dump 24 bit values as int
        
        for ( int row = 0; row < height; row++ ) {
          uint32_t *rowPtr = ((uint32_t*) mFramebuffer.mutableBytes) + (row * width);
          for ( int col = 0; col < width; col++ ) {
            int v = rowPtr[col] & 0x00FFFFFF;
            fprintf(stdout, "%5d ", v);
          }
          fprintf(stdout, "\n");
        }
        
        fprintf(stdout, "done\n");
      }
      
      if ((0)) {
        // Dump (X,Y) from 16 bit output
        
        fprintf(stdout, "(X,Y)\n");
        
        for ( int row = 0; row < height; row++ ) {
          uint32_t *rowPtr = ((uint32_t*) mFramebuffer.mutableBytes) + (row * width);
          for ( int col = 0; col < width; col++ ) {
            //int decodedSymbol = rowPtr[col] & 0xFF;
            int X = (rowPtr[col] >> 8) & 0xFF;
            int Y = rowPtr[col] & 0xFF;
            fprintf(stdout, "(%2d %2d) ", X, Y);
          }
          fprintf(stdout, "\n");
        }
        
        fprintf(stdout, "done\n");
      }

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
            int v = pixelsPtr[offset] & 0x00FFFFFF;
            fprintf(stdout, "%5d ", v);
          }
          fprintf(stdout, "\n");
        }
        
        if ((0)) {
          for ( int row = 0; row < height; row++ ) {
            for ( int col = 0; col < width; col++ ) {
              int offset = (row * width) + col;
              int v = pixelsPtr[offset] & 0x00FFFFFF;
              
              NSString *bitsAsString = [self codeBitsAsString:v width:16];
              fprintf(stdout, "%s ", [bitsAsString UTF8String]);
            }
            fprintf(stdout, "\n");
          }
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
            int renderedSymbol = renderedPixelPtr[offset] & 0xFF;
            
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

