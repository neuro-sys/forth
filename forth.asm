; ====================================================================== ;
;			     Fast & Small				 ;
; ====================================================================== ;
;
; This program creates a Forth system for intel x86 architecture.
;
; To build:
;
; nasm -f elf -w-zeroing -F dwarf -g -l forth.lst forth.asm &&	     \
;    ld -m elf_i386 --omagic forth.o -o forth &&		     \
;    ./forth

			    global _start

			    section .bss

; ====================================================================== ;
;				Memory					 ;
; ====================================================================== ;

DICTIONARY_SIZE	equ	64*1024*1024

dstack:		resd	1024	; Data stack
dstacke:	equ	$-4
rstack:		resd	1024	; Return stack
rstacke:	equ	$-4
tempregs:	resd	16	; Temporary storage for host registers
pad:		resd	1024	; Pad area
tibarea:	resd	1024	; Terminal input buffer area
dictionary:	resd	DICTIONARY_SIZE

			    section .text

; ====================================================================== ;
;			 Dictionary Entry Macro				 ;
; ====================================================================== ;

%define		link	0	; Link pointer, initially set to zero

%macro		header	2	; char_len, string
%%here		dd	link	; Store the previous word address
%define		link	%%here	; Set link to current address
		db	%1,%2	; Store char_len, and string
align		4		; Align to 32 bit boundary
%endmacro

%macro		variable 4	; char_len,string,label,val
header		%1,%2
%3:		call	doVAR
@%3:		dd	%4
%endmacro

; ====================================================================== ;
;			 Machine dependent words			 ;
; ====================================================================== ;
; Rest of the system will be built upon these words in high level
; Forth source. Keep this minimal to make it easier to port it to
; another system.

variable	2,"s0",		_s_zero,	dstacke
variable	2,"r0",		_r_zero,	rstacke
variable	2,"dp",		_dp,		dictionary
variable	3,"tib",	_tib,		tibarea
variable	4,"#tib",	_hash_tib,	0
variable	3,">in",	_to_in,		0
variable	4,"state",	_state,		0

_start:
		mov	[tempregs+0],ebp
		mov	[tempregs+1],esp

		mov	ebp,dstacke
		mov	esp,rstacke

		call	boot

doVAR:		xchg	ebp,esp
		mov	eax,[ebp]
		push	eax
		xchg	ebp,esp
		add	dword[esp],4
		ret

doLIT:		xchg	ebp,esp
		mov	eax,[ebp]
		push	dword[eax]
		xchg	ebp,esp
		add	dword[esp],4
		ret

header		3,"bye"			; --
_bye:		mov	ebp,[tempregs+0]
		mov	esp,[tempregs+1]
		mov	eax,1
		int	0x80

header		6,"branch"		; --
_branch:	pop	eax
		mov	eax,[eax]
		push	eax
		ret

header		7,"0branch"		; n --
_0branch:	xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		test	eax,eax
		jz	_0branch_nz
		pop	eax
		mov	eax,[eax]
		push	eax
		ret
_0branch_nz:	add	dword[esp],4
		ret

header		7,"execute"		; addr --
_execute:	xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		pop	ebx
		push	eax
		ret

header		1,"!"			; n addr --
_store:		xchg	ebp,esp
		pop	eax
		pop	ebx
		mov	[eax],ebx
		xchg	ebp,esp
		ret

header		1,"@"			; addr -- n
_fetch:		xchg	ebp,esp
		pop	eax
		push	dword[eax]
		xchg	ebp,esp
		ret

header		2,"c!"			; b addr --
_cstore:	xchg	ebp,esp
		pop	eax
		pop	ebx
		mov	byte[eax],bl
		xchg	ebp,esp
		ret

header		2,"c@"			; addr -- b
_cfetch:	xchg	ebp,esp
		pop	eax
		xor	ebx,ebx
		mov	bl,byte[eax]
		push	ebx
		xchg	ebp,esp
		ret

header		1,"+"			; n1 n2 -- n3
_plus:		xchg	ebp,esp
		pop	eax
		pop	ebx
		add	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

