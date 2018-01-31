// C++ impl of huffman utility functions
//  MIT Licensed

#include "HuffmanUtil.hpp"

#include <string>
#include <vector>
#include <unordered_map>
#include <cstdint>

#include "HuffmanEncoder.hpp"
#include "huff_util.hpp"

#include <assert.h>

using namespace std;


// Generate signed delta, note that this method supports repeated value that delta to zero

template <typename T>
vector<T>
encodeDelta(const vector<T> & orderVec)
{
  T prev;
  vector<T> deltas;
  deltas.reserve(orderVec.size());
  
  // The first value is always a delta from zero, so handle it before
  // the loop logic.
  
  {
    T val = orderVec[0];
    deltas.push_back(val);
    prev = val;
  }
  
  int maxi = (int) orderVec.size();
  for (int i = 1; i < maxi; i++) {
    T val = orderVec[i];
    T delta = val - prev;
    deltas.push_back(delta);
    prev = val;
  }
  
  return std::move(deltas);
}

template <typename T>
vector<T>
decodePlusDelta(const vector<T> &deltas, const bool minusOne = false)
{
  T prev;
  vector<T> values;
  values.reserve(deltas.size());
  
  // The first value is always a delta from zero, so handle it before
  // the loop logic.
  
  {
    T val = deltas[0];
    values.push_back(val);
    prev = val;
  }
  
  int maxi = (int) deltas.size();
  for (int i = 1; i < maxi; i++) {
    T delta = deltas[i];
    if (minusOne) {
      delta += 1;
    }
    T val = prev + delta;
    values.push_back(val);
    prev = val;
  }
  
  return std::move(values);
}

template <typename T>
vector<T>
decodeDelta(const vector<T> &deltas)
{
  return decodePlusDelta(deltas, false);
}

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

// This method accepts a range of symbol
// values (symbolStart, symbolEnd) and
// a range of array values to map the
// symbols into. Every possible variation
// of the huffman pattern for the symbol
// is created in the lookup table so that
// an O(1) lookup can determine the symbol
// given its huffman code. Note that
// (rangeStart, rangeEnd) is inclusive so
// that for (0, 0xFFFF) the largest value
// is at lookupTablePtr[65535]

