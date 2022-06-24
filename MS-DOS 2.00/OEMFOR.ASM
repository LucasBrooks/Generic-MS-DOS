;
; OEM Disk Format Module for FORMAT
;

FALSE   EQU     0
TRUE    EQU     NOT FALSE

IBMJAPVER EQU   FALSE           ; SET ONLY ONE SWITCH TO TRUE!
IBMVER  EQU     FALSE
MSVER   EQU     TRUE

KANJI   EQU     FALSE

        .xlist
        INCLUDE DOSSYM.ASM
        .list

CODE    SEGMENT PUBLIC 'CODE'

        ASSUME  CS:CODE,DS:CODE,ES:CODE

        PUBLIC  FATID,STARTSECTOR,SWITCHLIST,FREESPACE,FATSPACE
        PUBLIC  INIT,DISKFORMAT,BADSECTOR,DONE,WRTFAT,HARDFLAG
        EXTRN   SWITCHMAP:WORD,DRIVE:BYTE

        DW      OFFSET BOOT2X
        DW      OFFSET BOOT1X

WRTFAT:
        MOV     AL,DRIVE
        CBW
        MOV     CX,FATSECS              ; All FAT sectors
        MOV     DX,1                    ; Starting sector of 1st FAT
        MOV     BX,FATSPACE
        INT     26H                     ; Absolute disk write
        POP     AX
        JB      GORET
        MOV     AL,DRIVE
        CBW
        MOV     CX,FATSECS              ; All FAT sectors
        MOV     DX,CX
        INC     DX                      ; Starting sector of 2nd FAT
        MOV     BX,FATSPACE
        INT     26H                     ; Absolute disk write
        POP     AX
        JB      GORET
        JMP     SHORT OKRET

INIT:
        MOV     AL,DRIVE
        MOV     FMTDRIVE,AL
        INT     11H                     ; EQUIPMENT DETERMINATION
                                        ; Return: AX = equipment flag bits
        ROL     AL,1
        ROL     AL,1
        AND     AX,3                    ; Any additional drives installed?
        JNZ     INIT1
        MOV     BYTE PTR FMTDRIVE,0     ; No, force A: (drive 0)
        INC     AX
INIT1:
        MOV     BYTE PTR HARDFLAG,0
        CMP     DRIVE,AL
        JBE     PHANTOM
        MOV     HARDFLAG,AL
        PUSH    AX
        MOV     AH,8
        MOV     DL,80H
        INT     13H                     ; Get drive parms, returns # of drives in DL
        POP     AX
        JB      SETDRV

        ADD     AL,DL
SETDRV:
        CMP     DRIVE,AL
        JBE     DRVOK
        MOV     DX,OFFSET NOTCDM
        JMP     SHORT OUTMSG

DRVOK:
        TEST    SWITCHMAP,6             ; SWITCH_8+SWITCH_1
        JZ      OKRET
        MOV     DX,OFFSET HDCOMPM
OUTMSG:
        CALL    PRTMSG
        STC
        RET

PHANTOM:
        MOV     AL,DRIVE
        PUSH    DS
        MOV     BX,50H
        MOV     DS,BX
        ASSUME  DS:NOTHING
        MOV     DS:4,AL
        POP     DS
        ASSUME  DS:CODE
        MOV     AL,BYTE PTR SWITCHMAP
        AND     AL,0DH                  ; Mask SWITCH_8+SWITCH_V+SWITCH_S
        CMP     AL,0CH                  ; SWITCH_8+SWITCH_V?
        JNZ     OKRET
        MOV     DX,OFFSET INCOMPM
        JMP     SHORT OUTMSG

OKRET:
        CLC
GORET:
        RET

