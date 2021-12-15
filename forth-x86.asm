; ====================================================================== ;
;			      ANS Forth
; ====================================================================== ;
;
; Description
; ===========
; This program creates a Forth system for intel x86 for Linux.
;
; Conventions
; ===========
; - It uses 8 character tab width.
; - Counted strings use 1 cell for the count
; - There are no double numbers (probably not a good idea)
;
; Build
; =====
; A compile.sh script is provided. But here is an example:
;
; nasm -f elf32		\
;      -w-zeroing	\
;      -F dwarf		\
;      -g		\
;      -l forth-x86.lst	\
;      -o forth-x86.o	\
;      forth-x86.asm && \
; ld -m elf_i386	\
;      --omagic		\
;      -o forth-x86	\
;      forth-x86.o &&	\
; ./forth-x86
;
; TODO
; ====
; - Reduce the primitive words size
; - Reduce the size of bootstrap compiler
; - Add Windows support
; - Add PC boot support
; - Implement rest of the CORE word set
; - Implement BLOCK word set
;
; Change Log
; ==========
; 20211215 - Change log added, code formatted, todo added.
;


			    global _start

			    section .bss

; ====================================================================== ;
;				Memory					 ;
; ====================================================================== ;

DIC_SIZ		equ	64*1024*1024 ; Dictionary area
TIB_SIZ		equ	1024	; Temporary input buffer

dstack:		resd	1024	; Data stack
dstacke:	equ	$
rstack:		resd	1024	; Return stack
rstacke:	equ	$
tib:		resd	TIB_SIZ	; Terminal input buffer area
dictionary:	resd	DIC_SIZ	; Consider making this parametrized
tempregs:	resd	16	; Temporary storage for host registers

; ====================================================================== ;
;			      Entry point
; ====================================================================== ;

			    section .text

_start:
		mov	[tempregs+0],ebp
		mov	[tempregs+1],esp

		mov	ebp,dstacke
		mov	esp,rstacke

		call	boot

; ====================================================================== ;
;			      Primitives
; ====================================================================== ;
; Dictionary entry structure looks like this:
;
; link		1 cell
; count+masks	1 cell
; name		N bytes
; code		N bytes
;

m_immediate	equ	(1 << 31)
m_compile_only	equ	(1 << 30)
count_mask	equ	~(m_immediate + m_compile_only)

w_cell:		dd	0		; link
		dd	4		; count+masks
		db	"cell"		; name
xt_cell:	call	xt_doconst	; code
@_cell:		dd	4		; parameter

w_dp:		dd	w_cell
		dd	2
		db	"dp"
xt_dp:		call	xt_dovar
@_dp:		dd	dictionary

w_num_tib:	dd	w_dp
		dd	4
		db	"#tib"
xt_num_tib:	call	xt_dovar
@_num_tib:	dd	0

w_max_num_tib:	dd	w_num_tib
		dd	7
		db	"max#tib"
xt_max_num_tib:	call	xt_doconst
@_max_num_tib:	dd	TIB_SIZ

w_to_in:	dd	w_max_num_tib
		dd	3
		db	">in"
xt_to_in:	call	xt_dovar
@_to_in:	dd	0

w_state:	dd	w_to_in
		dd	5
		db	"state"
xt_state:	call	xt_dovar
@_state:	dd	0

w_last:		dd	w_state
		dd	4
		db	"last"
xt_last:	call	xt_dovar
@_last:		dd	0

w_source_id:	dd	w_last
		dd	9
		db	"source-id"
xt_source_id:	call	xt_dovar
@_source_id:	dd	0


w_base:		dd	w_source_id
		dd	4
		db	"base"
xt_base:	call	xt_dovar
@_base:		dd	10


w_s0:		dd	w_base
		dd	2
		db	"s0"
xt_s0:		call	xt_doconst
@_s0:		dd	dstacke

w_r0:		dd	w_s0
		dd	2
		db	"r0"
xt_r0:		call	xt_doconst
@_r0:		dd	rstacke