static inline
void
generateLookupTableRange(HuffLookupSymbol * lookupTablePtr,
                         const int lookupTableNumEntries,
                         const vector<uint8_t> & symbols,
                         const int rangeStart,
                         const int rangeEnd,
                         const int ljustRightShift,
                         const int ljustMask,
                         const bool canContainEmptyEntries)
{
  const int debugOut = 0;
  const int debugOutEveryStoredCode = 0;

  if (debugOut) {
    printf("generateLookupTableRange for %d symbols : range (%5d %5d)\n", (int)symbols.size(), rangeStart, rangeEnd);
  }
  
#if defined(DEBUG)
  {
    HuffLookupSymbol hls;
    memset(&hls, 0, sizeof(HuffLookupSymbol));
    lookupTablePtr[0] = hls;
    lookupTablePtr[lookupTableNumEntries-1] = hls;
  }
  
  memset(lookupTablePtr, 0, lookupTableNumEntries * sizeof(HuffLookupSymbol));
#endif // DEBUG
  
  // Loop over each symbol, generate a mask portion of the
  // table and then fill in a lookup value for each possible
  // code to the right of the left justified mask.
    
  for ( uint8_t symbol : symbols ) {
    int symbolBitWidth = bitWidthTable[symbol];
    
#if defined(DEBUG)
    assert(symbolBitWidth != 0);
#endif // DEBUG
    
    {
      uint16_t leftJustifiedBits = canonicalSymbolTable[symbol];
      
      if (debugOut) {
        printf("symbol %3d : num bits %d : %s\n", symbol, symbolBitWidth, get_code_bits_as_string(leftJustifiedBits, 16).c_str());
      }
      
      leftJustifiedBits >>= ljustRightShift;
      leftJustifiedBits &= ljustMask;
      
      if (debugOut) {
        printf("symbol rshift %2d : mask %s\n", ljustRightShift, get_code_bits_as_string(ljustMask, 16).c_str());
      }
      
      if (debugOut) {
        printf("symbol %3d : num bits %d : %s\n", symbol, symbolBitWidth, get_code_bits_as_string(leftJustifiedBits, 16).c_str());
      }
      
      // Generate every 16 bit value that has the same bit prefix
      
      const uint32_t mask = ~(0xFFFF >> (ljustRightShift + symbolBitWidth)) & 0xFFFF;
      if (debugOut) {
        printf("LJ mask %s\n", get_code_bits_as_string(mask, 16).c_str());
      }
      
      // Determine the largest unsigned int that can be represented
      // by this number of bits that are off in the mask.
      
      const uint32_t maxUnsignedForNumBits = (0xFFFF >> (ljustRightShift + symbolBitWidth));
      
      if (debugOut) {
        printf("max int %s (aka %d)\n", get_code_bits_as_string(maxUnsignedForNumBits, 16).c_str(), maxUnsignedForNumBits);
      }
      
      // entry is loop invariant
      
      HuffLookupSymbol entry;
      entry.symbol = symbol;
      entry.bitWidth = symbolBitWidth;
      
      for ( unsigned int genBits = 0; genBits <= maxUnsignedForNumBits; genBits++ ) {
#if defined(DEBUG)
        assert((leftJustifiedBits & genBits) == 0);
#endif // DEBUG
        unsigned int combined = leftJustifiedBits | genBits;
        
        if (debugOutEveryStoredCode) {
          printf("combo   %s\n", get_code_bits_as_string(combined, 16).c_str());
        }

        unsigned int combinedOffset = rangeStart + combined;
        
#if defined(DEBUG)
        assert(combinedOffset >= rangeStart);
        assert(combinedOffset <= rangeEnd);
        
        assert(combinedOffset >= 0);
        assert(combinedOffset <= lookupTableNumEntries);
        
        HuffLookupSymbol prevEntry = lookupTablePtr[combinedOffset];
        
        if (prevEntry.bitWidth != 0) {
          assert(0);
        }
#endif // DEBUG
        
        if (debugOutEveryStoredCode) {
          printf("store codeLookupTable[%5d] = %s -> (symbol bitWidth) (%d %d)\n", combinedOffset, get_code_bits_as_string(combined, 16).c_str(), entry.symbol, entry.bitWidth);
        }

        lookupTablePtr[combinedOffset] = entry;
      }
    }
  }
  
  // Verify that each and every value in codeLookupTable has an entry that
  // corresponds to a valid symbol.
  
#if defined(DEBUG)
  if ((1)) {
    const int debugOutEveryCheck = 0;
    
    for ( int i = rangeStart; i <= rangeEnd; i++ ) {
      if (debugOutEveryCheck) {
        printf("check bit pattern %s\n", get_code_bits_as_string(i, 16).c_str());
      }
      HuffLookupSymbol entry = lookupTablePtr[i];
      
      if (debugOutEveryCheck) {
        printf("codeLookupTable[%5d] = %s -> (symbol bitWidth) (%d %d)\n", i, get_code_bits_as_string(i, 16).c_str(), entry.symbol, entry.bitWidth);
      }

      if (canContainEmptyEntries) {
        // Empty entries are allowed, both bitWidth and symbol are zero at this point
        
        if (entry.bitWidth == 0) {
          // Empty entry
          ;
        }
      } else {
        assert(entry.bitWidth > 0);
        assert(entry.bitWidth <= 16);
        assert(entry.symbol >= 0 && entry.symbol <= 255);
      }
    }
  }
#endif // DEBUG
  
  return;
}

// Parse a canonical header of 256 bytes and extract the
// symbol table to local storage in this module.