header		1,"-"			; n1 n2 -- n3
_minus:		xchg	ebp,esp
		pop	eax
		pop	ebx
		sub	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

header		1,"*"			; n1 n2 -- n3
_times:		xchg	ebp,esp
		pop	eax
		pop	ebx
		imul	ebx
		push	eax
		xchg	ebp,esp
		ret

header		1,"/"			; n1 n2 -- n3
_divide:	xchg	ebp,esp
		pop	ebx
		pop	eax
		idiv	ebx
		push	eax
		xchg	ebp,esp
		ret

header		2,">r"			; n --
_to_r:		mov	eax,[esp]
		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

header		2,"r>"			; -- n
_r_from:	pop	eax
		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

header		3,"and"			; n1 n2 -- n3
_and:		xchg	ebp,esp
		pop	eax
		pop	ebx
		and	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

header		2,"or"			; n1 n2 -- n3
_or:		xchg	ebp,esp
		pop	eax
		pop	ebx
		or	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

header		3,"xor"			; n1 n2 -- n3
_xor:		xchg	ebp,esp
		pop	eax
		pop	ebx
		xor	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

header		3,"not"			; flag -- flag
_not:		call	doLIT
		dd	-1
		call	_xor
		ret

header		1,"="			; a b -- flag
_equal:		call	_minus
		call	_zero
		ret

header		2,"=0"			; n -- flag
_zero:		xchg	ebp,esp
		pop	eax
		test	eax,eax
		jne	_zero_ne
		mov	eax,-1
		jmp	_zero_end
_zero_ne:	mov	eax,0
_zero_end:	push	eax
		xchg	ebp,esp
		ret

header		2,"0<"			; n -- flag
_zero_less:	xchg	ebp,esp
		pop	eax
		test	eax,eax
		jl	_zero_less_l
		mov	eax,0
		jp	_zero_less_e
_zero_less_l:	mov	eax,-1
_zero_less_e:	push	eax
		xchg	ebp,esp
		ret

header		4,"swap"		; n1 n2 -- n2 n1
_swap:		mov	eax,[ebp]
		xchg	eax,[ebp+4]
		ret

header		4,"drop"		; n --
_drop:		add	ebp,4
		ret

header		3,"dup"			; n -- n n
_dup:		xchg	ebp,esp
		push	dword[esp]
		xchg	ebp,esp
		ret

header		4,"over"		; n1 n2 -- n1 n2 n1
_over:		xchg	ebp,esp
		push	dword[ebp+8]
		xchg	ebp,esp
		ret

header		3,"key"			; -- char
_key:		xor	eax,eax
		mov	dword[pad],eax
		mov	ebx,0
		mov	ecx,pad
		mov	eax,3		; read
		mov	edx,1		; Read 1 character
		int	0x80
		xchg	ebp,esp
		push	dword[pad]
		xchg	ebp,esp
		ret

header		4,"emit"		; x --
_emit:		xchg	ebp,esp
		pop	eax
		call	putc
		xchg	ebp,esp
		ret

; ====================================================================== ;
;			    Meta compiler				 ;
; ====================================================================== ;
;
; The so called "meta compiler" is the program that compiles Forth
; source into dictionary on target machine. It is limited in
; functionality to compile only the words needed for outer
; interpreter. Once the outer interpreter is built, it will jump to it
; and let it build the rest of the system.
;
; Outline
; =======
;
; - Let DP be Dictionary pointer.
; - Read one word from string buffer.
; - If it's ":", fetch next word and create dictionary entry.
; - If it's ";", finalize the dictionary entry.
; - If it's "VARIABLE", create a variable with 0 as value.
; - If it's "USER", create a user variable with 0 as value.
; - If it's a number, convert to binary, and store as literal.
; - For everything else compile a token into current DP.

; IN eax holds address of file name to open
; OUT eax holds file descriptor
open:		mov	ebx,eax
		mov	eax,5		; open
		mov	ecx,0
		mov	edx,0
		int	0x80
		ret

