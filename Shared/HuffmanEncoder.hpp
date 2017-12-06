//
//  HuffmanEncoder.hpp
//
//  Created by Mo DeJong on 11/19/17.
//  MIT Licensed
//
// Huffman encoder for input symbols limited to the valid byte range
// of (0, 255) inclusive. This leads to huffman table codes that are
// a maximum of 16 bits wide which can be processed efficiently.

#ifndef HuffmanEncoder_hpp
#define HuffmanEncoder_hpp

#include <string>
#include <vector>
#include <unordered_map>

using namespace std;

typedef struct {
  int index;
  unsigned int weight;
} HuffmanEncoderNode;

class HuffmanEncoder
{
private:
  int numSymbols;
  int numActiveSymbols;

  int originalInputSizeInBytes;
  
  vector<int> frequency;
  int *leaf_index;
  vector<int> parent_index;
  
  vector<HuffmanEncoderNode> nodes;
  
  vector<int> stack;
  int stack_top;
  int free_index = 1;
  int num_nodes;

  vector<uint16_t> nonCanonicalSymbolTable;
  vector<uint16_t> canonicalSymbolTable;
  vector<uint8_t> bitWidthTable;
  vector<uint8_t> canonicalHeader;
  
  int blockCounter;
  uint8_t bitBuffer;
  int bitBufferN;
  
  // Counter for the total number of bits output
  // while encoding.
  int huffmanCodeBitOffset;

  int numSymbolsEncoded;
  
  // Record the bit location in the emitted huffman symbol
  // stream where a given symbol starts.
  vector<uint32_t> bitOffsetForSymbols;
  
  void determine_frequency(const vector<uint8_t> & bytes);
  
  void allocate_tree();

  void add_leaves();
  
  int add_node(int index, int weight);
  
  void build_tree();
  
  uint16_t encode_one_symbol(int symbol, int & bitWidth);
  
  void create_canonical_codes_from_tree();
  
  void encode_alphabet(int character,
                       vector<uint8_t> & huffmanCodeBytes);
  
  void flush_buffered_bits(vector<uint8_t> & huffmanCodeBytes);
  
public:
  
  HuffmanEncoder();
  
  // Entry point for original byte to huffman encoding. The
  // header is always a fixed 256 byte canonical table.
  
  bool encode(const vector<uint8_t> & bytes,
              vector<uint8_t> & headerBytes,
              vector<uint8_t> & canonicalTableBytes,
              vector<uint8_t> & huffmanCodeBytes);
  
  vector<uint32_t> lookupBufferBitOffsets(const vector<uint32_t> & offsets);
  
};

#endif /* HuffmanEncoder_hpp */