void
HuffmanUtil::parseCanonicalHeader(uint8_t *canonData)
{
  const int maxNumSymbols = 256;
  
  if (canonicalSymbolTable.size() != maxNumSymbols) {
    canonicalSymbolTable.resize(maxNumSymbols);
    bitWidthTable.resize(maxNumSymbols);
    canonicalHeader.resize(maxNumSymbols);
  }

  memcpy(canonicalHeader.data(), canonData, maxNumSymbols * sizeof(uint8_t));
  memset(bitWidthTable.data(), 0, maxNumSymbols * sizeof(uint8_t));
  
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
      
      if ((1)) {
      printf("canonicalSymbolTable[%3d] = %s (bit width %2d)\n", symbol, get_code_bits_as_string(canonicalCode, 16).c_str(), bitWidth);
      }
    }
  }
  
  // FIXME: determine the bit offset where each block of original input
  // values actually begins. It is not efficient to store the start bit
  // offset after scanning, but okay for now.
  
  return;
}

// Generate values for lookup table

void
HuffmanUtil::generateLookupTable(HuffLookupSymbol *lookupTablePtr,
                                 const int lookupTableNumEntries)
{
  vector<uint8_t> symbols;
  symbols.reserve(256);
  
  for ( int symbol = 0; symbol < 256; symbol++) {
    int symbolBitWidth = bitWidthTable[symbol];
    
    if (symbolBitWidth > 0) {
      symbols.push_back(symbol);
    }
  }
  
  generateLookupTableRange(lookupTablePtr, lookupTableNumEntries,
                           symbols,
                           0, 0xFFFF, 0, 0xFFFF, false);
  
  return;
}

// Generate a low/high pair of lookup tables

