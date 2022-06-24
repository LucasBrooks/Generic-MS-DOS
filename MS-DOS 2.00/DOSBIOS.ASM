TITLE   DOS BIOS FOR THE IBM PC.

;This BIOS designed to be linked with the SYSINIT module provided by
;Microsoft

FALSE   EQU     0
TRUE    EQU     NOT FALSE

IBMVER  EQU     FALSE
IBM     EQU     IBMVER
IBMJAPVER EQU   FALSE                   ; If TRUE set KANJI true also
MSVER   EQU     TRUE 
ALTVECT EQU     FALSE                   ; Switch to build ALTVECT version
HIGHMEM EQU     FALSE
KANJI   EQU     FALSE

ANSI    EQU     NOT IBMVER
ESCCHR  EQU     1BH

BIOSSEG EQU     70H
SYSIZE  EQU    100H

;Things needed to communicate with SYSINIT

EXTRN   SYSINIT:FAR                     ; The entry point of SYSINIT
EXTRN   CURRENT_DOS_LOCATION:WORD       ; Where the DOS is when SYSINIT called
EXTRN   FINAL_DOS_LOCATION:WORD         ; Where I want SYSINIT to put the DOS
EXTRN   DEVICE_LIST:DWORD               ; Pointer to the DEVICE list.
EXTRN   MEMORY_SIZE:WORD                ; Size in paragraphs of Physical memory.
EXTRN   DEFAULT_DRIVE:BYTE              ; Default Drive to use when system booted

CODE    SEGMENT
ASSUME  CS:CODE,DS:CODE,ES:CODE,SS:CODE

START$:
        JMP     INIT
        DB      20 DUP(0)

DSKTBL  DW      OFFSET DSK_INIT         ;0  - Initialize Driver.
        DW      OFFSET MEDIACHK         ;1  - Return current media code.
        DW      OFFSET GET_BPB          ;2  - Get Bios Parameter Block.
        DW      OFFSET CMDERR           ;3  - Reserved. (currently returns error)
        DW      OFFSET DSK_READ         ;4  - Block read.
        DW      OFFSET BUS_EXIT         ;5  - (Not used, return busy flag)
        DW      OFFSET EXIT             ;6  - Return status. (Not used)
        DW      OFFSET EXIT             ;7  - Flush input buffer. (Not used.)
        DW      OFFSET DSK_WRIT         ;8  - Block write.
        DW      OFFSET DSK_WRTV         ;9  - Block write with verify.

        IF      ANSI
CONTBL  DW      OFFSET EXIT             ;0  - Init. (Not used)
        DW      OFFSET EXIT             ;1  - Media check (Not used)
        DW      OFFSET EXIT             ;2  - Get Bios Parameter Block (Not used)
        DW      OFFSET CMDERR           ;3  - Reserved. (Currently returns error)
        DW      OFFSET CON$READ         ;4  - Character read. (Destructive)
        DW      OFFSET CON$RDND         ;5  - Character read. (Non-destructive)
        DW      OFFSET EXIT             ;6  - Return status. (Not used)
        DW      OFFSET CON$FLSH         ;7  - Flush Input buffer.
        DW      OFFSET CON$WRIT         ;8  - Character write.
        DW      OFFSET CON$WRIT         ;9  - Character write with Verify.
        DW      OFFSET EXIT             ;10 - Character write status.
        DW      OFFSET EXIT             ;11 - (Not used.)
        ELSE
CONTBL  DW      OFFSET EXIT             ;0  - Init. (Not used)
        DW      OFFSET EXIT             ;1  - Media check (Not used)
        DW      OFFSET EXIT             ;2  - Get Bios Parameter Block (Not used)
        DW      OFFSET CMDERR           ;3  - Reserved. (Currently returns error)
        DW      OFFSET CON_READ         ;4  - Character read. (Destructive)
        DW      OFFSET CON_RDND         ;5  - Character read. (Non-destructive)
        DW      OFFSET EXIT             ;6  - Return status. (Not used)
        DW      OFFSET CON_FLSH         ;7  - Flush Input buffer.
        DW      OFFSET CON_WRIT         ;8  - Character write.
        DW      OFFSET CON_WRIT         ;9  - Character write with Verify.
        ENDIF

AUXTBL  DW      OFFSET EXIT             ;0  - Init. (Not used)
        DW      OFFSET EXIT             ;1  - Media check (Not used)
        DW      OFFSET EXIT             ;2  - Get Bios Parameter Block (Not used)
        DW      OFFSET CMDERR           ;3  - Reserved. (Returns an error)
        DW      OFFSET AUX_READ         ;4  - Character read. (Destructive)
        DW      OFFSET AUX_RDND         ;5  - Character read. (Non-destructive)
        DW      OFFSET EXIT             ;6  - Return status. (Not used)
        DW      OFFSET AUX_FLSH         ;7  - Flush Input buffer.
        DW      OFFSET AUX_WRIT         ;8  - Character write.
        DW      OFFSET AUX_WRIT         ;9  - Character write with verify.
        DW      OFFSET AUX_WRST         ;10 - Character write status.

TIMTBL  DW      OFFSET EXIT             ;0  - Init. (Not used)
        DW      OFFSET EXIT             ;1  - Media check (Not used)
        DW      OFFSET EXIT             ;2  - Get Bios Parameter Block (Not used)
        DW      OFFSET CMDERR           ;3  - Reserved. (Currently returns an error)
        DW      OFFSET TIM_READ         ;4  - Character read. (Destructive)
        DW      OFFSET BUS_EXIT         ;5  - (Not used, returns busy flag.)
        DW      OFFSET EXIT             ;6  - Return status. (Not used)
        DW      OFFSET EXIT             ;7  - Flush Input buffer. (Not used)
        DW      OFFSET TIM_WRT          ;8  - Character write.
        DW      OFFSET TIM_WRT          ;9  - Character write with verify.

PRNTBL  DW      OFFSET EXIT             ;0  - (Not used)
        DW      OFFSET EXIT             ;1  - (Not used)
        DW      OFFSET EXIT             ;2  - Block (Not used)
        DW      OFFSET CMDERR           ;3  - Reserved. (currently returns error)
        DW      OFFSET EXITP            ;4  - (Not used)
        DW      OFFSET BUS_EXIT         ;5  - (Not used, returns busy flag.)
        DW      OFFSET EXIT             ;6  - (Not used)
        DW      OFFSET EXIT             ;7  - (Not used)
        DW      OFFSET PRN_WRT          ;8  - Character write.
        DW      OFFSET PRN_WRT          ;9  - Character write with verify.
        DW      OFFSET PRN_STA          ;10 - Character write status.
        DW      OFFSET EXIT             ;11 - (Not used.)

;Define offsets for io data packet

IODAT   STRUC
CMDLEN  DB      ?               ;LENGTH OF THIS COMMAND
UNIT    DB      ?               ;SUB UNIT SPECIFIER
CMD     DB      ?               ;COMMAND CODE
STATUS  DW      ?               ;STATUS
        DB      8 DUP (?)
MEDIA   DB      ?               ;MEDIA DESCRIPTOR
TRANS   DD      ?               ;TRANSFER ADDRESS
COUNT   DW      ?               ;COUNT OF BLOCKS OR CHARACTERS
START   DW      ?               ;FIRST BLOCK TO TRANSFER
IODAT   ENDS

PTRSAV  DD      0
AUXNUM  DB      0

;
; Simplistic Strategy routine for non-multi-Tasking system.
;
;   Currently just saves I/O packet pointers in PTRSAV for
;   later processing by the individual interrupt routines.
;

STRATP  PROC    FAR

STRATEGY:
        MOV     WORD PTR CS:PTRSAV,BX
        MOV     WORD PTR CS:PTRSAV+2,ES

        IF      NOT IBM
        IF      NOT IBMJAPVER
        PUBLIC RE_INIT
        ENDIF
        ENDIF
RE_INIT:
        RET

STRATP  ENDP

;
; Console interrupt routine for processing I/O packets.
;

CON_INT:
        PUSH    SI
        MOV     SI,OFFSET CONTBL
        JMP     SHORT ENTRY

;
; Auxilary interrupt routine for processing I/O packets.
;

AUX_INT:
        PUSH    SI
        PUSH    AX
        XOR     AL,AL
        JMP     SHORT AUXENT

AUX2INT:
        PUSH    SI
        PUSH    AX
        MOV     AL,1
AUXENT:
        MOV     SI,OFFSET AUXTBL
        JMP     SHORT ENTRY1

;
; Printer interrupt routine for processing I/O packets.
;

PRN_INT:
        PUSH    SI
        PUSH    AX
        XOR     AL,AL
        JMP     SHORT PRNENT

