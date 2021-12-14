#!/bin/bash

clear &&              \
nasm -f elf32         \
     -w-zeroing       \
     -F dwarf         \
     -g               \
     -l forth-x86.lst \
     -o forth-x86.o   \
     forth-x86.asm && \
ld -m elf_i386        \
     --omagic         \
     -o forth-x86     \
     forth-x86.o &&   \
./forth-x86            