w_tib:		dd	w_r0
		dd	3
		db	"tib"
xt_tib:		call	xt_doconst
@_tib:		dd	tib

w_dovar:	dd	w_tib
		dd	5
		db	"(var)"
xt_dovar:	xchg	ebp,esp
		mov	eax,[ebp]
		push	eax
		xchg	ebp,esp
		add	esp,4
		ret

w_doconst:	dd	w_dovar
		dd	7
		db	"(const)"
xt_doconst:	xchg	ebp,esp
		mov	eax,[ebp]
		mov	eax,[eax]
		push	eax
		xchg	ebp,esp
		add	esp,4
		ret

w_dolit:	dd	w_doconst
		dd	5
		db	"(lit)"
xt_dolit:	xchg	ebp,esp
		mov	eax,[ebp]
		push	dword[eax]
		xchg	ebp,esp
		add	dword[esp],4
		ret

w_branch:	dd	w_dolit
		dd	8
		db	"(branch)"
xt_branch:	pop	eax
		mov	eax,[eax]
		jmp	eax

w_0branch:	dd	w_branch
		dd	9
		db	"(0branch)"
xt_0branch:	xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		test	eax,eax
		jnz	_0branch_nz
		pop	eax
		mov	eax,[eax]
		jmp	eax
_0branch_nz:	add	dword[esp],4
		ret

w_bye:		dd	w_0branch
		dd	3
		db	"bye"
xt_bye:		mov	ebp,[tempregs+0]
		mov	esp,[tempregs+1]
		call	sys_bye

w_execute:	dd	w_bye
		dd	7
		db	"execute"
xt_execute:	xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		pop	ebx
		push	eax
		ret

w_store:	dd	w_execute
		dd	1
		db	"!"
xt_store:	xchg	ebp,esp
		pop	eax
		pop	ebx
		mov	[eax],ebx
		xchg	ebp,esp
		ret

w_fetch:	dd	w_store
		dd	1
		db	"@"
xt_fetch:	xchg	ebp,esp
		pop	eax
		push	dword[eax]
		xchg	ebp,esp
		ret

w_cstore:	dd	w_fetch
		dd	2
		db	"c!"
xt_cstore:	xchg	ebp,esp
		pop	eax
		pop	ebx
		mov	byte[eax],bl
		xchg	ebp,esp
		ret

w_cfetch:	dd	w_cstore
		dd	2
		db	"c@"
xt_cfetch:	xchg	ebp,esp
		pop	eax
		xor	ebx,ebx
		mov	bl,byte[eax]
		push	ebx
		xchg	ebp,esp
		ret

w_plus:		dd	w_cfetch
		dd	1
		db	"+"
xt_plus:	xchg	ebp,esp
		pop	eax
		pop	ebx
		add	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

w_minus:	dd	w_plus
		dd	1
		db	"-"
xt_minus:	xchg	ebp,esp
		pop	ebx
		pop	eax
		sub	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

w_um_star:	dd	w_minus
		dd	3
		db	"um*"
xt_um_star:	xchg	ebp,esp
		pop	ebx
		pop	eax
		xor	edx,edx
		mul	ebx
		push	edx
		push	eax
		xchg	ebp,esp
		ret

w_um_mod:	dd	w_um_star
		dd	6
		db	"um/mod"
xt_um_mod:	xchg	ebp,esp
		pop	ebx
		pop	eax
		xor	edx,edx
		idiv	ebx
		push	edx
		push	eax
		xchg	ebp,esp
		ret

w_to_r:		dd	w_um_mod
		dd	2
		db	">r"
xt_to_r:	pop	eax
		xchg	ebp,esp
		pop	ebx
		xchg	ebp,esp
		push	ebx
		push	eax
		ret

w_r_from:	dd	w_to_r
		dd	2
		db	"r>"
xt_r_from:	pop	eax
		pop	ebx
		xchg	ebp,esp
		push	ebx
		xchg	ebp,esp
		push	eax
		ret