PRN2INT:
        PUSH    SI
        PUSH    AX
        MOV     AL,1
        JMP     SHORT PRNENT

PRN3INT:
        PUSH    SI
        PUSH    AX
        MOV     AL,2
PRNENT:
        MOV     SI,OFFSET PRNTBL
        JMP     SHORT ENTRY1

;
; Clock interrupt routine for processing I/O packets.
;


TIM_INT:
        PUSH    SI
        MOV     SI,OFFSET TIMTBL
        JMP     SHORT ENTRY

;
; Disk interrupt routine for processing I/O packets.
;

DSK_INT:
        PUSH    SI
        MOV     SI,OFFSET DSKTBL

;
; Common program for handling the simplistic I/O packet
;   processing scheme in MSDOS 2.0
;

ENTRY:
        PUSH    AX                      ; Save all nessacary registers.
ENTRY1:
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    BP
        PUSH    DS
        PUSH    ES
        PUSH    BX
        MOV     CS:AUXNUM,AL
        LDS     BX,CS:PTRSAV            ; Retrieve pointer to I/O Packet.
        MOV     AL,[BX.UNIT]            ; AL = Unit code.
        MOV     AH,[BX.MEDIA]           ; AH = Media descriptor.
        MOV     CX,[BX.COUNT]           ; CX = Contains byte/sector count.
        MOV     DX,[BX.START]           ; DX = Starting Logical sector.
        XCHG    AX,DI                   ; Move Unit & Media into DI temporarily.
        MOV     AL,[BX.CMD]             ; Retrieve Command type. (1 => 11)
        XOR     AH,AH                   ; Clear upper half of AX for calculation.
        ADD     SI,AX                   ; Compute entry pointer in dispatch table.
        ADD     SI,AX
        CMP     AL,11                   ; Verify that not more than 11 commands.
        JA      CMDERR                  ; Ah, well, error out.
        XCHG    AX,DI                   ; Move Unit & Media back where they belong.
        LES     DI,[BX.TRANS]           ; DI contains addess of Transfer address.
                                        ; ES contains segment.
        PUSH    CS
        POP     DS                      ; Data segment same as Code segment.
        JMP     WORD PTR [SI]

BUS_EXIT:                               ; Device busy exit.
        MOV     AH,00000011B            ; Set busy and done bits.
        JMP     SHORT ERR1
CMDERR:
        MOV     AL,3                    ; Set unknown command error #.

;
;  Common error processing routine.
;   AL contains actual error code.
;
;   Error # 0 = Write Protect violation.
;           1 = Unkown unit.
;           2 = Drive not ready.
;           3 = Unknown command in I/O packet.
;           4 = CRC error.
;           5 = Bad drive request structure length.
;           6 = Seek error.
;           7 = Unknown media discovered.
;           8 = Sector not found.
;           9 = Printer out of paper.
;          10 = Write fault.
;          11 = Read fault.
;          12 = General failure.

DEVERR:
        LDS     BX,PTRSAV
        SUB     [BX.COUNT],CX
        MOV     AH,10000001B            ; Set error and done bits.
        JMP     SHORT ERR1              ; Quick way out.

EXITP   PROC    FAR                     ; Normal exit for device drivers.
        LDS     BX,PTRSAV
        XOR     AX,AX
        MOV     [BX.COUNT],AX
EXIT:
        MOV     AH,00000001B            ; Set done bit for MSDOS.
ERR1:
        LDS     BX,CS:PTRSAV
        MOV     [BX.STATUS],AX          ; Save operation compete and status.
        POP     BX
        POP     ES
        POP     DS
        POP     BP
        POP     DI
        POP     DX
        POP     CX
        POP     AX
        POP     SI
        RET                             ; RESTORE REGS AND RETURN
EXITP   ENDP

;
; ANSI Console Driver for MS-DOS
;
        IF      ANSI

CMDTABL DB      'A'
        DW      OFFSET CUU              ; cursor up
        DB      'B'
        DW      OFFSET CUD              ; cursor down
        DB      'C'
        DW      OFFSET CUF              ; cursor forward
        DB      'D'
        DW      OFFSET CUB              ; cursor back
        DB      'H'
        DW      OFFSET CUP              ; cursor position
        DB      'J'
        DW      OFFSET ED               ; erase display
        DB      'K'
        DW      OFFSET EL               ; erase line
        DB      'R'
        DW      OFFSET CPR              ; cursor postion report
        DB      'f'
        DW      OFFSET CUP              ; cursor position
        DB      'h'
        DW      OFFSET SM               ; set mode
        DB      'l'
        DW      OFFSET RM               ; reset mode
        DB      'm'
        DW      OFFSET SGR              ; select graphics rendition
        DB      'n'
        DW      OFFSET DSR              ; device status report
        DB      'p'
        DW      OFFSET KEYASN           ; key assignment
        DB      's'
        DW      OFFSET PSCP             ; save cursor postion
        DB      'u'
        DW      OFFSET PRCP             ; restore cursor position
        DB      0

GRMODE  DB      00,00000000B,00000111B
        DB      01,11111111B,00001000B
        DB      04,11111000B,00000001B
        DB      05,11111111B,10000000B
        DB      07,11111000B,01110000B
        DB      08,10001000B,00000000B
        DB      30,11111000B,00000000B
        DB      31,11111000B,00000100B
        DB      32,11111000B,00000010B
        DB      33,11111000B,00000110B
        DB      34,11111000B,00000001B
        DB      35,11111000B,00000101B
        DB      36,11111000B,00000011B
        DB      37,11111000B,00000111B
        DB      40,10001111B,00000000B
        DB      41,10001111B,01000000B
        DB      42,10001111B,00100000B
        DB      43,10001111B,01100000B
        DB      44,10001111B,00010000B
        DB      45,10001111B,01010000B
        DB      46,10001111B,00110000B
        DB      47,10001111B,01110000B
        DB      0FFH

CBREAK:
        MOV     CS:ALTAH,3              ; INDICATE BREAK KEY SET
INTRET:
        IRET

DEVSTART DW      OFFSET AUXDEV
        DW      BIOSSEG
        DW      8013H
        DW      OFFSET STRATEGY
        DW      OFFSET CON_INT
        DB      "CON     "

WRAP    DB      0                       ; 0 = WRAP, 1 = NO WRAP
ASNPTR  DW      4
STATE   DW      OFFSET S1
MODE    DB      3
MAXCOL  DB      79
COL     DB      0
ROW     DB      0
SAVCR   DW      0
INQ     DB      0
PRMCNT  LABEL   BYTE
PRMCNTW DW      0
KEYCNT  DB      0
KEYPTR  DW      OFFSET BUF
REPORT  DB      ESCCHR,"[00;00R",13     ; CURSOR POSTION REPORT BUFFER
ALTAH   DB      0                       ; Special key handling
ATTRW   LABEL   WORD
ATTR    DB      00000111B               ; CHARACTER ATTRIBUTE
BPAGE   DB      0                       ; BASE PAGE
BASE    DW      0B800H
SCREEN_SEG DW   0

CHROUT:
        CMP     AL,13
        JNZ     TRYLF
        MOV     [COL],0
        JMP     SHORT SETIT

TRYLF:
        CMP     AL,10
        JZ      LF
        CMP     AL,7
        JNZ     TRYBACK

TOROM:
        MOV     BX,[ATTRW]
        AND     BL,7
        MOV     AH,14
        INT     10H

RET5:
        RET

TRYBACK:
        CMP     AL,8
        JNZ     OUTCHR
        CMP     [COL],0
        JZ      RET5
        DEC     [COL]
        JMP     SHORT SETIT

OUTCHR:
        MOV     BX,[ATTRW]
        MOV     CX,1
        MOV     AH,9
        INT     10H
        INC     [COL]
        MOV     AL,[COL]
        CMP     AL,[MAXCOL]
        JBE     SETIT
        CMP     [WRAP],0
        JZ      OUTCHR1
        DEC     [COL]
        RET

OUTCHR1:
        MOV     [COL],0

LF:
        INC     [ROW]
        CMP     [ROW],25
        JB      SETIT
        MOV     [ROW],24
        CALL    SCROLL

SETIT:
        MOV     DH,ROW
        MOV     DL,COL
        MOV     BH,[BPAGE]
        MOV     AH,2
        INT     10H
        RET

SCROLL:
        MOV     AL,MODE
        CMP     AL,2
        JZ      TMPLAB1
        CMP     AL,3
        JZ      TMPLAB1
        MOV     AL,10
        JMP     SHORT TOROM