DONE:
        TEST    SWITCHMAP,4             ; SWITCH_B?
        JZ      OKRET
        MOV     AL,DRIVE
        CBW
        MOV     CX,7                    ; Read 7 sectors
        MOV     DX,3                    ; 4th sector -- root directory
        MOV     BX,FATSPACE
        INT     25H                     ; Absolute disk read
        POP     AX
        JB      GORET
        MOV     BX,FATSPACE
        MOV     BYTE PTR [BX+11],6
        MOV     BYTE PTR [BX+11+32],6
        MOV     AX,NUMENTY
        DEC     AX
        MOV     BX,32
        MUL     BX
        ADD     AX,FATSPACE
        MOV     BX,AX
        XOR     AX,AX
        MOV     AH,0E5H                 ; Unused directory entry marker
NXTROOT:
        CMP     [BX],AL
        JNZ     WR_ROOT
        MOV     [BX],AH                 ; Set markers for DOS 1.x
        SUB     BX,32
        CMP     BX,FATSPACE
        JNB     NXTROOT
WR_ROOT:
        MOV     AL,DRIVE
        CBW
        MOV     CX,7                    ; Write 7 sectors
        MOV     DX,3                    ; Start at sector 3 (4th sector)
        MOV     BX,FATSPACE
        INT     26H                     ; Absolute disk write
        POP     AX
DON_ERR2:
        JB      GORET
        TEST    SWITCHMAP,1             ; SWITCH_S?
        JNZ     DONEOK
        MOV     AL,DRIVE
        CBW
        MOV     BX,OFFSET BOOT1X
        CMP     BYTE PTR FATID,0FEH     ; Single-sided 8-sector disk?
        JZ      WRSEC
        MOV     WORD PTR [BX+3],103H    ; Fix up starting sector of system area
WRSEC:
        MOV     CX,1
        XOR     DX,DX
        INT     26H                     ; Absolute disk write
        POP     AX
        JB      DON_ERR2
DONEOK:
        CLC
        RET

DISKFORMAT:
        CMP     HARDFLAG,0
        JNZ     FMTHARD
        JMP     FMTFLOP

FMTHARD:
        MOV     BYTE PTR FATID,0F8H
        XOR     BX,BX
        MOV     WORD PTR HDD_BPB,BX     ; Initially points to 70:0
        PUSH    DS
        LDS     BX,HDD_BPB
        MOV     BX,[BX]                 ; Word at 70:0 is offset of HARDDRV in IBMBIO
        MOV     AL,[BX]                 ; First BIOS drive number
        INC     BX                      ; Point to the hard disk BPB
        POP     DS
        MOV     WORD PTR HDD_BPB,BX
        MOV     HARDDRV,AL
        MOV     DL,DRIVE
        SUB     DL,HARDFLAG
        DEC     DL
        JZ      HAVHDD                  ; Was it the first hard disk?
        ADD     WORD PTR HDD_BPB,19     ; No, point to the second BPB
HAVHDD:
        ADD     DL,HARDDRV
        MOV     FMTDRIVE,DL
        CALL    GETHDPARM
        JMP     FMTCMN

FMTFLOP:
        MOV     CURCYL,0
        MOV     TRACKS,40               ; 40 tracks
        MOV     BYTE PTR ERRFLG,0
        MOV     SI,OFFSET BPB92         ; 9 SPT, double sided
        TEST    SWITCHMAP,2             ; SWITCH_1?
        JZ      CHK8SEC
        MOV     SI,OFFSET BPB91         ; 9 SPT, single sided
        TEST    SWITCHMAP,4             ; SWITCH_8?
        JZ      SETBPB
        MOV     SI,OFFSET BPB81         ; 8 SPT, single sided
        JMP     SHORT SETBPB

CHK8SEC:
        TEST    SWITCHMAP,4             ; SWITCH_8?
        JZ      SETBPB
        MOV     SI,OFFSET BPB82         ; 8 SPT, double sided
SETBPB:
        PUSH    DS
        POP     ES
        ASSUME  ES:CODE
        MOV     DI,OFFSET SECCLUS
        MOV     CX,12H
        NOP
        CLD
        REP     MOVSB                   ; Copy over, skip sector size (leave at 512)