w_and:		dd	w_r_from
		dd	3
		db	"and"
xt_and:		xchg	ebp,esp
		pop	eax
		pop	ebx
		and	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

w_or:		dd	w_and
		dd	2
		db	"or"
xt_or:		xchg	ebp,esp
		pop	eax
		pop	ebx
		or	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

w_xor:		dd	w_or
		dd	3
		db	"xor"
xt_xor:		xchg	ebp,esp
		pop	eax
		pop	ebx
		xor	eax,ebx
		push	eax
		xchg	ebp,esp
		ret

w_equals:	dd	w_xor
		dd	1
		db	"="
xt_equals:	xchg	ebp,esp
		pop	eax
		pop	ebx
		cmp	eax,ebx
		jz	xt_equals1
		push	0
		jmp	xt_equals2
xt_equals1:	push	-1
xt_equals2:	xchg	ebp,esp
		ret

w_notequals:	dd	w_equals
		dd	2
		db	"<>"
xt_notequals:	call	xt_equals
		call	xt_invert
		ret

w_invert:	dd	w_notequals
		dd	6
		db	"invert"
xt_invert:	call	xt_dolit
		dd	-1
		call	xt_xor
		ret

w_zero_less:	dd	w_invert
		dd	2
		db	"0<"
xt_zero_less:	xchg	ebp,esp
		pop	eax
		cmp	eax,0
		jl	xt_zero_less_l
		mov	eax,0
		jmp	xt_zero_less_e
xt_zero_less_l:	mov	eax,-1
xt_zero_less_e:	push	eax
		xchg	ebp,esp
		ret

w_swap:		dd	w_zero_less
		dd	4
		db	"swap"
xt_swap:	mov	eax,[ebp]
		mov	ebx,[ebp+4]
		mov	[ebp],ebx
		mov	[ebp+4],eax
		ret

w_rot:		dd	w_swap
		dd	3
		db	"rot"
xt_rot:		xchg	ebp,esp
		pop	ecx
		pop	ebx
		pop	eax
		push	ebx
		push	ecx
		push	eax
		xchg	ebp,esp
		ret

w_drop:		dd	w_rot
		dd	4
		db	"drop"
xt_drop:	add	ebp,4
		ret

w_dup:		dd	w_drop
		dd	3
		db	"dup"
xt_dup:		xchg	ebp,esp
		push	dword[esp]
		xchg	ebp,esp
		ret

w_over:		dd	w_dup
		dd	4
		db	"over"
xt_over:	xchg	ebp,esp
		pop	eax
		pop	ebx
		push	ebx
		push	eax
		push	ebx
		xchg	ebp,esp
		ret

w_key:		dd	w_over
		dd	3
		db	"key"
xt_key:		mov	eax,[@_source_id]
		call	sys_readc
		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

w_emit:		dd	w_key
		dd	4
		db	"emit"
xt_emit:	xchg	ebp,esp
		pop	eax
		call	putc
		xchg	ebp,esp
		ret

w_2dup:		dd	w_emit
		dd	4
		db	"2dup"
xt_2dup:	call	xt_over
		call	xt_over
		ret

w_dash_rot:	dd	w_2dup
		dd	4
		db	"-rot"
xt_dash_rot:	call	xt_rot
		call	xt_rot
		ret

w_accept:	dd	w_dash_rot
		dd	6
		db	"accept"
xt_accept:	call	xt_2dup
xt_accept1:	call	xt_key
		call	xt_dup
		call	xt_dolit
		dd	10
		call	xt_notequals
		call	xt_over
		call	xt_dolit
		dd	13
		call	xt_notequals
		call	xt_and
		call	xt_over
		call	xt_and
		call	xt_0branch
		dd	xt_accept2
		call	xt_dup
		call	xt_dolit
		dd	127
		call	xt_equals
		call	xt_0branch
		dd	xt_accept3
		call	xt_drop