void
HuffmanUtil::generateSplitLookupTables(
                                       const int table1NumBits,
                                       const int table2NumBits,
                                       vector<HuffLookupSymbol> & table1,
                                       vector<HuffLookupSymbol> & table2)
{
#if defined(DEBUG)
  assert((table1NumBits + table2NumBits) == 16);
#endif
  
  const int numEntriesInTable1 = HUFF_TABLE1_SIZE;
  const int numEntriesInTable2 = HUFF_TABLE2_SIZE;
  
  if (table1.size() != numEntriesInTable1) {
    table1.resize(numEntriesInTable1);
    memset(table1.data(), 0, numEntriesInTable1 * sizeof(HuffLookupSymbol));
  } else {
    // Not resized, zero out memory though
    memset(table1.data(), 0, numEntriesInTable1 * sizeof(HuffLookupSymbol));
  }

  HuffLookupSymbol *table1Ptr = table1.data();
  HuffLookupSymbol *table2Ptr = nullptr;
  
  // Loop over each symbol and generate a 16 bit wide symbol
  // value. If the symbol fits entirely into table1 then
  // mark it as such, otherwise it must go in table 2.
  
  const int maxNumSymbols = 256;
  const int debugOut = 0;
  
  typedef struct {
    uint16_t low;
    HuffLookupSymbol symbol;
  } DupLowTablesEntry;
  
  unordered_map<uint16_t, vector<DupLowTablesEntry>> dupLowTables;
  
  vector<uint8_t> table1Symbols;
  table1Symbols.reserve(numEntriesInTable1);
  
  vector<uint8_t> table2Symbols;
  table2Symbols.reserve(numEntriesInTable2);
  
  for ( unsigned int symbol = 0; symbol < maxNumSymbols; symbol++ ) {
    int symbolBitWidth = bitWidthTable[symbol];
    if (symbolBitWidth != 0) {
      if (debugOut) {
        printf("for symbol %3d, bit width is %d\n", symbol, symbolBitWidth);
      }
      
      if (symbolBitWidth <= table1NumBits) {
        table1Symbols.push_back(symbol);
        
        if (debugOut) {
          printf("table1\n");
        }
      } else {
        table2Symbols.push_back(symbol);
        
        if (debugOut) {
          printf("table2\n");
        }
      }
    }
  }
  
  // Generate table1 from symbols that fit in table1NumBits
  
  generateLookupTableRange(table1Ptr, numEntriesInTable1,
                           table1Symbols,
                           0, numEntriesInTable1-1,
                           (16 - table1NumBits), 0xFFFF >> (16 - table1NumBits), // rshift and mask
                           true);

#if defined(DEBUG)
  if ((1)) {
    int numUnique = 0;
    
    for ( int i = 0; i < numEntriesInTable1; i++ ) {
      HuffLookupSymbol entry = table1Ptr[i];
      if (entry.bitWidth != 0) {
        if (debugOut) {
          printf("unique     T1 bit pattern %s : %3d : bitWidth %d\n", get_code_bits_as_string(i, table1NumBits).c_str(), entry.symbol, entry.bitWidth);
        }
        numUnique += 1;
      } else {
        if (debugOut) {
          printf("non-unique T1 bit pattern %s : %3d\n", get_code_bits_as_string(i, table1NumBits).c_str(), entry.symbol);
        }
      }
    }
    
    if (debugOut) {
      printf("T1 num unique     %d\n", numUnique);
      printf("T1 num non-unique %d\n", numEntriesInTable1-numUnique);
    }
  }
#endif // DEBUG
  
  // Generate table2 based on non-unique high bit patterns
  
  for ( uint8_t symbol : table2Symbols ) {
    int symbolBitWidth = bitWidthTable[symbol];
    
#if defined(DEBUG)
    assert(symbolBitWidth > 0);
    assert(symbolBitWidth > table1NumBits);
#endif // DEBUG
    
    {
      if (debugOut) {
        printf("for symbol %3d, bit width is %d\n", symbol, symbolBitWidth);
      }
      
      uint16_t leftJustifiedBits = canonicalSymbolTable[symbol];
      
      // Grab high and low portions of the huffman code
      
      uint16_t high = (leftJustifiedBits >> table2NumBits);
      uint16_t low = leftJustifiedBits & (0xFFFF >> table1NumBits);
      
      if (debugOut) {
        printf("LJ  symbol    %s\n", get_code_bits_as_string(leftJustifiedBits, 16).c_str());
        printf("symbol high   %s (%d bits)\n", get_code_bits_as_string(high, table1NumBits).c_str(), table1NumBits);
        printf("symbol low    %s (%d bits)\n", get_code_bits_as_string(low, table2NumBits).c_str(), table2NumBits);
      }
      
      vector<DupLowTablesEntry> & vec = dupLowTables[high];
      
      HuffLookupSymbol lookupSymbol;
      lookupSymbol.symbol = symbol;
      lookupSymbol.bitWidth = symbolBitWidth;
      
      DupLowTablesEntry tableEntry;
      tableEntry.low = low;
      tableEntry.symbol = lookupSymbol;
      
      if (debugOut) {
        if (vec.size() == 0) {
          printf("new table entry for symbol high   %s (%d bits)\n", get_code_bits_as_string(high, table1NumBits).c_str(), table1NumBits);
        } else {
          printf("apd table entry for symbol high   %s (%d bits)\n", get_code_bits_as_string(high, table1NumBits).c_str(), table1NumBits);
        }
      }
      
#if defined(DEBUG)
      if (vec.size() > 0) {
        for ( DupLowTablesEntry te : vec ) {
          if (te.low == low) {
            assert(0);
          }
        }
      }
#endif // DEBUG
      
      vec.push_back(tableEntry);
    }
  }
  
  if (debugOut) {
    // Iterate over each secondary table and print all the values that
    // can correspond to this table.
    
    for ( unsigned int high = 0; high < numEntriesInTable1; high++ ) {
      if (dupLowTables.count(high) == 0) {
        continue;
      }
      
      vector<DupLowTablesEntry> & vec = dupLowTables[high];
      
      if (debugOut) {
        printf("high bit prefix %s : aka %3d : contains %d entries\n", get_code_bits_as_string(high, table1NumBits).c_str(), high, (int)vec.size());
      }
      
      for ( DupLowTablesEntry & tableEntry : vec ) {
        uint16_t low = tableEntry.low;
        HuffLookupSymbol lookupSymbol = tableEntry.symbol;
        
        if (debugOut) {
          printf("symbol %3d : num bits %d : low part %s : aka %d\n", lookupSymbol.symbol, lookupSymbol.bitWidth, get_code_bits_as_string(low, table2NumBits).c_str(), low);
        }
      }
    }
    
    ;
  }

  // Now that the number of table2 table is known, allocate the table of tables
  // of the required size that will be returned
  
  {
    // Note that table2 is a table of tables, each secondary table
    // contains the number of entries required to fit all possible symbols
    
    // FIXME: the number of bytes allocated to table2 only needs to support
    // the number of secondary tables, not all possible tables.

    int numSecondaryTables = (int)dupLowTables.size() + 1;
    int numEntriesInAllTable2 = numEntriesInTable2 * numSecondaryTables;
    
    if (table2.size() != numEntriesInAllTable2) {
      table2.resize(numEntriesInAllTable2);
      memset(table2.data(), 0, numEntriesInAllTable2 * sizeof(HuffLookupSymbol));
    } else {
      // Not resized, no need to zero out memory here since if a cell
      // will be accessed then it should have been written above.
    }
    table2Ptr = table2.data();
  }
  
  // T2[0] must map to (symbol, bitWidth) (0, 0) so that
  // shader can unconditionally read from this slot and add the
  // symbol value and bit width. This wastes one table entry
  // but makes it possible to unconditionally read from the second
  // table and let the read value go unused in the execution path.
  
  int t2SymbolOffset = 1;
  
  // Process each secondary table entry in int order by iterating over
  // each high prefix that exists in dupLowTables. For each secondary table,
  // generate a table that contains a slot for each valid low slot.
  
  for ( unsigned int high = 0; high < numEntriesInTable1; high++ ) {
    if (dupLowTables.count(high) == 0) {
      continue;
    }
    
    vector<DupLowTablesEntry> & vec = dupLowTables[high];
    
    if (debugOut) {
      printf("high bit prefix %s : aka %3d : contains %d entries\n", get_code_bits_as_string(high, table1NumBits).c_str(), high, (int)vec.size());
    }
    
    vector<uint8_t> table2Symbols;
    table2Symbols.reserve(numEntriesInTable2);
    
    for ( DupLowTablesEntry & tableEntry : vec ) {
      uint16_t low = tableEntry.low;
      HuffLookupSymbol lookupSymbol = tableEntry.symbol;
      
      if (debugOut) {
        printf("symbol %3d : num bits %d : low part %s : aka %d\n", lookupSymbol.symbol, lookupSymbol.bitWidth, get_code_bits_as_string(low, table2NumBits).c_str(), low);
      }
      
      table2Symbols.push_back(lookupSymbol.symbol);
    }
    
    // Generate table2 for this high pattern
    
    vector<HuffLookupSymbol> table2ThisSymbol(numEntriesInTable2);
    
    // FIXME: optimize by calling generateLookupTableRange() with table2Ptr directly
    
    // Generate table2 from symbols that fit in table2NumBits
    
    generateLookupTableRange(table2ThisSymbol.data(), numEntriesInTable2,
                             table2Symbols,
                             0, numEntriesInTable2-1,
                             0, numEntriesInTable2-1, // rshift and mask
                             true);
    
    // Copy values from tmp table to table2Ptr
    
    const int rangeStart = (t2SymbolOffset * numEntriesInTable2);
    const int rangeEnd = rangeStart + numEntriesInTable2;
    
#if defined(DEBUG)
    assert(table2ThisSymbol.size() == numEntriesInTable2);
#endif // DEBUG
    
    if (debugOut) {
      printf("copy %5d symbol entries into range (%5d, %5d)\n", (int)table2ThisSymbol.size(), rangeStart, rangeEnd);
    }
    
    for (int i = 0, ti = rangeStart; ti < rangeEnd; ti++, i++) {
      table2Ptr[ti] = table2ThisSymbol[i];
      
      if (debugOut) {
        printf("copy to codeLookupTable[%5d] (symbol bitWidth) (%d %d)\n", ti, table2ThisSymbol[i].symbol, table2ThisSymbol[i].bitWidth);
      }
    }
    
    //HuffLookupSymbol *table2PtrForThisSymbol = table2Ptr + rangeStart;
    //memcpy(table2PtrForThisSymbol, table2ThisSymbol.data(), table2ThisSymbol.size() * sizeof(HuffLookupSymbol));
    
    // Update the symbol value in table1 to correspond to the secondary table offset
    
#if defined(DEBUG)
    assert(high < table1.size());
#endif // DEBUG
    
    HuffLookupSymbol & t1Entry = table1Ptr[high];
    if (t1Entry.bitWidth == 0) {
      // Bit width should be zero since high is not a unique bit prefix
    } else {
      //printf("high part lookup for %d returned non-zero bit width element %d\n", high, (int)t1Entry.bitWidth);
      assert(0);
    }
    
    // The T1[high].symbol value is set to an offset that indicates
    // how many tables should be skipped in T2 to find the starting
    // offset of the specific table for this high prefix. Each
    // secondary table of N bits has to be a constant size so that
    // a second table lookup is not needed.
    
    t1Entry.symbol = t2SymbolOffset;
    t2SymbolOffset += 1;
  }
  
#if defined(DEBUG)
  // Print t1 again since it has been updated with table offsets
  
  for ( int i = 0; i < numEntriesInTable1; i++ ) {
    HuffLookupSymbol entry = table1Ptr[i];
    if (entry.bitWidth != 0) {
      if (debugOut) {
        printf("unique     T1 bit pattern %s : %3d : symbol %3d : bitWidth %d\n", get_code_bits_as_string(i, table1NumBits).c_str(), i, entry.symbol, entry.bitWidth);
      }
    } else {
      if (debugOut) {
        printf("non-unique T1 bit pattern %s : %3d : offset %3d\n", get_code_bits_as_string(i, table1NumBits).c_str(), i, entry.symbol);
      }
    }
  }
#endif // DEBUG
  
  return;
}