TMPLAB1:
        MOV     BH,[ATTR]
        MOV     BL,32
        MOV     BP,50H
        MOV     AX,[BASE]
        ADD     AX,[SCREEN_SEG]
        MOV     ES,AX
        MOV     DS,AX
        XOR     DI,DI
        MOV     SI,0A0H
        MOV     CX,780H
        CLD
        CMP     CS:[BASE],0B800H
        JZ      TMPLAB3
        REP     MOVSW
        MOV     AX,BX
        MOV     CX,BP
        REP     STOSW

TMPLAB2:
        PUSH    CS
        POP     DS
ASSUME  DS:CODE
        RET

TMPLAB3:
        MOV     DX,3DAH

TMPLAB4:
        IN      AL,DX
        TEST    AL,8
        JZ      TMPLAB4
        MOV     AL,25H
        MOV     DX,3D8H
        OUT     DX,AL
        REP     MOVSW
        MOV     AX,BX
        MOV     CX,BP
        REP     STOSW
        MOV     AL,29H
        MOV     DX,3D8H
        OUT     DX,AL
        JMP     SHORT TMPLAB2

;
; Console Read Routine
;

CON$READ:
        JCXZ    CON$EXIT

CON$LOOP:
        PUSH    CX                      ; SAVE COUNT
        CALL    CHRIN                   ; GET CHAR IN AL
        POP     CX
        STOSB                           ; STORE CHAR AT ES:DI
        LOOP    CON$LOOP

CON$EXIT:
        JMP     EXIT

CHRIN:
        XOR     AX,AX
        XCHG    AL,ALTAH                ; GET CHARACTER & ZERO ALTAH
        OR      AL,AL
        JNZ     KEYRET

INAGN:
        CMP     KEYCNT,0
        JNZ     KEY5
        XOR     AH,AH
        INT     16H
        CALL    SCAN                    ; check for redefinition
        JNZ     ALT10                   ; IF NO MATCH JUST RETURN IT
        DEC     CX
        DEC     CX
        INC     BX
        INC     BX
        OR      AL,AL                   ; check whether keypacket is an extended one
        JNZ     TMPLAB6
        DEC     CX
        INC     BX

TMPLAB6:
        MOV     KEYCNT,CL
        MOV     KEYPTR,BX
        CALL    KEY5

ALT10:
        OR      AX,AX                   ; Check for non-key after BREAK
        JZ      INAGN
        OR      AL,AL                   ; SPECIAL CASE?
        JNZ     KEYRET
        MOV     ALTAH,AH                ; STORE SPECIAL KEY

KEYRET:
        RET

KEY5:
        MOV     BX,KEYPTR               ; GET A KEY FROM TRANSLATION TABLE
        MOV     AX,WORD PTR [BX]
        DEC     KEYCNT
        INC     BX
        OR      AL,AL
        JNZ     KEY6
        INC     BX
        DEC     KEYCNT

KEY6:
        MOV     KEYPTR,BX
        RET

SCAN:
        MOV     BX,OFFSET BUF

KEYLP:
        MOV     CL,[BX]
        XOR     CH,CH
        OR      CX,CX
        JZ      NOTFND
        OR      AL,AL                   ; check whether extended keypacket
        JNZ     TMPLAB9
        CMP     AX,WORD PTR [BX+1]      ; yes...compare the word
        JMP     SHORT TMPLAB10

TMPLAB9:
        CMP     AL,BYTE PTR [BX+1]      ; no...compare the byte

TMPLAB10:
        JZ      MATCH
        ADD     BX,CX
        JMP     SHORT KEYLP

NOTFND:
        OR      BX,BX

MATCH:
        RET

;
; Keyboard Non Destructive Read, No Wait
;

CON$RDND:
        MOV     AL,[ALTAH]
        OR      AL,AL
        JNZ     RDEXIT
        CMP     [KEYCNT],0
        JZ      RD1
        MOV     BX,[KEYPTR]
        MOV     AL,BYTE PTR [BX]
        JMP     SHORT RDEXIT

RD1:
        MOV     AH,1
        INT     16H
        JZ      CONBUS
        OR      AX,AX
        JNZ     RD2
        MOV     AH,0
        INT     16H
        JMP     SHORT CON$RDND

RD2:
        CALL    SCAN
        JNZ     RDEXIT
        MOV     AL,BYTE PTR [BX+2]
        CMP     BYTE PTR [BX+1],0
        JNZ     RDEXIT
        MOV     AL,BYTE PTR [BX+3]

RDEXIT:
        LDS     BX,PTRSAV
ASSUME  DS:NOTHING
        MOV     [BX.MEDIA],AL

EXVEC:
        JMP     EXIT

CONBUS:
        JMP     BUS_EXIT

;
; Keyboard Flush Routine
;

CON$FLSH:
        MOV     DS:[ALTAH],0               ; Clear out holding buffer
        MOV     DS:[KEYCNT],0
        PUSH    DS
        XOR     BP,BP
        MOV     DS,BP
ASSUME  DS:CODE
        MOV     BYTE PTR DS:[41AH],1EH
        MOV     BYTE PTR DS:[41CH],1EH
        POP     DS
ASSUME  DS:NOTHING
        JMP     SHORT EXVEC

;
; Console Write Routine
;

CON$WRIT:
        JCXZ    EXVEC

CON$LP:
        MOV     AL,ES:[DI]              ; GET CHAR
        INC     DI
        CALL    OUTC                    ; OUTPUT CHAR
        LOOP    CON$LP                  ; REPEAT UNTIL ALL THROUGH
        JMP     SHORT EXVEC

COUT:
        STI
        PUSH    DS
        PUSH    CS
        POP     DS
        CALL    OUTC
        POP     DS
        IRET

OUTC:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    ES
        PUSH    BP
        MOV     DS:[BASE],0B800H
        XCHG    AX,SI                   ; SAVE CHARACTER TO STUFF
        MOV     AX,40H                  ; POINT TO ROS BIOS
        MOV     DS,AX
        MOV     AX,DS:[49H]             ; AL=MODE, AH=MAX COL
        DEC     AH                      ; ANSI NEEDS 0-79 OR 0-39
        MOV     WORD PTR CS:[MODE],AX   ; SAVE MODE and MAX COL
        CMP     AL,7
        JNZ     SHORT NOT_BW
        MOV     CS:[BASE],0B000H

NOT_BW:
        MOV     AL,DS:[62H]             ; GET ACTIVE PAGE
        MOV     CS:[BPAGE],AL
        CBW
        ADD     AX,AX
        MOV     BX,AX
        MOV     AX,[BX+50H]             ; AL=COL, AH=ROW
        MOV     WORD PTR CS:[COL],AX    ; SAVE ROW and COLUMN
        MOV     AX,DS:[4EH]             ; GET START OF SCREEN SEG
        MOV     CL,4
        SHR     AX,CL                   ; CONVERT TO A SEGMENT
        PUSH    CS
        POP     DS
ASSUME  DS:CODE
        MOV     SCREEN_SEG,AX
        XCHG    AX,SI                   ; GET BACK CHARACTER IN AL
        CALL    VIDEO
        POP     BP
        POP     ES
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET

;
; Output Single Char In AL To Video Device
;

VIDEO:
        MOV     SI,OFFSET STATE
        JMP     WORD PTR [SI]

S2:
        CMP     AL,"["
        JZ      S22
        JMP     S1

S22:
        MOV     WORD PTR [SI],OFFSET S3
        XOR     BX,BX
        MOV     WORD PTR INQ,BX
        JMP     SHORT S3B

S3:
        CMP     AL,";"
        JNZ     S3C

S3A:    
        INC     PRMCNT

S3B:    
        CALL    GETPTR
        XOR     AX,AX
        MOV     WORD PTR [BX],AX        ; DEFAULT VALUE IS ZERO
        RET

S3C:
        CMP     AL,"0"
        JB      S3D
        CMP     AL,"9"
        JA      S3D
        CALL    GETPTR
        SUB     AL,"0"
        XCHG    AL,BYTE PTR [BX]
        MOV     AH,10
        MUL     AH                      ; *10
        ADD     BYTE PTR [BX],AL        ; MOVE IN DIGIT
        RET

S3D:
        CMP     AL,"="
        JZ      S3RET
        CMP     AL,"?"
        JZ      S3RET
        CMP     AL,'"'
        JZ      S3E
        CMP     AL,"'"
        JNZ     S7

S3E:
        MOV     WORD PTR [SI],OFFSET S4
        MOV     [INQ],AL

S3RET:
        RET

S4:
        CMP     AL,[INQ]                ; CHECK FOR STRING TERMINATOR
        JNZ     S4A
        DEC     PRMCNT                  ; TERMINATE STRING
        MOV     WORD PTR [SI],OFFSET S3
        RET

S4A:
        CALL    GETPTR
        MOV     BYTE PTR [BX],AL
        MOV     WORD PTR [SI],OFFSET S4
        JMP     SHORT S3A

