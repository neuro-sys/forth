; ====================================================================== ;
;                        Minimal Forth System
; ====================================================================== ;
;
; Description
; ===========
; Beware, here be elemental FORTH wizardry.
; This program creates a Forth system for intel x86 computers.
;
; Design
; ======
; - Reasonably minimal machine dependent assembly code
; - Ease of porting to other architectures/platforms
; - Aim for the sweet spot between Forth 83 and 94 standards
;
; Build
; =====
; nasm -f elf32         \
;      -w-zeroing       \
;      -F dwarf         \
;      -g               \
;      -l forth-x86.lst \
;      -o forth-x86.o   \
;      forth-x86.asm && \
; ld -m elf_i386        \
;      --omagic         \
;      -o forth-x86     \
;      forth-x86.o &&   \
; ./forth-x86
;
; TODO
; ====
; - Document every word's stack effect
; - Add stack overflow/underflow detection
; - Consider coming up with utilities to help debugging
; - Reduce the primitive words size
; - Convert the following words to hand-coded forth:
;   - compare
;   - find
;   - parse
;   - parse-name
;   - interpret
;   - quit
; - Counted strings use 1 cell for the count (TODO adapt to standard)
; - No "double" numbers (TODO adapt to standard)
; - Consider using block words instead of open-file, etc.
; - Implement rest of the CORE word set
; - Add ability to call external c functions
; - Add PC boot support
; - Can we make it easy to convert to Z80? Meta primitives?
; - Consider using hand-encoded machine code source code
; - List reference books
;   - A Problem Oriented Language
;   - Threaded Interpreted Languages
;   - Forth standards 79, 83, 94
;   - Zen & eForth
;
; Change Log
; ==========
; 20220729 - Add Win32 platform
; 20220513 - Converted >tonumber to hand coded forth.
; 20211215 - Change log added, code formatted, todo added.
; 20211215 - Added ACCEPT in Forth


                            global _start

                            section .bss

; ====================================================================== ;
;                               Memory                                   ;
; ====================================================================== ;

DIC_SIZ         equ     65536   ; Dictionary area
TIB_SIZ         equ     1024    ; Temporary input buffer

dstack:         resd    1024    ; Data stack
dstacke:        equ     $-4
rstack:         resd    1024    ; Return stack
rstacke:        equ     $-4
tib:            resd    TIB_SIZ ; Terminal input buffer area
dictionary:     resd    DIC_SIZ ; Consider making this parametrized
tempregs:       resd    16      ; Temporary storage for host registers

; ====================================================================== ;
;                             Entry point
; ====================================================================== ;

                            section .text

_start:
                mov     [tempregs+0],ebp
                mov     [tempregs+1],esp

                mov     ebp,dstacke
                mov     esp,rstacke

                call    boot

; ====================================================================== ;
;                                EQU
; ====================================================================== ;


m_immediate     equ     (1 << 31)
m_compile_only  equ     (1 << 30)
count_mask      equ     ~(m_immediate + m_compile_only)

; ====================================================================== ;
;                             Primitives
; ====================================================================== ;
; Dictionary entry structure looks like this:
;
; link          1 cell                  ; holds address of next word
; count+masks   1 cell                  ; mask data + name string length
; name          N bytes                 ; word name
; code          N bytes                 ; machine code

; ( -- addr )
w_dovar:        dd      0
                dd      5
                db      "(var)"
xt_dovar:       xchg    ebp,esp
                mov     eax,[ebp]
                push    eax
                xchg    ebp,esp
                add     esp,4
                ret

; ( -- n )
w_doconst:      dd      w_dovar
                dd      7
                db      "(const)"
xt_doconst:     xchg    ebp,esp
                mov     eax,[ebp]
                mov     eax,[eax]
                push    eax
                xchg    ebp,esp
                add     esp,4
                ret

; ( -- n )
w_dolit:        dd      w_doconst
                dd      5
                db      "(lit)"
xt_dolit:       xchg    ebp,esp
                mov     eax,[ebp]
                push    dword[eax]
                xchg    ebp,esp
                add     dword[esp],4
                ret

; ( -- n )
w_cell:         dd      w_dolit
                dd      4
                db      "cell"
xt_cell:        call    xt_doconst
@_cell:         dd      4

; ( -- addr )
w_dp:           dd      w_cell
                dd      2
                db      "dp"
xt_dp:          call    xt_dovar
@_dp:           dd      dictionary

; ( -- addr )
w_num_tib:      dd      w_dp
                dd      4
                db      "#tib"
xt_num_tib:     call    xt_dovar
@_num_tib:      dd      0

; ( -- addr )
w_to_in:        dd      w_num_tib
                dd      3
                db      ">in"
xt_to_in:       call    xt_dovar
@_to_in:        dd      0

; ( -- addr )
w_state:        dd      w_to_in
                dd      5
                db      "state"
xt_state:       call    xt_dovar
@_state:        dd      0

; ( -- addr )
w_last:         dd      w_state
                dd      4
                db      "last"
xt_last:        call    xt_dovar
@_last:         dd      0

; ( -- addr )
w_source_id:    dd      w_last
                dd      9
                db      "source-id"
xt_source_id:   call    xt_dovar
@_source_id:    dd      0

; ( -- addr )
w_base:         dd      w_source_id
                dd      4
                db      "base"
xt_base:        call    xt_dovar
@_base:         dd      10

; ( -- n )
w_s0:           dd      w_base
                dd      2
                db      "s0"
xt_s0:          call    xt_doconst
@_s0:           dd      dstacke

; ( -- n )
w_r0:           dd      w_s0
                dd      2
                db      "r0"
xt_r0:          call    xt_doconst
@_r0:           dd      rstacke

; ( -- n )
w_tib:          dd      w_r0
                dd      3
                db      "tib"
xt_tib:         call    xt_doconst
@_tib:          dd      tib

; ( -- )
w_branch:       dd      w_tib
                dd      8
                db      "(branch)"
