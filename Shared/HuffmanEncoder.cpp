//
//  HuffmanEncoder.cpp
//
//  Created by Mo DeJong on 11/19/17.
//  MIT Licensed

#include "HuffmanEncoder.hpp"

#include "huff_util.hpp"

const static int MAX_NUM_SYMBOLS = 256;

HuffmanEncoder::HuffmanEncoder() {
  numSymbols = 0;
  numActiveSymbols = 0;
  originalInputSizeInBytes = 0;
  
  frequency.resize(2 * MAX_NUM_SYMBOLS);
  memset(frequency.data(), 0, frequency.size() * sizeof(int));

  leaf_index = ((int*)frequency.data()) + MAX_NUM_SYMBOLS - 1;
  
  stack_top = -1;  
  free_index = 1;  
  num_nodes = 0;
}

void
HuffmanEncoder::determine_frequency(const vector<uint8_t> & bytes) {
  for (uint8_t b : bytes) {
    frequency[b] += 1;
  }
  originalInputSizeInBytes += (int) bytes.size();
  
  for (int c = 0; c < MAX_NUM_SYMBOLS; c++) {
    if (frequency[c] > 0) {
      numActiveSymbols += 1;
//#if defined(DEBUG)
      if ((1)) {
      printf("frequency[%3d] = %8d\n", c, frequency[c]);
      }
//#endif // DEBUG
    }
  }
  
//#if defined(DEBUG)
  if ((1)) {
      printf("numActiveSymbols = %d\n", numActiveSymbols);
  }
//#endif // DEBUG
}

void
HuffmanEncoder::allocate_tree() {
  nodes.resize(2 * numActiveSymbols);
  parent_index.resize(numActiveSymbols);
}

void
HuffmanEncoder::add_leaves() {
  for (int i = 0; i < MAX_NUM_SYMBOLS; i++) {
    int freq = frequency[i];
    if (freq > 0) {
      add_node(-(i + 1), freq);
    }
  }
}

void
HuffmanEncoder::build_tree() {
  int a, b, index;
  while (free_index < num_nodes) {
    a = free_index++;
    b = free_index++;
    index = add_node(b/2,
                     nodes[a].weight + nodes[b].weight);
    parent_index[b/2] = index;
  }
}

int
HuffmanEncoder::add_node(int index, int weight) {
  int i = num_nodes++;
  while (i > 0 && nodes[i].weight > weight) {
    memcpy(&nodes[i + 1], &nodes[i], sizeof(HuffmanEncoderNode));
    if (nodes[i].index < 0)
      ++leaf_index[-nodes[i].index];
    else
      ++parent_index[nodes[i].index];
    --i;
  }
  
  ++i;
  nodes[i].index = index;
  nodes[i].weight = weight;
  if (index < 0)
    leaf_index[-index] = i;
  else
    parent_index[index] = i;
  
  return i;
}

// Encode a symbol as a 16 bit huffman code

uint16_t
HuffmanEncoder::encode_one_symbol(int symbol, int & bitWidth)
{
  const int dumpSymbolEncoding = 0;
  
  int node_index;
  stack_top = 0;
  node_index = leaf_index[symbol + 1];
  while (node_index < num_nodes) {
    stack[stack_top++] = node_index % 2;
    node_index = parent_index[(node_index + 1) / 2];
  }
  if (num_nodes == 1) {
    stack[0] = 0; // emit single bit "0" as the huffman code
    stack_top = 1;
  }
  if (dumpSymbolEncoding) {
    printf("encoding char %3d as huffman:\n", symbol);
  }
  uint16_t code = 0;
  int codei = 0;
  bitWidth = 0;
  while (--stack_top > -1) {
    int bitVal = stack[stack_top];
    if (bitVal) {
      assert(codei < 16);
      code |= ((bitVal << 15) >> codei);
    }
    if (dumpSymbolEncoding) {
      printf("%d", bitVal);
    }
    codei += 1;
    bitWidth++;
  }
  if (dumpSymbolEncoding) {
    printf("\n");
  }
  
  return code;
}

// Given an existing tree structure stored as an array of
// nodes, construct canonical codes from the minimal data
// about bit widths.