FMTCMN:
        MOV     AL,NUMFATS
        CBW
        MUL     FATSECS
        ADD     AX,RESVSEC
        MOV     STARTSECTOR,AX
        MOV     AX,32
        MUL     NUMENTY
        MOV     BX,SECSIZE
        ADD     AX,BX
        DEC     AX
        XOR     DX,DX
        DIV     BX
        ADD     STARTSECTOR,AX
        CALL    SETHEAD
        MOV     DX,OFFSET FMTPRGM
        CALL    PRTMSG
RSTTRY:
        CALL    DSKRESET
        JNB     RSTOK
        CALL    CHKERR
        CMP     BYTE PTR RETRIES,0
        JNZ     RSTTRY
RSTOK:
        CMP     HARDFLAG,0
        JNZ     TRKVERIFY
        MOV     BYTE PTR RETRIES,3
TRKFORMAT:
        MOV     DH,CURHEAD
        XOR     CH,CH
        CALL    FMTTRACK
        JNB     SETRETRY
        CALL    CHKERR
        CMP     BYTE PTR RETRIES,0
        JNZ     TRKFORMAT
        MOV     BYTE PTR ERRFLG,1
        CLC
        RET

SETRETRY:
        MOV     BYTE PTR RETRIES,3
        MOV     DH,CURHEAD
        DEC     CURHEAD
        OR      DH,DH
        JNZ     TRKFORMAT
        CALL    SETHEAD
TRKVERIFY:
        MOV     DH,CURHEAD
        CALL    SETCYL
        CALL    VFYTRACK
        JNC     FMTDON
        CALL    CHKERR
        CMP     BYTE PTR RETRIES,0
        JNZ     TRKVERIFY
        CMP     HARDFLAG,0
        JNZ     BADHDTRK
        CMP     CURHEAD,0
        JNZ     FIX1SIDE
BADHDTRK:
        MOV     BYTE PTR ERRFLG,1
        CLC
        RET

FIX1SIDE:
        DEC     BYTE PTR FATID
        SUB     BYTE PTR STARTSECTOR,3
        MOV     BYTE PTR NUMENTY,64
        MOV     BYTE PTR NUMHEAD,1
        SHR     NUMSECT,1
FMTDON:
        MOV     BYTE PTR RETRIES,3
        MOV     DH,CURHEAD
        DEC     CURHEAD
        OR      DH,DH
        JNZ     TRKVERIFY
        CALL    SETHEAD
        INC     CURCYL
        CLC
        RET

DSKRESET:
        MOV     AL,BYTE PTR SECTTRK
        MOV     CX,1
        MOV     DL,FMTDRIVE
        XOR     DH,DH
        MOV     AH,0                    ; Reset disk
        CALL    INT13
        RET

FMTTRACK:
        MOV     DI,1
        MOV     BX,OFFSET FMTMEND
        MOV     AL,9
NXTSEC:
        SUB     BX,4
        MOV     [BX],CH
        MOV     [BX+DI],DH
        DEC     AL
        JNZ     NXTSEC
        MOV     DL,FMTDRIVE
        MOV     AL,BYTE PTR SECTTRK
        MOV     AH,5                    ; Format track
        CALL    COPYMAP
        MOV     BX,60H                  ; Buffer at 60:0
        MOV     ES,BX
        ASSUME  ES:NOTHING
        XOR     BX,BX
        CALL    INT13
        PUSH    CS
        POP     ES
        ASSUME  ES:CODE
        CALL    COPYMAP
        RET

VFYTRACK:
        MOV     DL,FMTDRIVE
        MOV     AL,BYTE PTR SECTTRK     ; One track
        OR      CL,1                    ; Start at sector 1
        MOV     AH,4                    ; Verify disk sectors
        CALL    INT13
        RET

CHKERR:
        CMP     AH,3
        JNZ     NOTWP
        MOV     DX,OFFSET WPERRM