xt_branch:      pop     eax
                mov     eax,[eax]
                jmp     eax

; ( n -- )
w_0branch:      dd      w_branch
                dd      9
                db      "(0branch)"
xt_0branch:     xchg    ebp,esp
                pop     eax
                xchg    ebp,esp
                test    eax,eax
                jnz     _0branch_nz
                pop     eax
                mov     eax,[eax]
                jmp     eax
_0branch_nz:    add     dword[esp],4
                ret

; ( -- )
w_bye:          dd      w_0branch
                dd      3
                db      "bye"
xt_bye:         mov     ebp,[tempregs+0]
                mov     esp,[tempregs+1]
                call    sys_bye

; ( addr -- )
w_execute:      dd      w_bye
                dd      7
                db      "execute"
xt_execute:     xchg    ebp,esp
                pop     eax
                xchg    ebp,esp
                pop     ebx
                push    eax
                ret

; ( n addr -- )
w_store:        dd      w_execute
                dd      1
                db      "!"
xt_store:       xchg    ebp,esp
                pop     eax
                pop     ebx
                mov     [eax],ebx
                xchg    ebp,esp
                ret

; ( addr -- n )
w_fetch:        dd      w_store
                dd      1
                db      "@"
xt_fetch:       xchg    ebp,esp
                pop     eax
                push    dword[eax]
                xchg    ebp,esp
                ret

; ( c addr -- )
w_cstore:       dd      w_fetch
                dd      2
                db      "c!"
xt_cstore:      xchg    ebp,esp
                pop     eax
                pop     ebx
                mov     byte[eax],bl
                xchg    ebp,esp
                ret

; ( addr -- c )
w_cfetch:       dd      w_cstore
                dd      2
                db      "c@"
xt_cfetch:      xchg    ebp,esp
                pop     eax
                xor     ebx,ebx
                mov     bl,byte[eax]
                push    ebx
                xchg    ebp,esp
                ret

; ( n n -- n )
w_plus:         dd      w_cfetch
                dd      1
                db      "+"
xt_plus:        xchg    ebp,esp
                pop     eax
                pop     ebx
                add     eax,ebx
                push    eax
                xchg    ebp,esp
                ret

; ( n n -- n )
w_minus:        dd      w_plus
                dd      1
                db      "-"
xt_minus:       xchg    ebp,esp
                pop     ebx
                pop     eax
                sub     eax,ebx
                push    eax
                xchg    ebp,esp
                ret

; ( u1 u2 -- ud )
w_um_star:      dd      w_minus
                dd      3
                db      "um*"
xt_um_star:     xchg    ebp,esp
                pop     ebx
                pop     eax
                xor     edx,edx
                mul     ebx
                push    edx
                push    eax
                xchg    ebp,esp
                ret

; ( ud u1 -- u2 u3 )
w_um_mod:       dd      w_um_star
                dd      6
                db      "um/mod"
xt_um_mod:      xchg    ebp,esp
                pop     ebx
                pop     eax
                xor     edx,edx
                idiv    ebx
                push    edx
                push    eax
                xchg    ebp,esp
                ret

; ( n -- ) ( R: -- n )
w_to_r:         dd      w_um_mod
                dd      2
                db      ">r"
xt_to_r:        pop     eax
                xchg    ebp,esp
                pop     ebx
                xchg    ebp,esp
                push    ebx
                push    eax
                ret

; ( -- n ) ( R: n -- )
w_r_from:       dd      w_to_r
                dd      2
                db      "r>"
xt_r_from:      pop     eax
                pop     ebx
                xchg    ebp,esp
                push    ebx
                xchg    ebp,esp
                push    eax
                ret

; ( n n -- n )
w_and:          dd      w_r_from
                dd      3
                db      "and"
xt_and:         xchg    ebp,esp
                pop     eax
                pop     ebx
                and     eax,ebx
                push    eax
                xchg    ebp,esp
                ret

; ( n n -- n )
w_or:           dd      w_and
                dd      2
                db      "or"
xt_or:          xchg    ebp,esp
                pop     eax
                pop     ebx
                or      eax,ebx
                push    eax
                xchg    ebp,esp
                ret

; ( n n -- n )
w_xor:          dd      w_or
                dd      3
                db      "xor"
xt_xor:         xchg    ebp,esp
                pop     eax
                pop     ebx
                xor     eax,ebx
                push    eax
                xchg    ebp,esp
                ret

; ( n n -- t )
w_equals:       dd      w_xor
                dd      1
                db      "="
xt_equals:      xchg    ebp,esp
                pop     eax
                pop     ebx
                cmp     eax,ebx
                jz      xt_equals1
                push    0
                jmp     xt_equals2
xt_equals1:     push    -1
xt_equals2:     xchg    ebp,esp
                ret

; ( n n -- t )
w_notequals:    dd      w_equals
                dd      2
                db      "<>"
xt_notequals:   call    xt_equals
                call    xt_invert
                ret

; ( n -- n )
w_invert:       dd      w_notequals
                dd      6
                db      "invert"
xt_invert:      call    xt_dolit
                dd      -1
                call    xt_xor
                ret

; ( n -- t )
w_zero_less:    dd      w_invert
                dd      2
                db      "0<"
xt_zero_less:   xchg    ebp,esp
                pop     eax
                cmp     eax,0
                jl      xt_zero_less_l
                mov     eax,0
                jmp     xt_zero_less_e
xt_zero_less_l: mov     eax,-1
xt_zero_less_e: push    eax
                xchg    ebp,esp
                ret

; ( n n -- t )
w_less:         dd      w_zero_less
                dd      4
                db      "less"
xt_less:        xchg    ebp,esp
                pop     ebx
                pop     eax
                cmp     eax,ebx
                jl      xt_less1
                push    dword 0
                jmp     xt_less2
xt_less1:       push    dword -1
xt_less2:       xchg    ebp,esp
                ret

