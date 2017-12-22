// Objective C interface to huffman parsing functions
//  MIT Licensed

#import "Huffman.h"

#import "HuffmanUtil.hpp"

#include <assert.h>

#include <string>
#include <vector>
#include <unordered_map>
#include <cstdint>

#include "HuffmanEncoder.hpp"
#include "huff_util.hpp"

using namespace std;

// Invoke huffman util module functions

// Main class performing the rendering

@implementation Huffman

// Parse a canonical header of 256 bytes and extract the
// symbol table to local storage in this module.

+ (void) parseCanonicalHeader:(NSData*)canonData
{
  HuffmanUtil::parseCanonicalHeader((uint8_t*)canonData.bytes);
}

// Generate values for lookup table

+ (void) generateLookupTable:(HuffLookupSymbol*)lookupTablePtr
       lookupTableNumEntries:(const int)lookupTableNumEntries
{
  HuffmanUtil::generateLookupTable(lookupTablePtr,
                                   lookupTableNumEntries);
}

// Generate a low/high pair of lookup tables

+ (void) generateSplitLookupTables:(const int)table1NumBits
                     table2NumBits:(const int)table2NumBits
                            table1:(NSMutableData*)table1
                            table2:(NSMutableData*)table2
{
  vector<HuffLookupSymbol> table1Vec;
  vector<HuffLookupSymbol> table2Vec;
  
  HuffmanUtil::generateSplitLookupTables(
                                         table1NumBits,
                                         table2NumBits,
                                         table1Vec,
                                         table2Vec);
  
  // Copy vector data into NSMutableData
  
  {
    int numBytesInTable1 = (int)(table1Vec.size() * sizeof(HuffLookupSymbol));
    [table1 setLength:numBytesInTable1];
    memcpy(table1.mutableBytes, table1Vec.data(), numBytesInTable1);
  }

  {
    int numBytesInTable2 = (int)(table2Vec.size() * sizeof(HuffLookupSymbol));
    [table2 setLength:numBytesInTable2];
    memcpy(table2.mutableBytes, table2Vec.data(), numBytesInTable2);
  }
  
  return;
}

// Unoptimized serial decode logic. Note that this logic
// assumes that huffBuff contains +2 bytes at the end
// of the buffer to account for read ahead.

+ (void) decodeHuffmanBits:(HuffLookupSymbol*)huffSymbolTable
        numSymbolsToDecode:(int)numSymbolsToDecode
                  huffBuff:(uint8_t*)huffBuff
                 huffBuffN:(int)huffBuffN
                 outBuffer:(uint8_t*)outBuffer
            bitOffsetTable:(uint32_t*)bitOffsetTable
{
  HuffmanUtil::decodeHuffmanBits(
                                 huffSymbolTable,
                                 numSymbolsToDecode,
                                 huffBuff,
                                 huffBuffN,
                                 outBuffer,
                                 bitOffsetTable);
}

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
{
  HuffmanUtil::decodeHuffmanBitsFromTables(huffSymbolTable1,
                                           huffSymbolTable2,
                                           table1BitNum,
                                           table2BitNum,
                                           numSymbolsToDecode,
                                           huffBuff,
                                           huffBuffN,
                                           outBuffer,
                                           bitOffsetTable
#if defined(DecodeHuffmanBitsFromTablesCompareToOriginal)
                                           ,
                                           originalBytes
#endif // DecodeHuffmanBitsFromTablesCompareToOriginal
                                           );
}

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
              blockDim:(int)blockDim
{
  vector<uint8_t> outFileHeaderVec;
  vector<uint8_t> outCanonHeaderVec;
  vector<uint8_t> outHuffCodesVec;
  vector<uint32_t> outBlockBitOffsetsVec;
  
  HuffmanUtil::encodeHuffman(
                             inBytes,
                             inNumBytes,
                             outFileHeaderVec,
                             outCanonHeaderVec,
                             outHuffCodesVec,
                             outBlockBitOffsetsVec,
                             width,
                             height,
                             blockDim);

  // Copy vector data into NSMutableData
  
  {
    auto & vec = outFileHeaderVec;
    int numBytes = (int)(vec.size() * sizeof(uint8_t));
    [outFileHeader setLength:numBytes];
    memcpy(outFileHeader.mutableBytes, vec.data(), numBytes);
  }

  {
    auto & vec = outCanonHeaderVec;
    int numBytes = (int)(vec.size() * sizeof(uint8_t));
    [outCanonHeader setLength:numBytes];
    memcpy(outCanonHeader.mutableBytes, vec.data(), numBytes);
  }

  {
    auto & vec = outHuffCodesVec;
    int numBytes = (int)(vec.size() * sizeof(uint8_t));
    [outHuffCodes setLength:numBytes];
    memcpy(outHuffCodes.mutableBytes, vec.data(), numBytes);
  }

  {
    auto & vec = outBlockBitOffsetsVec;
    int numBytes = (int)(vec.size() * sizeof(uint32_t));
    [outBlockBitOffsets setLength:numBytes];
    memcpy(outBlockBitOffsets.mutableBytes, vec.data(), numBytes);
  }
  
  return;
}

// Encode signed byte deltas

+ (NSData*) encodeSignedByteDeltas:(NSData*)data
{
  vector<int8_t> inBytes;
  inBytes.resize(data.length);
  memcpy(inBytes.data(), data.bytes, data.length);
  
  vector<int8_t> outDeltaBytes = HuffmanUtil::encodeSignedByteDeltas(inBytes);
  
  NSMutableData *mDeltas = [NSMutableData data];
  [mDeltas setLength:outDeltaBytes.size()];
  memcpy((void*)mDeltas.bytes, (void*)outDeltaBytes.data(), outDeltaBytes.size());
  return [NSData dataWithData:mDeltas];
}

// Decode signed byte deltas

+ (NSData*) decodeSignedByteDeltas:(NSData*)deltas
{
  vector<int8_t> inBytes;
  inBytes.resize(deltas.length);
  memcpy(inBytes.data(), deltas.bytes, deltas.length);
  
  vector<int8_t> outBytes = HuffmanUtil::decodeSignedByteDeltas(inBytes);
  
  NSMutableData *mData = [NSMutableData data];
  [mData setLength:outBytes.size()];
  memcpy((void*)mData.bytes, (void*)outBytes.data(), outBytes.size());
  return [NSData dataWithData:mData];
}

@end