; LOOK FOR ANSI COMMAND SPECIFIED IN AL

S7:
        MOV     BX,OFFSET CMDTABL-3

S7A:
        ADD     BX,3
        CMP     BYTE PTR [BX],0
        JZ      S1B
        CMP     BYTE PTR [BX],AL
        JNZ     S7A

S7B:
        MOV     AX,WORD PTR [BX+1]      ; AX = JUMP ADDRESS
        MOV     BX,OFFSET BUF
        INC     BX
        ADD     BX,ASNPTR               ; BX = PTR TO PARM LIST
        MOV     DL,BYTE PTR [BX]
        XOR     DH,DH                   ; DX = FIRST PARAMETER
        MOV     CX,DX
        OR      CX,CX
        JNZ     S7C
        INC     CX                      ; CX = DX, CX=1 IF DX=0

S7C:
        JMP     AX                      ; AL = COMMAND

S1:
        CMP     AL,ESCCHR               ; ESCAPE SEQUENCE?
        JNZ     S1B
        MOV     WORD PTR [SI],OFFSET S2
        RET

S1B:
        CALL    CHROUT

S1A:
        MOV     STATE,OFFSET S1
        RET

MOVCUR:
        CMP     BYTE PTR [BX],AH
        JZ      SETCUR
        ADD     BYTE PTR [BX],AL
        LOOP    MOVCUR

SETCUR:
        MOV     DX,WORD PTR COL
        XOR     BX,BX
        MOV     AH,2
        INT     10H
        JMP     SHORT S1A

CUP:
        CMP     CL,25
        JA      SETCUR
        MOV     AL,MAXCOL
        MOV     CH,BYTE PTR [BX+1]
        OR      CH,CH
        JZ      CUP1
        DEC     CH

CUP1:
        CMP     AL,CH
        JA      CUP2
        MOV     CH,AL

CUP2:
        XCHG    CL,CH
        DEC     CH
        MOV     WORD PTR COL,CX
        JMP     SHORT SETCUR

CUF:
        MOV     AH,MAXCOL
        MOV     AL,1

CUF1:
        MOV     BX,OFFSET COL
        JMP     SHORT MOVCUR

CUB:
        MOV     AX,0FFH
        JMP     SHORT CUF1

CUU:
        MOV     AX,0FFH

CUU1:
        MOV     BX,OFFSET ROW
        JMP     SHORT MOVCUR

CUD:
        MOV     AX,1801H
        JMP     SHORT CUU1

PSCP:
        MOV     AX,WORD PTR COL
        MOV     SAVCR,AX
        JMP     SHORT SETCUR

PRCP:
        MOV     AX,SAVCR
        MOV     WORD PTR COL,AX
        JMP     SHORT SETCUR

SGR:
        XOR     CX,CX
        XCHG    CL,PRMCNT
        CALL    GETPTR
        INC     CX

SGR1:
        MOV     AL,BYTE PTR [BX]
        PUSH    BX
        MOV     BX,OFFSET GRMODE

SGR2:
        MOV     AH,BYTE PTR [BX]
        ADD     BX,3
        CMP     AH,0FFH
        JZ      SGR3
        CMP     AH,AL
        JNZ     SGR2
        MOV     AX,WORD PTR [BX-2]
        AND     ATTR,AL
        OR      ATTR,AH

SGR3:
        POP     BX
        INC     BX
        LOOP    SGR1
        JMP     SETCUR

ED:
        XOR     CX,CX
        MOV     WORD PTR COL,CX
        MOV     DH,25

ERASE:
        MOV     DL,MAXCOL
        MOV     BH,ATTR
        MOV     AX,600H
        INT     10H
        JMP     SETCUR

EL:
        MOV     CX,WORD PTR COL
        MOV     DH,CH
        JMP     SHORT ERASE

BIN2ASC:
        MOV     DL,10
        INC     AL
        XOR     AH,AH
        DIV     DL
        ADD     AX,"00"
        RET

DSR:
        MOV     AL,ROW
        CALL    BIN2ASC
        MOV     WORD PTR REPORT+2,AX
        MOV     AL,COL
        CALL    BIN2ASC
        MOV     WORD PTR REPORT+5,AX
        MOV     [KEYCNT],9
        MOV     [KEYPTR],OFFSET REPORT

CPR:
        JMP     S1A

RM:
        MOV     CL,1
        JMP     SHORT SM1

SM:
        XOR     CX,CX

SM1:
        MOV     AL,DL
        CMP     AL,7
        JA      CPR
        JB      SETMODE
        MOV     WRAP,CL
        RET

SETMODE:
        MOV     AH,0                    ; WGR yes....set mode..
        INT     10H
        JMP     SHORT CPR

KEYASN:
        XOR     DX,DX
        XCHG    DL,PRMCNT               ; GET CHARACTER COUNT
        INC     DX
        INC     DX
        CALL    GETPTR
        MOV     AX,WORD PTR [BX]        ; GET CHARACTER TO BE ASSIGNED
        CALL    SCAN                    ; LOOK IT UP
        JNZ     KEYAS1
        MOV     DI,BX                   ; DELETE OLD DEFINITION
        SUB     ASNPTR,CX
        MOV     SI,DI
        ADD     SI,CX
        MOV     CX,OFFSET BUF+0C8H
        SUB     CX,SI
        CLD
        PUSH    ES                      ; SAVE USER'S ES
        PUSH    CS
        POP     ES                      ; SET UP ES ADDRESSABILITY
        REP     MOVSB
        POP     ES                      ; RESTORE ES

KEYAS1:
        CALL    GETPTR
        CMP     DL,3
        JB      KEYAS3
        MOV     BYTE PTR [BX-1],DL      ; SET LENGTH
        ADD     ASNPTR,DX               ; REMEMBER END OF LIST
        ADD     BX,DX

KEYAS3:
        MOV     BYTE PTR [BX-1],0
        MOV     STATE,OFFSET S1         ; RETURN
        RET

GETPTR:
        MOV     BX,ASNPTR
        INC     BX
        ADD     BX,PRMCNTW
        CMP     BX,0C8H
        JB      GET1
        DEC     PRMCNT
        JMP     SHORT GETPTR

GET1:
        ADD     BX,OFFSET BUF
        RET

BUF     DB      4,0,72H,16,0
        DB      0C3H DUP (0)

;
; Routines used by other devices
;

GETDX:
        MOV     DL,AUXNUM
        XOR     DH,DH
        RET

FLUSH:
        MOV     ALTAH,0                 ; clear out holding buffer
        MOV     KEYCNT,0
        PUSH    DS
        XOR     BP,BP
        MOV     DS,BP
        MOV     BYTE PTR DS:[41AH],1EH  ; Empty BIOS keyboard buffer
        MOV     BYTE PTR DS:[41CH],1EH
        POP     DS
        RET

;
; Normal Console Driver for PC-DOS
;

        ELSE

COUT:
        STI
        PUSH    AX
        MOV     BX,7                    ; SET FOREGROUND COLOR
        MOV     AH,0EH                  ; SET COMMAND TO WRITE A CHAR
        INT     10H                     ; CALL ROM-BIOS (Write TTY)
        POP     AX
        IRET

;----------------------------------------------
;
; Fill DX register with value in AUXNUM
;

GETDX:
        MOV     DL,AUXNUM
        XOR     DH,DH
        RET

CBREAK:
        MOV     CS:ALTAH,3
INTRET:
        IRET

DEVSTART DW      OFFSET AUXDEV
        DW      BIOSSEG
        DW      8013H
        DW      OFFSET STRATEGY
        DW      OFFSET CON_INT
        DB      "CON     "

ALTAH   DB      0

CON_READ:
        JCXZ    CONR_DON

CONRNXT:
        PUSH    CX
        CALL    CHRIN                   ; Get character.
        POP     CX
        STOSB                           ; Save it in users buffer.
        LOOP    CONRNXT                 ; Loop until CX is exhausted.

CONR_DON:
        JMP     EXIT


CHRIN:
        XOR     AX,AX
        XCHG    AL,ALTAH
        OR      AL,AL
        JNZ     KEYRET
        INT     16H                     ; KBD: Read char from buffer with wait
        OR      AX,AX
        JZ      CHRIN
        CMP     AX,7200H                ; Check for CTRL-PRTSC
        JNZ     ALT15
        MOV     AL,16                   ; indicate prtsc
ALT15:
        OR      AL,AL
        JNZ     KEYRET
        MOV     ALTAH,AH
KEYRET:
        RET

CON_RDND:
        MOV     AL,ALTAH
        OR      AL,AL
        JNZ     RDEXIT
        MOV     AH,1
        INT     16H                     ; KBD: Buffer peek, ZF set if empty
        JZ      CONBUS
        OR      AX,AX
        JNZ     NOTBRK
        MOV     AH,0
        INT     16H                     ; KBD: Read char from buffer with wait
        JMP     CON_RDND