; ( n n -- t)
w_more:         dd      w_less
                dd      4
                db      "more"
xt_more:        xchg    ebp,esp
                pop     ebx
                pop     eax
                cmp     eax,ebx
                jg      xt_more1
                push    dword 0
                jmp     xt_more2
xt_more1:       push    dword -1
xt_more2:       xchg    ebp,esp
                ret

; ( n1 n2 -- n2 n1 )
w_swap:         dd      w_more
                dd      4
                db      "swap"
xt_swap:        mov     eax,[ebp]
                mov     ebx,[ebp+4]
                mov     [ebp],ebx
                mov     [ebp+4],eax
                ret

; ( n1 n2 n3 -- n2 n3 n1 )
w_rot:          dd      w_swap
                dd      3
                db      "rot"
xt_rot:         xchg    ebp,esp
                pop     ecx
                pop     ebx
                pop     eax
                push    ebx
                push    ecx
                push    eax
                xchg    ebp,esp
                ret

; ( n -- )
w_drop:         dd      w_rot
                dd      4
                db      "drop"
xt_drop:        add     ebp,4
                ret

; ( n1 -- n1 n1 )
w_dup:          dd      w_drop
                dd      3
                db      "dup"
xt_dup:         xchg    ebp,esp
                push    dword[esp]
                xchg    ebp,esp
                ret

; ( n1 n2 -- n1 n2 n1 )
w_over:         dd      w_dup
                dd      4
                db      "over"
xt_over:        xchg    ebp,esp
                pop     eax
                pop     ebx
                push    ebx
                push    eax
                push    ebx
                xchg    ebp,esp
                ret

; ( -- n )
w_key:          dd      w_over
                dd      3
                db      "key"
xt_key:         mov     eax,[@_source_id]
                call    sys_readc
                xchg    ebp,esp
                push    eax
                xchg    ebp,esp
                ret

; ( n -- )
w_emit:         dd      w_key
                dd      4
                db      "emit"
xt_emit:        xchg    ebp,esp
                pop     eax
                call    sys_putc
                xchg    ebp,esp
                ret

; ( n -- )
w_comma:        dd      w_emit
                dd      1
                db      ","
xt_comma:       xchg    ebp,esp
                pop     eax
                xchg    ebp,esp
comma:          mov     ebx,[@_dp]
                mov     [ebx],eax
                add     dword[@_dp],4
                ret

; ( c -- )
w_c_comma:      dd      w_comma
                dd      2
                db      "c,"
xt_c_comma:     xchg    ebp,esp
                pop     eax
                xchg    ebp,esp
                mov     ebx,[@_dp]
                mov     byte[ebx],al
                inc     dword[@_dp]
                ret

; ( addr -- addr )
w_nfa:          dd      w_c_comma
                dd      3
                db      "nfa"
xt_nfa:         xchg    ebp,esp
                pop     eax
                xchg    ebp,esp
                call    nfa
                xchg    ebp,esp
                push    eax
                xchg    ebp,esp
                ret

nfa:            add     eax,4
                ret

; ( addr -- addr )
w_cfa:          dd      w_nfa
                dd      3
                db      "cfa"
xt_cfa:         xchg    ebp,esp
                pop     eax
                xchg    ebp,esp
                call    cfa
                xchg    ebp,esp
                push    eax
                xchg    ebp,esp
                ret

cfa:            call    nfa
                mov     ebx,[eax]
                and     ebx,count_mask
                add     eax,4
                add     eax,ebx
                ret

; ( -- addr )
w_sp_fetch:     dd      w_cfa
                dd      3
                db      "sp@"
xt_sp_fetch:    xchg    ebp,esp
                push    esp
                xchg    ebp,esp
                ret

; ( addr -- )
w_sp_store:     dd      w_sp_fetch
                dd      3
                db      "sp!"
xt_sp_store:    xchg    ebp,esp
                pop     eax
                mov     esp,eax
                xchg    ebp,esp
                ret

; ( -- addr )
w_rp_fetch:     dd      w_sp_store
                dd      3
                db      "rp@"
xt_rp_fetch:    xchg    ebp,esp
                push    ebp
                xchg    ebp,esp
                ret

; ( addr -- )
w_rp_store:     dd      w_rp_fetch
                dd      3
                db      "rp!"
xt_rp_store:    xchg    ebp,esp
                pop     eax
                mov     ebp,eax
                xchg    ebp,esp
                ret

; ====================================================================== ;
;                       Hand coded Forth words
; ====================================================================== ;

; ( n1 n2 -- n1 n2 n1 n2 )
w_2dup:         dd      w_rp_store
                dd      4
                db      "2dup"
xt_2dup:        call    xt_over
                call    xt_over
                ret

; ( n1 n2 n3 -- n3 n1 n2 )
w_dash_rot:     dd      w_2dup
                dd      4
                db      "-rot"
xt_dash_rot:    call    xt_rot
                call    xt_rot
                ret

; ( -- addr )
w_here:         dd      w_dash_rot
                dd      4
                db      "here"
xt_here:        call    xt_dp
                call    xt_fetch
                ret

; ( -- )
w_backspace:    dd      w_here
                dd      8
                db      "backspace"
; : backspace 8 emit 32 emit 8 emit ;
xt_backspace:   call    xt_dolit
                dd      8
                call    xt_emit
                call    xt_dolit
                dd      32
                call    xt_emit
                call    xt_dolit
                dd      8
                call    xt_emit
                ret

; : accept ( addr n -- n )
;   2dup
;   begin
;     key dup  10 <>
;         over 13 <> and
;         over       and
;   while
;     dup 127 = if drop backspace
;                  swap 1- swap 1+
;               else
;                 rot 2dup c! -rot emit
;                 swap 1+ swap 1-
;               then
;   repeat drop
;   drop swap drop swap -
; ;
w_accept:       dd      w_backspace
                dd      6
                db      "accept"