void
HuffmanEncoder::create_canonical_codes_from_tree()
{
  nonCanonicalSymbolTable.resize(MAX_NUM_SYMBOLS);
  canonicalSymbolTable.resize(MAX_NUM_SYMBOLS);
  bitWidthTable.resize(MAX_NUM_SYMBOLS);
  
  if (num_nodes == 1) {
    // Special case when just 1 node, encode a single symbol as 1
    stack.resize(1);
  }
  
  for ( int symbol = 0; symbol < MAX_NUM_SYMBOLS; symbol++ ) {
    if (frequency[symbol] > 0) {
      int bitWidth;
      uint16_t huffCode = encode_one_symbol(symbol, bitWidth);
      nonCanonicalSymbolTable[symbol] = huffCode;
#if defined(DEBUG)
      assert(bitWidth <= 16);
#endif // DEBUG
      bitWidthTable[symbol] = bitWidth;
    }
  }
  
  // From the non-canonical codes, generate canonical codes
  
  vector<int> canonicalBitWidths;
  canonicalBitWidths.resize(MAX_NUM_SYMBOLS);
  
  for ( int symbol = 0; symbol < MAX_NUM_SYMBOLS; symbol++ ) {
    if (frequency[symbol] > 0) {
      int bitWidth = bitWidthTable[symbol];
      canonicalBitWidths[symbol] = bitWidth;
    }
  }
  
  canonicalHeader = huff_generate_canonical_table(canonicalBitWidths);
  
  vector<uint16_t> canonicalCodesTable = huff_generate_canonical_codes(canonicalHeader);
  
  for ( int symbol = 0; symbol < MAX_NUM_SYMBOLS; symbol++ ) {
    int bitWidth = canonicalHeader[symbol];
    if (bitWidth != 0) {
      uint16_t canonicalCode = canonicalCodesTable[symbol];
      canonicalSymbolTable[symbol] = canonicalCode;
      
#if defined(DEBUG)
      printf("canonicalSymbolTable[%3d] = %s (bit width %2d)\n", symbol, get_code_bits_as_string(canonicalCode, 16).c_str(), bitWidth);
#endif // DEBUG
    }
  }
  
  
  return;
}

// Encode an input byte to huffman bits

//#define PRINT_ENCODED_BITS

void
HuffmanEncoder::encode_alphabet(int character,
                                vector<uint8_t> & huffmanCodeBytes) {
  int symbol = character;
#if defined(DEBUG)
  assert(symbol >= 0 && symbol < canonicalSymbolTable.size());
  assert(symbol >= 0 && symbol < bitWidthTable.size());
#endif // DEBUG
  uint16_t code = canonicalSymbolTable[symbol];
  int bitWidth = bitWidthTable[symbol];
#if defined(DEBUG)
  assert(bitWidth > 0);
#endif // DEBUG

#if defined(PRINT_ENCODED_BITS)
  printf("encoding char %3d '%3d' as canonical huffman with bit width %3d:\n", symbol, symbol, bitWidth);
#endif //PRINT_ENCODED_BITS
  
  bitOffsetForSymbols[numSymbolsEncoded] = huffmanCodeBitOffset;
  numSymbolsEncoded += 1;
  
  for ( int bi = 0; bi < bitWidth; bi++ ) {
    int shiftR = 15 - bi;
    int bit = (code >> shiftR) & 0x1;
    
#if defined(DEBUG)
    assert(bitWidth <= 16);
    assert(bitBufferN >= 0 && bitBufferN <= (8-1));
#endif // DEBUG
    
    bitBuffer |= (bit << ((8-1) - bitBufferN));
    
    if ((0)) {
      printf("\n");
      printf("tmp LJ bits %s\n", get_code_bits_as_string(bitBuffer, 8).c_str());
    }
    
    bitBufferN += 1;
    huffmanCodeBitOffset += 1;
    
#if defined(PRINT_ENCODED_BITS)
    printf("%d", bit);
#endif //PRINT_ENCODED_BITS
    
    if (bitBufferN == 8) {
      if ((0)) {
        printf("\n");
        printf("emit LJ bits %s\n", get_code_bits_as_string(bitBuffer, 8).c_str());
      }
      
      huffmanCodeBytes.push_back(bitBuffer);
      
      bitBuffer = 0;
      bitBufferN = 0;
    }
  }
  
#if defined(PRINT_ENCODED_BITS)
  printf("\n");
  fflush(stdout);
#endif //PRINT_ENCODED_BITS
  
// FIXME: account for block dim
  
  return;
}

