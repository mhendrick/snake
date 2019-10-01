
!to "snake.prg", cbm	; set output file and format
;setup basic system statement to enable run command
*=$0801
!h 0d 08 0a 00 9e 20 24
!h 31 30 30 30 00 00 00

*=$1000

; ---  Declarations  start  ----

;key mapping
Up  = $57
Down  = $53
Left  = $41
Right =  $44
ExitKey =  $58
StartKey  = $53


;kernel routine to get keyboard character
GetKey  = $FFE4

;some storage locations for game variables

CurrentDirection = $00
SnakeHeadOffSet = $01
XValue  =  $3100
YValue  =  $3200

;Border values
LeftBorder  = $fb
UpperBorder = $fc
RightBorder = $fd
BottomBorder  = $fe

;Vera values
VERA_addr_high = $9F22
VERA_addr_mid = $9F21
VERA_addr_lo  = $9F20
VERA_data_0  = $9F23
VERA_CTRL = $9F25

DelayStart  = $3010

SnakeColor = $bb
NoSnakeColor  = $ff
AppleColor = $22
StartColor  = $55

;--- init  start---
Init:
;add routine to get screen size and set boundaries
  jsr Start

  ;set color
  lda #NoSnakeColor
  sta $0286

;clear screen
  lda #147
  jsr $ffd2

;init SnakeLength to 8 (Value )
  lda #$07
  sta SnakeHeadOffSet

;Set initial position of snake array at (x at $3100 y at $3200)
  ldx SnakeHeadOffSet
  ldy #$55  ;initial x position of head
  tya
  sta XValue,x
  lda #$10  ;initial y position of head
  sta YValue,x

  dey
  dey
  dex

loop1:
    tya
    sta XValue,X
    lda #$10
    sta YValue,X

    dey
    dey
    dex

    bpl loop1
  jsr DrawSnake ;draw snake


;start snake moving right
  lda Right
  sta CurrentDirection

;get screen size and set borders
;temp hardcoded need to check screen size and set as appropriate
lda #$00
sta UpperBorder

lda #$01
sta LeftBorder

lda #$9f
sta RightBorder

lda #$3b
sta BottomBorder

;place first apple at fixed location
ldx #$33
ldy #$06
lda #$00
sta VERA_addr_high
sty VERA_addr_mid
stx VERA_addr_lo

lda #AppleColor
sta VERA_data_0

;--- init End

;--- Main start------------------------------------------------------
loop:

jsr ReadKey   ; read key and store

jsr UpdateSnakeVector  ;update location values

jsr DrawSnake ;draw snake

jmp loop
;--- Main End ------------------------------------------------------

;----readKeys start---------------------------------------------
ReadKey:

;kernal routine to get character from keyboard
jsr GetKey

;load current direction to x-register
ldx CurrentDirection

;compare keys to valid commands
xkey:
cmp #ExitKey  ;x PETSCII code
bne wkey
brk

wkey:
CMP #Up  ;w PETSCII code
bne skey
cpx #Down ;exit if reverses direction
bne StoreNewDirection
jmp Init

skey:
CMP #Down  ;s PETSCII code
bne akey
cpx #Up ;exit if reverses direction
bne StoreNewDirection
jmp Init

akey:
CMP #Left  ;a PETSCII code
bne dkey
cpx #Right ;exit if reverses direction
bne StoreNewDirection
jmp Init

dkey:
CMP #Right  ;d PETSCII code
bne novalidkey
cpx #Left ;exit if reverses direction
bne StoreNewDirection
jmp Init

StoreNewDirection:
sta CurrentDirection

novalidkey:
rts
;---readKeys End-------------------------------------------------

;---- Update Snake Positions Vectors---------------------------
UpdateSnakeVector:

;---only move once per x seconds
wait:
;read clock and wait for greater than 2 jiffes
jsr $ffde ;read clock
cmp #$03
bcs DelayOver
rts

DelayOver:
;reset timer to zero
lda #$00
ldx #$00
ldy #$00
jsr $ffdb
;--- Delay code End

jsr SnakeUpdate

jsr SetSnakeHead

jsr DetectCollision

rts
;---------Update Snake Vector end---------------------------
SnakeUpdate:
;shift all positions down one in the matrix  2->1 3->2 ...

ldx #$01
ldy #$00

