: hex     16 base ! ;
: decimal 10 base ! ;

hex
: #immediate   80000000 ;
: #compile-only 8000000 ;
: #mask #immediate #compile-only or ;
decimal

: mask!        last @ nfa dup @ rot or swap ! ;
: immediate    #immediate mask! ;
: compile-only #compile-only mask! ;

: 2drop drop drop ;
: tuck dup rot swap ;

: ) 41 ;
: ( ) parse 2drop ; immediate
( now we can write comments between parantheses )

: / um/mod swap drop ;
: * um* swap drop ;
: mod um/mod drop ;

: \ refill drop ;
\ We can also do comments without enclosing token

: ' parse-name find cfa ;

: compile r> dup 1 + dup @ + cell + compile, cell 1 + + >r ;
( note that this definition is specific to x86 far call )
( it should be better abstracted away with a primitive word )

: [compile] ' compile, ; immediate

: literal compile (lit) , ; immediate
: ['] ' literal ;

: [ -1 state ! ; immediate
: ] 0 state ! ; immediate

: here dp @ ;
: cells cell * ;

: if compile (0branch) here 0 , ; immediate
: else compile (branch) here 0 , swap here swap ! ; immediate
: then here swap ! ; immediate

: begin here ; immediate
: while [compile] if ; immediate
: repeat compile (branch) swap , here swap ! ; immediate
: again compile (branch) , ; immediate
: until compile (0branch) , ; immediate

: clearstack s0 + sp! ;

: exit r> drop ;
: 2dup over over ;

: < 2dup xor 0< if drop 0< exit then - 0< ;
: > < invert ;

: 1+ 1 + ;
: 1- 1 - ;
: 2+ 2 + ;
: 2- 2 - ;

: = xor if 0 exit then -1 ;
: <> = invert ;

: 0<> 0 <> ;
: 0> 0 > ;

: +! dup @ rot + swap ! ;

: -rot rot rot ;
: 0= 0 = ;
: nip swap drop ;

: type ( caddr u -- )
  begin
    dup
  while
    swap dup c@ emit 1+ swap
    1-
  repeat 2drop
;

: allot here + dp ! ;

: create parse-name        ( parse next word )
         here last @ ,     ( save last link here )
         last !
         dup ,             ( save name count )
         dup >r
         here swap cmove   ( save name )
         r> allot
         compile (var) ;

: variable create 0 , ;

: bl 32 ;
: cr 10 emit ;
: space bl emit ;

: char bl parse drop c@ ;
: [char] char [compile] literal ; immediate

: count dup cell + swap @ ;
: (.") r> dup count type dup @ dup >r  + 4 + r> allot >r ;
: !" dup , dup >r here swap cmove r> allot ;
: ." [char] " parse state @ if compile (.") !" else type then ; immediate

: pad here 80 + ;
variable hld

: extract um/mod swap 9 over < 7 and + [char] 0 + ;
: <# pad hld ! ;
: hold ( c -- ) hld @ 1 - dup hld ! c! ;
: # ( u -- u ) base @ extract hold ;
: #s ( u -- 0 ) begin # dup while repeat ;
: #> drop hld @ pad over - ;
: sign 0< if [char] - hold then ;

: u. <# #s #> space type ;

: negate invert 1 + ;
: abs dup 0< if negate then ;

: +. dup >r abs <# #s r> sign #> ;

: . base @ 10 <>
    if u. exit then
    +. space type ;

: depth s0 sp@ - 4 / ;

: words
  cr
  last @
  begin
    dup
  while
    dup nfa count #mask invert and type space
    @
  repeat drop
;

: .s
  cr
  depth [char] <   emit
    dup [char] 0 + emit
        [char] >   emit
  begin
    dup
  while
    dup 1-
    depth 1- swap -
    cells s0 2 cells + swap - @ .
    1-
  repeat drop
;

: 2>r compile >r compile >r ; immediate
: 2r> compile r> compile r> ; immediate

variable (i)
: i (i) @ ;

: (do) dup (i) ! 2dup r> -rot 2>r >r <> ;
: (loop) r> 2r> 1+ rot >r ;
: unloop r> 2r> 2drop >r ;

: do here
     compile (do)
     compile (0branch) here 0 , ; immediate

: loop swap
       compile (loop)
       compile (branch) ,
       here swap !
       compile unloop ; immediate

: backspace 8 emit 32 emit 8 emit ;

: accept ( addr n -- n )
  2dup
  begin
    key dup  10 <>
        over 13 <> and
        over       and
  while
    dup 127 = if drop backspace
                 swap 1- swap 1+
              else
                rot 2dup c! -rot emit
                swap 1+ swap 1-
              then
  repeat drop
  drop swap drop swap -
;


cr ."                       ********** FORTH **********"
cr ."                              COPYRIGHT 1986"
cr ."                      AN ANS FORTH BY FIRAT SALGUR"