PRTERR:
        CALL    PRTMSG
        MOV     AH,0                    ; Reset disk
        CALL    INT13
        ADD     SP,2
        JMP     RETERR

NOTWP:
        CMP     AH,80H
        JNZ     GENERR
        MOV     DX,OFFSET NOTRDYM
        JMP     SHORT PRTERR

GENERR:
        MOV     AH,0                    ; Reset disk
        CALL    INT13
        DEC     BYTE PTR RETRIES
        RET

BADSECTOR:
        MOV     BYTE PTR RETRIES,3
        CMP     BYTE PTR ERRFLG,0       ; Was there an error?
        JZ      FMTCONT
        MOV     BYTE PTR ERRFLG,0       ; Yes, clear flag and report
        XOR     AX,AX
        MOV     BX,AX                   ; Bad sector number
        MOV     AL,BYTE PTR SECTTRK     ; Number of consecutive sectors
        CLC
        RET

FMTCONT:
        CALL    DSKRESET
        JNB     NEXTTRACK
        CALL    CHKERR
        CMP     BYTE PTR RETRIES,0
        JNZ     FMTCONT
NEXTTRACK:
        MOV     CX,CURCYL
        CMP     CX,TRACKS               ; All tracks/cylinders done?
        JZ      WRBOOT
        CMP     HARDFLAG,0
        JNZ     RETRYVFY
        MOV     BYTE PTR RETRIES,3
TRYFMT:
        MOV     DH,CURHEAD
        MOV     CH,BYTE PTR CURCYL
        CALL    FMTTRACK
        JNB     RETRYVFY
        CALL    CHKERR
        CMP     BYTE PTR RETRIES,0      ; Retries left?
        JNZ     TRYFMT
        JMP     RPTBAD                  ; Report bad sectors (track)

RETRYVFY:
        MOV     BYTE PTR RETRIES,3
TRYVFY:
        MOV     DH,CURHEAD
        CALL    SETCYL
        CALL    VFYTRACK
        JNB     NXTHED
        CALL    CHKERR
        CMP     BYTE PTR RETRIES,0      ; Retries left?
        JNZ     TRYVFY
        JMP     RPTBAD                  ; Report bad sectors (track)

NXTHED:
        MOV     DH,CURHEAD
        DEC     CURHEAD
        OR      DH,DH                   ; Last head done?
        JNZ     NEXTTRACK               ; No, next head on same cylinder
        CALL    SETHEAD
        CALL    SETCYL
        MOV     DX,CURCYL
        INC     DX                      ; Next cylinder
        MOV     CURCYL,DX
        JMP     SHORT NEXTTRACK

WRBOOT:
        MOV     BX,OFFSET BOOT2X
        MOV     DX,0                    ; Start at very first sector
        MOV     CX,1                    ; Write 1 sector
        MOV     AH,0
        MOV     AL,DRIVE
        INT     26H                     ; Absolute disk write
        JB      BTWERR
        MOV     DX,OFFSET FMTDONM
        CALL    PRTMSG
        POPF
        XOR     AX,AX
        CLC
        RET

BTWERR:
        POPF
        MOV     DX,OFFSET BWERRM
        CALL    PRTMSG
RETERR:
        STC
        RET

RPTBAD:
        MOV     AX,CURCYL
        MUL     NUMHEAD
        MOV     BL,CURHEAD
        XOR     BH,BH
        ADD     AX,BX
        MUL     SECTTRK
        SUB     AX,HIDHIGH
        MOV     BX,AX                   ; First bad sector to report
        MOV     DH,CURHEAD
        DEC     CURHEAD
        OR      DH,DH                   ; Done last head?
        JNZ     BSRET
        CALL    SETHEAD                 ; Reset head
        INC     CURCYL                  ; Next track/cylinder
BSRET:
        MOV     AX,SECTTRK              ; Number of consecutive sectors
        CLC
        RET

PRTMSG:
        MOV     AH,9
        INT     21H                     ; DOS Print String
        RET