xt_accept:      call    xt_2dup
xt_accept1:     call    xt_key
                call    xt_dup
                call    xt_dolit
                dd      10
                call    xt_notequals
                call    xt_over
                call    xt_dolit
                dd      13
                call    xt_notequals
                call    xt_and
                call    xt_over
                call    xt_and
                call    xt_0branch
                dd      xt_accept2
                call    xt_dup
                call    xt_dolit
                dd      127
                call    xt_equals
                call    xt_0branch
                dd      xt_accept3
                call    xt_drop
                call    xt_backspace
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_minus
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_plus
                jmp     xt_accept4
xt_accept3:     call    xt_rot
                call    xt_2dup
                call    xt_cstore
                call    xt_dash_rot
                call    xt_emit
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_plus
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_minus
xt_accept4:     jmp     xt_accept1
xt_accept2:     call    xt_drop
                call    xt_drop
                call    xt_swap
                call    xt_drop
                call    xt_swap
                call    xt_minus
                ret

; : refill tib 80 accept #tib ! 0 >in ! 0 ;
w_refill:       dd      w_accept
                dd      6
                db      "refill"
xt_refill:      call    xt_tib
                call    xt_dolit
                dd      80
                call    xt_accept
                call    xt_num_tib
                call    xt_store
                call    xt_dolit
                dd      0
                call    xt_to_in
                call    xt_store
                call    xt_dolit
                dd      -1
                ret

w_less_or_equal:
                dd      w_refill
                dd      2
                db      "<="
xt_less_or_equal:
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_minus
                call    xt_swap
                call    xt_less
                ret

w_more_or_equal:
                dd      w_less_or_equal
                dd      2
                db      ">="
xt_more_or_equal:
                call    xt_dolit
                dd      1
                call    xt_minus
                call    xt_more
                ret

; : between rot swap over >= -rot <= and ;
w_between:      dd      w_more_or_equal
                dd      7
                db      "between"
xt_between:     call    xt_rot
                call    xt_swap
                call    xt_over
                call    xt_more_or_equal
                call    xt_dash_rot
                call    xt_less_or_equal
                call    xt_and
                ret

; : >number  ( c-addr1 u1 -- n flag )
;   over c@ 45 =          ( is minus sign? )
;   if -1 -rot ( sign ) 1- swap 1+ swap ( skip sign char )
;   else 1 -rot ( sign ) then  ( sign string length )
;   swap                  ( sign length string )
;   0 >r                  ( sign length string ) ( R: 0 )
;   begin
;     dup c@              ( sign length string c ) ( R: 0 )
;     dup 48 57 between             if [char] 0 -       else
;     32 or dup 98 102 between      if [char] a - 10 +  else
;     rdrop 2drop 2drop false exit  then then
;                         ( sign length string n ) ( R: 0 )
;     r> base @ * + >r    ( sign length string ) ( R: n1 )
;     1+ swap 1- swap     ( sign length-1 string+1 ) ( R: n1 )
;     over 0=
;   until
;   2drop
;   r> * true
; ;
w_tonumber:     dd      w_between
                dd      7
                db      ">number"
xt_tonumber:    call    xt_over
                call    xt_cfetch
                call    xt_dolit
                dd      45
                call    xt_equals       ; over c@ 45 =
                call    xt_0branch
                dd      xt_tonumber2
xt_tonumber1:   call    xt_dolit
                dd      -1
                call    xt_dash_rot
                call    xt_dolit
                dd      1
                call    xt_minus
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_plus
                call    xt_swap         ; 1- swap 1+ swap
                jmp     xt_tonumber3
xt_tonumber2:   call    xt_dolit
                dd      1
                call    xt_dash_rot
xt_tonumber3:   call    xt_swap         ; swap
                call    xt_dolit
                dd      0
                call    xt_to_r         ; 0 >r
xt_tonumber5:   call    xt_dup
                call    xt_cfetch       ; dup c@
                call    xt_dup
                call    xt_dolit
                dd      '0'
                call    xt_dolit
                dd      '9'
                call    xt_between
                call    xt_0branch
                dd      xt_tonumber6
                call    xt_dolit
                dd      '0'
                call    xt_minus        ; [char] 0 -
                jmp     xt_tonumber8
xt_tonumber6:   call    xt_dolit
                dd      32
                call    xt_or           ; 32 or
                call    xt_dup
                call    xt_dolit
                dd      'a'
                call    xt_dolit
                dd      'f'
                call    xt_between
                call    xt_0branch
                dd      xt_tonumber7
                call    xt_dolit
                dd      'a'
                call    xt_minus
                call    xt_dolit
                dd      10
                call    xt_plus         ; [char] a - 10 +
                jmp     xt_tonumber8
xt_tonumber7:   call    xt_r_from
                call    xt_drop         ; rdrop
                call    xt_drop
                call    xt_drop         ; 2drop
                call    xt_drop
                call    xt_drop         ; 2drop
                call    xt_dolit
                dd      0
                ret
xt_tonumber8:   call    xt_r_from
                call    xt_base
                call    xt_fetch
                call    xt_um_star
                call    xt_swap
                call    xt_drop
                call    xt_plus
                call    xt_to_r
                call    xt_dolit
                dd      1
                call    xt_plus
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_minus
                call    xt_swap         ; 1+ swap 1- swap
                call    xt_over
                call    xt_dolit
                dd      0
                call    xt_equals       ; over 0 =
                call    xt_0branch
                dd      xt_tonumber5
                call    xt_drop
                call    xt_drop
                call    xt_r_from
                call    xt_um_star
                call    xt_swap
                call    xt_drop         ; 2drop r> *
                call    xt_dolit
                dd      -1
                ret