; backspace handling can be removed when the outer interpreter
; is compiled via source
		; call	xt_backspace
		call	xt_swap
		call	xt_dolit
		dd	1
		call	xt_minus
		call	xt_swap
		call	xt_dolit
		dd	1
		call	xt_plus
		jmp	xt_accept4
xt_accept3:	call	xt_rot
		call	xt_2dup
		call	xt_cstore
		call	xt_dash_rot
		call	xt_emit
		call	xt_swap
		call	xt_dolit
		dd	1
		call	xt_plus
		call	xt_swap
		call	xt_dolit
		dd	1
		call	xt_minus
xt_accept4:	jmp	xt_accept1
xt_accept2:	call	xt_drop
		call	xt_drop
		call	xt_swap
		call	xt_drop
		call	xt_swap
		call	xt_minus
		ret

w_refill:	dd	w_accept
		dd	6
		db	"refill"
xt_refill:	call	xt_tib
		call	xt_max_num_tib
		call	xt_accept
		call	xt_num_tib
		call	xt_store
		call	xt_dolit
		dd	0
		call	xt_to_in
		call	xt_store
		call	xt_dolit
		dd	0
		ret

tonumber_u:	resd	1
tonumber_sum:	resd	1
tonumber_sign:	resd	1

w_tonumber:	dd	w_refill
		dd	7
		db	">number"
xt_tonumber:	xchg	ebp,esp
		pop	ebx
		pop	eax
		xchg	ebp,esp
		call	tonumber
		xchg	ebp,esp
		push	eax
		push	ebx
		xchg	ebp,esp
		ret

; c-addr u -- n flag
tonumber:	cmp	byte[eax],'-'
		jnz	tonumber1
		mov	dword[tonumber_sign],1
		inc	eax
		dec	ebx
		jmp	tonumber3
tonumber1:	mov	dword[tonumber_sign],0
tonumber3:	mov	ecx,ebx		; count
		add	ebx,eax		; addr
		dec	ebx
		mov	dword[tonumber_u],1	; digit factor
		mov	dword[tonumber_sum],0
tonumber2:	xor	eax,eax
		mov	al,byte[ebx]
		cmp	al,'0'
		jl	tonumber_err
		cmp	al,'9'
		jg	tonumber_hex
		sub	al,'0'
		jmp	tonumber4
tonumber_hex:	and	al,~0x20
		cmp	al,'A'
		jl	tonumber_err
		cmp	al,'F'
		jg	tonumber_err
		sub	al,55
tonumber4:	mul	dword[tonumber_u]
		add	dword[tonumber_sum],eax
		mov	eax,dword[tonumber_u]
		mul	dword[@_base]
		mov	dword[tonumber_u],eax
		dec	ebx
		dec	ecx
		cmp	ecx,0
		jz	tonumber_e
		jmp	tonumber2
tonumber_err:	mov	ebx,0
		ret
tonumber_e:	mov	eax,dword[tonumber_sum]
		cmp	dword[tonumber_sign],1
		jnz	tonumber_e1
		neg	eax
tonumber_e1:	mov	ebx,-1
		ret

w_cmove:	dd	w_tonumber
		dd	5
		db	"cmove"
xt_cmove:	xchg	ebp,esp
		pop	ecx
		pop	ebx
		pop	eax
		xchg	ebp,esp
		call	cmove
		ret

cmove:		mov	esi,eax
		mov	edi,ebx
		cld
		rep	movsb
		ret

w_comma:	dd	w_cmove
		dd	1
		db	","
xt_comma:	xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		call	comma
		ret
; n --
comma:		mov	ebx,[@_dp]
		mov	[ebx],eax
		add	dword[@_dp],4
		ret

w_c_comma:	dd	w_comma
		dd	2
		db	"c,"
_c_comma:	xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		call	c_comma
		ret
c_comma:	mov	ebx,[@_dp]
		mov	byte[ebx],al
		inc	dword[@_dp]
		ret

colon_a:	resd	1
colon_n:	resd	1

w_colon:	dd	w_c_comma
		dd	1
		db	":"