NOTBRK:
        CMP     AX,7200H                ; check for ctrl-prtsc
        JNZ     RDEXIT
        MOV     AL,16
RDEXIT:
        LDS     BX,PTRSAV
        MOV     [BX.MEDIA],AL
EXVEC:
        JMP     EXIT

CONBUS:
        JMP     BUS_EXIT

CON_FLSH:
        CALL    FLUSH
        JMP     EXVEC

FLUSH:
        MOV     ALTAH,0                 ; clear out holding buffer
        PUSH    DS
        XOR     BP,BP
        MOV     DS,BP
        MOV     BYTE PTR DS:[41AH],1EH  ; Empty BIOS keyboard buffer
        MOV     BYTE PTR DS:[41CH],1EH
        POP     DS
        RET

CON_WRIT:
        JCXZ    EXVEC
CONWNXT:
        MOV     AL,ES:[DI]
        INC     DI
        PUSH    CX
        PUSH    DI
        INT     29H                     ; Shortcut to COUT
        POP     DI
        POP     CX
        LOOP    CONWNXT
        JMP     EXVEC
        ENDIF

AUXDEV  DW      OFFSET PRNDEV
        DW      BIOSSEG
        DW      8000H
        DW      OFFSET STRATEGY
        DW      OFFSET AUX_INT
        DB      "AUX     "

DEVCOM1 DW      OFFSET DEVLPT1
        DW      BIOSSEG
        DW      8000H
        DW      OFFSET STRATEGY
        DW      OFFSET AUX_INT
        DB      "COM1    "

AUXBUF  DB      0
        DB      0

AUX_READ:
        JCXZ    EXVEC2
        CALL    GETBX
        XOR     AX,AX
        XCHG    AL,[BX]
        OR      AL,AL
        JNZ     AUX2

AUX1:
        CALL    AUXIN
AUX2:
        STOSB
        LOOP    AUX1

EXVEC2:
        JMP     EXIT


AUXIN:
        MOV     AH,2
        CALL    AUXSVC
        TEST    AH,0EH
        JZ      AROK
        POP     AX
        MOV     AL,0BH                  ; report a 'read error'
        JMP     DEVERR

AROK:
        RET


AUX_RDND:
        CALL    GETBX
        MOV     AL,[BX]
        OR      AL,AL
        JNZ     AUXRDX
        CALL    AUXSTAT
        TEST    AH,1
        JZ      AUXBUS
        TEST    AL,20H
        JZ      AUXBUS
        CALL    AUXIN
        CALL    GETBX
        MOV     [BX],AL
AUXRDX:
        JMP     RDEXIT

AUXBUS:
        JMP     BUS_EXIT

AUX_WRST:
        CALL    AUXSTAT
        TEST    AL,20H
        JZ      AUXBUS
        TEST    AH,20H
        JZ      AUXBUS
        JMP     EXVEC2


AUXSTAT:
        MOV     AH,3
AUXSVC:
        CALL    GETDX
        INT     14H                     ; Serial service
        RET

AUX_FLSH:
        CALL    GETBX
        MOV     BYTE PTR [BX],0
        JMP     EXVEC2
AUX_WRIT:
        JCXZ    EXVEC2
AUX_LOOP:
        MOV     AL,ES:[DI]
        INC     DI
        MOV     AH,1
        CALL    AUXSVC
        TEST    AH,80H
        JZ      AWOK
        MOV     AL,0AH
        JMP     DEVERR
AWOK:
        LOOP    AUX_LOOP
        JMP     EXVEC2


GETBX:
        CALL    GETDX
        MOV     BX,DX
        ADD     BX,OFFSET AUXBUF
        RET


PRNDEV  DW      OFFSET TIMDEV
        DW      BIOSSEG
        DW      8000H
        DW      OFFSET STRATEGY
        DW      OFFSET PRN_INT
        DB      "PRN     "

DEVLPT1 DW      OFFSET DEVLPT2
        DW      BIOSSEG
        DW      8000H
        DW      OFFSET STRATEGY
        DW      OFFSET PRN_INT
        DB      "LPT1    "

PRNBYTE DB      0

PRN_WRT:
        JCXZ    EXVEC3

PRN_LOOP:
        MOV     AL,ES:[DI]
        INC     DI
        MOV     PRNBYTE,0

PRNL1:
        XOR     AH,AH
        CALL    PRNOP
        JZ      GOPRLP
        XOR     PRNBYTE,1
        JNZ     PRNL1
PMESSG:
        JMP     DEVERR

GOPRLP:
        LOOP    PRN_LOOP

EXVEC3:
        JMP     EXIT

PRN_STA:
        CALL    PRNSTAT
        JNZ     PMESSG
        TEST    AH,80H
        JNZ     EXVEC3
        JMP     BUS_EXIT

PRNSTAT:
        MOV     AH,2
PRNOP:
        CALL    GETDX
        INT     17H                     ; Printer service
        MOV     AL,2                    ; error_I24_not_ready
        TEST    AH,1
        JNZ     PRNOP2
        MOV     AL,10
        TEST    AH,8
        JZ      PRNOP2
        TEST    AH,20H
        JZ      PRNOP1
        MOV     AL,9
PRNOP1:
        OR      AL,AL
PRNOP2:
        RET


TIMDEV  DW      OFFSET DSKDEV
        DW      BIOSSEG
        DW      8008H
        DW      OFFSET STRATEGY
        DW      OFFSET TIM_INT
        DB      "CLOCK$  "

DAYCNT  DW      0


TIM_WRT:
        MOV     AX,ES:[DI]              ; Days since 1-1-1980
        MOV     DS:DAYCNT,AX
        XOR     AX,AX
        INT     1AH                     ; CLOCK - SET TIME OF DAY
                                        ; CX:DX = clock count
                                        ; Return: time of day set
        MOV     CX,ES:[DI+2]            ; Minutes (CL) and hours (CH)
        MOV     DX,ES:[DI+4]            ; 100ths of second (DL) and seconds (DH)
        MOV     AL,60
        MUL     CH                      ; Convert hours to minutes
        MOV     CH,0
        ADD     AX,CX                   ; AX now holds hours+mins in minutes
        MOV     CX,6000                 ; 100ths of seconds in a minute
        MOV     BX,DX                   ; Stash DX (seconds and 100ths) in BX
        MUL     CX                      ; DX:AX now holds hours/minutes in 100ths of seconds
        MOV     CX,AX                   ; Stash low word of result in CX
        MOV     AL,100
        MUL     BH                      ; AX now has seconds in 100ths/sec
        ADD     CX,AX                   ; Add seconds to DX:CX
        ADC     DX,0
        MOV     BH,0                    ; BX now hold only 100ths/sec
        ADD     CX,BX                   ; Add 100ths to DX:CX
        ADC     DX,0
        XCHG    AX,DX                   ; Swap DX:CX into DX:AX
        XCHG    AX,CX                   ; DX:CX now holds time of day in 100ths of a second
        MOV     BX,59659                ; 1,193,180 * 5 / 100
        MUL     BX                      ; Multiply high word
        XCHG    DX,CX                   ; Swap DX:AX with CX:DX
        XCHG    AX,DX
        MUL     BX                      ; Multiply low word
        ADD     AX,CX
        ADC     DX,0                    ; DX:AX now holds timer ticks * 5
        XCHG    AX,DX                   ; Swap around DX and AX
        MOV     BX,5                    ; AX now has the high word
        DIV     BL                      ; Divide AX by 5
        MOV     CL,AL                   ; Put quotient in CL
        MOV     CH,0                    ; And zero extend (we know result will fit)
        MOV     AL,AH                   ; Now move remainder into AL
        CBW                             ; And sign extend
        XCHG    AX,DX                   ; DX now holds remainder, AX the low word
        DIV     BX                      ; Now divide DX:AX by 5
        MOV     DX,AX                   ; And put the result (low word) back in DX
        MOV     AH,1
        INT     1AH                     ; CLOCK - SET TIME OF DAY
                                        ; CX:DX = clock count
                                        ; Return: time of day set
        JMP     EXIT

TIM_READ:
        XOR     AX,AX
        INT     1AH                     ; Get time of day (ticks in CX:DX), AL !=0 if rollover
        ADD     DS:DAYCNT,AX
        MOV     AX,CX                   ; CX:DX to AX:BX
        MOV     BX,DX
        SHL     DX,1                    ; Multiply CX:DX by 4
        RCL     CX,1
        SHL     DX,1
        RCL     CX,1
        ADD     DX,BX                   ; Add to multiply by 5
        ADC     AX,CX
        XCHG    AX,DX                   ; AX:DX now holds initial timer ticks * 5
        MOV     CX,59659                ; 1,193,180 * 5 / 100
        DIV     CX
        MOV     BX,AX                   ; Stash quotient in BX
        XOR     AX,AX
        DIV     CX                      ; Now divide the remainder
        MOV     DX,BX
        MOV     CX,200
        DIV     CX
        CMP     DL,100
        JB      NOADJ
        SUB     DL,100