; IN eax holds fd
close:		mov	ebx,eax
		mov	eax,6		; close
		int	0x80
		ret

; IN eax holds character to print
putc:		mov	[pad],eax
		mov	eax,4		; write
		mov	ebx,1		; stdout
		mov	ecx,pad
		mov	edx,1		; 1 character
		int	0x80
		ret

; IN eax holds nul terminated string to print to stdout
puts:		mov	bl,byte[eax]
		test	bl,bl
		jz	puts_e
		push	eax
		mov	al,bl
		call	putc
		pop	eax
		inc	eax
		jmp	puts
puts_e:		ret

; IN eax holds non-nil terminated string to print to stdout
;    ecx holds the count
puts1		push	ecx
		push	eax
		mov	al,byte[eax]
		call	putc
		pop	eax
		pop	ecx
		inc	eax
		dec	ecx
		js	puts1_e
		jmp	puts1
puts1_e:	ret


; IN ebx fd
;    ecx buf
read:		mov	eax,3		; read
		mov	edx,1023	; Read until memory blows up
		int	0x80
		ret

; IN ebx fd
;    ecx buf
read_file:	call	read
		test	eax,eax
		jns	read_success
		mov	eax,$read_error
		call	puts
		call	_bye
read_success:	add	eax,ecx
		mov	byte[eax],0
		ret

$filename:	db "forth.fs",0
$read_error:	db "Failed to read file",0

header		4,"2dup"
_two_dup:	call	_dup
		call	_dup
		ret

header		2,"u<"
_less_u:	call	_two_dup
		call	_xor
		call	_zero_less
		call	_0branch
		dd	_less_u1
		call	_swap
		call	_drop
_less_u1:	call	_minus
		call	_zero_less
		ret

header		6,"negate"
_negate:	call	_not
		call	doLIT
		dd	1
		call	_plus
		ret

header		6,"um/mod"		; udl udh u -- ur uq
_um_div_mod:	call	_two_dup
		call	_less_u
		call	_0branch
		dd	_um_div_mod1
		call	_negate
		call	doLIT
		dd	15
_um_div_mod1:

_word:					; char -- addr
		ret

_find:		ret
_immediate?:	ret
_to_number:	ret
_comma:		ret
_char_comma:	ret
_count:		ret
_abort:		ret

_compile:	call	doLIT		; --
		dd	32
		call	_word		; bl word
		call	_find
		call	_0branch	; find if
		dd	_compile1
		call	_dup		;   dup
		call	_immediate?
		call	_0branch	;   immediate? if
		dd	_compile2
		call	_execute	;     execute
		jmp	_compile2e	;   else
_compile2:	call	doLIT
		dd	0xe8
		call	_char_comma
		call	_comma		;     e8h c, ,
_compile2e:	jmp	_compile1e	;   then
_compile1:	call	_count		; else
		call	_to_number
		call	_0branch	;   count >number if
		dd	_compile3
		call	doLIT
		dd	0xe8
		call	_char_comma
		call	doLIT
		dd	doLIT
		call	_comma
		call	_comma		;     e8h c, [ =doLIT ] , ,
		jmp	_compile3e	;   else
_compile3:	call	_abort		;     abort
_compile3e:				;   then
_compile1e:				; then
		ret


fd:		resd	1

boot:
		mov	eax,$filename
		call	open
		mov	ebx,eax
		mov	ecx,tibarea
		call	read_file

		call	_compile

		call	_bye

; ---------------------------------------------------------------------- ;
;			     Test program				 ;
; ---------------------------------------------------------------------- ;

header		2,"1-"
_one_minus:	call	doLIT
		dd	-1
		call	_plus
		ret

; : demo 9 begin dup 0 + emit 1- dup until ;

demo:		call	doLIT
		dd	9
demo1:		call	_dup
		call	doLIT
		dd	'0'
		call	_plus
		call	_emit
		call	_one_minus
		call	_dup
		call	_not
		call	_0branch
		dd	demo1
		call	_bye