: hex                           16 base ! ;
: decimal                       10 base ! ;

hex
: #immediate                    80000000 ;
: #compile-only                 8000000 ;
: #mask                         #immediate #compile-only or ;
decimal

: mask!                         last @ nfa dup @ rot or swap !
                                ;
: immediate                     #immediate mask! ;
: compile-only                  #compile-only mask! ;

: 2drop                         drop drop ;
: tuck                          dup rot swap ;

: )                             41 ;
: ( )                           parse 2drop ; immediate

( now we can write comments between parantheses )

: /             ( n n -- n )    um/mod swap drop ;
: *             ( n n -- n )    um* swap drop ;
: mod           ( n n -- n )    um/mod drop ;

: \             ( -- )          refill drop ;

\ We can also do comments without enclosing token

: '             ( -- n )        parse-name find cfa ;

: compile       ( -- )          r> dup 1 + dup @ + cell +
                                compile, cell 1 + + >r ;

\ note that this definition is specific to x86 far call

\ it should be better abstracted away with a primitive word

: [compile]     ( -- )          ' compile, ; immediate

: literal       ( n -- )        compile (lit) , ; immediate
: [']           ( -- )          ' literal ;

: [             ( -- )          -1 state ! ; immediate
: ]             ( -- )          0 state ! ; immediate

: here          ( -- n )        dp @ ;
: cells         ( n -- n )      cell * ;

: if            ( n -- )        compile (0branch) here 0 , ;
                                immediate
: else          ( -- )          compile (branch) here 0 , swap
                                here swap ! ; immediate
: then          ( -- )          here swap ! ; immediate

: begin         ( -- )          here ; immediate
: while         ( n -- )        [compile] if ; immediate
: repeat        ( -- )          compile (branch) swap , here
                                swap ! ; immediate
: again         ( -- )          compile (branch) , ; immediate
: until         ( n -- )        compile (0branch) , ; immediate

: clearstack    ( ... -- )      s0 sp! ;

: exit          ( -- )          r> drop ;
: 2dup          ( a b -- a b a b ) over over ;

: <             ( a b -- t )    2dup xor 0< if drop 0< exit
                                then - 0< ;
: >             ( a b -- t )    < invert ;

: 1+            ( a -- b )      1 + ;
: 1-            ( a -- b )      1 - ;
: 2+            ( a -- b )      2 + ;
: 2-            ( a -- b )      2 - ;

: =             ( a b -- t )    xor if 0 exit then -1 ;
: <>            ( a b -- t )    = invert ;

: 0<>           ( a -- t )      0 <> ;
: 0>            ( a -- t )      0 > ;

: +!            ( n addr -- )   dup @ rot + swap ! ;

: -rot          ( a b c -- c a b ) rot rot ;
: 0=            ( a -- t )      0 = ;
: nip           ( a b -- b )    swap drop ;

: type  ( caddr u -- )
  begin
    dup
  while
    swap dup c@ emit 1+ swap
    1-
  repeat 2drop
;

: allot         ( n -- )        here + dp ! ;

: create ( "<spaces>name" -- )
  parse-name                    ( parse next word )
  here last @ ,                 ( save last link here )
  last !
  dup ,                         ( save name count )
  dup >r
  here swap cmove               ( save name )
  r> allot
  compile (var) ;

: variable      ( "<spaces>name" -- ) create 0 , ;

: bl            ( -- n )        32 ;
: cr            ( -- )          10 emit ;
: space         ( -- )          bl emit ;

: char          ( "<spaces>name" -- c ) bl parse drop c@ ;
: [char]        ( "<spaces>name" -- ) char [compile] literal ;
                                immediate

: count         ( addr -- addr n ) dup cell + swap @ ;
: (.")                          r> dup count type dup @ dup >r
                                + 4 + r> allot >r ;
: !"                            dup , dup >r here swap cmove r>
                                allot ;
: ."            ( "ccc<quote>" -- ) [char] " parse state @ if
                                compile (.") !" else type then ;
                                immediate

: pad           ( -- addr )     here 80 + ;

variable hld

: extract                       um/mod swap 9 over < 7 and +
                                [char] 0 + ;
: <#                            pad hld ! ;
: hold          ( c -- )        hld @ 1 - dup hld ! c! ;
: #             ( u -- u )      base @ extract hold ;
: #s            ( u -- 0 )      begin # dup while repeat ;
: #>                            drop hld @ pad over - ;
: sign                          0< if [char] - hold then ;

: u.            ( u -- )        <# #s #> space type ;

: negate        ( n -- n )      invert 1 + ;
: abs           ( n -- n )      dup 0< if negate then ;

: +.                            dup >r abs <# #s r> sign #> ;

: .             ( n -- )        base @ 10 <>
                                if u. exit then
                                +. space type ;

: depth         ( -- n )        s0 sp@ - 4 / ;

: words ( -- )
  cr
  last @
  begin
    dup
  while
    dup nfa count #mask invert and type space
    @
  repeat drop
;

: .s ( -- )
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

: 2>r           ( a b -- ) ( R: -- a b ) compile >r compile >r
                                         ; immediate
: 2r>           ( -- a b ) ( R: a b -- ) compile r> compile r>
                                         ; immediate

variable (i)

: i             ( -- n )        (i) @ ;

: (do)                          dup (i) ! 2dup r> -rot 2>r >r
                                <> ;
: (loop)                        r> 2r> 1+ rot >r ;
: unloop                        r> 2r> 2drop >r ;

: do ( a b -- ) here
                compile (do)
                compile (0branch) here 0 , ; immediate

: loop          swap
                compile (loop)
                compile (branch) ,
                here swap !
                compile unloop ; immediate

: backspace     ( -- )          8 emit 32 emit 8 emit ;

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