nextshift:
  lda XValue,X
  sta XValue,Y

  lda YValue,X
  sta YValue,Y

  iny
  inx
  cpy SnakeHeadOffSet
  bne nextshift
rts

SetSnakeHead:
;set the new position to the snake head.
;Everything else has been shifted down 1
lda CurrentDirection
ldx SnakeHeadOffSet

;move up code
  cmp #Up  ;check if current direction is up
  bne down  ;if not next direction
  ;move up
  lda YValue,X
  cmp UpperBorder
  beq Collision  ;hit upper border row 0 engs game
  dec YValue,X
  rts

;move down code
down:
  cmp #Down  ;check if current direction is down
  bne left  ;if not next direction
  ;move down
  lda YValue,X
  cmp BottomBorder   ;Compare location to bottom border
  beq Collision   ;hit border ends game
  inc YValue,X
  rts

left:
  cmp #Left  ;check if current direction is down
  bne right ;if not next direction
  ;move left
  lda XValue,X
  cmp LeftBorder  ;Compare location to left border
  beq Collision  ;hit border ends game
  dec XValue,X  ;x direction is 2 positions from current screen is 2 bytes for each location
  dec XValue,X
  rts

right:
  ;if not up/down/left must move right
  lda RightBorder
  cmp XValue,X  ;Compare location to left border
  beq Collision  ;hit border ends game
  inc XValue,X  ;x direction is 2 positions from current screen is 2 bytes for each location
  inc XValue,X
  rts

Collision:
jmp GameOver

;----Detect Collision Start --------------
DetectCollision:
;load current head screen values
;cmp to apple and snake color for DetectCollision
;handle collisions and return if no collisions

  ldx SnakeHeadOffSet

  lda XValue,X
  ldy YValue,X
  ldx #$00
  jsr ReadVeraMemory

  cmp #SnakeColor
  beq Collision

  cmp #AppleColor
  beq EatApple

rts
;----Detect Collision End--------------
;----Eat Apple Start----------
EatApple:
;grow the snake
ldx SnakeHeadOffSet
inc SnakeHeadOffSet ;x is now the new head location
ldy SnakeHeadOffSet ;y is the previous head location
lda XValue,X  ;copy previous head values to new head
sta XValue,y
lda YValue,x
sta YValue,y

jsr SetSnakeHead

;place a new Apple
; move apple to x=right boarder - x and y=bottom boarder -y
jsr $ffde ;read clock

clc

lda BottomBorder
sbc YValue,X
tay

clc

lda RightBorder
sbc XValue,X

ora #$01 ;make sure x is on a color byte and not a chracter byte

ldx #$00

stx VERA_addr_high
sty VERA_addr_mid
sta VERA_addr_lo

lda #AppleColor
sta VERA_data_0

rts
;----Eat Apple End------------
;-----Draw Snake start------------------------
DrawSnake:
;  Load Vera External Address

lda #$00
sta VERA_addr_high


  ldx SnakeHeadOffSet
snakepos:
;set  position
  lda YValue,X
  sta VERA_addr_mid

  lda XValue,X
  sta VERA_addr_lo

  lda #SnakeColor
  sta VERA_data_0

  dex
  bmi snakepos
  jsr EraseTail

rts
;----Snake Draw End------------------------------------
;-----Erase Snake 0 position end
EraseTail:

ldx #$00
ldy YValue
lda XValue

stx VERA_addr_high
sty VERA_addr_mid
sta VERA_addr_lo

lda #NoSnakeColor
sta VERA_data_0

rts
;-----erase Snake end

;start wait for s to start game

Start:
;routine waiting to start screen or exit
;set color
lda #StartColor
sta $0286

;clear screen
lda #147
jsr $ffd2

waitforstart:
;press s to start game
;need to add text to the screen
  JSR GetKey  ;kernal routine to get key
  cmp #ExitKey
  bne checks
    brk
checks:
  CMP #StartKey  ;s PETSCII code
  bne waitforstart
rts

;----Read Vera Memory Start-----------------
;set Vera External Address and read data0 and return in accumlator
ReadVeraMemory:
  stx VERA_addr_high ;incrment upper nibble high address byte upper nibble
  sty VERA_addr_mid
  sta VERA_addr_lo

  lda VERA_data_0
rts
;---Read Vera Memory End-----------------

GameOver:
; code for end of game. Temp jump to init
jmp Init