xt_colon:	call	xt_parse_name
		xchg	ebp,esp
		pop	ebx
		pop	eax
		xchg	ebp,esp
		mov	dword[colon_a],eax
		mov	dword[colon_n],ebx
		mov	eax,[@_dp]
		push	eax		; here last @
		mov	eax,[@_last]
		call	comma		; ,
		pop	eax
		mov	[@_last],eax	; last !
		mov	eax,[colon_n]
		call	comma		; n ,
		mov	eax,[colon_a]
		mov	ebx,[@_dp]
		mov	ecx,[colon_n]
		call	cmove		; copy name
		mov	eax,[colon_n]
		add	dword[@_dp],eax
		mov	dword[@_state],-1
		ret

w_semicolon:	dd	w_colon
		dd	1 + m_immediate
		db	";"
xt_semicolon:	mov	eax,0xc3
		call	c_comma		; compile near return
		mov	dword[@_state],0
		ret

w_compile_comma:
		dd	w_semicolon
		dd	8
		db	"compile,"
xt_compile_comma:
		call	xt_dolit
		dd	0xe8
		call	_c_comma
		call	xt_dp
		call	xt_fetch
		call	xt_minus
		call	xt_cell
		call	xt_minus
		call	xt_comma
		ret

compare_a:	resd	1
compare_n:	resd	1
compare_b:	resd	1
compare_u:	resd	1

w_compare:	dd	w_compile_comma
		dd	7
		db	"compare"
		xchg	ebp,esp
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		xchg	ebp,esp
		call	compare
		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

; c-addr1 u1 c-addr2 u2 -- flag
; note that it is case insensitive
compare:	mov	[compare_a],eax
		mov	[compare_n],ebx
		mov	[compare_b],ecx
		cmp	dword[compare_n],edx
		jz	compare_s	; if counts not match
		mov	eax,0		; return false
		ret
compare_s:	mov	ecx,-1		; set found flag
compare2:	xor	eax,eax
		mov	al,[compare_n]
		cmp	al,0
		jz	compare_e
		mov	ebx,[compare_a]
		xor	eax,eax
		mov	al,byte[ebx]
		mov	ecx,[compare_b]
		xor	ebx,ebx
		mov	bl,byte[ecx]
		bts	eax,5
		bts	ebx,5
		cmp	al,bl
		jnz	compare1
		inc	dword[compare_a]
		inc	dword[compare_b]
		dec	dword[compare_n]
		jmp	compare2
compare1:	mov	ecx,0		; clear found flag
compare_e:	mov	eax,ecx
		ret

find_str:	resd	1
find_u:		resd	1
find_curlink:	resd	1

w_find:		dd	w_compare
		dd	4
		db	"find"
xt_find:	xchg	ebp,esp
		pop	ebx
		pop	eax
		xchg	ebp,esp
		call	find
		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

; c-addr u -- xt
find:		mov	[find_str],eax
		mov	[find_u],ebx
		mov	eax,[@_last]	; link
		mov	[find_curlink],eax
find1:		mov	eax,[find_curlink]
		add	eax,4		; we are at count
		mov	ebx,[eax]	; count
		and	ebx,count_mask
		add	eax,4		; name
		mov	ecx,[find_str]
		mov	edx,[find_u]
		call	compare
		cmp	eax,0
		jz	find_n		; not found
		mov	eax,[find_curlink]
		call	nfa
		mov	eax,[find_curlink]
		ret			; found and return
find_n:		mov	eax,[find_curlink]
		mov	eax,[eax]	; next link
		or	eax,eax
		jz	find_e
		mov	[find_curlink],eax
		jmp	find1
find_e:		mov	eax,0
		ret

; ( char "ccc<char>" -- c-addr u )
w_parse:	dd	w_find
		dd	5
		db	"parse"
xt_parse:	mov	eax,[@_tib]
		mov	edx,eax
		inc	dword[@_to_in]	; skip current character
		add	eax,[@_to_in]
		add	edx,[@_num_tib]	; eol
		mov	ecx,eax		; begin
		xchg	ebp,esp
		pop	ebx		; char
		xchg	ebp,esp