// Unoptimized serial decode logic. Note that this logic
// assumes that huffBuff contains +2 bytes at the end
// of the buffer to account for read ahead.

void
HuffmanUtil::decodeHuffmanBits(
                               HuffLookupSymbol *huffSymbolTable,
                               int numSymbolsToDecode,
                               uint8_t *huffBuff,
                               int huffBuffN,
                               uint8_t *outBuffer,
                               uint32_t *bitOffsetTable)
{
  uint16_t inputBitPattern = 0;
  unsigned int numBitsRead = 0;
  
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

// Unoptimized logic that decodes from a pair of tables
// where the first table should contain the vast majority
// of the symbols and the second table is read and used
// only when needed.

void
HuffmanUtil::decodeHuffmanBitsFromTables(
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
)
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
    
    // inputBitPattern now contains a 16 bit huffman code pattern, lookup the table1 portion
    // of the pattern to see if just the 1 table lookup is enough to fully resolve the
    // symbol.
    
    uint16_t table1Pattern = inputBitPattern >> (16 - table1BitNum); // keep the left most 9 bits
    uint16_t table2Pattern = inputBitPattern & (0xFFFF >> (16 - table2BitNum)); // keep the bottom most 7 bits
    
    if (debugOut) {
      printf("table1Pattern input bit pattern %s : binary length %d\n", get_code_bits_as_string(table1Pattern, table1BitNum).c_str(), table1BitNum);
      printf("table2Pattern input bit pattern %s : binary length %d\n", get_code_bits_as_string(table2Pattern, table2BitNum).c_str(), table2BitNum);
    }
    
    HuffLookupSymbol hls = huffSymbolTable1[table1Pattern];
    
    if (hls.bitWidth == 0) {
      
      if (debugOut) {
        printf("input bit pattern %s : binary length %d\n", get_code_bits_as_string(inputBitPattern, 16).c_str(), 16);
        printf("table1Pattern input bit pattern %s : binary length %d\n", get_code_bits_as_string(table1Pattern, table1BitNum).c_str(), table1BitNum);
        printf("table2Pattern input bit pattern %s : binary length %d\n", get_code_bits_as_string(table2Pattern, table2BitNum).c_str(), table2BitNum);
      }

      int offset = ((int)hls.symbol) * (int)HUFF_TABLE2_SIZE;
      int offsetPlusPattern = offset + table2Pattern;

      if (debugOut) {
        printf("hls table offset %d\n", hls.symbol);
        printf("hls table offset * %d = %d\n", (int)pow(2,table2BitNum), offset);
        printf("lookup offset %d\n", offsetPlusPattern);
      }
      
      HuffLookupSymbol hls2 = huffSymbolTable2[offsetPlusPattern];
      
#if defined(DEBUG)
      assert(hls2.bitWidth != 0);
#endif // DEBUG
      
      hls = hls2;
    }
    
    // Lookup shortest matching bit pattern
    //HuffLookupSymbol hls = huffSymbolTable1[inputBitPattern];
#if defined(DEBUG)
    assert(hls.bitWidth != 0);
#endif // DEBUG
    
    numBitsRead += hls.bitWidth;
    
    if (debugOut) {
      printf("consume symbol bits %d\n", hls.bitWidth);
    }
    
    unsigned int symbol = hls.symbol;
    
    outBuffer[outOffseti] = symbol;
    
    if (debugOut) {
      printf("write symbol %d\n", symbol);
    }
    
    if (debugOutShowEmittedSymbols) {
      printf("out[%5d] = %3d (aka 0x%02X) : bits %2d : total num bits %5d\n", outOffseti, symbol, symbol, hls.bitWidth, numBitsRead-hls.bitWidth);
    }
    
#if defined(DecodeHuffmanBitsFromTablesCompareToOriginal)
    // Check output symbol as compared to the original
    if (originalBytes != nullptr)
    {
      uint8_t origCode = originalBytes[outOffseti];
      uint8_t decodedCode = symbol;
      
      if (decodedCode != origCode) {
        printf("%3d != %3d for block huffman offset %d\n", decodedCode, origCode, outOffseti);
        assert(0);
      } else {
        //printf("match %3d for block huffman offset %d\n", decodedCode, outOffseti);
      }
    }
#endif // DecodeHuffmanBitsFromTablesCompareToOriginal
    
    if (bitOffsetTable != NULL) {
      bitOffsetTable[symboli] = bufferBitOffset;
      bufferBitOffset += hls.bitWidth;
    }
    
    outOffseti += 1;
  }
  
  return;
}

