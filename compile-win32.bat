cls
C:\Users\neurosys\nasm-2.15.05\nasm -gcv8 -f win32 -w-zeroing -l forth-x86.lst -o forth-x86.obj forth-x86.asm
link /debug:full /subsystem:console /entry:start /SECTION:.text,RWE /SECTION:.data,RWE /SECTION:.bss,RWE forth-x86.obj kernel32.lib user32.lib legacy_stdio_definitions.lib ucrt.lib
forth-x86.exe
rem done