_parse2:	cmp	eax,edx
		jz	_parse1
		cmp	byte[eax],bl
		jz	_parse1
		inc	eax
		jmp	_parse2
_parse1:	mov	edx,eax
		sub	edx,ecx		; edx offset
		add	[@_to_in],edx
		inc	dword[@_to_in]
		xchg	ebp,esp
		push	ecx
		push	edx
		xchg	ebp,esp
		ret


; ( "<spaces>name<space>" -- c-addr u)
; FIXME, can use PARSE?
w_parse_name:	dd	w_parse
		dd	10
		db	"parse-name"
xt_parse_name:	mov	eax,[@_tib]
		mov	edx,eax
		add	eax,[@_to_in]
		add	edx,[@_num_tib]	; end c-addr
		mov	ecx,eax		; backup first c-addr
_parse_name2:	cmp	eax,edx
		jz	_parse_name1
		cmp	byte[eax],32
		jnz	_parse_name1
		inc	eax
		jmp	_parse_name2
_parse_name1:	mov	ebx,eax		; backup begin c-addr
_parse_name4:	cmp	eax,edx
		jz	_parse_name3
		cmp	byte[eax],32
		jz	_parse_name3
		inc	eax
		jmp	_parse_name4
_parse_name3:	mov	edx,eax
		sub	edx,ecx		; edx offset
		add	[@_to_in],edx
		sub	eax,ebx		; u
		xchg	ebp,esp
		push	ebx
		push	eax
		xchg	ebp,esp
		ret

w_nfa		dd	w_parse_name
		dd	3
		db	"nfa"
xt_nfa:		xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		call	nfa
		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

; addr -- addr
nfa:		add	eax,4
		ret

w_cfa:		dd	w_nfa
		dd	3
		db	"cfa"
xt_cfa:		xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		call	cfa
		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

; addr -- addr
cfa:		call	nfa
		mov	ebx,[eax]
		and	ebx,count_mask
		add	eax,4
		add	eax,ebx
		ret

w_sp_fetch:	dd	w_cfa
		dd	3
		db	"sp@"
xt_sp_fetch:	xchg	ebp,esp
		push	esp
		xchg	ebp,esp
		ret

w_sp_store:	dd	w_sp_fetch
		dd	3
		db	"sp!"
xt_sp_store:	xchg	ebp,esp
		pop	eax
		mov	esp,eax
		xchg	ebp,esp
		ret

w_rp_fetch:	dd	w_sp_store
		dd	3
		db	"rp@"
xt_rp_fetch:	xchg	ebp,esp
		push	ebp
		xchg	ebp,esp
		ret

w_rp_store:	dd	w_rp_fetch
		dd	3
		db	"rp!"
xt_rp_store:	xchg	ebp,esp
		pop	eax
		mov	ebp,eax
		xchg	ebp,esp
		ret

; Consider getting rid of open-file and close-file and use blocks instead
; ( c-addr u fam -- fileid ior )
w_open_file:	dd	w_rp_store
		dd	9
		db	"open-file"
xt_open_file:	xchg	ebp,esp
		pop	eax		; ignore fam
		pop	ebx
		pop	eax
		xchg	ebp,esp
		add	ebx,eax
		mov	byte[ebx],0	; Potential bug, this is wrong
		call	sys_open
		cmp	eax,0
		js	open_error
		xchg	ebp,esp
		push	eax
		push	0
		xchg	ebp,esp
		ret
open_error:	xchg	ebp,esp
		push	0
		push	eax
		xchg	ebp,esp
		ret

; ( fileid -- ior )
w_close_file:	dd	w_open_file
		dd	10
		db	"close-file"
xt_close_file:	xchg	ebp,esp
		pop	eax
		xchg	ebp,esp
		call	sys_close
		mov	dword[@_source_id],0
		cmp	eax,eax
		jnz	close_error
		call	xt_dolit
		dd	0
		ret