SETCYL:
        MOV     CX,CURCYL
        XCHG    CH,CL
        ROR     CL,1
        ROR     CL,1
        AND     CL,0C0H
        RET

GETHDPARM:
        PUSH    DS
        POP     ES
        MOV     DI,OFFSET SECSIZE
        LDS     SI,HDD_BPB
        MOV     CX,19
        CLD
        REP     MOVSB                   ; Copy BPB from IBMBIO
        PUSH    CS
        POP     DS
        MOV     AX,HIDHIGH
        MOV     BX,NUMSECT
        CALL    CALC_CYL
        DEC     AX
        MOV     CURCYL,AX
        MOV     AX,BX
        CALL    CALC_CYL
        ADD     AX,CURCYL
        MOV     TRACKS,AX
        RET

CALC_CYL:
        PUSH    AX
        MOV     AL,BYTE PTR NUMHEAD
        MUL     BYTE PTR SECTTRK
        MOV     CX,AX
        POP     AX
        ADD     AX,CX
        DEC     AX
        XOR     DX,DX
        DIV     CX
        RET

SETHEAD:
        MOV     DH,BYTE PTR NUMHEAD
        DEC     DH
        MOV     CURHEAD,DH
        RET

COPYMAP:
        PUSHF
        PUSH    ES
        PUSH    DI
        PUSH    SI
        PUSH    CX
        PUSH    BX
        PUSH    AX
        MOV     DI,60H
        MOV     ES,DI
        ASSUME  ES:NOTHING
        XOR     DI,DI
        MOV     SI,OFFSET FMTMAP
        MOV     CX,18                   ; 9*4 bytes
MCPYLP:
        LODSW
        MOV     BX,ES:[DI]
        STOSW
        MOV     [SI-2],BX
        LOOP    MCPYLP
        POP     AX
        POP     BX
        POP     CX
        POP     SI
        POP     DI
        POP     ES
        ASSUME  ES:NOTHING
        POPF
        RET

INT13:
        INT     13H
        RET


SWITCHLIST:
        DB      5
        DB      "B"                     ; 8-sector disk that can be made
                                        ; bootable under either DOS 1.x or 2.x
        DB      "V"                     ; Ask for a volume label
        DB      "8"                     ; 8 sectors per track
        DB      "1"                     ; Single-sided format
        DB      "S"                     ; Copy system files

BPB81   DB      1
        DW      1
        DB      2
        DW      64
        DW      320
        DB      0FEH
        DW      1
        DW      8
        DW      1
        DW      0
        DB      0

BPB82   DB      2
        DW      1
        DB      2
        DW      112
        DW      640
        DB      0FFH
        DW      1
        DW      8
        DW      2
        DW      0
        DB      0

BPB91   DB      1
        DW      1
        DB      2
        DW      64
        DW      360
        DB      0FCH
        DW      2
        DW      9
        DW      1
        DW      0
        DB      0

BPB92   DB      2
        DW      1
        DB      2
        DW      112
        DW      720
        DB      0FDH
        DW      2
        DW      9
        DW      2
        DW      0
        DB      0

FMTPRGM DB      "Formatting...$0"
FMTDONM DB      "Format complete",13,10,"$"
WPERRM  DB      13,10,"Attempted write-protect violation",13,10,"$"
BWERRM  DB      13,10,"Unable to write BOOT",13,10,"$"
HDCOMPM DB      13,10,"Parameter not compatible with fixed disk",13,10,"$"
INCOMPM DB      13,10,"Parameters not compatible",13,10,"$"
NOTRDYM DB      13,10,"Drive not ready",13,10,"$"
NOTCDM  DB      13,10,"Disk not compatible",13,10,"$"

FMTMAP  DB      0                       ; Floppy format template
        DB      0
        DB      1
        DB      2
        DB      0
        DB      0
        DB      2
        DB      2
        DB      0
        DB      0
        DB      3
        DB      2
        DB      0
        DB      0
        DB      4
        DB      2
        DB      0
        DB      0
        DB      5
        DB      2
        DB      0
        DB      0
        DB      6
        DB      2
        DB      0
        DB      0
        DB      7
        DB      2
        DB      0
        DB      0
        DB      8
        DB      2
        DB      0
        DB      0
        DB      9
        DB      2
