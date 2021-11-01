; Implementation of FORTH 79
;
; Build:
;
; nasm -f elf -w-zeroing -l forth-79.lst forth-79.asm &&     \
;    ld -m elf_i386 --omagic forth-79.o -o forth-79 &&       \
;    ./forth-79
global _start

section .data

dstack:		resd	1024	; Data stack
rstack:		resd	1024	; Return stack
tempregs:	resd	16	; Temporary storage for host registers
pad:		resd	1024	; Pad area

section .text

; Macros

%define 	link 	0	; Link pointer, initially set to zero

%macro		header	2	; char_len, string
%%here		dd	link	; Store the previous word address
%define		link	%%here	; Set link to current address
		db	%1,%2	; Store char_len, and string
align		4		; Align to 32 bit boundary
%endmacro

%macro		variable 4
header		%1,%2
%3:		call	doVAR
		dd	%4
%endmacro

; Variables

variable	5,"state",_state,0
variable	3,">in",_to_in,0
variable	4,"base",_base,0
variable	7,"context",_context,0
variable	7,"current",_current,0
variable	3,"scr",_scr,0

; Internal routines and words

_start:
		mov	[tempregs+0],ebp
		mov	[tempregs+1],esp

		mov	ebp,dstack
		mov	esp,rstack

		call	_quit
		xchg	ebp,esp
		push	42
		push	2
		mov	eax, 3
		xchg	ebp,esp
		call	_times_divide
		call	_bye

doVAR:		xchg	ebp,esp
		push	eax		; Make space in TOS
		xchg	ebp,esp
		pop	eax		; Next token has address of variable
		ret			; Return to previous caller

header		3,"bye"			; --
_bye:		mov	ebp,[tempregs+0]
		mov	esp,[tempregs+1]
		mov	eax,1
		int	0x80

header		6,"branch"		; --
_branch:	xchg	ebp,esp
		mov	ebx,[ebp]
		mov	ecx,[ebx]
		add	[ebp],ecx
		xchg	ebp,esp
		ret
header		7,"?branch"		; n --
_qbranch:	xchg	ebp,esp
		mov	ebx,eax
		pop	eax
		test	ebx,ebx
		jnz	_qbranch_nz
		call	_branch
		jmp	_qbranch_e
_qbranch_nz:	mov	ebx,[ebp]
		add	ebx,4
		mov	[ebp],ebx
_qbranch_e:	xchg	ebp,esp
		ret

header		7,"execute"		; addr --
_execute:	xchg	ebp,esp
		pop	ebx
		xchg	ebp,esp
		push	ebx
		ret

; Nucleus Words

header		1,"!"		; n addr --
_store:		xchg	ebp,esp
		pop	ebx
		mov	[ebx],eax
		pop	eax
		xchg	ebp,esp
		ret

header		1,"@"		; addr -- n
_fetch:		xchg	ebp,esp
		mov	eax,[eax]
		xchg	ebp,esp
		ret

header		2,"c!"		; b addr --
_cstore:	xchg	ebp,esp
		pop	ebx
		mov	byte[ebx],al
		pop	eax
		xchg	ebp,esp
		ret

header		2,"c@"		; addr -- b
_cfetch:	xchg	ebp,esp
		xor	eax,eax
		mov	al,byte[eax]
		xchg	ebp,esp
		ret

header		1,"*"		; n1 n2 -- n3
_times:		xchg	ebp,esp
		pop	ebx
		imul	ebx
		xchg	ebp,esp
		ret

header		1,"/"		; n1 n2 -- n3
_divide:	xchg	ebp,esp
		pop	ebx
		idiv	ebx
		xchg	ebp,esp
		ret

header		2,"*/"		; n1 n2 n3 -- n4
_times_divide:	
		
		ret

header		4,"swap"	; n1 n2 -- n2 n1
		xchg	eax,[ebp]
		ret


; Interpreter Words

header		1,"."		; n --
_dot:		xchg	ebp,esp
		mov	[pad],eax
		mov	eax,4
		mov	ebx,1
		mov	ecx,pad
		mov	edx,1
		int	0x80
		pop	eax
		xchg	ebp,esp
		ret

header		1,"#"		; ud1 -- ud2
_sharp:		xchg	ebp,esp
		
		xchg	ebp,esp
		ret

header		4,"quit"	; --
_quit:		mov	ebp,dstack	; Reset data stack
		pop	ebx		; Save return address
		mov	esp,rstack	; Reset return stack
		push	ebx		; Restore return address
		ret

; Compiler Words