close_error:	xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		ret

last		equ	w_close_file

; ====================================================================== ;
;			  Bootstrap Compiler
; ====================================================================== ;
;
; This part is a program that loads and compiles the rest of the Forth
; in Forth from source file. It is a minimal Forth compiler and
; interpreter
;
			    section .text

filename:	db	"forth.fs",0
filename_len:	equ	$-filename

putctemp:	resd	1
putc:		call	sys_putc	; c --
		ret

; Display zero terminated string
puts:		mov	bl,byte[eax]	; caddr --
		test	bl,bl
		jz	puts_e
		push	eax
		xor	eax,eax
		mov	al,bl
		call	putc
		pop	eax
		inc	eax
		jmp	puts
puts_e:		ret

; Display counter string
puts1:		test	ebx,ebx		; c-addr u --
		jz	puts1_e
		push	eax
		push	ebx
		mov	al,byte[eax]
		call	putc
		pop	ebx
		pop	eax
		inc	eax
		dec	ebx
		jmp	puts1
puts1_e:	ret

readline_error_str:
		db     "Failed to read file",0

readline_buf:	resd	1

; Read one line excluding the newline character at most size bytes
; into buffer from fd.
readline:	mov	dword[readline_buf],tib	     ; -- u
		xor	ecx,ecx
		mov	[@_num_tib],ecx
readline1:	mov	eax,[@_num_tib]
		cmp	eax,TIB_SIZ
		jz	readline_e
		mov	eax,[@_source_id]
		call	sys_readc
		cmp	ebx,-1
		jz	readline_error
		test	ebx,ebx
		jz	readline_eof
		; push	eax
		; call	putc
		; pop	eax
		cmp	al,10		; new line
		jz	readline_e
		cmp	al,13		; new line
		jz	readline_e
		cmp	al,127		; backspace
		jz	readline_bs
		mov	ebx,[readline_buf];
		mov	byte[ebx],al
		inc	dword[@_num_tib]
		inc	dword[readline_buf]
		jmp	readline1
readline_e:	mov	eax,0
		ret
readline_eof:	mov	eax,-1
		ret
readline_bs:	jmp	readline1
readline_error: mov	eax,readline_error_str
		call	puts
		call	xt_bye

interpret:	call	xt_parse_name
		xchg	ebp,esp
		pop	ebx
		pop	eax
		xchg	ebp,esp
		cmp	ebx,0
		jz	interpret_end

		call	find
		or	eax,eax
		jz	interpret_to_number

		mov	[quit_curhead],eax

		cmp	dword[@_state],0
		jz	interpret_execute

		mov	eax,[quit_curhead]
		add	eax,4
		test	dword[eax],m_immediate
		jnz	interpret_execute

		mov	eax,[quit_curhead]
		call	cfa

		xchg	ebp,esp
		push	eax
		xchg	ebp,esp
		call	xt_compile_comma

		jmp	interpret
interpret_execute:

		mov	eax,[quit_curhead]
		call	cfa
		call	eax

		jmp	interpret

interpret_to_number:
		mov	eax,[find_str]
		mov	ebx,[find_u]
		call	tonumber
		cmp	ebx,-1
		jnz	interpret_abort

		push	eax		; save the number

		cmp	dword[@_state],0
		jz	interpret_number_execute

		call	xt_dolit
		dd	xt_dolit
		call	xt_compile_comma

		pop	eax
		call	comma

		jmp	interpret

interpret_number_execute:

		pop	eax
		xchg	ebp,esp
		push	eax		; push to ds
		xchg	ebp,esp

		jmp	interpret

		mov	eax,0
interpret_end:	ret

interpret_abort:
		mov	eax,10
		call	putc
		mov	eax,[find_str]
		mov	ebx,[find_u]
		call	puts1
		mov	eax,interpret_abort$
		call	puts
		call	xt_dolit
		dd	0
		call	xt_state
		call	xt_store
		mov	eax,-1
		ret

