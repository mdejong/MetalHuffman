// Objective C interface to huffman parsing functions
//  MIT Licensed

#import "Huffman.h"

#include <assert.h>

#include <string>
#include <vector>
#include <unordered_map>
#include <cstdint>

#include "HuffmanEncoder.hpp"
#include "huff_util.hpp"

using namespace std;

/*

// Generate a canonical huffman table representation
// that supports a fixed size of 256 byte values.
// Each symbol must be represented by a bit width
// that is 16 bits at the maximum.

static inline
vector<uint8_t>
huff_generate_canonical_table(
                              vector<int> inBitWidths
                              )
{
#if defined(DEBUG)
  assert(inBitWidths.size() == 256);
#endif // DEBUG
  
  vector<uint8_t> canonicalSymbolToBitWidths(256);
  int canonBinaryBufferi = 0;
  
  for ( int bitWidth : inBitWidths ) {
#if defined(DEBUG)
    assert(bitWidth >= 0 && bitWidth <= 16);
    assert(canonBinaryBufferi < 256);
#endif // DEBUG
    uint8_t bitWidthByte = (uint8_t) bitWidth;
    canonicalSymbolToBitWidths[canonBinaryBufferi++] = bitWidthByte;
  }
  
  return canonicalSymbolToBitWidths;
}

// Given a canonical table generated above, create a mapping
// from symbol to the actual code value represented as
// left justified unsigned 16 bit values. The returned vector
// is the same size as inTable and in the case where the
// symbol bit width is zero then the canonical code will
// be zero, the caller should take care to avoid using
// a code from a bit width zero entry.

// huffmanCodes[ 97] = 0000-0000-0000-0000 : bit width 1
// huffmanCodes[ 98] = 0000-0000-0000-0100 : bit width 3
// huffmanCodes[100] = 0000-0000-0000-0101 : bit width 3
// huffmanCodes[114] = 0000-0000-0000-0110 : bit width 3
// huffmanCodes[ 10] = 0000-0000-0000-1110 : bit width 4
// huffmanCodes[ 99] = 0000-0000-0000-1111 : bit width 4
// 
// canonicalCodesTable[ 10] = 0000-0000-0000-1110 (bit width  4)
// canonicalCodesTable[ 97] = 0000-0000-0000-0000 (bit width  1)
// canonicalCodesTable[ 98] = 0000-0000-0000-0100 (bit width  3)
// canonicalCodesTable[ 99] = 0000-0000-0000-1111 (bit width  4)
// canonicalCodesTable[100] = 0000-0000-0000-0101 (bit width  3)
// canonicalCodesTable[114] = 0000-0000-0000-0110 (bit width  3)

static inline
vector<uint16_t>
huff_generate_canonical_codes(
                              vector<uint8_t> inTable
                              )
{
  typedef struct {
    uint8_t symbol;
    uint8_t bitWidth;
  } huff_generate_canonical_codes_type_pair;
  
#if defined(DEBUG)
  assert(inTable.size() == 256);
#endif // DEBUG
  
  vector<huff_generate_canonical_codes_type_pair> sortedTable;
  sortedTable.reserve(inTable.size());
  
  //vector<unsigned int> numCodesOfLen(inTable.size());
  
  uint8_t symbol = 0;
  
  for ( uint8_t bitWidth : inTable ) {
    huff_generate_canonical_codes_type_pair tp;
    tp.symbol = symbol;
    tp.bitWidth = bitWidth;
    if (bitWidth > 0) {
      sortedTable.push_back(tp);
      //numCodesOfLen[bitWidth] += 1;
    }
    
    symbol += 1;
  }
  
  sort(begin(sortedTable), end(sortedTable),
       [](const huff_generate_canonical_codes_type_pair & v1, const huff_generate_canonical_codes_type_pair & v2) -> bool
       {
         if (v1.bitWidth == v2.bitWidth) {
           return v1.symbol < v2.symbol;
         } else {
           return v1.bitWidth < v2.bitWidth;
         }
       }
       );
  
  vector<uint16_t> huffmanCodes(inTable.size());
  
  // Now generate the codes
  
  uint16_t currentCode = 0;
  
  for ( int pairOffset = 0; pairOffset < sortedTable.size(); pairOffset++ ) {
    huff_generate_canonical_codes_type_pair pair = sortedTable[pairOffset];
    uint8_t symbol = pair.symbol;
    uint8_t bitWidth = pair.bitWidth;
    
    huffmanCodes[symbol] = currentCode;
    currentCode += 1;
    
    //printf("huffmanCodes[%3d] = %s : bit width %d\n", symbol, get_code_bits_as_string(huffmanCodes[symbol], 16).c_str(), bitWidth);
    
    // Left justify the codes
    huffmanCodes[symbol] <<= (16 - bitWidth);
    
    int nextPairOffset = (pairOffset+1);
    if (nextPairOffset < sortedTable.size()) {
      huff_generate_canonical_codes_type_pair nextPair = sortedTable[nextPairOffset];
#if defined(DEBUG)
      uint8_t nextSymbol = nextPair.symbol;
      nextSymbol = nextSymbol;
#endif // DEBUG
      uint8_t nextSymbolBitWidth = nextPair.bitWidth;
      int bitWidthDiff = (nextSymbolBitWidth - bitWidth);
      if (bitWidthDiff > 0) {
        currentCode <<= bitWidthDiff;
      }
    }
    
    //printf("huffmanCodes[%3d] = %s : bit width %d\n", symbol, get_code_bits_as_string(huffmanCodes[symbol], 16).c_str(), bitWidth);
  }
  
#if defined(DEBUG)
  assert(huffmanCodes.size() == 256);
#endif // DEBUG
  
#if defined(DEBUG)
  // No 2 codes should map to the same value
  // except for the special case of zero.
  unordered_map<uint16_t, uint16_t> dedup;
  
  for ( uint16_t code : huffmanCodes ) {
    if (code != 0 && dedup.count(code) > 0) {
      assert(0);
    }
    dedup[code] = code;
  }
#endif // DEBUG
  
  return huffmanCodes;
}

*/

