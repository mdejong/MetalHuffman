// Objective C interface to huffman parsing functions
//  MIT Licensed

#ifndef HuffLookupSymbol_hpp
#define HuffLookupSymbol_hpp

typedef struct {
  uint8_t symbol;
  uint8_t bitWidth;
} HuffLookupSymbol;

#define DecodeHuffmanBitsFromTablesCompareToOriginal

#endif // HuffLookupSymbol_hpp