interpret_abort$:
		db	" is undefined word",10,0

; --
bootrefill:	call	readline
		mov	ebx,[readline_buf]
		sub	ebx,tib
		mov	[@_num_tib],ebx
		mov	dword[@_to_in],0
		ret


bootcompile:	call	bootrefill
		cmp	eax,-1
		jz	bootcompile_e
		call	interpret
		jmp	bootcompile
bootcompile_e:	ret

quit_ok$:	db	" ok",10,0
quit_error$:	db	" Failed to read input",10,0

quit_curhead:	resd	1

; --
quit:
quit_begin:	cmp	dword[@_source_id],0
		jnz	quit_sprompt
		mov	eax,quit_ok$
		call	puts
quit_sprompt:	call	xt_refill
		call	xt_0branch
		dd	quit1
		jmp	quit_end
quit1:		call	interpret
		cmp	eax,-1
		jz	quit2
		jmp	quit_begin
quit2:		call	xt_s0
		call	xt_plus
		call	xt_sp_store
		jmp	quit_begin
quit_end:	mov	eax,quit_error$
		call	puts
		ret

open_error$:	db	"Failed to open file",0

; --
boot:		mov	dword[@_last],last

		call	sys_init

		xchg	ebp,esp
		push	filename
		push	filename_len
		push	0
		xchg	ebp,esp
		call	xt_open_file
		call	xt_0branch
		dd	boot1
		mov	eax,open_error$
		call	puts
		call	xt_bye
boot1:
		call	xt_dolit
		dd	@_source_id
		call	xt_store
		call	bootcompile

		call	xt_source_id
		call	xt_close_file
		call	xt_drop

		call	xt_dolit
		dd	0
		call	xt_source_id
		call	xt_store
		call	quit

		call	xt_bye		; Should never reach

; ====================================================================== ;
;		     Linux specific system calls
; ====================================================================== ;

%ifidn __OUTPUT_FORMAT__, elf32
termios:	resd	36

ICANON		equ	1 << 1
ECHO		equ	1 << 3

TCGETS		equ	0x5401
TCSETS		equ	0x5402

gettermios:	mov	eax,54
		mov	ebx,1
		mov	ecx,TCGETS
		mov	edx,termios
		int	0x80
		ret

settermios:	mov	eax,54
		mov	ebx,1
		mov	ecx,TCSETS
		mov	edx,termios
		int	0x80
		ret

sys_init:	call	gettermios
		and	dword[termios+12], ~(ECHO|ICANON)
		call	settermios
		ret

sys_bye:
		or	dword[termios+12], (ECHO|ICANON)
		call	settermios
		mov	eax,1
		mov	ebx,0
		int	0x80

; IN eax: char
sys_putc:	mov	[putctemp],eax
		mov	eax,4		; write
		mov	ebx,1		; stdout
		mov	ecx,putctemp
		mov	edx,1		; 1 character
		int	0x80
		ret

; IN eax: nul terminated string
sys_open:	mov	ebx,eax
		mov	eax,5		; open
		mov	ecx,0
		mov	edx,0
		int	0x80
		ret

sys_close:	mov	ebx,eax		; fd --
		mov	eax,6		; close
		int	0x80
		ret

sys_readc_buf:	dd	1

; Read one byte character into buffer from fd
; when flag is 0, end of file, when -1, error, otherwize number of characters
; read
; fd -- c flag
sys_readc:	mov	ebx,eax		; fd -- c flag
		mov	ecx,sys_readc_buf
		mov	eax,3		; read
		mov	edx,1		; 1 byte
		int	0x80		; eax holds return value
		mov	ebx,eax
		xor	eax,eax
		mov	al,byte[sys_readc_buf]
		ret

%elifidn __OUTPUT_FORMAT__, bin

; ====================================================================== ;
;			       PC boot
; ====================================================================== ;

sys_init:	ret

sys_bye:	ret

sys_putc:
		ret

sys_open:
		ret

sys_close:
		ret

sys_readc:
		ret

%endif