FMTMEND:

HARDFLAG        DB      0
FMTDRIVE        DB      0
CURCYL          DW      0

CURHEAD         DB      0

ERRFLG          DB      0

RETRIES         DB      0

STARTSECTOR     DW      0
TRACKS          DW      0

HDD_BPB         DD      700000H

FREESPACE       DW      3050H
FATSPACE        DW      OFFSET FAT_SPACE

;
; Unmodified PC-DOS 1.10 boot sector here
;

BOOT1X:
        DB      0EBH,027H,090H,008H,000H,014H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,0CDH
        DB      019H,0FAH,08CH,0C8H,08EH,0D8H,033H,0D2H
        DB      08EH,0D2H,0BCH,000H,07CH,0FBH,0B8H,060H
        DB      000H,08EH,0D8H,08EH,0C0H,033H,0D2H,08BH
        DB      0C2H,0CDH,013H,072H,069H,0E8H,085H,000H
        DB      072H,0DDH,02EH,083H,03EH,003H,07CH,008H
        DB      074H,006H,02EH,0C6H,006H,064H,07DH,002H
        DB      0BBH,000H,000H,02EH,08BH,00EH,003H,07CH
        DB      051H,0B0H,009H,02AH,0C1H,0B4H,000H,08BH
        DB      0F0H,056H,033H,0D2H,033H,0C0H,08AH,0C5H
        DB      02EH,0F6H,036H,064H,07DH,08AH,0E8H,08AH
        DB      0F4H,08BH,0C6H,0B4H,002H,0CDH,013H,072H
        DB      02DH,05EH,059H,02EH,029H,036H,005H,07CH
        DB      074H,01FH,08BH,0C6H,02EH,0F7H,026H,065H
        DB      07DH,003H,0D8H,0FEH,0C5H,0B1H,001H,051H
        DB      0BEH,008H,000H,02EH,03BH,036H,005H,07CH
        DB      07CH,005H,02EH,08BH,036H,005H,07CH,0EBH
        DB      0C0H,0EAH,000H,000H,060H,000H,0BEH,067H
        DB      07DH,0E8H,002H,000H,0EBH,0FEH,032H,0FFH
        DB      02EH,0ACH,024H,07FH,074H,00BH,056H,0B4H
        DB      00EH,0BBH,007H,000H,0CDH,010H,05EH,0EBH
        DB      0EFH,0C3H,0E9H,033H,0FFH,0BBH,000H,000H
        DB      0B9H,004H,000H,0B8H,001H,002H,0CDH,013H
        DB      01EH,072H,033H,08CH,0C8H,08EH,0D8H,0BFH
;        IF      IBMVER OR IBMJAPVER     ; make names lowercase
        DB      000H,000H,0B9H,00BH,000H,026H,080H,00DH