NOADJ:
        CMC
        MOV     BL,DL                   ; Store 100ths in BL
        RCL     AX,1                    ; Multiply by two again
        MOV     DL,0
        RCL     DX,1
        MOV     CX,60
        DIV     CX
        MOV     BH,DL                   ; Store seconds in BH
        DIV     CL                      ; Divide AX by 60
        XCHG    AL,AH                   ; Swap quotient and remainder
        PUSH    AX
        MOV     AX,DS:DAYCNT            ; Days since 1-1-1980
        STOSW
        POP     AX                      ; Minutes (AL) and hours (AH)
        STOSW
        MOV     AX,BX                   ; 100ths of second (AL) and seconds (AH)
        STOSW
        JMP     EXIT

DSKDEV  DW      OFFSET DEVCOM1
        DW      BIOSSEG
        DW      0
        DW      OFFSET STRATEGY
        DW      OFFSET DSK_INT

DRVMAX  DB      4
CURDISK DB      -1
TIM_LO  DW      -1
TIM_HI  DW      -1
RFLAG   DW      2
PHANTOM DB      0
MOVFLG  DB      0
WORD3E2 DW      0
HARDNUM DB      99
DRIVENUM DB     0
CURHD   DB      0
CURSEC  DB      0
CURTRK  DW      0
SPSAV   DW      0


MEDIACHK:
        MOV     DI,1
        TEST    AH,4
        JZ      MEDCHG
        XOR     DI,DI
        MOV     SI,OFFSET CURDISK
        CMP     AL,[SI]
        JNZ     MEDCHG
        MOV     AH,0
        INT     1AH                     ; Get time of day (ticks in CX:DX), AL !=0 if rollover
        SUB     DX,[SI+1]               ; TIM_LO
        SBB     CX,[SI+3]               ; TIM_HI
        OR      CX,CX
        JNZ     MEDCHG
        OR      DX,DX
        JZ      MEDCHG
        CMP     DX,40                   ; 40 ticks is a little over 2 seconds
        JA      MEDCHG

        INC     DI                      ; Media not changed
MEDCHG:
        LDS     BX,PTRSAV
        MOV     WORD PTR [BX.TRANS],DI
        JMP     EXIT

GET_BPB:
        MOV     AH,ES:[DI]
        CALL    SETDRIVE
GET_BP1:
        LDS     BX,PTRSAV
        MOV     [BX.MEDIA],AH
        MOV     [BX.COUNT],DI
        MOV     WORD PTR [BX.START],CS
        JMP     EXIT

SETDRIVE:
        PUSH    AX
        PUSH    CX
        PUSH    DX
        PUSH    BX
        MOV     CL,AH
        AND     CL,0F8H
        CMP     CL,0F8H                 ; Top 5 bits set?
        JZ      IDGOOD
        MOV     AH,0FEH
IDGOOD:
        MOV     DI,OFFSET HDRIVE
        CMP     AL,[HARDNUM]
        JZ      GOTDRIVE
        JB      GETFLPY
        MOV     DI,OFFSET DRIVEX
        JMP     SHORT GOTDRIVE

GETFLPY:
        MOV     AL,1
        MOV     BX,4008H
        MOV     CX,320
        MOV     DX,101H
        MOV     DI,OFFSET FDRIVE
        TEST    AH,2                    ; 9 spt rather than 8?
        JNZ     CHKSID
        INC     AL
        INC     BL                      ; Increment sectors per track
        ADD     CX,40                   ; Add 40 sectors per side
CHKSID:
        TEST    AH,1                    ; Double sided disk?
        JZ      FILLBPB
        ADD     CX,CX                   ; Double total sectors
        MOV     BH,112                  ; More root dir entries
        INC     DH                      ; Increment sides
        INC     DL                      ; and sectors per cluster
FILLBPB:
        MOV     [DI+2],DH
        MOV     [DI+6],BH
        MOV     [DI+8],CX
        MOV     [DI+0AH],AH
        MOV     [DI+0BH],AL
        MOV     [DI+0DH],BL
        MOV     [DI+0FH],DL
GOTDRIVE:
        POP     BX
        POP     DX
        POP     CX
        POP     AX
        RET


FDRIVE  DW      512                     ; Bytes per sector
        DB      1                       ; Sectors per cluster
        DW      1                       ; Reserved sectors
        DB      2                       ; No. of FATs
        DW      64                      ; Root dir entries
        DW      360                     ; Total sectors
        DB      0FCH                    ; Media descriptor byte
        DW      2                       ; Number of FAT sectors
        DW      9                       ; Sectors per track
        DW      1                       ; Head limits
        DW      0                       ; Hidden sectors

DSK_READ:
        CALL    DISKRD
        JMP     SHORT DSKDON

DSK_WRTV:
        MOV     RFLAG,103H              ; Write with verify
        JMP     SHORT GODSK

DSK_WRIT:
        MOV     RFLAG,3                 ; Write operation
GODSK:
        CALL    DISKIO
DSKDON:
        JNB     DSKXIT
        JMP     DEVERR

DSKXIT:
        JMP     EXIT

DISKRD:
        MOV     BYTE PTR RFLAG,2        ; Read operation
DISKIO:
        CLC
        JCXZ    IORET
        MOV     CURDISK,AL
        MOV     SPSAV,SP
        XCHG    BX,DI
        CALL    SETDRIVE
        MOV     SI,DX
        ADD     SI,CX
        ADD     DX,[DI+11H]
        CMP     SI,[DI+8]
        JBE     DRVOK
        MOV     AL,8
        STC
IORET:
        RET

DRVOK:
        CMP     AL,[HARDNUM]
        JB      CHKSNG
        MOV     AL,HARDDRV
        JZ      GOTDRV
        INC     AL
        JMP     SHORT GOTDRV

CHKSNG:
        CMP     PHANTOM,1
        JNZ     GOTDRV
        CALL    SWPDSK
GOTDRV:
        MOV     DRIVENUM,AL
        MOV     WORD3E2,CX
        XCHG    AX,DX
        XOR     DX,DX
        DIV     WORD PTR [DI+0DH]
        INC     DL
        MOV     CURSEC,DL
        MOV     CX,[DI+0FH]
        XOR     DX,DX
        DIV     CX
        MOV     CURHD,DL
        MOV     CURTRK,AX
        MOV     AX,WORD3E2
        MOV     SI,ES
        SHL     SI,1
        SHL     SI,1
        SHL     SI,1
        SHL     SI,1
        ADD     SI,BX
        ADD     SI,511
        JB      BUFFER
        XCHG    BX,SI
        SHR     BH,1
        MOV     AH,80H
        SUB     AH,BH
        XCHG    BX,SI
        CMP     AH,AL
        JBE     DOBLOCK
        MOV     AH,AL
DOBLOCK:
        PUSH    AX
        MOV     AL,AH
        CALL    BLOCK
        POP     AX
        SUB     AL,AH
        JZ      CHKTIM

BUFFER:
        PUSH    AX
        PUSH    ES
        PUSH    BX
        CALL    MOVE
        ADD     BH,2
        CALL    DISK1
        POP     BX
        POP     ES
        POP     AX
        CALL    MOVE
        DEC     AL
        ADD     BH,2
        CALL    BLOCK
CHKTIM:
        MOV     AH,0
        INT     1AH                     ; Get time of day (ticks in CX:DX), AL !=0 if rollover
        MOV     TIM_LO,DX
        MOV     TIM_HI,CX
        CLC
        RET


MOVE:
        PUSH    DI
        PUSH    BX
        PUSH    AX
        MOV     DI,BX
        ADD     BH,2
        MOV     SI,BX
        CLD
        MOV     CX,256
MOVW:
        MOV     BX,ES:[DI]
        MOV     AX,ES:[SI]
        MOV     ES:[SI],BX
        STOSW
        INC     SI
        INC     SI
        LOOP    MOVW
        XOR     MOVFLG,1
        POP     AX
        POP     BX
        POP     DI
RETZ:
        RET


BLOCK:
        OR      AL,AL
        JZ      RETZ
        MOV     AH,[DI+0DH]
        INC     AH
        SUB     AH,CURSEC
        CMP     AH,AL
        JBE     GOTMIN
        MOV     AH,AL