static
int
originalSymbolBufferSize = 0;

static
int
numSymbolsInTable = 0;

static
vector<uint16_t> canonicalSymbolTable;

static
vector<uint8_t> bitWidthTable;

static
vector<uint8_t> canonicalHeader;

// Main class performing the rendering
@implementation Huffman

+ (void) parseCanonicalFileHeader:(NSData*)data
              originalSizePtr:(uint32_t*)originalSizePtr
              encodedBitsPtr:(uint8_t**)encodedBitsPtr
              encodedBitsNumBytesPtr:(int*)encodedBitsNumBytesPtr
{
  const int maxNumSymbols = 256;
  
  canonicalSymbolTable.resize(maxNumSymbols);
  bitWidthTable.resize(maxNumSymbols);
  canonicalHeader.resize(maxNumSymbols);
  originalSymbolBufferSize = 0;
  
  // First 4 bytes contains an int indicating the orginal
  // number of input symbols
  
  originalSymbolBufferSize = 1;
  uint32_t *sizePtr = (uint32_t *) data.bytes;
  originalSymbolBufferSize = sizePtr[0];
  *originalSizePtr = originalSymbolBufferSize;
  
  // Next 256 bytes is the canonical header
  
  memcpy(canonicalHeader.data(), &sizePtr[1], 256);
  
  *encodedBitsPtr = ((uint8_t*)&sizePtr[1]) + 256;
  *encodedBitsNumBytesPtr = (int)data.length - 256 - sizeof(uint32_t);

  // Decode canonical symbols
  
  numSymbolsInTable = 0;
  
  vector<uint16_t> canonicalCodesTable = huff_generate_canonical_codes(canonicalHeader);
  
  for ( int symbol = 0; symbol < maxNumSymbols; symbol++ ) {
    int bitWidth = canonicalHeader[symbol];
    if (bitWidth != 0) {
      numSymbolsInTable++;
      
      uint16_t canonicalCode = canonicalCodesTable[symbol];
      canonicalSymbolTable[symbol] = canonicalCode;
      bitWidthTable[symbol] = bitWidth;
      
      printf("canonicalSymbolTable[%3d] = %s (bit width %2d)\n", symbol, get_code_bits_as_string(canonicalCode, 16).c_str(), bitWidth);
    }
  }

  // FIXME: determine the bit offset where each block of original input
  // values actually begins. It is not efficient to store the start bit
  // offset after scanning, but okay for now.
  
  return;
}

// Parse a canonical header of 256 bytes and extract the
// symbol table to local storage in this module.

