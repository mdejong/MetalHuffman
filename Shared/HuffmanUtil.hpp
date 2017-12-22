//
//  HuffmanUtil.hpp
//
//  Created by Mo DeJong on 11/19/17.
//  MIT Licensed
//
// Huffman encoder for input symbols limited to the valid byte range
// of (0, 255) inclusive. This leads to huffman table codes that are
// a maximum of 16 bits wide which can be processed efficiently.

#ifndef HuffmanUtil_hpp
#define HuffmanUtil_hpp

#include <cstdint>
#include <vector>

// This header is pure C and can be included in either Objc or C++
#include "HuffmanLookupSymbol.h"

using namespace std;

class HuffmanUtil {

public:

  // Parse a canonical header of 256 bytes and extract the
  // symbol table to local storage in this module.
  
  static void
  parseCanonicalHeader(uint8_t *canonData);

  static void
  generateLookupTable(HuffLookupSymbol *lookupTablePtr,
                      const int lookupTableNumEntries);

  static void
  generateSplitLookupTables(
                            const int table1NumBits,
                            const int table2NumBits,
                            vector<HuffLookupSymbol> & table1,
                            vector<HuffLookupSymbol> & table2);

  // Unoptimized serial decode logic. Note that this logic
  // assumes that huffBuff contains +2 bytes at the end
  // of the buffer to account for read ahead.
  
  static void
  decodeHuffmanBits(
                    HuffLookupSymbol *huffSymbolTable,
                    int numSymbolsToDecode,
                    uint8_t *huffBuff,
                    int huffBuffN,
                    uint8_t *outBuffer,
                    uint32_t *bitOffsetTable);
  
  // Unoptimized logic that decodes from a pair of tables
  // where the first table should contain the vast majority
  // of the symbols and the second table is read and used
  // only when needed.
  
  static void
  decodeHuffmanBitsFromTables(
                              HuffLookupSymbol *huffSymbolTable1,
                              HuffLookupSymbol *huffSymbolTable2,
                              const int table1BitNum,
                              const int table2BitNum,
                              int numSymbolsToDecode,
                              uint8_t *huffBuff,
                              int huffBuffN,
                              uint8_t *outBuffer,
                              uint32_t *bitOffsetTable
#if defined(DecodeHuffmanBitsFromTablesCompareToOriginal)
                              ,
                              uint8_t *originalBytes
#endif // DecodeHuffmanBitsFromTablesCompareToOriginal
  );

  
  // Given an input buffer, huffman encode the input values and generate
  // output that corresponds to
  
  static void
  encodeHuffman(
                uint8_t* inBytes,
                int inNumBytes,
                vector<uint8_t> & outFileHeader,
                vector<uint8_t> & outCanonHeader,
                vector<uint8_t> & outHuffCodes,
                vector<uint32_t> & outBlockBitOffsets,
                int width,
                int height,
                int blockDim);
  
  static vector<int8_t>
  encodeSignedByteDeltas(const vector<int8_t> & bytes);
  
  static vector<int8_t>
  decodeSignedByteDeltas(const vector<int8_t> & deltas);

};
  
#endif // HuffmanUtil_hpp
