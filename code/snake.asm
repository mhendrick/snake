
;!to "snake.prg", cbm	; set output file and format
;setup basic system statement to enable run command
*=$0801
!h 0d 08 0a 00 9e 20 24
!h 31 30 30 30 00 00 00

*=$1000

; ---  Declarations  start  ----

;key mapping
UpKey  = $57
DownKey  = $53
LeftKey  = $41
RightKey =  $44
ExitKey =  $58
StartKey  = $53


;kernel routine to get keyboard character and Print character
CHRIN  = $FFE4
CHROUT  = $FFD2
SCREEN  = $FFED

;some storage locations for game variables

CurrentDirection = $00
SnakeHeadOffSet = $01
GOFlag  = $02
XValue  =  $3100
YValue  =  $3200

;Zero Page Addresses to hold Border values
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
StartColor  = $5B
GOColor = $27

;--- init  start---
Init:
;Setup for game
  jsr Start ; start screen

  ;set color
  lda #NoSnakeColor
  sta $0286 ; set screen color

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
  lda #RightKey
  sta CurrentDirection

;get screen size and set borders


jsr SCREEN
stx RightBorder
sty BottomBorder
clc
rol RightBorder
inc RightBorder

lda #$00
sta UpperBorder
sta LeftBorder
inc LeftBorder



;place first apple at fixed location
ldx #$33
ldy #$06
lda #$00
sta VERA_addr_high
sty VERA_addr_mid
stx VERA_addr_lo

lda #AppleColor
sta VERA_data_0

lda #$FF
sta GOFlag

;--- init End

;--- Main start------------------------------------------------------
loop:

jsr ReadKey   ; read key and store

jsr UpdateSnakeVector  ;update location values

jsr DrawSnake ;draw snake

lda GOFlag
bne onemoreloop
jsr GameOver
jmp Init

onemoreloop:
jmp loop
;--- Main End ------------------------------------------------------

;----readKeys start---------------------------------------------
ReadKey:

;kernal routine to get character from keyboard
jsr CHRIN

;load current direction to x-register
ldx CurrentDirection

;compare keys to valid commands
wkey:
CMP #UpKey ;w PETSCII code
bne skey
cpx #DownKey;exit if reverses direction
bne StoreNewDirection
lda #$00
sta GOFlag
rts

skey:
CMP #DownKey ;s PETSCII code
bne akey
cpx #UpKey;exit if reverses direction
bne StoreNewDirection
lda #$00
sta GOFlag
rts

akey:
CMP #LeftKey ;a PETSCII code
bne dkey
cpx #RightKey ;exit if reverses direction
bne StoreNewDirection
lda #$00
sta GOFlag
rts

dkey:
CMP #RightKey ;d PETSCII code
bne novalidkey
cpx #LeftKey;exit if reverses direction
bne StoreNewDirection
lda #$00
sta GOFlag
rts

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
  cmp #UpKey ;check if current direction is up
  bne down  ;if not next direction
  ;move up
  lda YValue,X
  cmp UpperBorder
  beq Collision  ;hit upper border row 0 engs game
  dec YValue,X
  rts

;move down code
down:
  cmp #DownKey ;check if current direction is down
  bne left  ;if not next direction
  ;move down
  lda YValue,X
  cmp BottomBorder   ;Compare location to bottom border
  beq Collision   ;hit border ends game
  inc YValue,X
  rts

left:
  cmp #LeftKey ;check if current direction is down
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
  cmp XValue,X  ;Compare location to right border
  beq Collision  ;hit border ends game
  inc XValue,X  ;x direction is 2 positions from current screen is 2 bytes for each location
  inc XValue,X
  rts

Collision:
lda #$00
sta GOFlag
rts

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
;routine waiting in start screen or exit
;set color
lda #StartColor
sta $0286

;clear screen
lda #147
jsr $ffd2

ldx	#0	; X register is used to index the string

loopstartpage:
	lda	.string,x ; Load character from string into A reg
	beq	waitforstart	; If the character was 0, jump to end label
	jsr	CHROUT	; Output character stored in A register
	inx		; Increment X register
	jmp	loopstartpage	; Jump back to loop label to print next char
.string	!fi 15, 17
 !fi 32, 29
 !pet "press s to start"
 !fi 16, 157
 !fi 5, 17
 !pet "press x to exit",0

waitforstart:
;press s to start game
;need to add text to the screen
  JSR CHRIN  ;kernal routine to get key
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
;routine waiting in start screen or exit
;set color
lda #GOColor
sta $0286

;clear screen
lda #147
jsr $ffd2

ldx	#0	; X register is used to index the string

loopgopage:
	lda	.string1,x ; Load character from string into A reg
	beq	waitforgo	; If the character was 0, jump to end label
	jsr	CHROUT	; Output character stored in A register
	inx		; Increment X register
	jmp	loopgopage	; Jump back to loop label to print next char
.string1	!fi 15, 17
 !fi 32, 29
 !pet "game over"
 !fi 16, 157
 !fi 5, 17
 !pet "press any key to continue",0
 

waitforgo:
  JSR CHRIN  ;kernal routine to get key
  beq waitforgo
rts