+ (void) parseCanonicalHeader:(NSData*)canonData
              originalSize:(uint32_t)originalSize
{
  const int maxNumSymbols = 256;
  
  canonicalSymbolTable.resize(maxNumSymbols);
  bitWidthTable.resize(maxNumSymbols);
  canonicalHeader.resize(maxNumSymbols);
  
  originalSymbolBufferSize = originalSize;
  
  // First 4 bytes contains an int indicating the orginal
  // number of input symbols
  
//  originalSymbolBufferSize = 1;
//  uint32_t *sizePtr = (uint32_t *) data.bytes;
//  originalSymbolBufferSize = sizePtr[0];
//  *originalSizePtr = originalSymbolBufferSize;
  
  // Next 256 bytes is the canonical header
  
  //memcpy(canonicalHeader.data(), &sizePtr[1], 256);
  //*encodedBitsPtr = ((uint8_t*)&sizePtr[1]) + 256;
  //*encodedBitsNumBytesPtr = (int)data.length - 256 - sizeof(uint32_t);
  
  memcpy(canonicalHeader.data(), canonData.bytes, 256);
  
  // Decode canonical symbols
  
  numSymbolsInTable = 0;
  
  vector<uint16_t> canonicalCodesTable = huff_generate_canonical_codes(canonicalHeader);
  
  for ( int symbol = 0; symbol < maxNumSymbols; symbol++ ) {
    int bitWidth = canonicalHeader[symbol];
    if (bitWidth != 0) {
      numSymbolsInTable++;
      
      uint16_t canonicalCode = canonicalCodesTable[symbol];
      canonicalSymbolTable[symbol] = canonicalCode;
      bitWidthTable[symbol] = bitWidth;
      
      printf("canonicalSymbolTable[%3d] = %s (bit width %2d)\n", symbol, get_code_bits_as_string(canonicalCode, 16).c_str(), bitWidth);
    }
  }
  
  // FIXME: determine the bit offset where each block of original input
  // values actually begins. It is not efficient to store the start bit
  // offset after scanning, but okay for now.
  
  return;
}

// Generate values for lookup table

