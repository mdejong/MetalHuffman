// Objective C interface to huffman parsing functions
//  MIT Licensed

#import <Foundation/Foundation.h>

typedef struct {
  uint8_t symbol;
  uint8_t bitWidth;
} HuffLookupSymbol;

// Our platform independent render class
@interface Huffman : NSObject

// Parse a canonical header of 256 bytes and extract the
// symbol table to local storage in this module.

+ (void) parseCanonicalHeader:(NSData*)canonData
                 originalSize:(uint32_t)originalSize;

// Generate values for lookup table

+ (void) generateLookupTable:(HuffLookupSymbol*)lookupTablePtr
             lookupTableSize:(const int)lookupTableSize;

// Unoptimized serial decode logic. Note that this logic
// assumes that huffBuff contains +2 bytes at the end
// of the buffer to account for read ahead.

+ (void) decodeHuffmanBits:(HuffLookupSymbol*)huffSymbolTable
        numSymbolsToDecode:(int)numSymbolsToDecode
                  huffBuff:(uint8_t*)huffBuff
                 huffBuffN:(int)huffBuffN
                 outBuffer:(uint8_t*)outBuffer
            bitOffsetTable:(uint32_t*)bitOffsetTable;

// Given an input buffer, huffman encode the input values and generate
// output that corresponds to

+ (void) encodeHuffman:(uint8_t*)inBytes
            inNumBytes:(int)inNumBytes
         outFileHeader:(NSMutableData*)outFileHeader
        outCanonHeader:(NSMutableData*)outCanonHeader
          outHuffCodes:(NSMutableData*)outHuffCodes
    outBlockBitOffsets:(NSMutableData*)outBlockBitOffsets
                 width:(int)width
                height:(int)height
              blockDim:(int)blockDim;

@end