GOTMIN:
        PUSH    AX
        MOV     AL,AH
        CALL    DISK
        POP     AX
        SUB     AL,AH
        SHL     AH,1
        ADD     BH,AH
        JMP     BLOCK


DISK1:
        MOV     AL,1
DISK:
        MOV     SI,5                    ; Retry count
        MOV     AH,BYTE PTR RFLAG
RETRY:
        PUSH    AX
        MOV     DX,CURTRK
        MOV     CL,6
        SHL     DH,CL
        OR      DH,CURSEC
        MOV     CX,DX
        XCHG    CH,CL
        MOV     DX,WORD PTR DRIVENUM
        INT     13H
        JB      AGAIN
        POP     AX
        PUSH    AX
        CMP     RFLAG,103H              ; Write with verify?
        JNZ     NOVFY
        MOV     AH,4                    ; Verify
        INT     13H                     ; Disk service
        JB      AGAIN

NOVFY:
        POP     AX
        AND     CL,3FH
        XOR     AH,AH
        SUB     WORD3E2,AX
        ADD     CL,AL
        MOV     CURSEC,CL
        CMP     CL,[DI+0DH]
        JBE     DSKRET
        MOV     CURSEC,1
        MOV     DH,CURHD
        INC     DH
        CMP     DH,[DI+0FH]
        JB      SAVHD
        XOR     DH,DH
        INC     CURTRK
SAVHD:
        MOV     CURHD,DH
DSKRET:
        RET

AGAIN:
        PUSH    AX
        MOV     AH,0
        INT     13H                     ; Reset disk
        POP     AX
        DEC     SI                      ; Decrement retry count
        JZ      NORETRY
        CMP     AH,80H
        JZ      NORETRY
        POP     AX
        JMP     RETRY

NORETRY:
        CMP     MOVFLG,0
        JZ      MAPERROR
        POP     BX
        POP     BX
        POP     ES
        CALL    MOVE
MAPERROR:
        PUSH    CS
        POP     ES
        MOV     AL,AH
        MOV     ERROUT,AL
        MOV     CX,7
        MOV     DI,OFFSET ERRIN
        REPNE   SCASB
        MOV     AL,BYTE PTR [DI+6]
        MOV     CX,WORD3E2
        MOV     SP,SPSAV
        STC
        RET

ERRIN   DB      80H
        DB      40H
        DB      10H
        DB      8
        DB      4
        DB      3

ERROUT  DB      0
        DB      2
        DB      6
        DB      4
        DB      4
        DB      8
        DB      0
        DB      0CH

DSK_INIT:
        MOV     AH,DRVMAX
        MOV     DI,OFFSET DSKDRVS
        JMP     GET_BP1

DSKDRVS DW      OFFSET FDRIVE
        DW      OFFSET FDRIVE
        DW      OFFSET FDRIVE
        DW      OFFSET FDRIVE

HDSKTAB DW      OFFSET HDRIVE
        DW      OFFSET DRIVEX

DEVLPT2 DW      OFFSET DEVLPT3
        DW      BIOSSEG
        DW      8000H
        DW      OFFSET STRATEGY
        DW      OFFSET PRN2INT
        DB      "LPT2    "

DEVLPT3 DW      OFFSET DEVCOM2
        DW      BIOSSEG
        DW      8000H
        DW      OFFSET STRATEGY
        DW      OFFSET PRN3INT
        DB      "LPT3    "

DEVCOM2 DW      0FFFFH
        DW      BIOSSEG
        DW      8000H
        DW      OFFSET STRATEGY
        DW      OFFSET AUX2INT
        DB      "COM2    "

NOSWAP$ LABEL   WORD

SWPDSK:
        PUSH    DS
        XOR     SI,SI
        MOV     DS,SI
        MOV     AH,AL
        XCHG    AH,DS:[504H]
        POP     DS
        CMP     AL,AH
        JZ      NOSWP
        ADD     AL,"A"
        MOV     SNGMSG+1CH,AL
        MOV     SI,OFFSET SNGMSG
        PUSH    BX
        CALL    WRMSG
        CALL    FLUSH
        XOR     AH,AH
        INT     16H                     ; KBD: Buffer peek, ZF set if empty
        POP     BX
NOSWP:
        XOR     AL,AL
WRMRET:
        RET


WRMSG:
        LODSB
        AND     AL,7FH
        JZ      WRMRET
        INT     29H                     ; Shortcut to COUT
        JMP     WRMSG


SNGMSG  DB      13,10,"Insert diskette for drive A: and strike",13,10
        DB      "any key when ready",13,10
        DB      10,0

        PAGE
        SUBTTL  Initalization code and temporary work areas.

;
; Overlayed by MSDOS by SYSINIT.
;

INIT$   LABEL   WORD

HNUM    DB      0
HARDDRV DB      80H

HDRIVE  DW      512
        DB      1
        DW      1
        DB      2
        DW      16
        DW      0
        DB      0F8H
        DW      1
        DW      0
        DW      0
        DW      0

INITHD1$ LABEL  WORD

DRIVEX  DW      512
        DB      0
        DW      1
        DB      2
        DW      0
        DW      0
        DB      0F8H
        DW      0
        DW      0
        DW      0
        DW      0

INITHD2$ LABEL  WORD

DRVFAT  DW      0
BIOSTRT DW      0
DOSCNT  DW      0

INIT:
        XOR     DX,DX
        CLI
        MOV     SS,DX
        MOV     SP,700H
        STI
        PUSH    CX                      ; save number of floppies and media byte
        MOV     CS:BIOSTRT,BX           ; save first data sector
        PUSH    AX                      ; save boot drive number, and media byte
        MOV     AL,20H
        OUT     20H,AL                  ; Interrupt controller, 8259A.
        MOV     SI,OFFSET DEVLPT3
        CALL    PRINT_INIT
        MOV     SI,OFFSET DEVLPT2
        CALL    PRINT_INIT
        MOV     SI,OFFSET DEVLPT1
        CALL    PRINT_INIT
        MOV     SI,OFFSET DEVCOM2
        CALL    AUX_INIT
        MOV     SI,OFFSET DEVCOM1
        CALL    AUX_INIT

        IF      ANSI
        INT     11H
        AND     AL,00110000B
        CMP     AL,00110000B
        JNZ     ISCOLOR
        MOV     CS:[BASE],0B000H        ; look for bw card
ISCOLOR:
        CMP     AL,00010000B            ; look for 40 col mode
        JA      ANSIDONE
        MOV     CS:[MODE],0
        MOV     CS:[MAXCOL],39          ; 40 columns
ANSIDONE:
        ENDIF

        XOR     DX,DX
        MOV     DS,DX                   ; Set DS, ES to zero
        MOV     ES,DX
        MOV     AX,CS
        MOV     DS:[6CH],OFFSET CBREAK  ; INT 1BH
        MOV     DS:[6EH],AX
        MOV     WORD PTR DS:[0A4H],OFFSET COUT  ; INT 29H
        MOV     WORD PTR DS:[0A6H],AX
        MOV     DS:[78H],522H           ; Set INT 1EH to 0:522
        MOV     DS:[7AH],ES
        MOV     DI,4                    ; INT 2 (NMI)
        MOV     BX,OFFSET INTRET
        XCHG    AX,BX
        STOSW
        XCHG    AX,BX
        STOSW
        ADD     DI,4
        XCHG    AX,BX
        STOSW
        XCHG    AX,BX
        STOSW
        XCHG    AX,BX
        STOSW
        XCHG    AX,BX
        STOSW
        ADD     DI,28H
        XCHG    AX,BX
        STOSW
        XCHG    AX,BX
        STOSW
        MOV     WORD PTR DS:[500H],DX
        MOV     WORD PTR DS:[504H],DX
        MOV     DI,522H                 ; Write DPT to 0:522
        MOV     AX,2DFH
        STOSW
        MOV     AX,225H
        STOSW
        MOV     AX,2A09H                ; 9 sectors per track
        STOSW
        MOV     AX,50FFH
        STOSW
        MOV     AX,0F6H
        STOSW
        MOV     AL,2
        STOSB
        INT     12H                     ; Get memory size in 1K units
        MOV     CL,6                    ; Convert KB to paragraphs
        SHL     AX,CL
        POP     CX
        MOV     CS:DRVFAT,CX
        MOV     DX,SEG SYSINIT
        MOV     DS,DX
ASSUME  DS:SEG SYSINIT
        MOV     DS:MEMORY_SIZE,AX       ; Mem size in paras
        INC     CL
        MOV     DS:DEFAULT_DRIVE,CL     ; Store to DEFAULT_DRIVE
DOSSEG  = ((((OFFSET END$)-(OFFSET START$))+15)/16)+BIOSSEG+SYSIZE
        MOV     WORD PTR DS:CURRENT_DOS_LOCATION,DOSSEG
