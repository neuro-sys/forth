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

( Now we can write comments between parantheses )

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
: 2dup          ( a b -- a b a b )
   over over ;

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

: -rot          ( a b c -- c a b )
   rot rot ;
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

: (last)        ( -- )          here last @ , last ! ;

: (name)        ( addr u -- )
   dup ,                        ( write count )
   dup >r                       ( save count )
   here swap cmove              ( copy name )
   r> allot ;                   ( advance dp by count )

: (header)      ( addr u -- )   (last) (name) ;
                
: create        ( "<spaces>name" -- )
   parse-name (header) compile (var) ;

: variable      ( "<spaces>name" -- )
   create 0 , ;

: constant      ( "n <spaces>name" -- )
   parse-name (header) compile (const) , ;

: bl            ( -- n )        32 ;
: cr            ( -- )          10 emit ;
: space         ( -- )          bl emit ;

: char          ( "<spaces>name" -- c )
   bl parse drop c@ ;

: [char]        ( "<spaces>name" -- )
  char [compile] literal ; immediate

: count         ( addr -- addr n )
   dup cell + swap @ ;

: (.")          ( ? )                
   r> dup count type dup @ dup >r
   + 4 + r> allot >r ;

: !"            ( ? )
   dup , dup >r here swap cmove r> allot ;

: s"            ( -- addr u )   [char] " parse ;

: ."            ( "ccc<quote>" -- )
   s" state @
   if compile (.") !" else type then ; immediate

: pad           ( -- addr )     here 80 + ;

variable hld

: extract       ( ? )
   um/mod swap 9 over < 7 and +
   [char] 0 + ;

: <#                            pad hld ! ;
: hold          ( c -- )        hld @ 1 - dup hld ! c! ;
: #             ( u -- u )      base @ extract hold ;
: #s            ( u -- 0 )      begin # dup while repeat ;
: #>            ( ? )           drop hld @ pad over - ;
: sign          ( ? )           0< if [char] - hold then ;

: u.            ( u -- )        <# #s #> space type ;

: negate        ( n -- n )      invert 1 + ;
: abs           ( n -- n )      dup 0< if negate then ;

: +.            ( ? )           dup >r abs <# #s r> sign #> ;

: .             ( n -- )
   base @ 10 <>
   if u. exit then
   +. space type ;

: depth         ( -- n )        s0 sp@ - 4 / ;

: words         ( -- )
   cr
   last @
   begin
    dup
   while
    dup nfa count #mask invert and type space
    @
   repeat drop
;

: .s            ( -- )
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

: 2>r           ( a b -- ) ( R: -- a b )
   compile >r compile >r ; immediate

: 2r>           ( -- a b ) ( R: a b -- )
   compile r> compile r> ; immediate

variable (i)

: i             ( -- n )        (i) @ ;

: (do)          ( ? )
   dup (i) ! 2dup r> -rot 2>r >r <> ;

: (loop)        ( ? )           r> 2r> 1+ rot >r ;
: unloop        ( ? )           r> 2r> 2drop >r ;

: do            ( a b -- )
   here
   compile (do)
   compile (0branch) here 0 , ; immediate

: loop
   swap
   compile (loop)
   compile (branch) ,
   here swap !
   compile unloop ; immediate

: backspace     ( -- )          8 emit 32 emit 8 emit ;

: accept        ( addr n -- n )
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

: true          ( -- t )        -1 ;
: false         ( -- t )        0 ;
: rdrop         ( -- )          r> drop ;

: r@            ( -- n ) ( R: n -- )
   r> dup >r ;

: compare       ( caddr1 u1 caddr2 u2 -- t )
   rot 2dup <>                  ( caddr1 caddr2 u1 u2 t )
   if 2drop 2drop 0 exit
   else drop then               ( caddr1 caddr2 u2 )
   begin
    dup
   while
    >r                          ( caddr1 caddr2 )
    over c@ over c@             ( caddr1 caddr2 c1 c2 )
    <> if r> drop 2drop 0 exit then
    r>                          ( caddr1 caddr2 u2 )
    1-
   repeat
   drop 2drop -1 ;

: find          ( caddr u -- xt )
   2dup                         ( caddr u caddr u )
   last @                       ( caddr u caddr u addr )
   begin
    dup
   while
    dup >r                      ( caddr u caddr u addr )
    nfa count #mask invert and  ( caddr u caddr u caddr2 u2 )
    compare if 2drop r> exit then
    2dup                        ( caddr u caddr u )
    r> @
   repeat
;

: interpret ( -- )
   begin
    parse-name                  ( caddr u )
    dup
   while
    2dup find                   ( caddr u addr )
    dup if
     state @ if
      dup nfa @ #immediate if
       cfa execute
      else
       cfa compile,
      then
     else
      cfa execute
     then
    else
     >number if
    then
   repeat 2drop
;

: quit ( -- )
   begin
    ." ok" cr type
    refill drop interpret
    s0 sp!
   repeat
;

: parse         ( char "ccc<char>" -- c-addr u )
   >in @ 1+ tib + swap          ( caddr c )
   begin
    over c@ over <> >r          ( caddr c )
    over tib #tib @ + <>        ( caddr c )
    r> and
   while
    swap 1+ swap                ( next addr )
   repeat
   drop                         ( caddr )
   tib >in @ + 1+               ( caddr c-addr )
   over tib >in @ + - 1-        ( caddr c-addr u )
   rot tib - 1+ >in !
;

: space?        ( c -- t )      dup 32 = swap 9 = or ;

: parse-name
   >in @ 1+ tib +       ( caddr )
   begin
      dup c@ 32 <>      ( caddr t )
      over c@ 10 <>     ( fixme should check for #tib instead )
      and               ( caddr t )
   while
      1+
   repeat
   tib - >in !
   32 parse 
;

: check-depth depth 0<> if ." Depth is not zero" .s then ;

check-depth
