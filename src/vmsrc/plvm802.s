;**********************************************************
;*
;*          APPLE ][ 65802/65816 PLASMA INTERPRETER
;*
;*              SYSTEM ROUTINES AND LOCATIONS
;*
;**********************************************************
        !CPU    65816
DEBUG   =       1
;*
;* THE DEFAULT CPU MODE FOR EXECUTING OPCODES IS:
;*   16 BIT A/M
;*    8 BIT X/Y
;*
;* THE EVALUATION STACK WILL BE THE HARDWARE STACK UNTIL
;* A CALL IS MADE. THE 16 BIT PARAMETERS WILL BE COPIED
;* TO THE ZERO PAGE INTERLEAVED EVALUATION STACK.
;*
;*
;* MONITOR SPECIAL LOCATIONS
;*
CSWL    =       $36
CSWH    =       $37
PROMPT  =       $33
;*
;* PRODOS
;*
PRODOS  =       $BF00
DEVCNT  =       $BF31            ; GLOBAL PAGE DEVICE COUNT
DEVLST  =       $BF32            ; GLOBAL PAGE DEVICE LIST
MACHID  =       $BF98            ; GLOBAL PAGE MACHINE ID BYTE
RAMSLOT =       $BF26            ; SLOT 3, DRIVE 2 IS /RAM'S DRIVER VECTOR
NODEV   =       $BF10
;*
;* HARDWARE ADDRESSES
;*
KEYBD   =       $C000
CLRKBD  =       $C010
SPKR    =       $C030
LCRDEN  =       $C080
LCWTEN  =       $C081
ROMEN   =       $C082
LCRWEN  =       $C083
LCBNK2  =       $00
LCBNK1  =       $08
ALTZPOFF=       $C008
ALTZPON =       $C009
ALTRDOFF=       $C002
ALTRDON =       $C003
ALTWROFF=       $C004
ALTWRON =       $C005
        !SOURCE "vmsrc/plvmzp.inc"
HWSP    =       TMPH+1
PSR     =       HWSP+1
DROP    =       $EF
NEXTOP  =       DROP+1
FETCHOP =       NEXTOP+3
IP      =       FETCHOP+1
IPL     =       IP
IPH     =       IPL+1
OPIDX   =       FETCHOP+4
OPPAGE  =       OPIDX+1
;
; BUFFER ADDRESSES
;
STRBUF  =       $0280
INTERP  =       $03D0
;*
;* HARDWARE STACK OFFSETS
;*
TOS     =       $01             ; TOS
NOS     =       $03             ; TOS-1
;*
;* INTERPRETER INSTRUCTION POINTER INCREMENT MACRO
;*
        !MACRO  INC_IP  {
        INY
        BNE     * + 8
        SEP     #$20            ; SET 8 BIT MODE
        !AS
        INC     IPH
        !AL
        REP     #$20            ; SET 16 BIT MODE
        }
;******************************
;*                            *
;* INTERPRETER INITIALIZATION *
;*                            *
;******************************
*        =      $2000
        LDX     #$FE
        TXS
        LDX     #$00
        STX     $01FF
;*
;* DISCONNECT /RAM
;*
        ;SEI                    ; DISABLE /RAM
        LDA     MACHID
        AND     #$30
        CMP     #$30
        BNE     RAMDONE
        LDA     RAMSLOT
        CMP     NODEV
        BNE     RAMCONT
        LDA     RAMSLOT+1
        CMP     NODEV+1
        BEQ     RAMDONE
RAMCONT LDY     DEVCNT
RAMLOOP LDA     DEVLST,Y
        AND     #$F3
        CMP     #$B3
        BEQ     GETLOOP
        DEY
        BPL     RAMLOOP
        BMI     RAMDONE
GETLOOP LDA     DEVLST+1,Y
        STA     DEVLST,Y
        BEQ     RAMEXIT
        INY
        BNE     GETLOOP
RAMEXIT LDA     NODEV
        STA     RAMSLOT
        LDA     NODEV+1
        STA     RAMSLOT+1
        DEC     DEVCNT
RAMDONE ;CLI UNTIL I KNOW WHAT TO DO WITH THE UNENHANCED IIE
;*
;* MOVE VM INTO LANGUAGE CARD
;*
        BIT     LCRWEN+LCBNK2
        BIT     LCRWEN+LCBNK2
        LDA     #<VMCORE
        STA     SRCL
        LDA     #>VMCORE
        STA     SRCH
        LDY     #$00
        STY     DSTL
        LDA     #$D0
        STA     DSTH
-       LDA     (SRC),Y         ; COPY VM+CMD INTO LANGUAGE CARD
        STA     (DST),Y
        INY
        BNE     -
        INC     SRCH
        INC     DSTH
        LDA     DSTH
        CMP     #$E0
        BNE     -
;*
;* MOVE FIRST PAGE OF 'BYE' INTO PLACE
;*
        STY     SRCL
        LDA     #$D1
        STA     SRCH
-       LDA     (SRC),Y
        STA     $1000,Y
        INY
        BNE     -
;*
;* SAVE DEFAULT COMMAND INTERPRETER PATH IN LC
;*
        JSR     PRODOS          ; GET PREFIX
        !BYTE   $C7
        !WORD   GETPFXPARMS
        LDY     STRBUF          ; APPEND "CMD"
        LDA     #"/"
        CMP     STRBUF,Y
        BEQ     +
        INY
        STA     STRBUF,Y
+       LDA     #"C"
        INY
        STA     STRBUF,Y
        LDA     #"M"
        INY
        STA     STRBUF,Y
        LDA     #"D"
        INY
        STA     STRBUF,Y
        STY     STRBUF
        BIT     LCRWEN+LCBNK2    ; COPY TO LC FOR BYE
        BIT     LCRWEN+LCBNK2
-       LDA     STRBUF,Y
        STA     LCDEFCMD,Y
        DEY
        BPL     -
        JMP     CMDENTRY
GETPFXPARMS !BYTE 1
        !WORD   STRBUF          ; PATH STRING GOES HERE
;************************************************
;*                                              *
;* LANGUAGE CARD RESIDENT PLASMA VM STARTS HERE *
;*                                              *
;************************************************
VMCORE  =        *
        !PSEUDOPC       $D000 {
;****************
;*              *
;* OPCODE TABLE *
;*              *
;****************
        !ALIGN  255,0
OPTBL   !WORD   ZERO,ADD,SUB,MUL,DIV,MOD,INCR,DECR              ; 00 02 04 06 08 0A 0C 0E
        !WORD   NEG,COMP,BAND,IOR,XOR,SHL,SHR,IDXW              ; 10 12 14 16 18 1A 1C 1E
        !WORD   LNOT,LOR,LAND,LA,LLA,CB,CW,CS                   ; 20 22 24 26 28 2A 2C 2E
        !WORD   DROP,DUP,PUSHEP,PULLEP,BRGT,BRLT,BREQ,BRNE      ; 30 32 34 36 38 3A 3C 3E
        !WORD   ISEQ,ISNE,ISGT,ISLT,ISGE,ISLE,BRFLS,BRTRU       ; 40 42 44 46 48 4A 4C 4E
        !WORD   BRNCH,IBRNCH,CALL,ICAL,ENTER,LEAVE,RET,CFFB     ; 50 52 54 56 58 5A 5C 5E
        !WORD   LB,LW,LLB,LLW,LAB,LAW,DLB,DLW                   ; 60 62 64 66 68 6A 6C 6E
        !WORD   SB,SW,SLB,SLW,SAB,SAW,DAB,DAW                   ; 70 72 74 76 78 7A 7C 7E
;*
;* ENTER INTO BYTECODE INTERPRETER - IMMEDIATELY SWITCH TO NATIVE
;*
        !AS
DINTRP  PHP
        PLA
        STA     PSR
        SEI
        CLC                     ; SWITCH TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        !AL
        PLA
        INC
        STA     IP
        LDA     IFP
        PHA                     ; SAVE ON STACK FOR LEAVE/RET
        LDA     PP              ; SET FP TO PP
        STA     IFP
        STX     ESP
        TSX
        STX     HWSP
        LDX     #>OPTBL
!IF DEBUG {
        BRA     SETDBG
} ELSE {
        STX     OPPAGE
        LDY     #$00
        JMP     FETCHOP
}
        !AS
IINTRP  PHP
        PLA
        STA     PSR
        SEI
        CLC                     ; SWITCH TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        !AL
        LDY     #$01
        LDA     (TOS,S),Y
        DEY
        STA     IP
        LDA     IFP
        STA     TOS,S           ; SAVE ON STACK FOR LEAVE/RET
        LDA     PP              ; SET FP TO PP
        STA     IFP
        STX     ESP
        TSX
        STX     HWSP
        LDX     #>OPTBL
!IF DEBUG {
        BRA     SETDBG
} ELSE {
        STX     OPPAGE
        JMP     FETCHOP
}
        !AS
IINTRPX PHP
        PLA
        STA     PSR
        SEI
        CLC                     ; SWITCH TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        !AL
        LDY     #$01
        LDA     (TOS,S),Y
        DEY
        STA     IP
        LDA     IFP
        STA     TOS,S           ; SAVE ON STACK FOR LEAVE/RET
        LDA     PP             ; SET FP TO PP
        STA     IFP
        STX     ESP
        TSX
        STX     HWSP
        STX     ALTRDON
        LDX     #>OPXTBL
!IF DEBUG {
SETDBG  LDY     LCRWEN+LCBNK2
        LDY     LCRWEN+LCBNK2
        STX     DBG_OP+2
        LDX     #>DBGTBL
        LDY     #$00
}
        STX     OPPAGE
        JMP     FETCHOP
;************************************************************
;*                                                          *
;* 'BYE' PROCESSING - COPIED TO $1000 ON PRODOS BYE COMMAND *
;*                                                          *
;************************************************************
        !AS
        !ALIGN  255,0
        !PSEUDOPC       $1000 {
BYE     LDY     DEFCMD
-       LDA     DEFCMD,Y        ; SET DEFAULT COMMAND WHEN CALLED FROM 'BYE'
        STA     STRBUF,Y
        DEY
        BPL     -
        INY                     ; CLEAR CMDLINE BUFF
        STY     $01FF
CMDENTRY =      *
;
; DEACTIVATE 80 COL CARDS
;
        BIT     ROMEN
        LDY     #4
-       LDA     DISABLE80,Y
        ORA     #$80
        JSR     $FDED
        DEY
        BPL     -
        BIT     $C054           ; SET TEXT MODE
        BIT     $C051
        BIT     $C05F
        JSR     $FC58           ; HOME
!IF     DEBUG {
        LDA     #20             ; SET TEXT WINDOW ABOVE DEBUG OUTPUT
        STA     $23
;        LDA     $BF98           ; FORCE 64K
;        AND     #$CF
;        STA     $BF98
}
;
; INSTALL PAGE 0 FETCHOP ROUTINE
;
        LDY     #$11
-       LDA     PAGE0,Y
        STA     DROP,Y
        DEY
        BPL     -
;
; INSTALL PAGE 3 VECTORS
;
        LDY     #$12
-       LDA     PAGE3,Y
        STA     INTERP,Y
        DEY
        BPL     -
;
; READ CMD INTO MEMORY
;
        JSR     PRODOS          ; CLOSE EVERYTHING
        !BYTE   $CC
        !WORD   CLOSEPARMS
        BNE     FAIL
        JSR     PRODOS          ; OPEN CMD
        !BYTE   $C8
        !WORD   OPENPARMS
        BNE     FAIL
        LDA     REFNUM
        STA     READPARMS+1
        JSR     PRODOS
        !BYTE   $CA
        !WORD   READPARMS
        BNE     FAIL
        JSR     PRODOS
        !BYTE   $CC
        !WORD   CLOSEPARMS
        BNE     FAIL
;
; INIT VM ENVIRONMENT STACK POINTERS
;
;        LDA #$00               ; INIT FRAME POINTER
        STA     PPL
        STA     IFPL
        LDA     #$BF
        STA     PPH
        STA     IFPH
        LDX     #$FE            ; INIT STACK POINTER (YES, $FE. SEE GETS)
        TXS
        LDX     #ESTKSZ/2       ; INIT EVAL STACK INDEX
        JMP     $2000           ; JUMP TO LOADED SYSTEM COMMAND
;
; PRINT FAIL MESSAGE, WAIT FOR KEYPRESS, AND REBOOT
;
FAIL    INC     $3F4            ; INVALIDATE POWER-UP BYTE
        LDY     #33
-       LDA     FAILMSG,Y
        ORA     #$80
        JSR     $FDED
        DEY
        BPL     -
        JSR     $FD0C           ; WAIT FOR KEYPRESS
        JMP     ($FFFC)         ; RESET
OPENPARMS !BYTE 3
        !WORD   STRBUF
        !WORD   $0800
REFNUM  !BYTE   0
READPARMS !BYTE 4
        !BYTE   0
        !WORD   $2000
        !WORD   $9F00
        !WORD   0
CLOSEPARMS !BYTE 1
        !BYTE   0
DISABLE80 !BYTE 21, 13, '1', 26, 13
FAILMSG !TEXT   "...TESER OT YEK YNA .DMC GNISSIM"
PAGE0    =      *
;******************************
;*                            *
;* INTERP BYTECODE INNER LOOP *
;*                            *
;******************************
        !PSEUDOPC       DROP {
        PLA                     ; DROP @ $EF
        INY                     ; NEXTOP @ $F0
        BEQ     NEXTOPH
        LDX     $FFFF,Y         ; FETCHOP @ $F3, IP MAPS OVER $FFFF @ $F4
        JMP     (OPTBL,X)       ; OPIDX AND OPPAGE MAP OVER OPTBL
NEXTOPH LDX     IPH
        INX
        STX     IPH
        BRA     FETCHOP
}
PAGE3   =       *
;*
;* PAGE 3 VECTORS INTO INTERPRETER
;*
        !PSEUDOPC       $03D0 {
        BIT     LCRDEN+LCBNK2   ; $03D0 - DIRECT INTERP ENTRY
        JMP     DINTRP
        BIT     LCRDEN+LCBNK2   ; $03D6 - INDIRECT INTERP ENTRY
        JMP     IINTRP
        BIT     LCRDEN+LCBNK2   ; $03DC - INDIRECT INTERPX ENTRY
        JMP     IINTRPX
}
!IF     DEBUG {
DEFCMD  !FILL   23
} ELSE {
DEFCMD  !FILL   28
}
ENDBYE  =       *
}
!IF     DEBUG {
LCDEFCMD =      *-23 ;*-28      ; DEFCMD IN LC MEMORY
} ELSE {
LCDEFCMD =      *-28            ; DEFCMD IN LC MEMORY
}
;*****************
;*               *
;* OPXCODE TABLE *
;*               *
;*****************
        !ALIGN  255,0
OPXTBL  !WORD   ZERO,ADD,SUB,MUL,DIV,MOD,INCR,DECR              ; 00 02 04 06 08 0A 0C 0E
        !WORD   NEG,COMP,BAND,IOR,XOR,SHL,SHR,IDXW              ; 10 12 14 16 18 1A 1C 1E
        !WORD   LNOT,LOR,LAND,LA,LLA,CB,CW,CSX                  ; 20 22 24 26 28 2A 2C 2E
        !WORD   DROP,DUP,PUSHEP,PULLEP,BRGT,BRLT,BREQ,BRNE      ; 30 32 34 36 38 3A 3C 3E
        !WORD   ISEQ,ISNE,ISGT,ISLT,ISGE,ISLE,BRFLS,BRTRU       ; 40 42 44 46 48 4A 4C 4E
        !WORD   BRNCH,IBRNCH,CALLX,ICALX,ENTER,LEAVEX,RETX,CFFB ; 50 52 54 56 58 5A 5C 5E
        !WORD   LBX,LWX,LLBX,LLWX,LABX,LAWX,DLB,DLW             ; 60 62 64 66 68 6A 6C 6E
        !WORD   SB,SW,SLB,SLW,SAB,SAW,DAB,DAW                   ; 70 72 74 76 78 7A 7C 7E
!IF     DEBUG {
;*
;* DEBUG PRINT ROUTINES
;*
        !AS
PRHEX   PHA
        LSR
        LSR
        LSR
        LSR
        CLC
        ADC     #'0'
        CMP     #':'
        BCC     +
        ADC     #6
+       ORA     #$80
        STA     $7D0,X
        INX
        PLA
        AND     #$0F
        ADC     #'0'
        CMP     #':'
        BCC     +
        ADC     #6
+       ORA     #$80
        STA     $7D0,X
        INX
        RTS
PRCHR   ORA     #$80
        STA     $7D0,X
        INX
        RTS
PRBYTE  PHA
        LDA     #'$'
        JSR     PRCHR
        PLA
        JMP     PRHEX
PRWORD  PHA
        LDA     #'$'
        JSR     PRCHR
        XBA
        JSR     PRHEX
        PLA
        JMP     PRHEX
;*****************
;*               *
;*  DEBUG TABLE  *
;*               *
;*****************
        !ALIGN  255,0
DBGTBL  !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 00 02 04 06 08 0A 0C 0E
        !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 10 12 14 16 18 1A 1C 1E
        !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 20 22 24 26 28 2A 2C 2E
        !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 30 32 34 36 38 3A 3C 3E
        !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 40 42 44 46 48 4A 4C 4E
        !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 50 52 54 56 58 5A 5C 5E
        !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 60 62 64 66 68 6A 6C 6E
        !WORD   STEP,STEP,STEP,STEP,STEP,STEP,STEP,STEP         ; 70 72 74 76 78 7A 7C 7E
        !AL
;*
;* DEBUG STEP ROUTINE
;*
STEP    STX     TMPL
        LDX     $C013           ; SAVE RAMRD
        STX     $C002
        STX     TMPH
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDX     #39             ; SCROLL PREVIOUS LINES UP
-       LDA     $6D0,X
        STA     $650,X
        LDA     $750,X
        STA     $6D0,X
        LDA     $7D0,X
        STA     $750,X
        DEX
        BPL     -
        BIT     TMPH            ; RAMRD SET?
        BPL     +
        STA     $C003
+       LDX     #$00
        REP     #$20            ; 16 BIT A/M
        !AL
        TYA
        CLC
        ADC     IP
        SEP     #$20            ; 8 BIT A/M
        !AS
        JSR     PRWORD
        LDA     #':'
        JSR     PRCHR
        LDA     (IP),Y
        JSR     PRBYTE
        INX
        REP     #$20            ; 16 BIT A/M
        !AL
        TSC
        SEP     #$20            ; 8 BIT A/M
        !AS
        JSR     PRWORD
        LDA     #$80+'['
        JSR     PRCHR
        STX     TMPH
        TSX
        TXA
        EOR     #$FF
        SEC
        ADC     HWSP
        LSR
        CLC
        ADC     #$80+'0'
        LDX     TMPH
        JSR     PRCHR
        LDA     #$80+']'
        JSR     PRCHR
        LDA     #':'
        JSR     PRCHR
        STX     TMPH
        TSX
        CPX     HWSP
        BEQ     ++
        BCC     +
        LDX     TMPH
        LDA     #' '
        JSR     PRCHR
        LDA     #'<'            ; STACK UNDERFLOW!
        JSR     PRCHR
        JSR     PRCHR
        JSR     PRCHR
        JSR     PRCHR
        BRA     DBGKEY
+       LDA     $102,X
        XBA
        LDA     $101,X
        LDX     TMPH
        JSR     PRWORD
        BRA     +++
++      LDX     TMPH
        LDA     #' '
        JSR     PRCHR
        LDA     #'-'
        JSR     PRCHR
        JSR     PRCHR
        JSR     PRCHR
        JSR     PRCHR
+++     LDA     #' '
-       JSR     PRCHR
        CPX     #40
        BNE     -
;        LDX     TMPL
;        CPX     #$56            ; FORCE PAUSE AT 'ICAL'
;        BEQ     DBGKEY
-       LDX     $C000
        CPX     #$9B
        BNE     +
DBGKEY  STX     $C010
-       LDX     $C000
        BPL     -
        CPX     #$9B
        BEQ     +
        STX     $C010
        CPX     #$80+'Q'
        BNE     +
        SEC                     ; SWITCH TO EMU MODE
        XCE
        BIT     $C054           ; SET TEXT MODE
        BIT     $C051
        BIT     $C05F
        LDA     #20             ; SET TEXT WINDOW ABOVE DEBUG OUTPUT
        STA     $23
        STZ     $20
        STZ     $22
        STZ     $24
        STZ     $25
        STZ     $28
        LDA     #$04
        STA     $29
        BRK
+       REP     #$20            ; 16 BIT A/M
        !AL
        LDX     TMPL
DBG_OP  JMP     (OPTBL,X)
}
;*********************************************************************
;*
;*      CODE BELOW HERE DEFAULTS TO NATIVE 16 BIT A/M, 8 BIT X,Y
;*
;*********************************************************************
        !AL
;*
;* ADD TOS TO TOS-1
;*
ADD     PLA
        CLC
        ADC     TOS,S
        STA     TOS,S
        JMP     NEXTOP
;*
;* SUB TOS FROM TOS-1(NOS)
;*
SUB     LDA     NOS,S
        SEC
        SBC     TOS,S
        STA     NOS,S
        JMP     DROP
;*
;* SHIFT TOS LEFT BY 1, ADD TO TOS-1
;*
IDXW    PLA
        ASL
        CLC
        ADC     TOS,S
        STA     TOS,S
        JMP     NEXTOP
;*
;* MUL TOS-1 BY TOS
;*
MUL     LDX     #$10
        LDA     NOS,S
        EOR     #$FFFF
        STA     TMP
        LDA     #$0000
MULLP   ASL     TMP             ;LSR     TMP             ; MULTPLR
        BCS     +
        ADC     TOS,S           ; MULTPLD
+       ASL                     ;ASL     TOS,S           ; MULTPLD
        DEX
        BNE     MULLP
        STA     NOS,S           ; PROD
        JMP     DROP
;*
;* INTERNAL DIVIDE ALGORITHM
;*
_DIV    STY     IPY
        LDY     #$11            ; #BITS+1
        LDX     #$00
        LDA     TOS+2,S         ; WE JSR'ED HERE SO OFFSET ACCORDINGLY
        BPL     +
        LDX     #$81
        EOR     #$FFFF
        INC
        STA     TOS+2,S
+       LDA     NOS+2,S
        BPL     +
        INX
        EOR     #$FFFF
        INC
+       STA     TMP             ; NOS,S
        BEQ     _DIVEX
_DIV1   ASL                     ; DVDND
        DEY
        BCC     _DIV1
        STA     TMP             ;NOS,S           ; DVDND
        LDA     #$0000          ; REMNDR
_DIVLP  ROL                     ; REMNDR
        CMP     TOS+2,S         ; DVSR
        BCC     +
        SBC     TOS+2,S         ; DVSR
        SEC
+       ROL     TMP             ;NOS,S           ; DVDND
        DEY
        BNE     _DIVLP
_DIVEX  LDY     IPY
        RTS
;*
;* DIV TOS-1 BY TOS
;*
DIV     JSR     _DIV
        LDA     TMP
        STA     NOS,S
        PLA
        TXA
        LSR                     ; SIGN(RESULT) = (SIGN(DIVIDEND) + SIGN(DIVISOR)) & 1
        BCS     NEG
        JMP     NEXTOP
;*
;* MOD TOS-1 BY TOS
;*
MOD     JSR     _DIV
        STA     NOS,S           ; REMNDR
        PLA
        TXA
        AND     #$0080          ; REMAINDER IS SIGN OF DIVIDEND
        BNE     NEG
        JMP     NEXTOP
;*
;* NEGATE TOS
;*
NEG     LDA     #$0000
        SEC
        SBC     TOS,S
        STA     TOS,S
        JMP     NEXTOP
;*
;* INCREMENT TOS
;*
INCR    LDA     TOS,S
        INC
        STA     TOS,S
        JMP     NEXTOP
;*
;* DECREMENT TOS
;*
DECR    LDA     TOS,S
        DEC
        STA     TOS,S
        JMP     NEXTOP
;*
;* BITWISE COMPLIMENT TOS
;*
COMP    LDA     TOS,S
        EOR     #$FFFF
        STA     TOS,S
        JMP     NEXTOP
;*
;* BITWISE AND TOS TO TOS-1
;*
BAND    PLA
        AND     TOS,S
        STA     TOS,S
        JMP     NEXTOP
;*
;* INCLUSIVE OR TOS TO TOS-1
;*
IOR     PLA
        ORA     TOS,S
        STA     TOS,S
        JMP     NEXTOP
;*
;* EXLUSIVE OR TOS TO TOS-1
;*
XOR     PLA
        EOR     TOS,S
        STA     TOS,S
        JMP     NEXTOP
;*
;* SHIFT TOS-1 LEFT BY TOS
;*
SHL     PLA
        TAX
        BEQ     SHLEX
        LDA     TOS,S
-       ASL
        DEX
        BNE     -
        STA     TOS,S
SHLEX   JMP     NEXTOP
;*
;* SHIFT TOS-1 RIGHT BY TOS
;*
SHR     PLA
        TAX
        BEQ     SHREX
        LDA     TOS,S
-       CMP     #$8000
        ROR
        DEX
        BNE     -
        STA     TOS,S
SHREX   JMP     NEXTOP
;*
;* LOGICAL NOT
;*
LNOT    LDA     TOS,S
        BEQ     LNOT1
        LDA     #$0001
LNOT1   DEC
        STA     TOS,S
        JMP     NEXTOP
;*
;* LOGICAL AND
;*
LAND    PLA
        BEQ     LAND1
        LDA     TOS,S
        BEQ     LAND2
        LDA     #$FFFF
LAND1   STA     TOS,S
LAND2   JMP     NEXTOP
;*
;* LOGICAL OR
;*
LOR     PLA
        ORA     TOS,S
        BEQ     LOR1
        LDA     #$FFFF
        STA     TOS,S
LOR1    JMP     NEXTOP
;*
;* DUPLICATE TOS
;*
DUP     LDA     TOS,S
        PHA
        JMP     NEXTOP
;*
;* PRIVATE EP STASH
;*
EPSAVE  !BYTE   $01             ; INDEX INTO STASH ARRAY (16 SHOULD BE ENOUGH)
        !WORD   $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
        !WORD   $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
;*
;* PUSH EVAL STACK POINTER TO PRIVATE STASH
;*
PUSHEP  LDX     LCRWEN+LCBNK2   ; RWEN LC MEM
        LDX     LCRWEN+LCBNK2
        LDX     EPSAVE
        TSC
        STA     EPSAVE,X
        INX
        INX
!IF     DEBUG {
        CPX     #33
        BCC     +
        LDX     #$80+'>'
        STX     $7D0+30
-       BRA     -
        LDX     #$32
+
}
        STX     EPSAVE
        LDX     LCRDEN+LCBNK2   ; REN LC MEM
        JMP     NEXTOP
;*
;* PULL EVAL STACK POINTER FROM PRIVATE STASH
;*
PULLEP  LDX     LCRWEN+LCBNK2   ; RWEN LC MEM
        LDX     LCRWEN+LCBNK2
        LDX     EPSAVE
        DEX
        DEX
!IF     DEBUG {
        BPL     +
        LDX     #$80+'<'
        STX     $7D0+30
-       BRA     -
        LDX     #$00
+
}
        LDA     EPSAVE,X
        TCS
        STX     EPSAVE
        LDX     LCRDEN+LCBNK2   ; REN LC MEM
        JMP     NEXTOP
;*
;* CONSTANT
;*
ZERO    PEA     $0000
        JMP     NEXTOP
CFFB    +INC_IP
        LDA     (IP),Y
        ORA     #$FF00
        PHA
        JMP     NEXTOP
CB      +INC_IP
        LDA     (IP),Y
        AND     #$00FF
        PHA
        JMP     NEXTOP
;*
;* LOAD ADDRESS & LOAD CONSTANT WORD (SAME THING, WITH OR WITHOUT FIXUP)
;*
LA      =       *
CW      +INC_IP
        LDA     (IP),Y
        +INC_IP
        PHA
        JMP     NEXTOP
;*
;* CONSTANT STRING
;*
CS      +INC_IP
        TYA                     ; NORMALIZE IP AND SAVE STRING ADDR ON ESTK
        CLC
        ADC     IP
        STA     IP
        PHA
        LDA     (IP)
        TAY
        JMP     NEXTOP
;
CSX     +INC_IP
        TYA                     ; NORMALIZE IP
        CLC
        ADC     IP
        STA     IP
        LDA     PP              ; SCAN POOL FOR STRING ALREADY THERE
_CMPPSX STA     TMP
        CMP     IFP             ; CHECK FOR END OF POOL
        BCS     _CPYSX          ; AT OR BEYOND END OF POOL, COPY STRING OVER
_CMPSX  SEP     #$20            ; 8 BIT A/M
        !AS
        STX     ALTRDOFF        ; CHECK FOR MATCHING STRING
        LDA     (TMP)           ; COMPARE STRINGS FROM AUX MEM TO STRINGS IN MAIN MEM
        STX     ALTRDON
        CMP     (IP)            ; COMPARE STRING LENGTHS
        BNE     _CNXTSX1
        TAY
-       STX     ALTRDOFF
        LDA     (TMP),Y         ; COMPARE STRING CHARS FROM END
        STX     ALTRDON
        CMP     (IP),Y
        BNE     _CNXTSX
        DEY
        BNE     -
        LDA     TMPH            ; MATCH - SAVE EXISTING ADDR ON ESTK AND MOVE ON
        PHA
        LDA     TMPL
        PHA
        BRA     _CEXSX
_CNXTSX STX     ALTRDOFF
        LDA     (TMP)
        STX     ALTRDON
_CNXTSX1 REP     #$20           ; 16 BIT A/M
        !AL
        AND     #$00FF
        SEC                     ; SKIP OVER STRING+LEN BYTE
        ADC     TMP
        BRA     _CMPPSX
_CPYSX  LDA     (IP)            ; COPY STRING FROM AUX TO MAIN MEM POOL
        TAY                     ; MAKE ROOM IN POOL AND SAVE ADDR ON ESTK
        AND     #$00FF
        EOR     #$FFFF
        CLC
        ADC     PP
        STA     PP
        PHA                     ; SAVE ADDRESS ON ESTK
        SEP     #$20            ; 8 BIT A/M
        !AS
-       LDA     (IP),Y          ; ALTRD IS ON,  NO NEED TO CHANGE IT HERE
        STA     (PP),Y          ; ALTWR IS OFF, NO NEED TO CHANGE IT HERE
        DEY
        CPY     #$FF
        BNE     -
_CEXSX  LDA     (IP)            ; SKIP TO NEXT OP ADDR AFTER STRING
        TAY
        REP     #$20            ; 16 BIT A/M
        !AL
        JMP     NEXTOP
;*
;* LOAD VALUE FROM ADDRESS TAG
;*
LB      TYX
        LDY     #$00
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     (TOS,S),Y
        REP     #$20            ; 16 BIT A/M
        !AL
        AND     #$00FF
        STA     TOS,S
        TXY
        JMP     NEXTOP
LW      TYX
        LDY     #$00
        LDA     (TOS,S),Y
        STA     TOS,S
        TXY
        JMP     NEXTOP
;
LBX     TYX
        LDY     #$00
        STX     ALTRDOFF
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     (TOS,S),Y
        REP     #$20            ; 16 BIT A/M
        !AL
        STX     ALTRDON
        AND     #$00FF
        STA     TOS,S
        TXY
        JMP     NEXTOP
LWX     TYX
        LDY     #$00
        STX     ALTRDOFF
        LDA     (TOS,S),Y
        STX     ALTRDON
        STA     TOS,S
        TXY
        JMP     NEXTOP
;*
;* LOAD ADDRESS OF LOCAL FRAME OFFSET
;*
LLA     +INC_IP
        LDA     (IP),Y
        AND     #$00FF
        CLC
        ADC     IFP
        PHA
        JMP     NEXTOP
;*
;* LOAD VALUE FROM LOCAL FRAME OFFSET
;*
LLB     +INC_IP
        LDA     (IP),Y
        TYX
        TAY
        LDA     (IFP),Y
        AND     #$00FF
        PHA
        TXY
        JMP     NEXTOP
LLW     +INC_IP
        LDA     (IP),Y
        TYX
        TAY
        LDA     (IFP),Y
        PHA
        TXY
        JMP     NEXTOP
;
LLBX    +INC_IP
        LDA     (IP),Y
        TYX
        TAY
        STX     ALTRDOFF
        LDA     (IFP),Y
        STX     ALTRDON
        AND     #$00FF
        PHA
        TXY
        JMP     NEXTOP
LLWX    +INC_IP
        LDA     (IP),Y
        TYX
        TAY
        STX     ALTRDOFF
        LDA     (IFP),Y
        STX     ALTRDON
        PHA
        TXY
        JMP     NEXTOP
;*
;* LOAD VALUE FROM ABSOLUTE ADDRESS
;*
LAB     +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     (TMP)
        REP     #$20            ; 16 BIT A/M
        !AL
        AND     #$00FF
        PHA
        JMP     NEXTOP
LAW     +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        LDA     (TMP)
        PHA
        JMP     NEXTOP
;
LABX    +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        SEP     #$20            ; 8 BIT A/M
        !AS
        STX     ALTRDOFF
        LDA     (TMP)
        STX     ALTRDON
        REP     #$20            ; 16 BIT A/M
        !AL
        AND     #$00FF
        PHA
        JMP     NEXTOP
LAWX    +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        STX     ALTRDOFF
        LDA     (TMP)
        STX     ALTRDON
        PHA
        JMP     NEXTOP
;
;*
;* STORE VALUE TO ADDRESS
;*
SB      TYX
        LDY     #$00
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     NOS,S
        STA     (TOS,S),Y
        REP     #$20            ; 16 BIT A/M
        !AL
        TXY
        PLA
        JMP     DROP
SW      TYX
        LDY     #$00
        LDA     NOS,S
        STA     (TOS,S),Y
        TXY
        PLA
        JMP     DROP
;*
;* STORE VALUE TO LOCAL FRAME OFFSET
;*
SLB     +INC_IP
        TYX
        LDA     (IP),Y
        TAY
        PLA
        SEP     #$20            ; 8 BIT A/M
        !AS
        STA     (IFP),Y
        REP     #$20            ; 16 BIT A/M
        !AL
        TXY
        JMP     NEXTOP
SLW     +INC_IP
        LDA     (IP),Y
        TYX
        TAY
        PLA
        STA     (IFP),Y
        TXY
        JMP     NEXTOP
;*
;* STORE VALUE TO LOCAL FRAME OFFSET WITHOUT POPPING STACK
;*
DLB     +INC_IP
        TYX
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     (IP),Y
        TAY
        LDA     TOS,S
        STA     (IFP),Y
        REP     #$20            ; 16 BIT A/M
        !AL
        TXY
        JMP     NEXTOP
DLW     +INC_IP
        LDA     (IP),Y
        TYX
        TAY
        LDA     TOS,S
        STA     (IFP),Y
        TXY
        JMP     NEXTOP
;*
;* STORE VALUE TO ABSOLUTE ADDRESS
;*
SAB     +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        PLA
        SEP     #$20            ; 8 BIT A/M
        !AS
        STA     (TMP)
        REP     #$20            ; 16 BIT A/M
        !AL
        JMP     NEXTOP
SAW     +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        PLA
        STA     (TMP)
        JMP     NEXTOP
;*
;* STORE VALUE TO ABSOLUTE ADDRESS WITHOUT POPPING STACK
;*
DAB     +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     TOS,S
        STA     (TMP)
        REP     #$20            ; 16 BIT A/M
        !AL
        JMP     NEXTOP
DAW     +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
        LDA     TOS,S
        STA     (TMP)
        JMP     NEXTOP
;*
;* COMPARES
;*
ISEQ    PLA
        CMP     TOS,S
        BNE     ISFLS
ISTRU   LDA     #$FFFF
        STA     TOS,S
        JMP     NEXTOP
;
ISNE    PLA
        CMP     TOS,S
        BNE     ISTRU
ISFLS   LDA     #$0000
        STA     TOS,S
        JMP     NEXTOP
;
ISGE    PLA
        CMP     TOS,S
        BVS     +
        BMI     ISTRU
        BEQ     ISTRU
        BPL     ISFLS
+       BMI     ISFLS
        BEQ     ISFLS
        BPL     ISTRU
;
ISGT    PLA
        CMP     TOS,S
        BVS     +
        BMI     ISTRU
        BPL     ISFLS
+       BMI     ISFLS
        BPL     ISTRU
;
ISLE    PLA
        CMP     TOS,S
        BVS     +
        BPL     ISTRU
        BMI     ISFLS
+       BPL     ISFLS
        BMI     ISTRU
;
ISLT    PLA
        CMP     TOS,S
        BVS     +
        BMI     ISFLS
        BEQ     ISFLS
        BPL     ISTRU
+       BMI     ISTRU
        BEQ     ISTRU
        BPL     ISFLS
;*
;* BRANCHES
;*
BRTRU   PLA
        BNE     BRNCH
NOBRNCH +INC_IP
        +INC_IP
        JMP     NEXTOP
BRFLS   PLA
        BNE     NOBRNCH
BRNCH   LDA     IP
        +INC_IP
        CLC
        ADC     (IP),Y
        STA     IP
        DEY
        JMP     NEXTOP
BREQ    PLA
        CMP     TOS,S
        BEQ     BRNCH
        BNE     NOBRNCH
BRNE    PLA
        CMP     TOS,S
        BNE     BRNCH
        BEQ     NOBRNCH
BRGT    PLA
        CMP     TOS,S
        BVS     +
        BMI     BRNCH
        BPL     NOBRNCH
+       BMI     NOBRNCH
        BPL     BRNCH
BRLT    PLA
        CMP     TOS,S
        BVS     +
        BMI     NOBRNCH
        BEQ     NOBRNCH
        BPL     BRNCH
+       BMI     BRNCH
        BEQ     BRNCH
        BPL     NOBRNCH
IBRNCH  PLA
        CLC
        ADC     IP
        STA     IP
        JMP     NEXTOP
;*
;* CALL INTO ABSOLUTE ADDRESS (NATIVE CODE)
;*
CALL    +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
EMUSTK  TYA                     ; FLATTEN IP
        CLC
        ADC     IP
        STA     IP
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        !AS
        TSC                     ; MOVE HW EVAL STACK TO ZP EVAL STACK
        EOR     #$FF
        SEC
        ADC     HWSP            ; STACK DEPTH = (HWSP - SP)/2
        LSR
!IF     DEBUG {
        PHA
        CLC
        ADC     #$80+'0'
        STA     $7D0+31
        PLA
}
        EOR     #$FF
        SEC
        ADC     ESP             ; ESP - STACK DEPTH
        TAY
        TAX
        BRA     +
-       PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        INX
+       CPX     ESP
        BNE     -
!IF     DEBUG {
        TXA
        TSX
        CPX     HWSP
        BEQ     +
        LDX     #$80+'C'
        STX     $7D0+30
-       LDX    $C000
        BPL     -
        LDX     $C010
+       TAX
}
        LDA     IPH
        PHA
        LDA     IPL
        PHA
        PHX                     ; SAVE BASELINE ESP
        TYX
        LDA     PSR
        PHA
        PLP
        JSR     JMPTMP
        PHP
        PLA
        STA     PSR
        SEI
        PLY                     ; MOVE RETURN VALUES TO HW EVAL STACK
        STY     ESP             ; RESTORE BASELINE ESP
        PLA
        STA     IPL
        PLA
        STA     IPH
        STX     TMPL
!IF     DEBUG {
        TXA
        EOR     #$FF
        SEC
        ADC     ESP
        CLC
        ADC     #$80+'0'
        STA     $7D0+32
}
        TSX                     ; RESTORE BASELINE HWSP
        STX     HWSP
        TYX
        BRA     +
-       DEX
        LDA     ESTKH,X
        PHA
        LDA     ESTKL,X
        PHA
+       CPX     TMPL
        BNE     -
        CLC                     ; SWITCH BACK TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        !AL
        LDX     #>OPTBL         ; MAKE SURE WE'RE INDEXING THE RIGHT TABLE
!IF DEBUG {
        LDY     LCRWEN+LCBNK2
        LDY     LCRWEN+LCBNK2
        STX     DBG_OP+2
        LDX     #>DBGTBL
}
        STX     OPPAGE
        LDY     #$00
        JMP     NEXTOP
;
CALLX   +INC_IP
        LDA     (IP),Y
        +INC_IP
        STA     TMP
EMUSTKX TYA                     ; FLATTEN IP
        CLC
        ADC     IP
        STA     IP
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        !AS
        TSC                     ; MOVE HW EVAL STACK TO ZP EVAL STACK
        EOR     #$FF
        SEC
        ADC     HWSP            ; STACK DEPTH = (HWSP - SP)/2
        LSR
!IF     DEBUG {
        PHA
        CLC
        ADC     #$80+'0'
        STA     $7D0+31
        PLA
}
        EOR     #$FF
        SEC
        ADC     ESP             ; ESP - STACK DEPTH
        TAY
        TAX
        BRA     +
-       PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        INX
+       CPX     ESP
        BNE     -
!IF     DEBUG {
        TXA
        TSX
        CPX     HWSP
        BEQ     +
        LDX     #$80+'X'
        STX     $7D0+30
-       LDX     $C000
        BPL     -
        LDX     $C010
+       TAX
}
        LDA     IPH
        PHA
        LDA     IPL
        PHA
        PHX                     ; SAVE BASELINE ESP
        TYX
        STX     ALTRDOFF
        LDA     PSR
        PHA
        PLP
        JSR     JMPTMP
        PHP
        PLA
        STA     PSR
        SEI
        STX     ALTRDON
        PLY                     ; MOVE RETURN VALUES TO HW EVAL STACK
        STY     ESP             ; RESTORE BASELINE ESP
        PLA
        STA     IPL
        PLA
        STA     IPH
        STX     TMPL
!IF     DEBUG {
        TXA
        EOR     #$FF
        SEC
        ADC     ESP
        CLC
        ADC     #$80+'0'
        STA     $7D0+32
}
        TSX                     ; RESTORE BASELINE HWSP
        STX     HWSP
        TYX
        BRA     +
-       DEX
        LDA     ESTKH,X
        PHA
        LDA     ESTKL,X
        PHA
+       CPX     TMPL
        BNE     -
        CLC                     ; SWITCH BACK TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        !AL
        LDX     #>OPXTBL         ; MAKE SURE WE'RE INDEXING THE RIGHT TABLE
!IF DEBUG {
        LDY     LCRWEN+LCBNK2
        LDY     LCRWEN+LCBNK2
        STX     DBG_OP+2
        LDX     #>DBGTBL
}
        STX     OPPAGE
        LDY     #$00
        JMP     NEXTOP
;*
;* INDIRECT CALL TO ADDRESS (NATIVE CODE)
;*
ICAL    PLA
        STA     TMP
        JMP     EMUSTK
;
ICALX   PLA
        STA     TMP
        JMP     EMUSTKX
;*
;* JUMP INDIRECT THROUGH TMP
;*
JMPTMP  JMP     (TMP)
;*
;* ENTER FUNCTION WITH FRAME SIZE AND PARAM COUNT
;*
ENTER   INY
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     (IP),Y
!IF     DEBUG {
        PHA
        CLC
        ADC     #$80+'0'
        STA     $7D0+31
        PLA
}
        PHA                     ; SAVE ON STACK FOR LEAVE
        DEC     HWSP            ; UPDATE HWSP TO SKIP FRAME SIZE
        REP     #$20            ; 16 BIT A/M
        !AL
        AND     #$00FF
        EOR     #$FFFF          ; ALLOCATE FRAME
        SEC
        ADC     PP
        STA     PP
        STA     IFP
        SEP     #$20            ; 8 BIT A/M
        !AS
        INY
        LDA     (IP),Y
        BEQ     +
        ASL
        TAY
        LDX     ESP             ; MOVE PARAMETERS TO CALL FRAME
-       LDA     ESTKH,X
        DEY
        STA     (IFP),Y
        LDA     ESTKL,X
        INX
        DEY
        STA     (IFP),Y
        BNE -
        STX     ESP
+       REP     #$20            ; 16 BIT A/M
        !AL
        LDY     #$02
        JMP     NEXTOP
;*
;* LEAVE FUNCTION
;*
LEAVEX  STX     ALTRDOFF
LEAVE   SEP     #$20            ; 8 BIT A/M
        !AS
        TSC                     ; MOVE HW EVAL STACK TO ZP EVAL STACK
        EOR     #$FF
        SEC
        ADC     HWSP            ; STACK DEPTH = (HWSP - SP)/2
        LSR
!IF     DEBUG {
        PHA
        CLC
        ADC     #$80+'0'
        STA     $7D0+31
        PLA
}
        EOR     #$FF
        SEC
        ADC     ESP             ; ESP - STACK DEPTH
        TAY
        TAX
        BRA     +
-       PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        INX
+       CPX     ESP
        BNE     -
 !IF     DEBUG {
        STX     TMPL
        TSX
        CPX     HWSP
        BEQ     +
        LDX     #$80+'L'
        STX     $7D0+30
-       LDX    $C000
        BPL     -
        LDX     $C010
+       LDX     TMPL
}
        TYX                     ; RESTORE NEW ESP
        PLA                     ; DEALLOCATE POOL + FRAME
        REP     #$20            ; 16 BIT A/M
        !AL
        AND     #$00FF
        CLC
        ADC     IFP
        STA     PP
        PLA                     ; RESTORE PREVIOUS FRAME
        STA     IFP
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        LDA     PSR
        PHA
        PLP
        RTS
;
RETX    STX     ALTRDOFF
RET     SEP     #$20            ; 8 BIT A/M
        !AS
        TSC                     ; MOVE HW EVAL STACK TO ZP EVAL STACK
        EOR     #$FF
        SEC
        ADC     HWSP            ; STACK DEPTH = (HWSP - SP)/2
        LSR
!IF     DEBUG {
        PHA
        CLC
        ADC     #$80+'0'
        STA     $7D0+31
        PLA
}
        EOR     #$FF
        SEC
        ADC     ESP             ; ESP - STACK DEPTH
        TAY
        TAX
        BRA     +
-       PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        INX
+       CPX     ESP
        BNE     -
!IF     DEBUG {
        STX     TMPL
        TSX
        CPX     HWSP
        BEQ     +
        LDX     #$80+'R'
        STX     $7D0+30
-       LDX    $C000
        BPL     -
        LDX     $C010
+       LDX     TMPL
}
        TYX
        REP     #$20            ; 16 BIT A/M
        !AL
        LDA     IFP             ; DEALLOCATE POOL
        STA     PP
        PLA                     ; RESTORE PREVIOUS FRAME
        STA     IFP
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        !AS
        LDA     PSR
        PHA
        PLP
        RTS

VMEND   =       *
}