NEWSEG  = ((((OFFSET INIT$)-(OFFSET START$))+15)/16)+BIOSSEG
        MOV     WORD PTR DS:FINAL_DOS_LOCATION,NEWSEG
        MOV     WORD PTR DS:DEVICE_LIST,OFFSET DEVSTART ; To DEVICE_LIST
        MOV     AX,CS
        MOV     WORD PTR DS:DEVICE_LIST+2,AX    ; DEVICE_LIST segment
        PUSH    CS
        PUSH    CS
        POP     DS
ASSUME  DS:CODE
        POP     ES
        XOR     SI,SI                   ; Write to 70:0, FORMAT looks there
        MOV     WORD PTR [SI],OFFSET HARDDRV
        INT     11H                     ; Get equipment flags
        AND     AL,0C0H
        JNZ     MORDRV
        INC     PHANTOM
MORDRV:
        POP     AX
        MOV     [HARDNUM],AL
        MOV     [DRVMAX],AL
        SHL     AX,1
        MOV     DI,OFFSET DSKDRVS
        ADD     DI,AX
        MOV     SI,OFFSET HDSKTAB
        MOVSW
        MOVSW
        MOV     AH,8
        MOV     DL,80H
        INT     13H                     ; Get drive parameters (1st hard disk)
        JB      ENDDRV

        MOV     HNUM,DL                 ; Number of hard disks
ENDDRV:
        MOV     DL,80H
        MOV     DI,OFFSET HDRIVE
        CMP     HNUM,0
        JLE     CONFIGURE
        CALL    SETHARD
        MOV     DL,81H
        MOV     DI,OFFSET DRIVEX
        JC      CHKHD2
        CMP     HNUM,2
        JZ      TWOHD
        JMP     SHORT SETIT1

CHKHD2:
        MOV     HARDDRV,DL
        MOV     DI,OFFSET HDRIVE
        DEC     HNUM
        CMP     HNUM,0
        JZ      CONFIGURE
TWOHD:
        CALL    SETHARD
        JNB     SETIT1
        DEC     HNUM
SETIT1:
        MOV     AL,HNUM
        OR      AL,AL
        JZ      CONFIGURE
        ADD     AL,[HARDNUM]
        MOV     DRVMAX,AL
        MOV     AL,HNUM
        JMP     SHORT CFGHD

CONFIGURE:
        CMP     PHANTOM,1
        JZ      CFGDONE
        MOV     DX,SEG SYSINIT
        MOV     DS,DX
ASSUME  DS:SEG SYSINIT
NEWSEG  = ((((OFFSET NOSWAP$)-(OFFSET START$))+15)/16)+BIOSSEG
        MOV     WORD PTR DS:FINAL_DOS_LOCATION,NEWSEG
        JMP     SHORT CFGDONE

CFGHD:
        MOV     DX,SEG SYSINIT
        MOV     DS,DX
NEWSEG  = ((((OFFSET INITHD1$)-(OFFSET START$))+15)/16)+BIOSSEG
        MOV     WORD PTR DS:FINAL_DOS_LOCATION,NEWSEG
        DEC     AL
        JZ      CFGDONE
NEWSEG  = ((((OFFSET INITHD2$)-(OFFSET START$))+15)/16)+BIOSSEG
        MOV     WORD PTR DS:FINAL_DOS_LOCATION,NEWSEG
CFGDONE:
        PUSH    CS
        POP     DS
ASSUME  DS:CODE
        CALL    GETFAT
        XOR     DI,DI
        MOV     AL,ES:[DI]
        MOV     BYTE PTR DRVFAT+1,AL
        MOV     AX,DRVFAT
        CALL    SETDRIVE
        MOV     CL,[DI+2]
        MOV     AX,[DI+11H]
        SUB     BIOSTRT,AX
        XOR     CH,CH
        PUSH    DS
        XOR     DI,DI
        MOV     DS,DI                   ; ES:DI POINTS TO LOAD LOCATION
        MOV     BX,WORD PTR DS:[53AH]   ; clus=*53A;
        POP     DS
LOADIT:
        MOV     AX,DOSSEG
        MOV     ES,AX
ASSUME  ES:NOTHING
        CALL    GETCLUS
        CMP     BX,0FFFH
        JNZ     LOADIT
        JMP     SYSINIT

GETFAT:
        XOR     DI,DI
        MOV     CX,1
        MOV     DX,CX
        MOV     AX,7C0H                 ; FATLOC
        MOV     ES,AX
        MOV     AL,BYTE PTR DRVFAT
        MOV     AH,0FCH
        JMP     DISKRD


GETBOOT:
        MOV     CX,1
        MOV     AX,201H                 ; Read one sector
        MOV     BX,7C0H                 ; Read to 7C0:0 aka 0:7C00
        MOV     ES,BX
        XOR     BX,BX
        MOV     DH,BH
        INT     13H
        JB      ERRET
        CMP     WORD PTR ES:1FEH,0AA55H ; Check boot sector signature
        JNZ     ERRET
        RET


SETHARD:
        PUSH    DX
        MOV     AH,8
        INT     13H                     ; Get drive parameters
        INC     DH
        MOV     [DI+0FH],DH
        POP     DX
        JB      ERRET
        AND     CL,3FH                  ; extract number of sectors/track
        MOV     [DI+0DH],CL
        CALL    GETBOOT                 ; Check boot sector signature
        JB      ERRET
        MOV     BX,1C2H
SET1:
        CMP     BYTE PTR ES:[BX],1
        JZ      SET2
        ADD     BX,16
        CMP     BX,202H
        JNZ     SET1

ERRET:
        STC
        RET

SET2:
        MOV     AX,ES:[BX+4]
        MOV     [DI+11H],AX
        MOV     AX,ES:[BX+8]
        CMP     AX,40H
        JB      ERRET
        MOV     [DI+8],AX
        MOV     CX,100H
        MOV     DX,40H
        CMP     AX,200H
        JBE     GOTPARM
        ADD     CH,CH
        INC     CL
        MOV     DX,70H
        CMP     AX,800H
        JBE     GOTPARM
        ADD     CH,CH
        INC     CL
        MOV     DX,100H
        CMP     AX,2000H
        JBE     GOTPARM
        ADD     CH,CH
        INC     CL
        ADD     DX,DX
        CMP     AX,7FA8H
        JBE     GOTPARM
        ADD     CH,CH
        INC     CL
        ADD     DX,DX
GOTPARM:
        MOV     [DI+6],DX
        MOV     [DI+2],CH
        XOR     BX,BX
        MOV     BL,CH
        DEC     BX
        ADD     BX,AX
        SHR     BX,CL
        INC     BX
        AND     BL,0FEH
        MOV     SI,BX
        SHR     BX,1
        ADD     BX,SI
        ADD     BX,511
        SHR     BH,1
        MOV     [DI+0BH],BH
        CLC
        RET


GETCLUS:
        PUSH    CX
        PUSH    DI
        MOV     DOSCNT,CX
        MOV     AX,BX
        DEC     AX
        DEC     AX
        MUL     CX
        ADD     AX,BIOSTRT
        MOV     DX,AX
GETCL1:
        CALL    UNPACK
        SUB     SI,BX
        CMP     SI,-1
        JNZ     GETCL2
        ADD     DOSCNT,CX
        JMP     GETCL1

GETCL2:
        PUSH    BX
        MOV     AX,DRVFAT
        MOV     CX,DOSCNT
        CALL    DISKRD
        POP     BX
        POP     DI
        MOV     AX,DOSCNT
        XCHG    AH,AL
        SHL     AX,1
        ADD     DI,AX
        POP     CX
        RET


UNPACK:
        PUSH    DS
        PUSH    BX
        MOV     SI,7C0H                 ; FATLOC
        MOV     DS,SI
        MOV     SI,BX
        SHR     SI,1
        MOV     BX,[BX+SI]
        JNB     HAVCLUS
        SHR     BX,1
        SHR     BX,1
        SHR     BX,1
        SHR     BX,1
HAVCLUS:
        AND     BX,0FFFH
        POP     SI
        POP     DS
        RET


PRINT_INIT:
        MOV     BH,1
        MOV     DL,17H                  ; Do INT 17H
        JMP     SHORT DEV_INIT

AUX_INIT:
        MOV     BX,0A3H                 ; RSINIT
        MOV     DL,14H                  ; Do INT 14H
DEV_INIT:
        MOV     BYTE PTR CS:INT_INS+1,DL
        MOV     AL,CS:[SI+0DH]
        SUB     AL,"1"
        CBW
        MOV     DX,AX
        MOV     AX,BX
INT_INS:
        INT     17H                     ; Printer service
        RET

END$:

CODE    ENDS

        END