; : cmove ( c-addr1 c-addr2 u -- )
;   begin
;     dup 0<>
;   while
;     -rot               ( u c-addr1 c-addr2 )
;     over c@ over c!    ( copy a byte )
;     1+ swap 1+ swap    ( increment src and dest )
;     rot                ( c-addr1 c-addr2 u )
;     1-                 ( decrement u )
;   repeat 2drop drop
; ;
w_cmove:        dd      w_tonumber
                dd      5
                db      "cmove"
xt_cmove:       call    xt_dup
                call    xt_dolit
                dd      0
                call    xt_notequals
                call    xt_0branch
                dd      xt_cmove2
                call    xt_dash_rot
                call    xt_over
                call    xt_cfetch
                call    xt_over
                call    xt_cstore
                call    xt_dolit
                dd      1
                call    xt_plus
                call    xt_swap
                call    xt_dolit
                dd      1
                call    xt_plus
                call    xt_swap
                call    xt_rot
                call    xt_dolit
                dd      1
                call    xt_minus
                jmp     xt_cmove
xt_cmove2:      call    xt_drop
                call    xt_drop
                call    xt_drop
                ret

; : : parse-name       ( c-addr n )
;     dup rot swap     ( n caddr n )
;     here             ( save here )
;     last @ ,         ( store last word address )
;     last !           ( make the current addr last )
;     dup ,            ( save name count )
;     here swap cmove  ( copy name )
;     here + dp !      ( advance dp )
;     -1 state !
; ;
w_colon:        dd      w_cmove
                dd      1
                db      ":"
xt_colon:       call    xt_parse_name
                call    xt_dup
                call    xt_rot
                call    xt_swap
                call    xt_here
                call    xt_last
                call    xt_fetch
                call    xt_comma
                call    xt_last
                call    xt_store
                call    xt_dup
                call    xt_comma
                call    xt_here
                call    xt_swap
                call    xt_cmove
                call    xt_here
                call    xt_plus
                call    xt_dp
                call    xt_store
                call    xt_dolit
                dd      -1
                call    xt_state
                call    xt_store
                ret


; This is specific to the STC model we use
w_semicolon:    dd      w_colon
                dd      1 + m_immediate
                db      ";"
xt_semicolon:   call    xt_dolit
                dd      0xc3            ; compile near return
                call    xt_c_comma
                call    xt_dolit
                dd      0
                call    xt_state
                call    xt_store
                ret

; This is specific to the STC model we use
w_compile_comma:
                dd      w_semicolon
                dd      8
                db      "compile,"
xt_compile_comma:
                call    xt_dolit
                dd      0xe8	; compile call
                call    xt_c_comma
                call    xt_dp
                call    xt_fetch
                call    xt_minus
                call    xt_cell
                call    xt_minus
                call    xt_comma
                ret

; : space?	( c -- t )	dup 32 = swap 9 = or ;
w_space_q:	dd      w_compile_comma
		dd 	6
		db	"space?"
xt_space_q:	call	xt_dup
		call	xt_dolit
		dd	32
		call	xt_equals
		call	xt_swap
		call	xt_dolit
		dd	9
		call	xt_equals
		call	xt_or
		ret

; ( char "ccc<char>" -- c-addr u )
; : parse         ( char "ccc<char>" -- c-addr u )
;    >in @ 1+ tib + swap          ( caddr c )
;    begin
;     over c@ over <> >r          ( caddr c )
;     over tib #tib @ + <>        ( caddr c )
;     r> and
;    while
;     swap 1+ swap                ( next addr )
;    repeat
;    drop                         ( caddr )
;    tib >in @ + 1+               ( caddr c-addr )
;    over tib >in @ + - 1-        ( caddr c-addr u )
;    rot tib - 1+ >in !
; ;
w_parse:        dd      w_space_q
                dd      5
                db      "parse"
xt_parse:       call    xt_to_in
		call	xt_fetch
		call	xt_dolit
		dd	1
		call	xt_plus
		call	xt_tib
		call	xt_plus
		call	xt_swap
xt_parse1:	call	xt_over
		call	xt_cfetch
		call	xt_over
		call	xt_notequals
		call	xt_to_r
		call	xt_over
		call	xt_tib
		call	xt_num_tib
		call	xt_fetch
		call	xt_plus
		call	xt_notequals
		call	xt_r_from
		call	xt_and
		call	xt_0branch
		dd	xt_parse2
		call	xt_swap
		call	xt_dolit
		dd	1
		call	xt_plus
		call	xt_swap
		jmp	xt_parse1
xt_parse2:	call	xt_drop
		call	xt_tib
		call	xt_to_in
		call	xt_fetch
		call	xt_plus
		call	xt_dolit
		dd	1
		call	xt_plus
		call	xt_over
		call	xt_tib
		call	xt_to_in
		call	xt_fetch
		call	xt_plus
		call	xt_minus
		call	xt_dolit
		dd	1
		call	xt_minus
		call	xt_rot
		call	xt_tib
		call	xt_minus
		call	xt_dolit
		dd	1
		call	xt_plus
		call	xt_to_in
		call	xt_store
		ret

; ( "<spaces>name<space>" -- c-addr u)
w_parse_name:   dd      w_parse
                dd      10
                db      "parse-name"
; xt_parse_name:
; 		call	xt_to_in
; 		call	xt_fetch
; 		call	xt_dolit
; 		dd	1
; 		call	xt_tib
; 		call	xt_plus
; xt_parse_nam1:	call	xt_dup
; 		call	xt_cfetch
; 		call	xt_dolit
; 		dd	32
; 		call	xt_notequals
; 		call	xt_over
; 		call	xt_cfetch
; 		call	xt_dolit
; 		dd	10
; 		call	xt_notequals
; 		call	xt_and
; 		call	xt_0branch
; 		dd	xt_parse_nam2
; 		call	xt_dolit
; 		dd	1
; 		call	xt_plus
; xt_parse_nam2:	call	xt_drop
; 		call	xt_dolit
; 		dd	32
; 		call	xt_parse
; 		ret

