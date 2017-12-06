# MetalHuffman

A GPU huffman decoder for iOS on top of Metal, adapted from Basic Texturing example

## Overview

This project implements a huffman decoder directly on top of Apple's Metal API. Inspired by [huff0] https://github.com/Cyan4973/FiniteStateEntropy

## Decoding Speed

This code is needed for 1 reason only, speed! Decoding bytes of grayscale image data to be precise. While huff0 is amazon stuff, it is not as fast as lz4 and even lz4 is not fast enough to decode video at full screen iOS sizes at 30 FPS. The decoding needs to be done directly on the GPU so this code was created.

## Set a Fragment Texture

See AAPLRenderer.m and AAPLShaders.metal for the core GPU rendering logic. A huffman encoder and decoder are also included.