;        ELSE                            ; leave them as is
;        DB      000H,000H,0B9H,00BH,000H,0EBH,00DH,00DH
;        ENDIF
        DB      020H,026H,080H,04DH,020H,020H,047H,0E2H
        DB      0F4H,0BFH,000H,000H,0BEH,08BH,07DH,0B9H
        DB      00BH,000H,0FCH,0F3H,0A6H,075H,00FH,0BFH
        DB      020H,000H,0BEH,097H,07DH,0B9H,00BH,000H
        DB      0F3H,0A6H,075H,002H,01FH,0C3H,0BEH,01BH
        DB      07DH,0E8H,0A2H,0FFH,0B4H,000H,0CDH,016H
        DB      01FH,0F9H,0C3H,00DH,00AH,04EH,06FH,06EH
        DB      02DH,053H,079H,073H,074H,065H,06DH,020H
        DB      064H,069H,073H,06BH,020H,06FH,072H,020H
        DB      064H,069H,073H,06BH,020H,065H,072H,072H
        DB      06FH,072H,00DH,00AH,052H,065H,070H,06CH
        DB      061H,063H,065H,020H,061H,06EH,064H,020H
        DB      073H,074H,072H,069H,06BH,065H,020H,061H
        DB      06EH,079H,020H,06BH,065H,079H,020H,077H
        DB      068H,065H,06EH,020H,072H,065H,061H,064H
        DB      079H,00DH,00AH,000H,001H,000H,002H,00DH
        DB      00AH,044H,069H,073H,06BH,020H,042H,06FH
        DB      06FH,074H,020H,066H,061H,069H,06CH,075H
        DB      072H,065H,00DH,00AH,000H,04DH,069H,063H
        DB      072H,06FH,073H,06FH,066H,074H,02CH,049H
        DB      06EH,063H,020H
;        IF      IBMVER OR IBMJAPVER
IODIR1  DB      "ibmbio  com",48
DOSDIR1 DB      "ibmdos  com",48
;        ELSE
;IODIR1  DB      "IO      SYS",0
;DOSDIR1 DB      "MSDOS   SYS",0
;        ENDIF
        DB      005H,0C6H,006H,077H,02FH
        DB      0FFH,083H,07EH,0FCH,000H,075H,00BH,080H
        DB      07EH,0F7H,03BH,075H,005H,0C6H,006H,076H
        DB      02FH,0FFH,089H,0ECH,05DH,0CAH,004H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H
        DB      000H,000H,000H,000H,000H,000H,000H,000H

BOOT2X:
        DB      0EBH,02CH,090H
        IF      IBMVER OR IBMJAPVER
        DB      "IBM  2.0"
        ELSE
        DB      "MSDOS2.0"
        ENDIF

SECSIZE DW      512
SECCLUS DB      8
RESVSEC DW      1
NUMFATS DB      2
NUMENTY DW      512
NUMSECT DW      5103H
FATID   DB      0F8H
FATSECS DW      8
SECTTRK DW      17
NUMHEAD DW      4
HIDHIGH DW      1
HARDDRV DB      80H

BPBSIZ  =       $ - SECCLUS