void
HuffmanEncoder::flush_buffered_bits(vector<uint8_t> & huffmanCodeBytes)
{
  unsigned int b;
  
#if defined(DEBUG)
  assert(bitBufferN <= 8);
#endif // DEBUG
  
  if (bitBufferN > 0) {
    //b = (bitBuffer >> 24) & 0xFF;
    
#if defined(DEBUG)
    assert((bitBuffer & 0xFF) == bitBuffer);
#endif // DEBUG
    
    b = bitBuffer & 0xFF;
    huffmanCodeBytes.push_back(b);
    
#if defined(PRINT_ENCODED_BITS)
    printf("flush buffer byte 0x%2X\n", b);
#endif //PRINT_ENCODED_BITS
    
//    bitBufferN -= 8;
//    bitBuffer <<= 8;
  }
  
  return;
}

// Encode a buffer of bytes as huffman symbols

bool
HuffmanEncoder::encode(const vector<uint8_t> & bytes,
                       vector<uint8_t> & headerBytes,
                       vector<uint8_t> & canonicalTableBytes,
                       vector<uint8_t> & huffmanCodeBytes)
{
  determine_frequency(bytes);
  stack.resize(numActiveSymbols - 1);
  allocate_tree();
  
  add_leaves();
  build_tree();
  create_canonical_codes_from_tree();
  
  // Write known bit pattern and original number of bytes as header

  headerBytes.resize(sizeof(uint32_t) * 2);
  
  uint32_t bitPattern = 0xFFEEEEDD;

  headerBytes[0] = (bitPattern >> 0) & 0xFF;
  headerBytes[1] = (bitPattern >> 8) & 0xFF;
  headerBytes[2] = (bitPattern >> 16) & 0xFF;
  headerBytes[3] = (bitPattern >> 24) & 0xFF;
  
  uint32_t numBytes = originalInputSizeInBytes;
  
  headerBytes[4] = (numBytes >> 0) & 0xFF;
  headerBytes[5] = (numBytes >> 8) & 0xFF;
  headerBytes[6] = (numBytes >> 16) & 0xFF;
  headerBytes[7] = (numBytes >> 24) & 0xFF;
  
  // Write canonical bits widths as header
  
  canonicalTableBytes.clear();
  canonicalTableBytes.reserve(MAX_NUM_SYMBOLS);
  
  for ( uint8_t b : canonicalHeader ) {
    canonicalTableBytes.push_back(b);
  }
  
  // Write to huffmanCodeBytes
  
  huffmanCodeBytes.clear();
  huffmanCodeBytes.reserve(bytes.size());
  
  bitOffsetForSymbols.resize(originalInputSizeInBytes);
  
  blockCounter = 0;
  bitBuffer = 0;
  bitBufferN = 0;
  huffmanCodeBitOffset = 0;
  numSymbolsEncoded = 0;
  
  for ( uint8_t b : bytes ) {
    //fprintf(stderr, "in byte %02X : '%c'\n", b, b);
    encode_alphabet(b, huffmanCodeBytes);
  }
  
  flush_buffered_bits(huffmanCodeBytes);
  
  // The huffman buffer is now flushed to a byte bound,
  // but because the decoder may need to read as many as
  // 2 bytes ahead, append 2 more zero bytes so that the
  // encoded buffer need not be resize at decode time to
  // support the additional 2 bytes.
  
  huffmanCodeBytes.push_back(0);
  huffmanCodeBytes.push_back(0);
  
  return true;
}

vector<uint32_t>
HuffmanEncoder::lookupBufferBitOffsets(const vector<uint32_t> & offsets)
{
  vector<uint32_t> bitOffsets;
  bitOffsets.reserve(offsets.size());
  
  for ( uint32_t offset : offsets ) {
    uint32_t bitOffset = bitOffsetForSymbols[offset];
    bitOffsets.push_back(bitOffset);
  }
  
  return bitOffsets;
}

