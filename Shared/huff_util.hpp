// huff_util.hpp
//
// Huffman encoding and decoding utility functions as inline functions

//#include <stdio.h>
//#include <stdlib.h>
//#include <string.h>
#include <assert.h>

#include <string>
#include <vector>
#include <unordered_map>
#include <cstdint>

using namespace std;

static inline
string get_code_bits_as_string(uint32_t code, const int width)
{
  string bitsStr;
  int c4 = 1;
  for ( int i = 0; i < width; i++ ) {
    bool isOn = ((code & (0x1 << i)) != 0);
    if (isOn) {
      bitsStr = "1" + bitsStr;
    } else {
      bitsStr = "0" + bitsStr;
    }
    
    if ((c4 == 4) && (i != (width - 1))) {
      bitsStr = "-" + bitsStr;
      c4 = 1;
    } else {
      c4++;
    }
  }
  return bitsStr;
}

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

/*
 huffmanCodes[ 97] = 0000-0000-0000-0000 : bit width 1
 huffmanCodes[ 98] = 0000-0000-0000-0100 : bit width 3
 huffmanCodes[100] = 0000-0000-0000-0101 : bit width 3
 huffmanCodes[114] = 0000-0000-0000-0110 : bit width 3
 huffmanCodes[ 10] = 0000-0000-0000-1110 : bit width 4
 huffmanCodes[ 99] = 0000-0000-0000-1111 : bit width 4
 
 canonicalCodesTable[ 10] = 0000-0000-0000-1110 (bit width  4)
 canonicalCodesTable[ 97] = 0000-0000-0000-0000 (bit width  1)
 canonicalCodesTable[ 98] = 0000-0000-0000-0100 (bit width  3)
 canonicalCodesTable[ 99] = 0000-0000-0000-1111 (bit width  4)
 canonicalCodesTable[100] = 0000-0000-0000-0101 (bit width  3)
 canonicalCodesTable[114] = 0000-0000-0000-0110 (bit width  3)
*/

static inline
vector<uint16_t>
huff_generate_canonical_codes(
                              const vector<uint8_t> & inTable
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