xt_parse_name:  mov     eax,[@_tib]
                mov     edx,eax
                add     eax,[@_to_in]
                add     edx,[@_num_tib] ; end c-addr
                mov     ecx,eax         ; backup first c-addr
_parse_name2:   cmp     eax,edx
                jz      _parse_name1
                cmp     byte[eax],32    ; space
                jz      _parse_name5
		cmp	byte[eax],9	; tab
		jz	_parse_name5
		jmp	_parse_name1
_parse_name5:   inc     eax
                jmp     _parse_name2
_parse_name1:   mov     ebx,eax         ; backup begin c-addr
_parse_name4:   cmp     eax,edx
                jz      _parse_name3
                cmp     byte[eax],32	; space
                jz      _parse_name3
		cmp     byte[eax],9     ; tab
		jz      _parse_name3
                inc     eax
                jmp     _parse_name4
_parse_name3:   mov     edx,eax
                sub     edx,ecx         ; edx offset
                add     [@_to_in],edx
                sub     eax,ebx         ; u
                xchg    ebp,esp
                push    ebx
                push    eax
                xchg    ebp,esp
                ret

w_compare:      dd      w_parse_name
                dd      7
                db      "compare"
; : compare     ( caddr1 u1 caddr2 u2 -- t )
;    rot 2dup <>                  ( caddr1 caddr2 u1 u2 t )
;    if 2drop 2drop false exit
;    else drop then               ( caddr1 caddr2 u2 )
;    begin
;     dup
;    while
;     >r                          ( caddr1 caddr2 )
;     over c@ over c@             ( caddr1 caddr2 c1 c2 )
;     <> if rdrop 2drop false exit then
;     r>                          ( caddr1 caddr2 u2 )
;     1-
;    repeat
;    drop 2drop true ;
xt_compare:     call    xt_rot
                call    xt_2dup
                call    xt_notequals
                call    xt_0branch
                dd      xt_compare1
                call    xt_drop
                call    xt_drop
                call    xt_drop
                call    xt_drop
                call    xt_dolit
                dd      0
                ret
xt_compare1:    call    xt_drop
xt_compare2:    call    xt_dup
                call    xt_0branch
                dd      xt_compare3
                call    xt_to_r
                call    xt_over
                call    xt_cfetch
                call    xt_over
                call    xt_cfetch
                call    xt_notequals
                call    xt_0branch
                dd      xt_compare4
                call    xt_r_from
                call    xt_drop
                call    xt_drop
                call    xt_drop
                call    xt_dolit
                dd      0
                ret
xt_compare4:    call    xt_r_from
                call    xt_dolit
                dd      1
                call    xt_minus
                jmp     xt_compare2
xt_compare3:    call    xt_drop
                call    xt_drop
                call    xt_drop
                call    xt_dolit
                dd      -1
                ret

w_find:         dd      w_compare
                dd      4
                db      "find"
; : find                ( caddr u -- xt )
;    2dup                        ( caddr u caddr u )
;    last @                      ( caddr u caddr u addr )
;    begin
;     dup
;    while
;     dup >r                     ( caddr u caddr u addr )
;     nfa count #mask invert and ( caddr u caddr u caddr2 u2 )
;     compare if 2drop r> exit then
;     2dup                       ( caddr u caddr u )
;     r> @
;    repeat
; ;
xt_find:        call	xt_2dup
		call	xt_last
		call	xt_fetch
xt_find1:	call	xt_dup
		call	xt_0branch
		dd	xt_find2
		call	xt_dup
		call	xt_to_r
		call	xt_nfa
; : count
    	      	call    xt_dup
		call	xt_cell
		call	xt_plus
		call	xt_swap
		call	xt_fetch
; ;
		call	xt_dolit
		dd	count_mask
		call	xt_and
		call	xt_compare
		call	xt_0branch
		dd	xt_find3
		call	xt_drop
		call	xt_drop
		call	xt_r_from
		ret
xt_find3:	call	xt_2dup
		call	xt_r_from
		call	xt_fetch
		jmp	xt_find1
xt_find2:	ret

last            equ     w_find

; ====================================================================== ;
;                         Inner Interpreter
; ====================================================================== ;
;
; This part is a program that loads and compiles the rest of the Forth
; in Forth from source file. It is a minimal Forth compiler and
; interpreter.
;
                            section .text

compare_a:      resd    1
compare_n:      resd    1
compare_b:      resd    1
compare_u:      resd    1

; c-addr1 u1 c-addr2 u2 -- flag
; note that it is case insensitive
compare:        mov     [compare_a],eax
                mov     [compare_n],ebx
                mov     [compare_b],ecx
                cmp     dword[compare_n],edx
                jz      compare_s       ; if counts not match
                mov     eax,-1          ; return false
                ret
compare_s:      mov     ecx,0           ; set found flag
compare2:       xor     eax,eax
                mov     al,[compare_n]
                cmp     al,0
                jz      compare_e
                mov     ebx,[compare_a]
                xor     eax,eax
                mov     al,byte[ebx]
                mov     ecx,[compare_b]
                xor     ebx,ebx
                mov     bl,byte[ecx]
                bts     eax,5
                bts     ebx,5
                cmp     al,bl
                jnz     compare1
                inc     dword[compare_a]
                inc     dword[compare_b]
                dec     dword[compare_n]
                jmp     compare2
compare1:       mov     ecx,-1          ; clear found flag
compare_e:      mov     eax,ecx
                ret


find_str:       resd    1
find_u:         resd    1
find_curlink:   resd    1

; c-addr u -- xt
find:           mov     [find_str],eax
                mov     [find_u],ebx
                mov     eax,[@_last]    ; link
                mov     [find_curlink],eax
find1:          mov     eax,[find_curlink]
                add     eax,4           ; we are at count
                mov     ebx,[eax]       ; count
                and     ebx,count_mask
                add     eax,4           ; name
                mov     ecx,[find_str]
                mov     edx,[find_u]
                call    compare
                cmp     eax, -1
                jz      find_n          ; not found
                mov     eax,[find_curlink]
                ret                     ; found and return