;
; Boot sector 2.0 code embedded
;
        DB      000H,00AH,0DFH,002H,025H,002H,009H,02AH
        DB      0FFH,050H,0F6H,000H,002H,0CDH,019H,0FAH
        DB      033H,0C0H,08EH,0D0H,0BCH,000H,07CH,08EH
        DB      0D8H,0A3H,07AH,000H,0C7H,006H,078H,000H
        DB      021H,07CH,0FBH,0CDH,013H,073H,003H,0E9H
        DB      095H,000H,00EH,01FH,0A0H,010H,07CH,098H
        DB      0F7H,026H,016H,07CH,003H,006H,01CH,07CH
        DB      003H,006H,00EH,07CH,0A3H,003H,07CH,0A3H
        DB      013H,07CH,0B8H,020H,000H,0F7H,026H,011H
        DB      07CH,005H,0FFH,001H,0BBH,000H,002H,0F7H
        DB      0F3H,001H,006H,013H,07CH,0E8H,07EH,000H
        DB      072H,0B3H,0A1H,013H,07CH,0A3H,07EH,07DH
        DB      0B8H,070H,000H,08EH,0C0H,08EH,0D8H,0BBH
        DB      000H,000H,02EH,0A1H,013H,07CH,0E8H,0B6H
        DB      000H,02EH,0A0H,018H,07CH,02EH,02AH,006H
        DB      015H,07CH,0FEH,0C0H,032H,0E4H,050H,0B4H
        DB      002H,0E8H,0C1H,000H,058H,072H,038H,02EH
        DB      028H,006H,020H,07CH,076H,00EH,02EH,001H
        DB      006H,013H,07CH,02EH,0F7H,026H,00BH,07CH
        DB      003H,0D8H,0EBH,0CEH,00EH,01FH,0CDH,011H
        DB      0D0H,0C0H,0D0H,0C0H,025H,003H,000H,075H
        DB      001H,040H,040H,08BH,0C8H,0F6H,006H,01EH
        DB      07CH,080H,075H,002H,033H,0C0H,08BH,01EH
        DB      07EH,07DH,0EAH,000H,000H,070H,000H,0BEH
        DB      0C9H,07DH,0E8H,002H,000H,0EBH,0FEH,02EH
        DB      0ACH,024H,07FH,074H,04DH,0B4H,00EH,0BBH
        DB      007H,000H,0CDH,010H,0EBH,0F1H,0B8H,050H
        DB      000H,08EH,0C0H,00EH,01FH,02EH,0A1H,003H
        DB      07CH,0E8H,043H,000H,0BBH,000H,000H,0B8H
        DB      001H,002H,0E8H,058H,000H,072H,02CH,033H
        IF      IBMVER OR IBMJAPVER     ; make names lowercase
        DB      0FFH,0B9H,00BH,000H,026H,080H,00DH,020H
        ELSE                            ; leave them as is
        DB      0FFH,0B9H,00BH,000H,0EBH,00CH,00DH,020H
        ENDIF
        DB      026H,080H,04DH,020H,020H,047H,0E2H,0F4H
        DB      033H,0FFH,0BEH,0DFH,07DH,0B9H,00BH,000H
        DB      0FCH,0F3H,0A6H,075H,00EH,0BFH,020H,000H
        DB      0BEH,0EBH,07DH,0B9H,00BH,000H,0F3H,0A6H
        DB      075H,001H,0C3H,0BEH,080H,07DH,0E8H,0A6H
        DB      0FFH,0B4H,000H,0CDH,016H,0F9H,0C3H,01EH
        DB      00EH,01FH,033H,0D2H,0F7H,036H,018H,07CH
        DB      0FEH,0C2H,088H,016H,015H,07CH,033H,0D2H
        DB      0F7H,036H,01AH,07CH,088H,016H,01FH,07CH
        DB      0A3H,008H,07CH,01FH,0C3H,02EH,08BH,016H
        DB      008H,07CH,0B1H,006H,0D2H,0E6H,02EH,00AH
        DB      036H,015H,07CH,08BH,0CAH,086H,0E9H,02EH
        DB      08BH,016H,01EH,07CH,0CDH,013H,0C3H,000H
        DB      000H,00DH,00AH,04EH,06FH,06EH,02DH,053H
        DB      079H,073H,074H,065H,06DH,020H,064H,069H
        DB      073H,06BH,020H,06FH,072H,020H,064H,069H
        DB      073H,06BH,020H,065H,072H,072H,06FH,072H
        DB      00DH,00AH,052H,065H,070H,06CH,061H,063H
        DB      065H,020H,061H,06EH,064H,020H,073H,074H
        DB      072H,069H,06BH,065H,020H,061H,06EH,079H
        DB      020H,06BH,065H,079H,020H,077H,068H,065H
        DB      06EH,020H,072H,065H,061H,064H,079H,00DH
        DB      00AH,000H,00DH,00AH,044H,069H,073H,06BH
        DB      020H,042H,06FH,06FH,074H,020H,066H,061H
        DB      069H,06CH,075H,072H,065H,00DH,00AH,000H
        IF      IBMVER OR IBMJAPVER
IODIR2  DB      "ibmbio  com",48
DOSDIR2 DB      "ibmdos  com",48
        ELSE
IODIR2  DB      "IO      SYS",0
DOSDIR2 DB      "MSDOS   SYS",0
        ENDIF
        DB      000H,000H,000H,000H,000H,000H,000H      ; pad to 512 bytes - 2
        DB      055H,0AAH


FAT_SPACE:
        DB      0F8H,0FFH,0FFH
        DB      45 DUP(0)

CODE    ENDS
        END
