// Objective C interface to huffman parsing functions
//  MIT Licensed

#import <Foundation/Foundation.h>

#import "HuffmanLookupSymbol.h"

// Our platform independent render class
@interface Huffman : NSObject

// Parse a canonical header of 256 bytes and extract the
// symbol table to local storage in this module.

+ (void) parseCanonicalHeader:(NSData*)canonData;

// Generate values for lookup table

+ (void) generateLookupTable:(HuffLookupSymbol*)lookupTablePtr
       lookupTableNumEntries:(const int)lookupTableNumEntries;

+ (void) generateSplitLookupTables:(const int)table1NumBits
                     table2NumBits:(const int)table2NumBits
                            table1:(NSMutableData*)table1
                            table2:(NSMutableData*)table2;

// Unoptimized serial decode logic. Note that this logic
// assumes that huffBuff contains +2 bytes at the end
// of the buffer to account for read ahead.

+ (void) decodeHuffmanBits:(HuffLookupSymbol*)huffSymbolTable
        numSymbolsToDecode:(int)numSymbolsToDecode
                  huffBuff:(uint8_t*)huffBuff
                 huffBuffN:(int)huffBuffN
                 outBuffer:(uint8_t*)outBuffer
            bitOffsetTable:(uint32_t*)bitOffsetTable;

// Unoptimized logic that decodes from a pair of tables
// where the first table should contain the vast majority
// of the symbols and the second table is read and used
// only when needed.

+ (void) decodeHuffmanBitsFromTables:(HuffLookupSymbol*)huffSymbolTable1
                    huffSymbolTable2:(HuffLookupSymbol*)huffSymbolTable2
                        table1BitNum:(const int)table1BitNum
                        table2BitNum:(const int)table2BitNum
                  numSymbolsToDecode:(int)numSymbolsToDecode
                            huffBuff:(uint8_t*)huffBuff
                           huffBuffN:(int)huffBuffN
                           outBuffer:(uint8_t*)outBuffer
                      bitOffsetTable:(uint32_t*)bitOffsetTable
#if defined(DecodeHuffmanBitsFromTablesCompareToOriginal)
                       originalBytes:(uint8_t*)originalBytes
#endif // DecodeHuffmanBitsFromTablesCompareToOriginal
;

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

// Encode signed byte deltas

+ (NSData*) encodeSignedByteDeltas:(NSData*)data;

// Decode signed byte deltas

+ (NSData*) decodeSignedByteDeltas:(NSData*)deltas;

@end