find_n:         mov     eax,[find_curlink]
                mov     eax,[eax]       ; next link
                or      eax,eax
                jz      find_e
                mov     [find_curlink],eax
                jmp     find1
find_e:         mov     eax,0
                ret



filename:       db      "forth.fs",0
filename_len:   equ     $-filename

; Consider getting rid of open-file and close-file and use blocks instead
; Alternatively just embed the forth source into the memory image, and
; do not read from disk at all
; ( c-addr u fam -- fileid ior )
w_open_file:    dd      w_parse_name
                dd      9
                db      "open-file"
xt_open_file:   xchg    ebp,esp
                pop     eax             ; ignore fam
                pop     ebx
                pop     eax
                xchg    ebp,esp
                add     ebx,eax
                mov     byte[ebx],0     ; Potential bug, this is wrong
                call    sys_open
                cmp     eax,0
                js      open_error
                xchg    ebp,esp
                push    eax
                push    0
                xchg    ebp,esp
                ret
open_error:     xchg    ebp,esp
                push    0
                push    eax
                xchg    ebp,esp
                ret

; ( fileid -- ior )
w_close_file:   dd      w_open_file
                dd      10
                db      "close-file"
xt_close_file:  xchg    ebp,esp
                pop     eax
                xchg    ebp,esp
                call    sys_close
                mov     dword[@_source_id],0
                cmp     eax,eax
                jnz     close_error
                call    xt_dolit
                dd      0
                ret
close_error:    xchg    ebp,esp
                push    eax
                xchg    ebp,esp
                ret


; Display zero terminated string
puts:           mov     bl,byte[eax]    ; caddr --
                test    bl,bl
                jz      puts_e
                push    eax
                xor     eax,eax
                mov     al,bl
                call    sys_putc
                pop     eax
                inc     eax
                jmp     puts
puts_e:         ret

; Display counter string
puts1:          test    ebx,ebx         ; c-addr u --
                jz      puts1_e
                push    eax
                push    ebx
                mov     al,byte[eax]
                call    sys_putc
                pop     ebx
                pop     eax
                inc     eax
                dec     ebx
                jmp     puts1
puts1_e:        ret

readline_error_str:
                db     "Failed to read file",0

readline_buf:   resd    1

; FIXME use ACCEPT?
; Read one line excluding the newline character at most size bytes
; into buffer from fd.
readline:       mov     dword[readline_buf],tib      ; -- u
                xor     ecx,ecx
                mov     [@_num_tib],ecx
readline1:      mov     eax,[@_num_tib]
                cmp     eax,TIB_SIZ
                jz      readline_e
                mov     eax,[@_source_id]
                call    sys_readc
                cmp     ebx,-1
                jz      readline_error
                test    ebx,ebx
                jz      readline_eof
; Echo the characters
               ; push    eax
               ; call    sys_putc
               ; pop     eax
                cmp     al,10           ; new line
                jz      readline_e
                cmp     al,13           ; new line
                jz      readline_e
                cmp     al,127          ; backspace
                jz      readline_bs
                mov     ebx,[readline_buf];
                mov     byte[ebx],al
                inc     dword[@_num_tib]
                inc     dword[readline_buf]
                jmp     readline1
readline_e:     mov     eax,0
                ret
readline_eof:   mov     eax,-1
                ret
readline_bs:    jmp     readline1
readline_error: mov     eax,readline_error_str
                call    puts
                call    xt_bye

; FIXME write in Forth
interpret:      call    xt_parse_name
                xchg    ebp,esp
                pop     ebx
                pop     eax
                xchg    ebp,esp
                cmp     ebx,0
                jz      interpret_end

		mov     [find_str],eax
                mov     [find_u],ebx
                call    find
		; xchg	ebp,esp
		; push	eax
		; push	ebx
		; xchg	ebp,esp
		; call	xt_find
		; xchg	ebp,esp
		; pop	eax
		; xchg	ebp,esp

                or      eax,eax
                jz      interpret_to_tonumber

                mov     [quit_curhead],eax

                cmp     dword[@_state],0
                jz      interpret_execute

                mov     eax,[quit_curhead]
                add     eax,4
                test    dword[eax],m_immediate
                jnz     interpret_execute

                mov     eax,[quit_curhead]
                call    cfa

                xchg    ebp,esp
                push    eax
                xchg    ebp,esp
                call    xt_compile_comma

                jmp     interpret
interpret_execute:

                mov     eax,[quit_curhead]
                call    cfa
                call    eax

                jmp     interpret

interpret_to_tonumber:
                mov     eax,[find_str]
                mov     ebx,[find_u]
                xchg    ebp,esp
                push    eax
                push    ebx
                xchg    ebp,esp
                call    xt_tonumber
                xchg    ebp,esp
                pop     ebx
                pop     eax
                xchg    ebp,esp
                cmp     ebx,0
                jz      interpret_abort

                push    eax             ; save the number

                cmp     dword[@_state],0
                jz      interpret_tonumber_execute

                call    xt_dolit
                dd      xt_dolit
                call    xt_compile_comma

                pop     eax
                call    comma

                jmp     interpret

interpret_tonumber_execute:

                pop     eax
                xchg    ebp,esp
                push    eax             ; push to ds
                xchg    ebp,esp

                jmp     interpret

                mov     eax,0
interpret_end:  ret

interpret_abort:
                mov     eax,10
                call    sys_putc
                mov     eax,[find_str]
                mov     ebx,[find_u]
                call    puts1
                mov     eax,interpret_abort$
                call    puts
                call    xt_dolit
                dd      0
                call    xt_state
                call    xt_store
                mov     eax,-1
                ret

interpret_abort$:
                db      " is undefined word",10,0

; --
bootrefill:     call    readline
                mov     ebx,[readline_buf]
                sub     ebx,tib
                mov     [@_num_tib],ebx
                mov     dword[@_to_in],0
                ret