+ (void) generateLookupTable:(HuffLookupSymbol*)lookupTablePtr
             lookupTableSize:(const int)lookupTableSize
{
#if defined(DEBUG)
  {
    HuffLookupSymbol hls;
    lookupTablePtr[0] = hls;
    lookupTablePtr[lookupTableSize-1] = hls;
  }
  
  memset(lookupTablePtr, 0, lookupTableSize * sizeof(HuffLookupSymbol));
#endif // DEBUG
  
  // Loop over each symbol, generate a mask portion of the
  // table and then fill in a lookup value for each possible
  // code to the right of the left justified mask.
  
  const int maxNumSymbols = 256;
  
  const int debugOut = 0;
  
  for ( int symbol = 0; symbol < maxNumSymbols; symbol++ ) {
    int symbolBitWidth = bitWidthTable[symbol];
    if (symbolBitWidth != 0) {
      uint16_t leftJustifiedBits = canonicalSymbolTable[symbol];
      
      if (debugOut) {
        printf("symbol %3d : num bits %d : %s\n", symbol, symbolBitWidth, get_code_bits_as_string(leftJustifiedBits, 16).c_str());
      }
      
      // Generate every 16 bit value that has the same bit prefix
      
      const uint32_t mask = ~(0xFFFF >> symbolBitWidth) & 0xFFFF;
      if (debugOut) {
        printf("LJ mask %s\n", get_code_bits_as_string(mask, 16).c_str());
      }
      
      // Determine the largest unsigned int that can be represented
      // by this number of bits that are off in the mask.
      
      const uint32_t maxUnsignedForNumBits = (0xFFFF >> symbolBitWidth);
      
      // entry is loop invariant
      
      HuffLookupSymbol entry;
      entry.symbol = symbol;
      entry.bitWidth = symbolBitWidth;
      
      for ( unsigned int genBits = 0; genBits <= maxUnsignedForNumBits; genBits++ ) {
#if defined(DEBUG)
        assert((leftJustifiedBits & genBits) == 0);
#endif // DEBUG
        unsigned int combined = leftJustifiedBits | genBits;
        
        //printf("combo   %s\n", get_code_bits_as_string(combined, 16).c_str());
        
#if defined(DEBUG)
        assert(combined >= 0);
        assert(combined <= lookupTableSize);
        HuffLookupSymbol prevEntry = lookupTablePtr[combined];
        
        if (prevEntry.bitWidth != 0) {
          assert(0);
        }
#endif // DEBUG
        
        //printf("store codeLookupTable[%5d] = %s -> (symbol bitWidth) (%d %d)\n", combined, get_code_bits_as_string(combined, 16).c_str(), entry.symbol, entry.bitWidth);
        
        lookupTablePtr[combined] = entry;
      }
    }
  }
   
  // Verify that each and every value in codeLookupTable has an entry that
  // corresponds to a valid symbol.
  
#if defined(DEBUG)
  if ((1)) {
    
    for ( int i = 0; i <= 0xFFFF; i++ ) {
      //printf("check bit pattern %s\n", get_code_bits_as_string(i, 16).c_str());
      HuffLookupSymbol entry = lookupTablePtr[i];
      assert(entry.bitWidth != 0);
    }
    
  }
#endif // DEBUG
  
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
  uint16_t inputBitPattern = 0;
  int numBitsRead = 0;
  
  const int debugOut = 0;
  const int debugOutShowEmittedSymbols = 0;
  
  int symbolsLeftToDecode = numSymbolsToDecode;
  int symboli = 0;
  int bufferBitOffset = 0;
  
  int outOffseti = 0;
  
  for ( ; symbolsLeftToDecode > 0; symbolsLeftToDecode--, symboli++ ) {
    // Gather a 16 bit pattern by reading 2 or 3 bytes.
    
    if (debugOut) {
      printf("decode symbol number %5d : numBitsRead %d\n", symboli, numBitsRead);
    }
    
    const unsigned int numBytesRead = (numBitsRead / 8);
    const unsigned int numBitsReadMod8 = (numBitsRead % 8);
    
    // Read 3 bytes where a partial number of bits
    // is used from the first byte, then all the
    // bits in the second pattern are used, followed
    // by a partial number of bits from the 3rd byte.
#if defined(DEBUG)
    assert((numBytesRead+2) < huffBuffN);
#endif // DEBUG
    
    unsigned int b0 = huffBuff[numBytesRead];
    unsigned int b1 = huffBuff[numBytesRead+1];
    unsigned int b2 = huffBuff[numBytesRead+2];
    
    if (debugOut) {
      printf("read byte %5d : pattern %s\n", numBytesRead, get_code_bits_as_string(b0, 16).c_str());
      printf("read byte %5d : pattern %s\n", numBytesRead+1, get_code_bits_as_string(b1, 16).c_str());
      printf("read byte %5d : pattern %s\n", numBytesRead+2, get_code_bits_as_string(b2, 16).c_str());
    }
    
    // Prepare the input bytes using shifts so that the results always
    // fit into 16 bit intermediate registers.
    
    // Left shift the already consumed bits off left side of b0
    b0 <<= numBitsReadMod8;
    b0 &= 0xFF;
    
    if (debugOut) {
      printf("b0 %s\n", get_code_bits_as_string(b0, 16).c_str());
    }

    b0 = b0 << 8;
    
    if (debugOut) {
      printf("b0 %s\n", get_code_bits_as_string(b0, 16).c_str());
    }
    
    inputBitPattern = b0;
    
    if (debugOut) {
      printf("inputBitPattern (b0) %s : binary length %d\n", get_code_bits_as_string(inputBitPattern, 16).c_str(), 16);
    }
    
    // Left shift the 8 bits in b1 then OR into inputBitPattern
    
    if (debugOut) {
      printf("b1 %s\n", get_code_bits_as_string(b1, 16).c_str());
    }
    
    b1 <<= numBitsReadMod8;
    
    if (debugOut) {
      printf("b1 %s\n", get_code_bits_as_string(b1, 16).c_str());
    }
    
#if defined(DEBUG)
    assert((inputBitPattern & b1) == 0);
#endif // DEBUG
    
    inputBitPattern |= b1;
    
    if (debugOut) {
      printf("inputBitPattern (b1) %s : binary length %d\n", get_code_bits_as_string(inputBitPattern, 16).c_str(), 16);
    }
    
    if (debugOut) {
      printf("b2 %s\n", get_code_bits_as_string(b2, 16).c_str());
    }
    
    // Right shift b2 to throw out unused bits
    b2 >>= (8 - numBitsReadMod8);
    
    if (debugOut) {
      printf("b2 %s\n", get_code_bits_as_string(b2, 16).c_str());
    }
    
#if defined(DEBUG)
    assert((inputBitPattern & b2) == 0);
#endif // DEBUG
    
    inputBitPattern |= b2;
    
    if (debugOut) {
      printf("inputBitPattern (b2) %s : binary length %d\n", get_code_bits_as_string(inputBitPattern, 16).c_str(), 16);
    }
    
    if (debugOut) {
      printf("input bit pattern %s : binary length %d\n", get_code_bits_as_string(inputBitPattern, 16).c_str(), 16);
    }
    
    // Lookup shortest matching bit pattern
    HuffLookupSymbol hls = huffSymbolTable[inputBitPattern];
#if defined(DEBUG)
    assert(hls.bitWidth != 0);
#endif // DEBUG
    
    numBitsRead += hls.bitWidth;
    
    if (debugOut) {
      printf("consume symbol bits %d\n", hls.bitWidth);
    }
    
    char symbol = hls.symbol;
    
    outBuffer[outOffseti++] = symbol;
    
    if (debugOut) {
      printf("write symbol %d\n", symbol & 0xFF);
    }
    
    if (debugOutShowEmittedSymbols) {
      printf("out[%5d] = %3d (aka 0x%02X) : bits %2d : total num bits %5d\n", outOffseti-1, symbol&0xFF, symbol, hls.bitWidth, numBitsRead-hls.bitWidth);
    }
    
    if (bitOffsetTable != NULL) {
      bitOffsetTable[symboli] = bufferBitOffset;
      bufferBitOffset += hls.bitWidth;
    }
  }
  
  return;
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
  HuffmanEncoder enc;
  
  vector<uint8_t> bytes;
  bytes.reserve(inNumBytes);
  
  for (int i = 0; i < inNumBytes; i++) {
    int c = inBytes[i];
    bytes.push_back(c);
  }
  
  vector<uint8_t> headerBytes;
  vector<uint8_t> canonicalTableBytes;
  vector<uint8_t> huffmanCodeBytes;
  
  bool worked = enc.encode(bytes,
                           headerBytes,
                           canonicalTableBytes,
                           huffmanCodeBytes);
  assert(worked);
  
  // Copy canon table of 256 bytes back to caller
  
  assert(canonicalTableBytes.size() == 256);
  
  [outCanonHeader setLength:256];
  memcpy((void*)outCanonHeader.bytes, (void*)canonicalTableBytes.data(), 256);
  
  // Copy generated huffman codes back to caller
  
  [outHuffCodes setLength:huffmanCodeBytes.size()];
  uint8_t *outHuffCodesPtr = (uint8_t *) outHuffCodes.mutableBytes;

  uint8_t *codesPtr = (uint8_t *) huffmanCodeBytes.data();
  int codesN = (int) huffmanCodeBytes.size();
  
  for ( int i = 0 ; i < codesN; i++) {
    uint8_t code = codesPtr[i];
    outHuffCodesPtr[i] = code;
  }
  
  // Process the input data in terms of NxN blocks, so that a given width x height
  // combination is split into blocks. Then determine the positions of each block
  // starting point and pass these indexes into the encode module so that the bit
  // offset at each position can be determined.
  
  vector<uint32_t> bufferOffsetsToQuery;
  
  int numBlocks = (int)bytes.size() / (blockDim * blockDim);
  
  for ( int i = 0; i < numBlocks; i += 1) {
    int offset = i * (blockDim * blockDim);
    bufferOffsetsToQuery.push_back(offset);
  }
  
  vector<uint32_t> blockBitOffsetBytes = enc.lookupBufferBitOffsets(bufferOffsetsToQuery);
  
  [outBlockBitOffsets setLength:bufferOffsetsToQuery.size()*sizeof(uint32_t)];
  
  uint32_t *outBlockBitOffsetsPtr = (uint32_t *) outBlockBitOffsets.bytes;
  int outBlockBitOffsetsi = 0;
  
  for ( uint32_t offset : blockBitOffsetBytes ) {
    outBlockBitOffsetsPtr[outBlockBitOffsetsi++] = offset;
  }
  
  return;
}

@end