// Given an input buffer, huffman encode the input values and generate
// output that corresponds to

void
HuffmanUtil::encodeHuffman(
                           uint8_t* inBytes,
                           int inNumBytes,
                           vector<uint8_t> & outFileHeader,
                           vector<uint8_t> & outCanonHeader,
                           vector<uint8_t> & outHuffCodes,
                           vector<uint32_t> & outBlockBitOffsets,
                           int width,
                           int height,
                           int blockDim)
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
  outCanonHeader = canonicalTableBytes;
  
  // Copy generated huffman codes back to caller
  
  //[outHuffCodes setLength:huffmanCodeBytes.size()];
  //uint8_t *outHuffCodesPtr = (uint8_t *) outHuffCodes.mutableBytes;

//  uint8_t *codesPtr = (uint8_t *) huffmanCodeBytes.data();
//  int codesN = (int) huffmanCodeBytes.size();
//
//  for ( int i = 0 ; i < codesN; i++) {
//    uint8_t code = codesPtr[i];
//    outHuffCodesPtr[i] = code;
//  }

  outHuffCodes = std::move(huffmanCodeBytes);
  
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
  
//  [outBlockBitOffsets setLength:bufferOffsetsToQuery.size()*sizeof(uint32_t)];
//
//  uint32_t *outBlockBitOffsetsPtr = (uint32_t *) outBlockBitOffsets.bytes;
//  int outBlockBitOffsetsi = 0;
//
//  for ( uint32_t offset : blockBitOffsetBytes ) {
//    outBlockBitOffsetsPtr[outBlockBitOffsetsi++] = offset;
//  }

  outBlockBitOffsets = blockBitOffsetBytes;
  
  return;
}

vector<int8_t>
HuffmanUtil::encodeSignedByteDeltas(
                           const vector<int8_t> & bytes)
{
  return encodeDelta(bytes);
}

vector<int8_t>
HuffmanUtil::decodeSignedByteDeltas(
                                    const vector<int8_t> & deltas)
{
  return decodeDelta(deltas);
}