bootcompile:    call    bootrefill
                cmp     eax,-1
                jz      bootcompile_e
                call    interpret
                jmp     bootcompile
bootcompile_e:  ret

quit_ok$:       db      " ok",10,0
quit_error$:    db      " Failed to read input",10,0

quit_curhead:   resd    1

; FIXME write in FORTH
; In forth quit is the entry point for the outer interpreter
quit:
quit_begin:     cmp     dword[@_source_id],0
                jnz     quit_sprompt
                mov     eax,quit_ok$
                call    puts
quit_sprompt:   call    xt_refill
                call    xt_invert
                call    xt_0branch
                dd      quit1
                jmp     quit_end
quit1:          call    interpret
                cmp     eax,-1
                jz      quit2
                jmp     quit_begin
quit2:          call    xt_s0
                call    xt_sp_store
                jmp     quit_begin
quit_end:       mov     eax,quit_error$
                call    puts
                ret

open_error$:    db      "Failed to open file",0

; --
boot:           mov     dword[@_last],last

                call    sys_init

                xchg    ebp,esp
                push    filename
                push    filename_len
                push    0
                xchg    ebp,esp
                call    xt_open_file
                call    xt_0branch
                dd      boot1
                mov     eax,open_error$
                call    puts
                call    xt_bye
boot1:
                call    xt_dolit
                dd      @_source_id
                call    xt_store
                call    bootcompile

                call    xt_source_id
                call    xt_fetch        ; Check if this breaks linux
                call    xt_close_file
                call    xt_drop

                call    xt_dolit
                dd      0
                call    xt_source_id
                call    xt_store
                call    quit

                call    xt_bye          ; Should never reach

; ====================================================================== ;
;                    Linux specific system calls
; ====================================================================== ;

%ifidn __OUTPUT_FORMAT__, elf32
termios:        resd    36

ICANON          equ     1 << 1
ECHO            equ     1 << 3

TCGETS          equ     0x5401
TCSETS          equ     0x5402

gettermios:     mov     eax,54
                mov     ebx,1
                mov     ecx,TCGETS
                mov     edx,termios
                int     0x80
                ret

settermios:     mov     eax,54
                mov     ebx,1
                mov     ecx,TCSETS
                mov     edx,termios
                int     0x80
                ret

sys_init:       call    gettermios
                and     dword[termios+12], ~(ECHO|ICANON)
                call    settermios
                ret

sys_bye:
                or      dword[termios+12], (ECHO|ICANON)
                call    settermios
                mov     eax,1
                mov     ebx,0
                int     0x80

; IN eax: char
sys_putctemp:   resd    1
sys_putc:       mov     [sys_putctemp],eax
                mov     eax,4           ; write
                mov     ebx,1           ; stdout
                mov     ecx,sys_putctemp
                mov     edx,1           ; 1 character
                int     0x80
                ret

; IN eax: nul terminated string
sys_open:       mov     ebx,eax
                mov     eax,5           ; open
                mov     ecx,0
                mov     edx,0
                int     0x80
                ret

sys_close:      mov     ebx,eax         ; fd --
                mov     eax,6           ; close
                int     0x80
                ret

sys_readc_buf:  dd      1

; Read one byte character into buffer from fd
; when flag is 0, end of file, when -1, error, otherwize number of characters
; read
; fd -- c flag
sys_readc:      mov     ebx,eax         ; fd -- c flag
                mov     ecx,sys_readc_buf
                mov     eax,3           ; read
                mov     edx,1           ; 1 byte
                int     0x80            ; eax holds return value
                mov     ebx,eax
                xor     eax,eax
                mov     al,byte[sys_readc_buf]
                ret

%elifidn __OUTPUT_FORMAT__, bin

; ====================================================================== ;
;                              PC boot
; ====================================================================== ;

sys_init:       ret

sys_bye:        ret

sys_putc:
                ret

sys_open:
                ret

sys_close:
                ret

sys_readc:
                ret

; ====================================================================== ;
;                              Win32
; ====================================================================== ;

%elifidn __OUTPUT_FORMAT__, win32
extern          _printf
extern          _putchar
extern          _exit
extern          _fopen
extern          _fclose
extern          _fgetc
extern          _getchar

STD_OUTPUT_HANDLE   equ -11
STD_INPUT_HANDLE    equ -10

extern          _ExitProcess@4, _GetStdHandle@4, _WriteConsoleA@20, _ReadConsoleInputA@16

stdoutfd:       resd    1
stdinfd:        resd    1

sys_init:

                push    STD_OUTPUT_HANDLE
                call    _GetStdHandle@4
                mov     [stdoutfd],eax

                push    STD_INPUT_HANDLE
                call    _GetStdHandle@4
                mov     [stdinfd],eax

                ret


sys_bye:        push    dword 0
                call    _ExitProcess@4
                add     esp,4
                ret

sys_putcbuf:    resd    1
sys_putcbuf2:   resd    4

sys_putc:       mov     [sys_putcbuf],eax
                push    0
                push    sys_putcbuf2
                push    1
                push    sys_putcbuf
                push    dword[stdoutfd]
                call    _WriteConsoleA@20
                ; push  eax
                ; call  _putchar
                ; add   esp,4
                ret

sys_openmode:   db      "r",0

sys_open:       push    sys_openmode    ; c-addr --
                push    eax
                call    _fopen
                add     esp,8
                ret

sys_close:      push    eax             ; c-addr --
                call    _fclose
                add     esp,4
                ret

; fd -- c flag
sys_readc:      cmp     eax,0
                jz      sys_readc1
                push    eax
                call    _fgetc
                add     esp,4
                cmp     eax,-1
                jz      sys_readc2
                mov     ebx,1
                ret
sys_readc2:     mov     ebx,0
                ret
sys_readc1:     call    _getchar
                mov     ebx,1
                ret

%endif
