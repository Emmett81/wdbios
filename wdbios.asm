; Super-BIOS for WD1002A-WX1
; Disassembly and commenting by Sergio Aguayo
; Original code copyright (C) Western Digital Inc.
;
	CPU	8086
	ORG	0

	%include "inc/RomVars.inc"
	%include "inc/equs.inc"
	%include "inc/biosseg.inc"

	SECTION	.text
istruc ROMVARS
	AT	ROMVARS.wBiosSignature,		dw	0AA55h
	AT	ROMVARS.bBiosLength,		db	16
	AT	ROMVARS.rgbBiosEntry,		jmp	short ROMVARS.rgbBiosEntryJump
	AT	ROMVARS.rgbFormatEntry,		jmp	LAB_c800_0b50
	AT	ROMVARS.szCopyright,		db	'07/15/86(C) Copyright 1986 Western Digital Corp.'
	AT	ROMVARS.rgbUnknown,		db	0CFh, 02h, 25h, 02h, 08h, 2Ah, 0FFh, 50h, 0F6h, 19h, 04h

	%include "inc/drvpar1.inc"
	AT	ROMVARS.rgbBiosEntryJump,	jmp	short ENTRYPOINT
	%include "inc/drvpar2.inc"
iend

ENTRYPOINT:
	XOR	AX,AX
	MOV	DS,AX				; DS = 0000h
	CLI					; Interrupts disabled
	MOV	AX,CS
	MOV	AL,0				; First controller I/O offset
	CMP	AH,0C8h				; Check for CS=C800h
	JZ	INSTALL_BIOS			; Yes, setup as first controller

;--------------------------------------------------------------------------
; At this point we know that we're not running in C800h.
; This means that we may have another hard disk controller
; in the system. Thus, we need to check how many working 
; drives we really have before proceeding. We will update
; the drive count accordingly.
;--------------------------------------------------------------------------
	PUSH	AX				; Save our code segment for later
	MOV	AL,[TOTAL_FIXED_DISKS]		; Get number of fixed disks from BIOS
	CMP	AL,2				; Less than 2 drives present?
	JL	LAB_c800_00fd			; Assume working drives and configure
						; us as second controller

	XOR	AX,AX				; Counter for number of HDDs
	MOV	DX,80h				; Work with first HDDD

CHECK_DRIVE:
	PUSH	AX
	MOV	CX,1				; ???
	MOV	AL,CL				; AL=1 (???)
	MOV	AH,10h				; HDD - Check if drive ready
	INT	13H
	POP	AX				; Discard status in AH
	JC	NEXT_DRIVE			; Jump on error
	INC	AL				; We have a working HDD

NEXT_DRIVE:
	INC	DL				; Next drive
	TEST	DL,1				; Finished with second drive?
	JNZ	CHECK_DRIVE			; No, test second drive
	CMP	AL,2				; Do we have 2 working drives?
	JZ	LAB_c800_00fd			; Yes, skip BIOS parameter update
	MOV	[TOTAL_FIXED_DISKS],AL		; Update BIOS HDD count

LAB_c800_00fd:
	POP	AX				; Restore our code segment
	MOV	AL,4				; Set as second controller

;--------------------------------------------------------------------------
; This card has 4 bytes of I/O starting at 320h or 324h.
; These I/O values come with a BIOS address of C800h:0000h
; or CA00h(?).
; Based on our CS, we have determined which offset from
; 320h to use: either 00h or 04h. This is contained in AL.
;--------------------------------------------------------------------------
INSTALL_BIOS:
	XCHG	AH,AL				; Now AH=IO offset, AL=high CS
	PUSH	AX				; Save for later, will destroy AL
	MOV	DX,322H				; I/O: Read drive configuration info
	ADD	DL,AH				; Add offset to base I/O address
	IN	AL,DX				; Read from card
	AND	AL,S17				; Check S1-7 (IRQ)
	POP	AX				; AH=I/O offset, AH=high CS
	JZ	SET_IRQ2_HANDLER		; If S1-7 is 0 (closed), use IRQ 2
	MOV	WORD [INT_0DH_IRQ5_OFFSET],IRQ_HANDLER
	MOV	[INT_0DH_IRQ5_SEGMENT],CS
	JMP	SHORT LAB_c800_0124

SET_IRQ2_HANDLER:
	MOV	WORD [INT_0AH_IRQ2_OFFSET],IRQ_HANDLER
	MOV	[INT_0AH_IRQ2_SEGMENT],CS

LAB_c800_0124:
	LES	BX,[INT_13H_VECTOR]		; BX=INT 13h offset, ES=INT 13h segment
	MOV	CX,[INT_40H_OFFSET]
	OR	CX,[INT_40H_SEGMENT]		; Check if INT 40h is all zeroes
	JNZ	SECOND_CONTROLLER_INIT		; Non-zero -- Don't relocate

FIRST_CONTROLLER_INIT:
	MOV	[INT_40H_OFFSET],BX		; Set INT 40h to old INT 13h vector
	MOV	[INT_40H_SEGMENT],ES

	MOV	WORD [INT_19H_OFFSET],BOOTSTRAP_HANDLER
	MOV	[INT_19H_SEGMENT],CS

	MOV	WORD [INT_13H_OFFSET],DISK_HANDLER
	MOV	[INT_13H_SEGMENT],CS

	MOV	WORD [INT_41H_OFFSET],ROMVARS.driveType0Params
	CALL	FUN_c800_0971
	JZ	LAB_c800_015f
	MOV	WORD [INT_41H_OFFSET],ROMVARS.driveType4Params
	
LAB_c800_015f:
	MOV	[INT_41H_SEGMENT],CS		; Finish setting up INT 41h
	MOV	BX,FIRST_DISK_AREA	; Fixed disk data - first controller
	JMP	SHORT LAB_c800_019c
	NOP

SECOND_CONTROLLER_INIT:
	CMP	AL,0C8H				; Just in case, check if we're the
						; first controller
	JZ	FIRST_CONTROLLER_INIT		; We are -- go to proper init
	MOV	[INT_47H_OFFSET],BX		; Save old INT 13h vector to 2nd controller's chain
	MOV	[INT_47H_SEGMENT],ES
	MOV	WORD [INT_13H_OFFSET],SECOND_DISK_HANDLER
	MOV	[INT_13H_SEGMENT],CS
	MOV	BX,SECOND_DISK_AREA	; Fixed disk area - second controller
	IN	AL,DX				; Read hardware configuration register
	AND	AL,S18				; Check for S1-8 (XT/AT mode)
	JNZ	LAB_c800_019c			; Jump if S1-8 is open (XT mode)
	MOV	WORD [INT_46H_OFFSET],ROMVARS.driveType0Params
	MOV	[INT_46H_SEGMENT],CS
	CALL	FUN_c800_0971
	JZ	LAB_c800_019c			; Jump if S1-5 and S1-6 are open
	MOV	WORD [INT_46H_OFFSET],ROMVARS.driveType4Params
	
LAB_c800_019c:
	STI					; Enable interrupts
	MOV	AL,[TOTAL_FIXED_DISKS]		; Read BIOS num HDDs flags
	MOV	[BX+1],AL			; Update controller drive count
	MOV	CL,4
	SHL	AL,CL				; Move count to upper nibble
	OR	AL,AH				; I/O offset in lower nibble of AL
	MOV	[BX],AL				; Total drives - this controller only

	MOV	AX,00B2H
	CMP	WORD [POST_RESET_FLAG],1234H		; Warm boot?
	JZ	LAB_c800_01b8			; Yes, don't wait that much to settle
	XOR	AX,AX

LAB_c800_01b8:
	MOV	[TIMER_TICKS],AX		; Reset timer tick count
	CLI					; Disable interrupts
	IN	AL,21H				; Read PIC OCW1
	AND	AL,0FEH				; Enable timer interrupt (IRQ 0)
	OUT	21H,AL				; Set PIC OCW1
	STI					; Enable interrupts so timer starts counting
	MOV	SI,BX
	CALL	GET_STATUS_ADDRESS		; Get I/O address in DX
	OUT	DX,AL				; Reset controller (write to 0321h)
	MOV	CX,0584H

D1:
	LOOP	D1				; Delay loop
	MOV	AH,10				; Number of retries for init

WAIT_FOR_READY:
	INC	DX				; Point to 322h
	OUT	DX,AL				; Select controller
	DEC	DX				; Point to 321h
	IN	AL,DX				; Read status
	TEST	AL,30H				; Check IRQ and DRQ flags
	JNZ	CONTROLLER_FAILURE		; Fail if they're set
	AND	AL,0DH				; Preserve BUSY, IO, and REQ flags
	XOR	AL,0DH				; Check that all of those flags are set
	JZ	LAB_c800_01e4			; They are - Ready to start diagnostic
	LOOP	WAIT_FOR_READY			; Try again (0FFFFH times)
	DEC	AH				; Decrement retry counter
	JNZ	WAIT_FOR_READY

LAB_c800_01e4:
	MOV	DL,80H				; Start as first drive
	ADD	DL,[BX+1]			; DL contains number of disks in this controller
	MOV	CX,1
	MOV	DH,CH				; DH = 0
	MOV	AL,CL				; AH = 1
	MOV	AH,14H				; Controller internal diagnostic
	INT	13H				; Call it
	JC	CONTROLLER_FAILURE		; Fail if diagnostic returns error

LAB_c800_01f6:
	MOV	AH,10H				; Check if drive ready
	INT	13H
	JNC	LAB_c800_0206			; Jump if drive ready
	CMP	WORD [TIMER_TICKS],01BEH		; Enough time elapsed?
	JC	LAB_c800_01f6			; No, try again
	JMP	SHORT LAB_c800_0227

LAB_c800_0206:
	MOV	AH,0				; Reset disk system
	INT	13H
	JC	CONTROLLER_FAILURE		; Fail if reset returns error

	MOV	AH,11H				; Recalibrate drive
	INT	13H
	JC	LAB_c800_0227			; Jump if failed

;----- At this point, the current drive seems to work fine. Update counts and other flags -----

	INC	BYTE [BX+1]			; Increment drive count
	TEST	BYTE [BX+2],8
	JNZ	LAB_c800_0227
	INC	BYTE [BX+1]
	JMP	SHORT LAB_c800_0265		; Finish
	NOP

ERROR_STRING:
	DB	'1701',10,13
ERROR_STRING_LENGTH	EQU $ - ERROR_STRING

LAB_c800_0227:
	CMP	DL,80H				; Check for first drive
	JNZ	LAB_c800_023a
	CMP	WORD [POST_RESET_FLAG],1234H		; Is it warm boot?
	JZ	LAB_c800_023a			; Yes - Shorter delays
	MOV	WORD [TIMER_TICKS],0165H

LAB_c800_023a:
	INC	DL				; Next drive
	MOV	AH,DL
	CMP	BX,FIRST_DISK_AREA	; Check if first controller
	JZ	LAB_c800_0248			; Yes, skip update
	SUB	AH,[TOTAL_FIXED_DISKS]		; Decrement drive count

LAB_c800_0248:
	TEST	AH,1				; Is it already second drive?
	JNZ	LAB_c800_01f6			; No, go test again

CONTROLLER_FAILURE:
	CMP	BYTE [BX+1],0			; Check for no Total disks - this controller
	JNZ	LAB_c800_0265			; There is some disks - don't show error

	MOV	SI,ERROR_STRING
	MOV	CX,ERROR_STRING_LENGTH
	CLD

LAB_c800_025a:
	CS LODSB
	MOV	AH,0EH				; Teletype output
	INT	10H				; Output character
	LOOP	LAB_c800_025a			; Until no more characters left
	MOV	BP,0FH

LAB_c800_0265:
	MOV	CL,[BX+1]
	MOV	[TOTAL_FIXED_DISKS],CL
	RETF

BOOTSTRAP_HANDLER:
	XOR	AX,AX
	MOV	DS,AX				; DS=0000H
	MOV	ES,AX				; ES=0000H
	MOV	CX,3				; Retry counter
	XOR	DX,DX				; Head 0, first floppy

TRY_BOOT_FLOPPY:
	MOV	AX,0				; Reset disk system (for floppy)
	INT	40H
	JC	FLOPPY_FAILURE			; Error - possibly retry

	MOV	BX,BOOT_SECTOR_OFFSET	; Offset to load boot sector into
	MOV	AX,0201H			; Read 1 sector into memory
	PUSH	CX
	MOV	CX,1				; Cylinder 0, sector 1
	INT	40H				; Load it
	POP	CX
	JNC	JUMP_BOOT_SECTOR		; Jump to it on success

FLOPPY_FAILURE:
	CMP	AH,80H				; Check if error is timeout (not ready)
	JZ	SETUP_BOOT_HARD_DRIVE		; If so, proceed with another device
	LOOP	TRY_BOOT_FLOPPY			; Otherwise try again

SETUP_BOOT_HARD_DRIVE:
	MOV	AX,0				; Reset disk system (again)
	INT	40H
	MOV	DL,80H				; First hard drive
	MOV	CL,[TOTAL_FIXED_DISKS]		; Numer of hard disks available
	AND	CL,CL				; Check if none
	JZ	BOOT_BASIC			; If so, skip trying them

TRY_BOOT_HARD_DRIVE:
	MOV	AH,0				; Reset disk system (everything)
	INT	13H
	JC	HARD_DRIVE_FAILURE		; Jump on error
	MOV	BX,BOOT_SECTOR_OFFSET	; Offset to load boot sector
	MOV	AX,0201H			; Read 1 sector into memory
	PUSH	CX
	MOV	CX,1				; Cylinder 0, sector 1
	INT	13H				; Load it
	POP	CX
	JNC	CHECK_BOOT_MAGIC		; Jump if successful

HARD_DRIVE_FAILURE:
	INC	DL				; Try next drive
	LOOP	TRY_BOOT_HARD_DRIVE		; Try again, if able

BOOT_BASIC:
	INT	18H				; Call ROM BASIC
	JMP	SHORT BOOTSTRAP_HANDLER		; Shouldn't reach here

CHECK_BOOT_MAGIC:
	CMP	WORD [BOOT_SECTOR_MAGIC_OFF],0AA55H	; Check if magic value is there
	JNZ	HARD_DRIVE_FAILURE		; Fail if not

JUMP_BOOT_SECTOR:
	JMP	0:7C00h


IRQ_HANDLER:
	PUSH	AX
	PUSH	DX
	MOV	AL,20H				; OCW2, non-specific EOI
	OUT	20H,AL				; PIC
	MOV	AL,7				; DMA channel 3 masked
	OUT	0AH,AL				; 8237
	CALL	READ_HARDWARE_CONFIG
	AND	AL,40H				; Check if set for IRQ 2 or 5
	IN	AL,21H				; Get OCW1 from PIC
	JNZ	IRQ2_MASK			; Go mask IRQ 2
	OR	AL,4				; Mask IRQ 5
	JMP	SHORT LAB_c800_02e7

IRQ2_MASK:
	OR	AL,20h				; IRQ 2 masked

LAB_c800_02e7:
	OUT	21H,AL				; Write PIC OCW1
	POP	DX
	POP	AX
	IRET


SECOND_DISK_HANDLER:
	STI					; Interrupts enabled
	CMP	DL,80H				; Is the call for fixed disks?
	JNC	LAB_c800_02f7			; Yes, deal with hard drives

CALL_FLOPPY_HANDLER:
	INT	40H				; Call old INT 13H handler
	RETF	2				; Discard saved flags on return

LAB_c800_02f7:
	PUSH	BX				; Save registers
	PUSH	DS				; Save DS while we work on data
	PUSH	AX				; Save AX
	MOV	AX,0
	MOV	DS,AX				; DS=0000h
	MOV	BX,SECOND_DISK_AREA	; Second controller data area
	MOV	AL,[BX]				; Get our drive count
	SHR	AL,1				; Discard I/O offset in low nibble
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	ADD	AL,80H				; Set high nibble
	CMP	DL,AL				; Matches?
	POP	AX
	JNC	LAB_c800_032a			; Yes, handle it
	POP	DS				; Restore registers we didn't use
	POP	BX
	INT	47H				; Doesn't match - send it to first controller
	RETF	2				; Discard saved flags on return


DISK_HANDLER:
	STI					; Interrupts enabled
	CMP	DL,80H				; If this for hard drives?
	JC	CALL_FLOPPY_HANDLER		; No, call regular floppy handler
	PUSH	BX
	PUSH	DS				; Save DS while we work with data
	MOV	BX,0
	MOV	DS,BX
	MOV	BX,FIRST_DISK_AREA	; First controller data area

LAB_c800_032a:
	MOV	[DISK_AREA_PTR],BX		; Save disk area pointer
	POP	DS				; Restore DS
	PUSH	CX				; Save registers for return
	PUSH	DX
	PUSH	BP
	PUSH	DI
	PUSH	SI
	PUSH	DS
	PUSH	ES
	MOV	BP,SP				; Used to access saved registers later
	
	; Addresses for saved registers relative to BP:
	; BP+0		ES
	; BP+2		DS
	; BP+4		SI
	; BP+6		DI
	; BP+8		BP
	; BP+10 (0A)	DX
	; BP+12 (0C)	CX
	; BP+14 (0E)	BX
	
	PUSH	AX
	MOV	AX,0
	MOV	DS,AX				; DS=0000h
	MOV	SI,[DISK_AREA_PTR]		; Obtain disk area pointer
	MOV	AL,80H				; Start building hard disk device number
	ADD	AL,[BX+1]			; Last hard drive of this controller
	CMP	DL,AL				; Check if the drive is for us
	POP	AX
	JA	CALL_ROM_DISK_BIOS		; No, jump to saved vector
	CMP	AH,16H				; Calling greater than AH=16H?
	JA	LAB_c800_039a			; Yes, unsupported.
	CMP	AH,0				; Calling reset disk system?
	JNZ	DO_DISK_BIOS			; No, proceed only with hard drives
	INT	40H				; Call floppy disk reset
	MOV	AH,0				; Restore value of AH

DO_DISK_BIOS:
	CALL	FUN_c800_039e			; Do actual work

LAB_c800_035d:
	PUSH	AX				; Save AX during IRQ and DMA disable
	CALL	GET_MASK_REGISTER_ADDR		; Obtain mask register address in DX
	MOV	AL,0FCH				; Mask IRQ and DMA in controller
	OUT	DX,AL				; Write IRQ and DMA mask register
	MOV	AL,7				; DMA channel 3, masked
	OUT	0AH,AL				; Update 8237 DMA mask register
	CLI					; Disable interrupts
	CALL	READ_HARDWARE_CONFIG
	AND	AL,40H				; Check for IRQ bit
	IN	AL,21H				; Read OCW1 from PIC
	JNZ	MASK_IRQ5			; If set to IRQ 5, go for it
	OR	AL,4				; Mask IRQ 2
	JMP	SHORT DO_MASK_IRQ

MASK_IRQ5:
	OR	AL,20H				; Mask IRQ 5

DO_MASK_IRQ:
	OUT	21H,AL				; Update PIC OCW1
	STI					; Interrupts enabled
	CMP	AH,0F3H				; Check for non-error return
	JZ	LAB_c800_0383			; Yes, jump over
	ADD	AH,0FFH				; Force set carry to indicate error

LAB_c800_0383:
	POP	AX				; Restore AX

LAB_c800_0384:
	POP	ES
	POP	DS
	POP	SI
	POP	DI
	POP	BP
	POP	DX
	POP	CX
	POP	BX
	RETF	2				; Discard saved flags on return

CALL_ROM_DISK_BIOS:
	CMP	AH,0
	JNZ	LAB_c800_039a
	INT	40H
	MOV	AH,0
	JMP	SHORT LAB_c800_0384

LAB_c800_039a:
	MOV	AH,1
	JMP	SHORT LAB_c800_035d


FUN_c800_039e:
	MOV	[SAVED_INT13H_AL],AL		; Save AL input value
	DEC	CL
	MOV	[SAVED_INT13H_CX],CX
	PUSH	CS
	POP	CX
	CMP	CH,0C8H				; Check for C8xx
	MOV	CH,0
	JZ	LAB_c800_03b8			; First controller - go jump

	MOV	CH,[SI]				; Get drive from data area
	MOV	CL,4
	SHR	CH,CL				; Drive number in low nibble
	NEG	CH

LAB_c800_03b8:
	ADD	CH,DL
	AND	CH,1
	MOV	CL,5
	SHL	CH,CL
	MOV	BX,[SI+2]
	XCHG	BH,BL
	OR	CH,CH
	JZ	LAB_c800_0417
	TEST	BH,8
	XCHG	BH,BL
	JNZ	LAB_c800_0417
	XCHG	BH,BL
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	AND	BX,03FFH
	CALL	READ_HARDWARE_CONFIG
	NOT	AL
	AND	AL,30H
	XOR	AL,30H
	JNZ	LAB_c800_03f2
	MOV	AX,1529
	MUL	BX
	MOV	BX,1000
	DIV	BX
	MOV	BX,AX

LAB_c800_03f2:
	POP	DX
	POP	CX
	XOR	CH,CH
	MOV	AX,[SAVED_INT13H_CX]
	MOV	CL,6
	SHR	AL,CL
	XCHG	AH,AL
	ADD	AX,BX
	MOV	CL,6
	SHL	AH,CL
	XCHG	AH,AL
	XCHG	[SAVED_INT13H_CX],AX
	AND	AX,01FH
	OR	AX,[SAVED_INT13H_CX]
	MOV	[SAVED_INT13H_CX],AX
	POP	BX
	POP	AX

LAB_c800_0417:
	MOV	CL,4
	SHR	BH,CL
	AND	BH,7
	MOV	[LAB_0000_0447],BH
	AND	DH,0FH
	OR	CH,DH
	MOV	[LAB_0000_0443],CH
	CALL	FUN_c800_0a0f
	JNZ	LAB_c800_0433
	CALL	FUN_c800_0a48

LAB_c800_0433:
	MOV	AL,AH				; Function code in AL
	MOV	BX,COMMAND_TABLE
	CS XLATB				; Obtain command byte
	MOV	[LAB_0000_0442],AL		; Save it
	MOV	BL,AH				; Function code in BL
	XOR	BH,BH				; Clear BH
	SHL	BL,1				; Multiply by 2
	CS JMP	WORD [BX+FUNCTION_POINTERS]	; Call function

FUNCTION_POINTERS:
	DW	RESET_DISK_SYSTEM	; (AH=0) Reset disk system
	DW	FUN_c800_07d2		; (AH=1) Get status of last operation
	DW	FUN_c800_0696		; (AH=2) Read sector(s) into memory
	DW	FUN_c800_066a		; (AH=3) Write disk sector(s)
	DW	FUN_c800_0709		; (AH=4) Verify disk sector(s)
	DW	FUN_c800_0709		; (AH=5) Format track
	DW	FUN_c800_0709		; (AH=6) Format track and set bad sector flags
	DW	FUN_c800_0709		; (AH=7) Format drive starting at given track
	DW	FUN_c800_05ef		; (AH=8) Get drive parameters
	DW	LAB_c800_04c6		; (AH=9) Initialize controller with drive parameters
	DW	FUN_c800_067d		; (AH=0A) Read long sector
	DW	FUN_c800_0688		; (AH=0B) Write long sector
	DW	FUN_c800_0709		; (AH=0C) Seek to cylinder
	DW	RESET_DISK_SYSTEM	; (AH=0D) Reset hard disks
	DW	FUN_c800_068c		; (AH=0E) Read sector buffer
	DW	FUN_c800_0692		; (AH=0F) Write sector buffer
	DW	FUN_c800_0709		; (AH=10) Check if drive ready
	DW	FUN_c800_0709		; (AH=11) Recalibrate drive
	DW	FUN_c800_0709		; (AH=12) Controller RAM diagnostic
	DW	FUN_c800_0709		; (AH=13) Drive diagnostic
	DW	FUN_c800_0709		; (AH=14) Controller internal diagnostic
	DW	FUN_c800_05ab		; (AH=15) Get disk type
	DW	FUN_c800_059f		; (AH=16) Detect disk change

COMMAND_TABLE:
	DB	0CH				; (AH=0) Initialize drive parameters
	DB	00H				; (AH=1) Test drive ready
	DB	08H				; (AH=2) Read sectors
	DB	0AH				; (AH=3) Write sectors
	DB	05H				; (AH=4) Verify sectors
	DB	06H				; (AH=5) Format track
	DB	07H				; (AH=6) Format bad track
	DB	04H				; (AH=7) Format drive
	DB	00H				; (AH=8) Test drive ready
	DB	0CH				; (AH=9) Initialize drive parameters
	DB	0E5H				; (AH=0A) Read Long
	DB	0E6H				; (AH=0B) Write Long
	DB	0BH				; (AH=0C) Seek
	DB	0CH				; (AH=0D) Initialize drive parameters
	DB	0EH				; (AH=0E) Read sector BFFR
	DB	0FH				; (AH=0F) Write sector BFFR
	DB	00H				; (AH=10) Test drive ready
	DB	01H				; (AH=11) Recalibrate
	DB	0E0H				; (AH=12) Execute sector buffer diagnostic
	DB	0E3H				; (AH=13) Execute drive diagnostic
	DB	0E4H				; (AH=14) Execute controller diagnostic
	DB	00H				; (AH=15) Test drive ready
	DB	0CH				; (AH=16) Initialize drive parameters

RESET_DISK_SYSTEM:
	CALL	GET_STATUS_ADDRESS
	OUT	DX,AL				; Reset disk controller
	MOV	CX,0584H			; Delay counter

D2:
	LOOP	D2				; Delay loop

	MOV	AH,0AH				; Retry counter
RESET_LOOP:
	INC	DX				; Point to configuration register (0322h)
	OUT	DX,AL				; Select disk controller
	DEC	DX				; Back to status register
	IN	AL,DX				; Get status register
	TEST	AL,30H				; Test for IRQ and DRQ flags
	JNZ	RESET_FAILED			; Fail if they are set
	AND	AL,0DH				; Preserve BSY, CD, and REQ flags
	XOR	AL,0DH				; Check for all of them present
	JZ	LAB_c800_04af			; Yes, continue
	LOOP	RESET_LOOP			; Try again
	DEC	AH				; One try less
	JNZ	RESET_LOOP			; Jump if still left

RESET_FAILED:
	MOV	AH,5				; Indicate error: Reset failed

RESET_RETURN:
	RET					; Return to caller

LAB_c800_04af:
	MOV	BYTE [LAB_0000_0442],1
	MOV	BYTE [LAB_0000_0443],0
	CALL	FUN_c800_0709
	JC	RESET_FAILED
	
	MOV	BYTE [LAB_0000_0443],20H
	CALL	FUN_c800_0709

LAB_c800_04c6:	
	MOV	BYTE [LAB_0000_0443],0
	CALL	LAB_c800_04d5
	JC	RESET_RETURN

	MOV	BYTE [LAB_0000_0443],20H
LAB_c800_04d5:
	CALL	FUN_c800_097d

	MOV	BYTE [LAB_0000_0442],0CH
	MOV	AL,0FCH
	CALL	FUN_c800_07df
	JNC	LAB_c800_04e7
	JMP	LAB_c800_0595

LAB_c800_04e7:
	MOV	CX,ES:[BX+0AH]
	MOV	AX,[SI+2]
	TEST	BYTE [LAB_0000_0443],20H
	JZ	LAB_c800_04fb
	TEST	AL,8
	JZ	LAB_c800_04fb
	XCHG	AH,AL

LAB_c800_04fb:
	TEST	AL,80H
	JNZ	LAB_c800_0508
	CMP	WORD ES:[BX], BYTE 0
	JZ	LAB_c800_0508
	MOV	CX,ES:[BX]

LAB_c800_0508:
	CALL	READ_HARDWARE_CONFIG
	NOT	AL
	AND	AL,30H
	XOR	AL,30H
	JNZ	LAB_c800_0527
	MOV	AX,1529
	MUL	CX
	MOV	CX,1000
	DIV	CX
	CMP	AX,0400H
	JLE	LAB_c800_0525
	MOV	AX,0400H

LAB_c800_0525:
	MOV	CX,AX

LAB_c800_0527:
	MOV	AL,CH
	CALL	FUN_c800_05da
	MOV	AL,CL
	CALL	FUN_c800_05da
	MOV	DI,8
	CALL	FUN_c800_05d7
	MOV	DI,7
	CALL	FUN_c800_05d7
	MOV	DI,6
	CALL	FUN_c800_05d7
	MOV	DI,5
	CALL	FUN_c800_05d7
	MOV	DI,4
	CALL	FUN_c800_05d7
	MOV	DI,2
	CALL	FUN_c800_05d7
	CALL	FUN_c800_0812
	JC	LAB_c800_0599
	JNZ	LAB_c800_0599
	MOV	CH,ES:[BX+3]
	MOV	CL,4
	SHL	CH,CL
	TEST	BYTE [LAB_0000_0443],20H
	JZ	LAB_c800_0578
	TEST	BYTE [SI+2],8
	JZ	LAB_c800_0595
	MOV	AX,[SI+2]
	MOV	AH,CH
	JMP	SHORT LAB_c800_0590

LAB_c800_0578:
	TEST	BYTE [SI+2],80H
	JNZ	LAB_c800_0587
	MOV	AX,ES:[BX+0AH]
	CMP	AX,ES:[BX]
	JNZ	LAB_c800_058c

LAB_c800_0587:
	XOR	AL,AL
	OR	CH,8

LAB_c800_058c:
	OR	AH,CH
	XCHG	AH,AL

LAB_c800_0590:
	OR	[SI+2],AX
	XOR	AX,AX

LAB_c800_0595:
	CALL	FUN_c800_05e6
	RET

LAB_c800_0599:
	MOV	AH,7
	CALL	FUN_c800_05e6
	RET


FUN_c800_059f:
	MOV	ES,[BP+0]
	MOV	BX,[BP+14]
	MOV	CX,04DDH
	JMP	LAB_c800_09f0

FUN_c800_05ab:
	CALL	FUN_c800_097d
	CALL	READ_HARDWARE_CONFIG
	MOV	CL,11H
	NOT	AL
	AND	AL,30H
	XOR	AL,20H
	JNZ	LAB_c800_05bd
	MOV	CL,1AH
LAB_c800_05bd:
	MOV	AL,ES:[BX+8]
	MUL	CL
	CALL	FUN_c800_062c
	DEC	CX
	MUL	CX
	MOV	[BP+10],AX			; Update saved DX
	MOV	[BP+12],DX			; Update saved CX
	MOV	AH,0F3H
	XOR	AL,AL
	CALL	FUN_c800_05e6
	RET

FUN_c800_05d7:
	MOV	AL,ES:[BX+DI]
FUN_c800_05da:
	PUSH	AX
	CALL	WAIT_FOR_REQ_SET
	POP	AX
	JC	LAB_c800_05e3
	OUT	DX,AL
	RET

LAB_c800_05e3:
	POP	AX
	JMP	SHORT LAB_c800_0599

FUN_c800_05e6:
	POP	DX
	MOV	CX,6

LAB_c800_05ea:
	POP	BX
	LOOP	LAB_c800_05ea
	PUSH	DX
	RET

FUN_c800_05ef:
	CALL	FUN_c800_097d
	CALL	FUN_c800_062c
	MOV	AX,CX
	SUB	AX,WORD 2
	MOV	CH,AL
	SHR	AX,1
	SHR	AX,1
	AND	AL,0C0H
	PUSH	AX
	CALL	READ_HARDWARE_CONFIG
	MOV	CL,11H
	NOT	AL
	AND	AL,30H
	XOR	AL,20H
	JNZ	LAB_c800_0612
	MOV	CL,1AH
LAB_c800_0612:
	POP	AX
	OR	AL,CL
	MOV	AH,CH
	MOV	[BP+12],AX			; Update saved CX
	MOV	AH,ES:[BX+8]
	DEC	AH
	MOV	AL,[SI+1]
	MOV	[BP+10],AX			; Update saved DX
	MOV	AH,0
	CALL	FUN_c800_05e6
	RET

FUN_c800_062c:
	PUSH	AX
	MOV	CX,ES:[BX+10]
	CMP	CX,ES:[BX]
	JZ	LAB_c800_0647
	CMP	WORD ES:[BX], BYTE 0
	JZ	LAB_c800_0647
	TEST	BYTE [BP+10],1			; Saved DL
	JZ	LAB_c800_0647
	NEG	CX
	ADD	CX,ES:[BX]
LAB_c800_0647:
	CALL	READ_HARDWARE_CONFIG
	NOT	AL
	AND	AL,30H
	JZ	LAB_c800_0668
	XOR	AL,20H
	JZ	LAB_c800_0668
	MOV	AX,1529
	MUL	CX
	MOV	CX,1000
	DIV	CX
	CMP	AX,400H
	JLE	LAB_c800_0666
	MOV	AX,400H
LAB_c800_0666:
	MOV	CX,AX
LAB_c800_0668:
	POP	AX
	RET

FUN_c800_066a:
	CMP	WORD [BP+12], BYTE 1	; Saved CX
	JNZ	LAB_c800_0679
	CMP	BYTE [BP+11], BYTE 0	; Saved DH
	JNZ	LAB_c800_0679
	CALL	FUN_c800_0834
LAB_c800_0679:
	MOV	AL,04BH				; Single mode
						; Increment after each transfer
						; Read from memory
						; Channel 3
	JMP	SHORT LAB_c800_0698

FUN_c800_067d:
	MOV	AL,47H				; Single mode
						; Increment after each transfer
						; Write to memory
						; Channel 3
LAB_c800_067f:
	MOV	DL,[SAVED_INT13H_AL]
	MOV	DI,0204H
	JMP	SHORT LAB_c800_069f

FUN_c800_0688:
	MOV	AL,4BH				; Single mode
						; Increment after each transfer
						; Read from memory
						; Channel 3
	JMP	SHORT LAB_c800_067f

FUN_c800_068c:
	MOV	AL,47H				; Single mode
						; Increment after each transfer
						; Write to memory
						; Channel 3
LAB_c800_068e:
	MOV	DL,1
	JMP	SHORT LAB_c800_069c

FUN_c800_0692:
	MOV	AL,4BH				; Single mode
						; Increment after each transfer
						; Read from memory
						; Channel 3
	JMP	SHORT LAB_c800_068e

FUN_c800_0696:
	MOV	AL,47H				; Single mode
						; Increment after each transfer
						; Write to memory
						; Channel 3
LAB_c800_0698:
	MOV	DL,[SAVED_INT13H_AL]
LAB_c800_069c:
	MOV	DI,200H
LAB_c800_069f:
	CLI
	OUT	0BH,AL				; Set DMA mode
	NOP
	NOP
	OUT	0CH,AL				; Clear address and counter regs
	PUSH	DX
	CALL	READ_HARDWARE_CONFIG
	MOV	BL,AL
	POP	DX
	AND	BL,80H
	JNZ	LAB_c800_06b6
	MOV	AL,0C0H
	OUT	0D6H,AL				; Set DMA mode in 2nd 8237
LAB_c800_06b6:
	MOV	AX,ES
	MOV	CL,4
	ROL	AX,CL
	MOV	CH,AL
	AND	AL,0F0H
	ADD	AX,[BP+14]
	ADC	CH,0
	OUT	06H,AL				; First 8237, current address, byte 0
	XCHG	AH,AL
	NOP
	OUT	06H,AL				; First 8237, current address, byte 1
	XCHG	AL,CH
	MOV	CL,AH
	AND	AL,0FH
	OUT	82H,AL				; DMA channel 3, address byte 2
	MOV	AX,DI
	XOR	DH,DH
	MUL	DX
	SUB	AX,1
	SBB	DL,0
	OUT	07H,AL				; DMA channel 3, word count, byte 0
	XCHG	AL,AH
	NOP
	OUT	07H,AL				; DMA channel 3, word count, byte 1
	STI
	JNZ	LAB_c800_0706
	XCHG	AH,AL
	ADD	AX,CX
	JC	LAB_c800_0706
	MOV	AL,3
	CALL	FUN_c800_07df
	JC	LAB_c800_0708
	MOV	AL,3
	OUT	0AH,AL				; Unmask DMA channel 3
	OR	BL,BL
	JNZ	LAB_c800_0710
	XOR	AL,AL
	OUT	0D4H,AL				; Unmask DMA channel 4
	JMP	SHORT LAB_c800_0710

LAB_c800_0706:
	MOV	AH,9				; Data boundary error

LAB_c800_0708:
	RET


FUN_c800_0709:
	MOV	AL,2
	CALL	FUN_c800_07df
	JC	LAB_c800_0708

LAB_c800_0710:
	CLI
	CALL	READ_HARDWARE_CONFIG
	AND	AL,40H				; Check for bit 6 set
	IN	AL,21H				; Read OCW1
	JNZ	LAB_c800_071e			; Jump if set
	AND	AL,0FBH				; Disable IRQ 2
	JMP	SHORT LAB_c800_0720

LAB_c800_071e:
	AND	AL,0DFH				; Disable IRQ 5

LAB_c800_0720:
	OUT	21H,AL				; Write PIC OCW1
	STI					; Interrupts enabled
	CALL	GET_STATUS_ADDRESS
	MOV	AH,4BH				; Retry count
	MOV	CX,0BD00H			; Retry count
LAB_c800_072b:
	IN	AL,DX				; Read status register
	TEST	AL,20H				; Check for IRQ flag
	JNZ	LAB_c800_0744			; Jump if set
	TEST	AL,8				; Test for BSY flag
	JZ	LAB_c800_072b			; Retry if not set
	LOOP	LAB_c800_072b			; Retry - inner loop
	DEC	AH				; Decrement retry counter
	JNZ	LAB_c800_072b			; Retry - outer loop
	CMP	BYTE [LAB_0000_0442],4
	JZ	LAB_c800_072b
LAB_c800_0741:
	JMP	LAB_c800_07f0

LAB_c800_0744:
	CALL	GET_MASK_REGISTER_ADDR
	MOV	AL,0FCH				; Clear IRQEN and DRQEN flags
	OUT	DX,AL				; Write to Interrupt Mask Register
	CALL	FUN_c800_0812
	JC	LAB_c800_0741
	JZ	LAB_c800_0708

FUN_c800_0751:
	MOV	BYTE [LAB_0000_0442],3
	MOV	AL,0FCH
	CALL	FUN_c800_07df
	JC	LAB_c800_07cf
	MOV	DI,LAB_0000_0442
	MOV	AX,DS
	MOV	ES,AX
	MOV	CX,4
	CLD

LAB_c800_0768:
	CALL	WAIT_FOR_REQ_SET
	JC	LAB_c800_07cf
	IN	AL,DX
	STOSB
	LOOP	LAB_c800_0768
	CALL	FUN_c800_0812
	JC	LAB_c800_07cf
	JNZ	LAB_c800_07cf
	CALL	FUN_c800_0a0f
	JNZ	LAB_c800_0780
	CALL	FUN_c800_0ab1

LAB_c800_0780:
	MOV	CH,[LAB_0000_0442]
	MOV	BL,CH
	AND	BX,WORD 0030H
	MOV	CL,3
	SHR	BL,CL
	MOV	AH,CH
	AND	AH,0FH
	CMP	AH,CS:[BX+0B26H]
	JNC	LAB_c800_07cc
	INC	BX
	MOV	BL,CS:[BX+0B26H]
	ADD	BL,AH
	MOV	AH,CS:[BX+0B26H]
	CMP	CH,98H
	JNZ	LAB_c800_07ce
	MOV	BYTE [LAB_0000_0442],0DH
	MOV	BH,AH
	MOV	AL,0FCH
	CALL	FUN_c800_07df
	JC	LAB_c800_07cf
	CALL	WAIT_FOR_REQ_SET
	JC	LAB_c800_07cf
	IN	AL,DX
	MOV	BL,AL
	CALL	FUN_c800_0812
	JC	LAB_c800_07cf
	JNZ	LAB_c800_07cf
	MOV	AX,BX
	RET

LAB_c800_07cc:
	MOV	AH,0BBH

LAB_c800_07ce:
	RET

LAB_c800_07cf:
	MOV	AH,0FFH
	RET

FUN_c800_07d2:
	CALL	FUN_c800_0751
	CMP	AH,0FFH
	JZ	LAB_c800_07ce
	MOV	AL,AH
	XOR	AH,AH
	RET

FUN_c800_07df:
	CALL	GET_MASK_REGISTER_ADDR
	OUT	DX,AL				; Write DMA and IRQ mask register
	DEC	DX				; Point to configuration register
	OUT	DX,AL				; Select controller
	DEC	DX				; Point to status register
	MOV	CX,012CH			; Timeout for BSY

LAB_c800_07e9:
	IN	AL,DX				; Read status register
	TEST	AL,8				; Check for BSY
	JNZ	LAB_c800_07f4			; Is it set? Yes - jump
	LOOP	LAB_c800_07e9			; No, try again

LAB_c800_07f0:
	MOV	AH,80H				; Set error: timeout
	STC					; Carry indicates error

LAB_c800_07f3:
	RET					; Return to caller

LAB_c800_07f4:
	MOV	DI,LAB_0000_0442
	MOV	CX,6
	CLD

LAB_c800_07fb:
	CALL	WAIT_FOR_REQ_SET		; Wait for REQ flag
	JC	LAB_c800_07f3			; If failed, return
	AND	AL,0EH				; Preserve BSY, CD, and IO flags
	XOR	AL,0CH				; Check for IO flag
	JNZ	LAB_c800_07f0			; Fail if not set
	XCHG	DI,SI
	LODSB
	XCHG	DI,SI
	OUT	DX,AL
	LOOP	LAB_c800_07fb
	MOV	AH,0				; Success
	CLC					; Clear carry - no error
	RET

FUN_c800_0812:
	CALL	WAIT_FOR_REQ_SET
	MOV	AH,0
	JC	LAB_c800_082e
	AND	AL,0EH
	CMP	AL,0EH
	JNZ	LAB_c800_082d
	IN	AL,DX
	MOV	AH,AL
	INC	DX
	MOV	CX,100
LAB_c800_0826:
	IN	AL,DX
	AND	AL,8
	JZ	LAB_c800_082f
	LOOP	LAB_c800_0826

LAB_c800_082d:
	STC					; Set error flag

LAB_c800_082e:
	RET

LAB_c800_082f:
	XCHG	AL,AH
	TEST	AL,2
	RET


FUN_c800_0834:
	MOV	AX,[BP+0]
	MOV	BX,[BP+14]
	MOV	ES,AX
	CMP	WORD ES:[BX+01FEH],0AABBH
	JZ	LAB_c800_082e
	MOV	AH,[LAB_0000_0442]
	MOV	AL,[SAVED_INT13H_AL]
	PUSH	AX
	MOV	AX,[SAVED_INT13H_CX]
	PUSH	AX
	CALL	FUN_c800_089b
	JC	LAB_c800_088e
	PUSH	AX
	MOV	AX,[BP+0]
	MOV	BX,[BP+14]
	MOV	ES,AX
	POP	AX
	MOV	ES:[BX+01BDH],AL
	POP	AX
	MOV	ES:[BX+01B6H],AX
	POP	AX
	MOV	ES:[BX+01B4H],AL
	MOV	ES:[BX+01B5H],AH
	POP	AX
	MOV	ES:[BX+01B2H],AX
	POP	AX
	MOV	ES:[BX+01B0H],AX
	POP	AX
	MOV	ES:[BX+01AFH],AL
	POP	AX
	MOV	ES:[BX+01ADH],AX

LAB_c800_088e:
	POP	AX
	MOV	[SAVED_INT13H_CX],AX
	POP	AX
	MOV	[LAB_0000_0442],AH
	MOV	[SAVED_INT13H_AL],AL
	RET


FUN_c800_089b:
	MOV	AH,8
	MOV	[LAB_0000_0442],AH
	XOR	AX,AX
	MOV	[SAVED_INT13H_CX],AX
	MOV	AH,0E0H
	AND	AH,[LAB_0000_0443]
	MOV	[LAB_0000_0443],AH
	INC	AL
	MOV	[SAVED_INT13H_AL],AL
	MOV	AL,0FCH
	CALL	FUN_c800_07df
	JC	LAB_c800_0929
	CALL	FUN_c800_0942
	POP	DI
	MOV	CX,01ADH
	CALL	FUN_c800_092a
	JC	LAB_c800_0928
	CALL	FUN_c800_0933
	JC	LAB_c800_0928
	PUSH	AX
	MOV	CX,1
	CALL	FUN_c800_092a
	JC	LAB_c800_0926
	PUSH	AX
	CALL	FUN_c800_0933
	JC	LAB_c800_0925
	PUSH	AX
	CALL	FUN_c800_0933
	JC	LAB_c800_0924
	PUSH	AX
	CALL	FUN_c800_0933
	JC	LAB_c800_0923
	PUSH	AX
	CALL	FUN_c800_0933
	JC	LAB_c800_0922
	PUSH	AX
	MOV	CX,6
	CALL	FUN_c800_092a
	JC	LAB_c800_0921
	PUSH	AX
	MOV	CX,40H
	CALL	FUN_c800_092a
	JC	LAB_c800_0920
	CALL	FUN_c800_0933
	JC	LAB_c800_0920
	PUSH	AX
	CALL	FUN_c800_0812
	JC	LAB_c800_091f
	JNZ	LAB_c800_091f
	POP	AX
	CMP	AX,0AA55H
	JZ	LAB_c800_0918
	CMP	AX,0AABBH
	JNZ	LAB_c800_0920

LAB_c800_0918:
	POP	AX
	OR	AL,AL
	JNZ	LAB_c800_0928
	PUSH	AX
	PUSH	AX

LAB_c800_091f:
	POP	AX

LAB_c800_0920:
	POP	AX

LAB_c800_0921:
	POP	AX

LAB_c800_0922:
	POP	AX

LAB_c800_0923:
	POP	AX

LAB_c800_0924:
	POP	AX

LAB_c800_0925:
	POP	AX

LAB_c800_0926:
	POP	AX
	STC

LAB_c800_0928:
	PUSH	DI

LAB_c800_0929:
	RET

FUN_c800_092a:
	CALL	WAIT_FOR_REQ_SET
	JC	LAB_c800_0932
	IN	AL,DX
	LOOP	FUN_c800_092a

LAB_c800_0932:
	RET

FUN_c800_0933:
	CALL	WAIT_FOR_REQ_SET
	JC	LAB_c800_0941
	IN	AL,DX
	MOV	AH,AL
	CALL	WAIT_FOR_REQ_SET
	IN	AL,DX
	XCHG	AH,AL

LAB_c800_0941:
	RET


FUN_c800_0942:
	XOR	CX,CX
	MOV	AH,30H
	CALL	GET_STATUS_ADDRESS

LAB_c800_0949:
	IN	AL,DX
	TEST	AL,4
	JZ	LAB_c800_0958
	TEST	AL,2
	JNZ	LAB_c800_0958
	LOOP	LAB_c800_0949
	DEC	AH
	JNZ	LAB_c800_0949

LAB_c800_0958:
	RET

;--------------------------------------------------------------------------
; This function waits for the REQ flag to be set.
;
; Input: Nothing
; Output: DX containing data register address
;	AL contains status register value
;	On error, AH contains error code and carry is set
;--------------------------------------------------------------------------
WAIT_FOR_REQ_SET:
	PUSH	CX
	MOV	CX,0FA00H			; Number of retries
	CALL	GET_STATUS_ADDRESS

LAB_c800_0960:
	IN	AL,DX				; Read status register
	TEST	AL,1				; Check for REQ flag
	JNZ	LAB_c800_096e			; Jump if set
	TEST	AL,8				; Check for BSY flag
	JZ	LAB_c800_096b			; Fail if present
	LOOP	LAB_c800_0960			; Try again if possible

LAB_c800_096b:
	STC					; Indicate error
	MOV	AH,80H				; Timeout error

LAB_c800_096e:
	DEC	DX				; Point to data register
	POP	CX
	RET					; Return to caller

;--------------------------------------------------------------------------
; This function checks S1-5 and S1-6. As per the documentation,
; they should be left open which will use the built-in pull-ups
; to read high.
;
; Input: Nothing
; Output: ZF set if both S1-5 and S1-6 are open. ZF unset otherwise.
;--------------------------------------------------------------------------
FUN_c800_0971:
	PUSH	AX
	PUSH	DX
	CALL	READ_HARDWARE_CONFIG
	NOT	AL				; Inverts HW register value
	AND	AL,S15 | S16			; Checks for bits 4 and 5
	POP	DX
	POP	AX
	RET

FUN_c800_097d:
	POP	BX
	CALL	FUN_c800_0a0f
	JZ	LAB_c800_09a8
	MOV	CX,[SI+2]
	TEST	BYTE [LAB_0000_0443],20H
	JZ	LAB_c800_0994
	TEST	CL,8
	JZ	LAB_c800_0994
	XCHG	CH,CL

LAB_c800_0994:
	TEST	CL,80H
	JNZ	LAB_c800_09bf
	CALL	FUN_c800_089b
	JC	LAB_c800_09a8
	MOV	CX,BX

LAB_c800_09a0:
	MOV	AX,SS
	MOV	ES,AX
	MOV	BX,SP
	PUSH	CX
	RET

LAB_c800_09a8:
	TEST	BYTE [LAB_0000_0443],20H
	JZ	LAB_c800_09bb
	TEST	BYTE [SI+2],8
	JZ	LAB_c800_09bf
	OR	BYTE [SI+3],80H
	JMP	SHORT LAB_c800_09bf

LAB_c800_09bb:
	OR	BYTE [SI+2],080H

LAB_c800_09bf:
	CALL	READ_HARDWARE_CONFIG
	TEST	BYTE [LAB_0000_0443],20H
	JZ	LAB_c800_09cd
	SHR	AL,1
	SHR	AL,1

LAB_c800_09cd:
	AND	AX,3
	MOV	CL,4
	SHL	AX,CL
	MOV	CX,BX
	PUSH	CS
	POP	BX
	CMP	BH,0C8H
	LES	BX,[INT_41H_VECTOR]
	JZ	LAB_c800_09ee
	MOV	BX,43H
	CALL	FUN_c800_0971
	JZ	LAB_c800_09ee
	MOV	BX,85H
	PUSH	CS
	POP	ES
LAB_c800_09ee:
	ADD	BX,AX
LAB_c800_09f0:
	MOV	AX,ES:[BX]
	PUSH	AX
	MOV	AL,ES:[BX+2]
	PUSH	AX
	MOV	AX,ES:[BX+3]
	PUSH	AX
	MOV	AX,ES:[BX+5]
	PUSH	AX
	MOV	AX,ES:[BX+7]
	PUSH	AX
	MOV	AX,ES:[BX+9]
	PUSH	AX
	JMP	SHORT LAB_c800_09a0

FUN_c800_0a0f:
	PUSH	AX
	PUSH	DX
	CALL	READ_HARDWARE_CONFIG
	NOT	AL
	AND	AL,30H
	XOR	AL,10H
	POP	DX
	POP	AX
	RET

;--------------------------------------------------------------------------
; Reads the hardware configuration address at I/O 322h or 324h
; depending on the current CS value.
;
; Input: Nothing
; Output: AL = byte from hardware configuration register
;         DX is destroyed
;--------------------------------------------------------------------------
READ_HARDWARE_CONFIG:
	PUSH	CS
	POP	DX				; DX has CS value
	CMP	DH,0C8H				; Check if CS starts with C8H
	MOV	DX,0322H			; Base I/O address
	JZ	DO_READ_HARDWARE_CONFIG		; Yes, go straight to reading from hardware
	ADD	DX,BYTE 4			; Add offset for second card

DO_READ_HARDWARE_CONFIG:
	IN	AL,DX
	RET

GET_STATUS_ADDRESS:
	PUSH	CS
	POP	DX
	CMP	DH,0C8H				; Check for C8xx
	MOV	DX,0321H			; This is status address for first controller
	JZ	RETURN_STATUS_ADDRESS		; Don't add for first controller
	ADD	DX,BYTE 4			; Add for second controller

RETURN_STATUS_ADDRESS:
	RET

GET_MASK_REGISTER_ADDR:
	PUSH	CS
	POP	DX
	CMP	DH,0C8H				; Check for C8xx
	MOV	DX,0323H			; DMA and IRQ mask register for first controller
	JZ	LAB_c800_0a47			; Don't add for first controller
	ADD	DX,BYTE 4			; Add for second controller

LAB_c800_0a47:
	RET

FUN_c800_0a48:
	PUSH	ES
	PUSH	AX
	CALL	FUN_c800_097d
	MOV	CX,[SAVED_INT13H_CX]
	PUSH	CX
	MOV	AL,CH
	MOV	AH,CL
	MOV	CL,6
	SHR	AH,CL
	MOV	CX,AX
	MOV	AL,ES:[BX+8]
	XOR	AH,AH
	MUL	CX
	MOV	DL,[LAB_0000_0443]
	AND	DX,000FH
	ADD	AX,DX
	MOV	CX,11H
	MUL	CX
	POP	CX
	AND	CX,001FH
	ADD	AX,CX
	JNC	LAB_c800_0a7d
	INC	DX
LAB_c800_0a7d:
	PUSH	AX
	MOV	AL,ES:[BX+8]
	XOR	AH,AH
	MOV	CX,AX
	MOV	BX,1AH
	POP	AX
	DIV	BX
	PUSH	DX
	XOR	DX,DX
	DIV	CX
	MOV	BX,DX
	MOV	[SAVED_INT13H_CH],AL
	MOV	CL,6
	SHL	AH,CL
	POP	DX
	OR	AH,DL
	MOV	[SAVED_INT13H_CL],AH
	MOV	AL,[LAB_0000_0443]
	AND	AL,0F0H
	OR	AL,BL
	MOV	[LAB_0000_0443],AL
	CALL	FUN_c800_05e6
	POP	AX
	POP	ES
	RET

FUN_c800_0ab1:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	ES
	CALL	FUN_c800_097d
	MOV	DH,[LAB_0000_0443]
	AND	DH,1FH
	MOV	CL,[SAVED_INT13H_CL]
	MOV	CH,[SAVED_INT13H_CH]
	PUSH	CX
	PUSH	DX
	MOV	AL,CH
	MOV	AH,CL
	MOV	CL,6
	SHR	AH,CL
	MOV	CX,AX
	MOV	AL,ES:[BX+8]
	XOR	AH,AH
	MUL	CX
	POP	CX
	MOV	DL,CH
	ADD	AX,DX
	MOV	CX,1AH
	MUL	CX
	POP	CX
	AND	CX,WORD 001FH
	ADD	AX,CX
	JNC	LAB_c800_0af0
	INC	DX
LAB_c800_0af0:
	PUSH	AX
	MOV	AL,ES:[BX+8]
	XOR	AH,AH
	MOV	CX,AX
	MOV	BX,11H
	POP	AX
	DIV	BX
	INC	DX
	PUSH	DX
	XOR	DX,DX
	DIV	CX
	MOV	BX,DX
	MOV	[SAVED_INT13H_CH],AL
	MOV	CL,6
	SHL	AH,CL
	POP	DX
	OR	AH,DL
	MOV	[SAVED_INT13H_CL],AH
	MOV	AL,[LAB_0000_0443]
	OR	AL,BL
	MOV	[LAB_0000_0443],AL
	CALL	FUN_c800_05e6
	POP	ES
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET

LAB_c800_0b26:
	DB	9,8,10,17,2,27,3,29,0,32
	DB	64,32,128,0,32,0,64,16,16,2
	DB	0,4,64,0,0,17,11,1,2,32
	DB	32,16
	DB	10 dup(0)

LAB_c800_0b50:
	JMP	SHORT LAB_c800_0b57

LAB_c800_0b52:
	DB	0AAH,55H
	DB	1EH,07H,0DCH

LAB_c800_0b57:
	JMP	SHORT LAB_c800_0b71

LAB_c800_0b59:
	DW	LAB_c800_1973
	DW	LAB_c800_19a9
	DW	LAB_c800_19bb
	DW	LAB_c800_19d7
	DW	LAB_c800_19fc
	DW	LAB_c800_1a21
	DW	LAB_c800_1a3e
	DW	LAB_c800_1a54
	DW	LAB_c800_1a7b
	DW	LAB_c800_1a9a
	DW	LAB_c800_1abc
	DW	LAB_c800_1ae0

LAB_c800_0b71:
	PUSH	SS
	POP	ES
	MOV	BP,0
	MOV	[BP+116H],SP
	MOV	DI,0330H
	ADD	DI,BP
	MOV	[BP+129H],DI
	DEC	DI
	MOV	[BP+12BH],DI
	MOV	DI,SP
	SUB	DI,12CH
	CMP	DI,[BP+129H]
	JA	LAB_c800_0b98
	MOV	DI,[BP+12BH]
LAB_c800_0b98:
	MOV	[BP+12DH],DI
	MOV	DI,100H
	ADD	DI,BP
	XOR	AL,AL
	MOV	CX,23H
	REP 	STOSB
	CALL	FUN_c800_0fe1
	PUSH	SS
	POP	DS
	CALL	FUN_c800_1061
	MOV	BYTE [BP+110H],53H
	MOV	AX,[BP+114H]
	MOV	DL,AH
	OR	DL,80H
	MOV	AX,1
	INT	13H
	XOR	AX,AX
	MOV	DS,AX
	PUSH	CS
	POP	AX
	MOV	BX,0476H
	CMP	AH,0C8H
	JZ	LAB_c800_0bd4
	MOV	BX,0122H
LAB_c800_0bd4:
	AND	WORD [BX],7F7FH
	PUSH	ES
	PUSH	SS
	POP	ES
	MOV	BX,100H
	MOV	AX,1601H
	INT	13H
	POP	ES
	CALL	FUN_c800_0c11
	MOV	DX,LAB_c800_1dd5
	JC	LAB_c800_0bef
	MOV	DX,LAB_c800_1d4b
LAB_c800_0bef:
	PUSH	CS
	POP	DS
	MOV	AH,9
	INT	21H
LAB_c800_0bf5:
	MOV	AH,6
	MOV	DL,0FFH
	INT	21H
	JNZ	LAB_c800_0bf5
	MOV	DX,LAB_c800_1d5f
	MOV	AH,9
	INT	21H
LAB_c800_0c04:
	MOV	AH,6
	MOV	DL,0FFH
	INT	21H
	JZ	LAB_c800_0c04
	JMP	0FFFFH:00000H
	
FUN_c800_0c11:
	CALL	FUN_c800_0f3e
	JC	LAB_c800_0c64
	CALL	FUN_c800_0c65
	MOV	AX,[BP+129H]
	CMP	AX,[BP+12BH]
	JA	LAB_c800_0c26
	CALL	FUN_c800_0eb1
LAB_c800_0c26:
	TEST	BYTE [BP+0123H],30H
	JZ	LAB_c800_0c64
	MOV	AX,0
	MOV	CX,100H
	MOV	DI,130H
	ADD	DI,BP
	CLD
	REP	STOSW
	MOV	DI,02DDH
	MOV	SI,100H
	MOV	CX,11H
	REP	ES MOVSB
	MOV	CX,1
	MOV	DL,[BP+115H]
	ADD	DL,80H
	MOV	DH,0
	MOV	AX,301H
	MOV	BX,130H
	ADD	BX,BP
	MOV	WORD ES:[BX+01FEH],0AABBH
	INT	13H
LAB_c800_0c64:
	RET

FUN_c800_0c65:
	AND	BYTE [BP+012FH],0EFH
	XOR	AX,AX
	MOV	DS,AX
	MOV	AX,[BP+109H]
	AND	AX,AX
	JZ	LAB_c800_0c77
	DEC	AX
LAB_c800_0c77:
	MOV	[BP+111H],AX
	MOV	AL,[BP+102H]
	AND	AL,AL
	JZ	LAB_c800_0c85
	DEC	AL

LAB_c800_0c85:
	MOV	[BP+113H],AL
	MOV	DX,LAB_c800_1aff
	CALL	FUN_c800_1166
	JNZ	LAB_c800_0ca2

LAB_c800_0c91:
	MOV	BYTE SS:[019EH],80H
	CALL	FUN_c800_0cad
	MOV	DX,LAB_c800_1d2b
	CALL	FUN_c800_1166
	JZ	LAB_c800_0c91
LAB_c800_0ca2:
	TEST	BYTE [BP+12FH],10H
	JZ	LAB_c800_0cac
	CALL	FUN_c800_0d72
LAB_c800_0cac:
	RET


FUN_c800_0cad:
	MOV	DX,LAB_c800_1b30
	CALL	FUN_c800_1170
	MOV	SS:[11CH],SP
	CALL	FUN_c800_1324
LAB_c800_0cbb:
	CMP	DH,8
	JZ	LAB_c800_0cca
	CALL	FUN_c800_0ccb
	JC	LAB_c800_0cca
	CALL	FUN_c800_1416
	JMP	SHORT LAB_c800_0cbb
LAB_c800_0cca:
	RET

FUN_c800_0ccb:
	CALL	FUN_c800_12af
	MOV	SS:[19FH],BX
	CALL	FUN_c800_1416
	CALL	FUN_c800_12c9
	MOV	SS:[1A2H],BL
	MOV	BYTE SS:[1A1H],1
	PUSH	CX
	PUSH	SI
	CALL	FUN_c800_1334
	JC	LAB_c800_0cf4
	CALL	FUN_c800_0cf7
	OR	BYTE [BP+12FH],10H
	CLC
LAB_c800_0cf4:
	POP	SI
	POP	CX
	RET

FUN_c800_0cf7:
	CALL	FUN_c800_0d1d
	JNZ	LAB_c800_0d0a
LAB_c800_0cfc:
	MOV	AL,SS:[19EH]
	CMP	AL,SS:[DI]
	JZ	LAB_c800_0d1c
	CALL	FUN_c800_0d23
	JZ	LAB_c800_0cfc
LAB_c800_0d0a:
	CALL	FUN_c800_0d41
	MOV	CX,5
	MOV	SI,19EH
	CLD
	PUSH	ES
	POP	DS
	PUSH	ES
	PUSH	SS
	POP	ES
	REP	MOVSB
	POP	ES
LAB_c800_0d1c:
	RET

FUN_c800_0d1d:
	MOV	DI,[BP+129H]
	JMP	SHORT LAB_c800_0d26

FUN_c800_0d23:
	ADD	DI,BYTE 5
LAB_c800_0d26:
	CMP	DI,[BP+12BH]
	JA	LAB_c800_0d40
	MOV	AX,SS:[19FH]
	CMP	AX,SS:[DI+1]
	JNZ	LAB_c800_0d3e
	MOV	AX,SS:[1A1H]
	CMP	AX,SS:[DI+3]
LAB_c800_0d3e:
	JG	FUN_c800_0d23
LAB_c800_0d40:
	RET

FUN_c800_0d41:
	MOV	AX,DI
	MOV	SI,[BP+12BH]
	MOV	DI,SI
	ADD	DI,BYTE 5
	JC	LAB_c800_0d68
	CMP	DI,[BP+12DH]
	JA	LAB_c800_0d68
	MOV	[BP+12BH],DI
	MOV	CX,SI
	INC	CX
	SUB	CX,AX
	PUSH	ES
	PUSH	SS
	POP	ES
	STD
	REP	SS MOVSB
	POP	ES
	MOV	DI,AX
	RET

LAB_c800_0d68:
	MOV	DX,LAB_c800_1c72
	MOV	SP,[BP+116H]
	JMP	LAB_c800_0bef

FUN_c800_0d72:
	MOV	DX,LAB_c800_1c37
	MOV	SI,[BP+129H]
	CMP	SI,[BP+12BH]
	JA	LAB_c800_0d83
	CALL	FUN_c800_0d86
	RET
LAB_c800_0d83:
	JMP	FUN_c800_0eaa

FUN_c800_0d86:
	MOV	AL,80H
	CALL	FUN_c800_0e23
	JNC	LAB_c800_0dae
LAB_c800_0d8d:
	MOV	DX,LAB_c800_1bba
	CALL	FUN_c800_0eaa
	MOV	BYTE SS:[128H],18H
LAB_c800_0d99:
	CALL	FUN_c800_0dba
	CALL	FUN_c800_0e18
	JNC	LAB_c800_0dae
	SUB	BYTE SS:[128H],1
	JNZ	LAB_c800_0d99
	CALL	FUN_c800_0daf
	JMP	SHORT LAB_c800_0d8d
LAB_c800_0dae:
	RET

FUN_c800_0daf:
	MOV	DX,LAB_c800_1d00
	CALL	FUN_c800_0eaa
	MOV	AH,1
	INT	21H
	RET

FUN_c800_0dba:
	CALL	FUN_c800_0e09
LAB_c800_0dbd:
	CALL	FUN_c800_0e34
	CALL	FUN_c800_0e4a
	CMP	DI,156H
	JA	LAB_c800_0df8
	CALL	FUN_c800_0e18
	JNC	LAB_c800_0df8
	MOV	DI,156H
	JMP	SHORT LAB_c800_0dbd

LAB_c800_0dd3:
	CALL	FUN_c800_0e09

LAB_c800_0dd6:
	CALL	FUN_c800_0e34
	MOV	AL,SS:[SI+3]
	AND	AL,3FH
	XOR	AH,AH
	INC	DI
	CALL	FUN_c800_0e74
	CALL	FUN_c800_0e4a
	CMP	DI,156H
	JA	LAB_c800_0df8
	CALL	FUN_c800_0e1c
	JNC	LAB_c800_0df8
	MOV	DI,156H
	JMP	SHORT LAB_c800_0dd6

LAB_c800_0df8:
	MOV	DX,130H
	PUSH	ES
	POP	DS
	MOV	BYTE [DI],24H
	CALL	FUN_c800_0eac
	MOV	DX,LAB_c800_1970
	CALL	FUN_c800_0eaa

FUN_c800_0e09:
	MOV	AL,20H
	MOV	CX,50H
	MOV	DI,130H
	CLD
	REP	STOSB
	MOV	DI,130H
	RET

FUN_c800_0e18:
	MOV	AL,80H
	JMP	SHORT LAB_c800_0e1e
FUN_c800_0e1c:
	MOV	AL,40H				; Unused?

LAB_c800_0e1e:
	ADD	SI,BYTE 5
	JC	LAB_c800_0e31

FUN_c800_0e23:
	CMP	SI,[BP+12BH]
	JA	LAB_c800_0e31
	TEST	SS:[SI],AL
	JZ	LAB_c800_0e1e
	JMP	LAB_c800_115a

LAB_c800_0e31:
	JMP	LAB_c800_114b

FUN_c800_0e34:
	MOV	AX,SS:[SI+1]
	ADD	DI,BYTE 0
	CALL	FUN_c800_0e74
	MOV	AL,SS:[SI+4]
	AND	AL,1FH
	XOR	AH,AH
	INC	DI
	JMP	SHORT FUN_c800_0e74
	NOP

FUN_c800_0e4a:
	PUSH	ES
	PUSH	SI
	MOV	BL,SS:[SI]
	AND	BL,0FH
	XOR	BH,BH
	SHL	BX,1
	MOV	SI,CS:[BX+LAB_c800_18ae]
	MOV	CL,CS:[SI]
	XOR	CH,CH
	INC	SI
	CMP	DI,156H
	MOV	DI,161H
	JA	LAB_c800_0e6d
	MOV	DI,13BH

LAB_c800_0e6d:
	CLD
	REP	CS MOVSB
	POP	SI
	POP	ES
	RET

FUN_c800_0e74:
	MOV	BX,0EA4H
LAB_c800_0e77:
	CMP	AX,CS:[BX]
	JGE	LAB_c800_0e87
	ADD	BX,BYTE 2
	CMP	BX,0EAAH
	JC	LAB_c800_0e77
	JMP	SHORT LAB_c800_0e9a

LAB_c800_0e87:
	XOR	DX,DX
	DIV	WORD CS:[BX]
	CALL	FUN_c800_0e9d
	MOV	AX,DX
	ADD	BX,BYTE 2
	CMP	BX,0EAAH
	JC	LAB_c800_0e87

LAB_c800_0e9a:
	JMP	SHORT FUN_c800_0e9d
	NOP

FUN_c800_0e9d:
	OR	AL,30H
	MOV	ES:[DI],AL
	INC	DI
	RET

	DW	03E8H
	DW	0064H
	DW	000AH

FUN_c800_0eaa:
	PUSH	CS
	POP	DS

FUN_c800_0eac:
	MOV	AH,9
	INT	21H
	RET

FUN_c800_0eb1:
	MOV	SI,[BP+129H]
LAB_c800_0eb5:
	CMP	SI,[BP+12BH]
	JA	LAB_c800_0efd
	TEST	BYTE SS:[SI],0C0H
	JZ	LAB_c800_0ef8
	MOV	AL,[BP+122H]
	NOT	AL
	AND	AL,30H
	CMP	AL,30H
	JZ	LAB_c800_0efe
	XOR	AL,10H
	JZ	LAB_c800_0efe
	MOV	AL,SS:[SI+2]
	MOV	CL,6
	SHL	AL,CL
	MOV	CL,AL
	MOV	CH,SS:[SI+1]
	MOV	DH,SS:[SI+4]
	ADD	CL,SS:[SI+3]
LAB_c800_0ee7:
	MOV	DL,[BP+115H]
	OR	DL,80H
	MOV	AX,0601H
	INT	13H
	JNC	LAB_c800_0ef8
	JMP	LAB_c800_0fcb

LAB_c800_0ef8:
	ADD	SI,BYTE 5
	JMP	SHORT LAB_c800_0eb5

LAB_c800_0efd:
	RET

LAB_c800_0efe:
	MOV	CL,[BP+102H]
	XOR	CH,CH
	PUSH	CX
	MOV	AX,SS:[SI+1]
	MUL	CX
	MOV	DL,SS:[SI+4]
	XOR	DH,DH
	ADD	AX,DX
	MOV	CX,1AH
	MUL	CX
	MOV	CL,SS:[SI+3]
	ADD	AX,CX
	MOV	CX,11H
	DIV	CX
	POP	CX
	PUSH	DX
	XOR	DX,DX
	DIV	CX
	MOV	CH,AL
	MOV	CL,6
	SHL	AH,CL
	MOV	CL,AH
	MOV	DH,DL
	POP	AX
	AND	AL,AL
	JNZ	LAB_c800_0f3a
	INC	AL

LAB_c800_0f3a:
	OR	CL,AL
	JMP	SHORT LAB_c800_0ee7

FUN_c800_0f3e:
	MOV	AX,CS
	MOV	DS,AX
	MOV	DX,LAB_c800_14c0
	MOV	AH,9
	INT	21H
	MOV	AX,[BP+114H]
	OR	AL,AL
	JNZ	LAB_c800_0f53
	MOV	AL,3
LAB_c800_0f53:
	AND	AH,7
	PUSH	AX
	ADD	AH,43H
	MOV	DL,AH
	MOV	AH,2
	INT	21H
	MOV	DX,LAB_c800_1d39
	MOV	AH,9
	INT	21H
	POP	AX
	PUSH	AX
	MOV	AH,AL
	AND	AL,0FH
	DAA
	AND	AH,0F0H
	JZ	LAB_c800_0f76
	ADD	AL,16H
	DAA

LAB_c800_0f76:
	CALL	FUN_c800_14a2
	CALL	FUN_c800_115c
	PUSH	CS
	POP	DS
	CMP	AL,79H
	JZ	LAB_c800_0f89
	CMP	AL,59H
	JZ	LAB_c800_0f89
	POP	AX
	STC
	RET

LAB_c800_0f89:
	MOV	DX,LAB_c800_1899
	MOV	AH,9
	INT	21H
	MOV	AX,0
	MOV	CX,100H
	MOV	DI,130H
	CLD
	REP	STOSW
	POP	AX
	PUSH	AX
	MOV	DL,AH
	ADD	DL,80H
	MOV	AH,0FH
	PUSH	ES
	XOR	BX,BX
	MOV	ES,BX
	MOV	BX,130H
	INT	13H
	POP	ES
	MOV	BH,AH
	JC	LAB_c800_0fca
	POP	AX
	MOV	DL,AH
	ADD	DL,80H
	SUB	DH,DH
	PUSH	DX
	MOV	CX,1
	MOV	AH,7
	INT	13H
	MOV	BH,AH
	JC	LAB_c800_0fca
	POP	AX
	RET

LAB_c800_0fca:
	POP	AX

LAB_c800_0fcb:
	MOV	DX,LAB_c800_1dba
	MOV	SP,[BP+116H]
	MOV	AH,9
	INT	21H
	MOV	AL,BH
	CALL	FUN_c800_14a2
	MOV	DX,LAB_c800_1970
	JMP	LAB_c800_0bef

FUN_c800_0fe1:
	MOV	DL,80H
	MOV	AH,20H
	INT	13H
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	MOV	SI,[DISK_AREA_PTR]
	POP	DS
	CALL	READ_HARDWARE_CONFIG
	MOV	[BP+122H],AL
	MOV	WORD [BP+114H],3
	NOT	AL
	AND	AL,30H
	JZ	LAB_c800_100a
	MOV	WORD [BP+114H],4
LAB_c800_100a:
	MOV	DX,LAB_c800_14e7
	PUSH	CS
	POP	DS
	MOV	AH,9
	INT	21H
	MOV	DL,[BP+115H]
	ADD	DL,43H
	MOV	AH,2
	INT	21H
	MOV	DX,LAB_c800_1544
	CALL	FUN_c800_1170
	JCXZ	LAB_c800_1035
	CALL	FUN_c800_1324
	CALL	FUN_c800_1251
	CALL	FUN_c800_1334
	JC	LAB_c800_100a
	MOV	[BP+115H],BL
LAB_c800_1035:
	MOV	DX,LAB_c800_1571
	PUSH	CS
	POP	DS
	MOV	AH,9
	INT	21H
	MOV	DL,[BP+114H]
	ADD	DL,30H
	MOV	AH,2
	INT	21H
	MOV	DX,LAB_c800_158a
	CALL	FUN_c800_1170
	JCXZ	LAB_c800_1060
	CALL	FUN_c800_1324
	CALL	FUN_c800_1277
	CALL	FUN_c800_1334
	JC	LAB_c800_1035
	MOV	[BP+114H],BL

LAB_c800_1060:
	RET

FUN_c800_1061:
	MOV	WORD [BP+111H],800H
	MOV	BYTE [BP+113H],10H
	MOV	AL,[BP+122H]
	NOT	AL
	AND	AL,30H
	XOR	AL,10H
	JZ	LAB_c800_1084
	MOV	DX,LAB_c800_15bb
	CALL	FUN_c800_1166
	MOV	AL,30H
	JZ	LAB_c800_1084
	XOR	AL,AL

LAB_c800_1084:
	AND	BYTE [BP+123H],8FH
	OR	[BP+123H],AL
	TEST	BYTE [BP+123H],10H
	JNZ	LAB_c800_109a
	CALL	FUN_c800_10c9
	JMP	SHORT LAB_c800_109d
	NOP

LAB_c800_109a:
	CALL	FUN_c800_10b3

LAB_c800_109d:
	MOV	WORD [BP+100H],0
	CALL	FUN_c800_111c
	MOV	DI,0
	MOV	CX,SS:[11AH]
	MOV	[BP+100H],CX
	RET

FUN_c800_10b3:
	MOV	DX,LAB_c800_15f5
	CALL	FUN_c800_1170
	JCXZ	LAB_c800_110e
	CALL	FUN_c800_1190
	JC	FUN_c800_10b3
	MOV	AX,[BP+109H]
	MOV	SS:[180H],AX
	RET

FUN_c800_10c9:
	MOV	AL,[BP+122H]
	MOV	AH,AL
	NOT	AH
	AND	AH,30H
	MOV	SI,43H
	JZ	LAB_c800_10dc
	MOV	SI,85H

LAB_c800_10dc:
	TEST	BYTE [BP+115H],1
	JZ	LAB_c800_10e7
	SHR	AL,1
	SHR	AL,1

LAB_c800_10e7:
	AND	AX,3
	MOV	CL,4
	SHL	AX,CL
	CLD
	ADD	SI,AX
	PUSH	DS
	PUSH	ES
	MOV	AX,CS
	MOV	DS,AX
	MOV	AX,SS
	MOV	ES,AX
	MOV	CX,11H
	MOV	DI,100H
	REP	MOVSB
	MOV	AX,[BP+109H]
	MOV	SS:[11AH],AX
	POP	ES
	POP	DS
	RET

LAB_c800_110e:
	MOV	DX,LAB_c800_1dd5
	XOR	AX,AX
	MOV	ES,AX
	MOV	SP,[BP+116H]
	JMP	LAB_c800_0bef

FUN_c800_111c:
	MOV	AX,[BP+109H]
	MOV	SS:[11AH],AX
	CALL	FUN_c800_112f
	JC	LAB_c800_114d
	AND	BYTE [BP+123H],0DFH
	RET

FUN_c800_112f:
	TEST	BYTE [BP+115H],1
	JNZ	LAB_c800_114b
	TEST	BYTE [BP+123H],20H
	JZ	LAB_c800_114b
	MOV	DX,LAB_c800_17e6
	CALL	FUN_c800_115f
	CMP	AL,79H
	JZ	LAB_c800_115a
	CMP	AL,59H
	JZ	LAB_c800_115a

LAB_c800_114b:
	CLC
	RET

LAB_c800_114d:
	MOV	DX,LAB_c800_181e
	CALL	FUN_c800_1170
	JCXZ	FUN_c800_111c
	CALL	FUN_c800_11f3
	JC	LAB_c800_114d

LAB_c800_115a:
	STC
	RET

FUN_c800_115c:
	MOV	DX,LAB_c800_1970

FUN_c800_115f:
	CALL	FUN_c800_1170
	MOV	AL,ES:[SI]
	RET

FUN_c800_1166:
	CALL	FUN_c800_115f
	CMP	AL,79H
	JZ	LAB_c800_116f
	CMP	AL,59H

LAB_c800_116f:
	RET

FUN_c800_1170:
	PUSH	CS
	POP	DS
	MOV	AH,9
	INT	21H
	MOV	BYTE SS:[130H],50H
	PUSH	ES
	POP	DS
	MOV	DX,130H
	MOV	AH,0AH
	INT	21H
	MOV	SI,132H
	MOV	CL,SS:[131H]
	XOR	CH,CH
	RET

FUN_c800_1190:
	MOV	SS:[11CH],SP
	CALL	FUN_c800_1324
	CALL	FUN_c800_12af
	CMP	BX,400H
	JLE	LAB_c800_11a7
	OR	BYTE SS:[123H],40H

LAB_c800_11a7:
	MOV	[BP+109H],BX
	CALL	FUN_c800_1416
	CALL	FUN_c800_12c9
	MOV	[BP+102H],BL
	CALL	FUN_c800_1416
	MOV	BX,[BP+109H]
	INC	BX
	MOV	[BP+105H],BX
	CALL	FUN_c800_12aa
	MOV	[BP+103H],BX
	CALL	FUN_c800_1416
	MOV	BX,[BP+105H]
	CALL	FUN_c800_12aa
	MOV	[BP+105H],BX
	CALL	FUN_c800_1416
	MOV	BX,0BH
	CALL	FUN_c800_12f9
	MOV	[BP+107H],BL
	CALL	FUN_c800_1416
	MOV	BX,5
	CALL	FUN_c800_1311
	MOV	[BP+108H],BL
	JMP	FUN_c800_1334

FUN_c800_11f3:
	MOV	SS:[11CH],SP
	CALL	FUN_c800_1324
	MOV	BYTE SS:[119H],0
	MOV	WORD SS:[11AH],0
	MOV	BYTE SS:[118H],2
	XOR	DI,DI
LAB_c800_1210:
	CALL	FUN_c800_12af
	ADD	SS:[11AH],BX
	MOV	ES:[DI+1F70H],BX
	INC	BYTE SS:[119H]
	MOV	BX,[BP+109H]
	CMP	BX,SS:[11AH]
	JGE	LAB_c800_1232
	MOV	AL,0
	CALL	FUN_c800_1478
LAB_c800_1232:
	CALL	FUN_c800_1416
	CMP	DH,8
	JZ	LAB_c800_1246
	DEC	BYTE SS:[118H]
	JZ	LAB_c800_1249
	ADD	DI,[BP+1AH]
	JMP	SHORT LAB_c800_1210

LAB_c800_1246:
	JMP	FUN_c800_1334

LAB_c800_1249:
	MOV	AL,4
	CALL	FUN_c800_1486
	JMP	FUN_c800_1334

FUN_c800_1251:
	MOV	SS:[11CH],SP
	MOV	SS:[120H],SI
	SUB	AL,43H
	JC	LAB_c800_126f
	MOV	BL,AL
	INC	BL
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	CMP	BL,[TOTAL_FIXED_DISKS]
	POP	DS
	JBE	LAB_c800_1274
LAB_c800_126f:
	MOV	AL,2
	CALL	FUN_c800_1478
LAB_c800_1274:
	DEC	BL
	RET

FUN_c800_1277:
	MOV	SS:[11CH],SP
	CALL	FUN_c800_13b2
	CMP	BX,BYTE 0
	JZ	LAB_c800_1298
	MOV	AL,[BP+122H]
	NOT	AL
	AND	AL,30H
	JZ	LAB_c800_1293
	CMP	BX,BYTE 19H
	JMP	SHORT LAB_c800_1296

LAB_c800_1293:
	CMP	BX,BYTE 10H

LAB_c800_1296:
	JBE	LAB_c800_12a9

LAB_c800_1298:
	MOV	AL,[BP+122H]
	NOT	AL
	AND	AL,30H
	MOV	AL,6
	JZ	LAB_c800_12a6
	MOV	AL,8

LAB_c800_12a6:
	CALL	FUN_c800_1478

LAB_c800_12a9:
	RET

FUN_c800_12aa:
	TEST	DH,1
	JZ	LAB_c800_12c8

FUN_c800_12af:
	CALL	FUN_c800_13b2
	CMP	BX,[BP+111H]
	JLE	LAB_c800_12be
	MOV	AL,12H
	CALL	FUN_c800_1478
	RET

LAB_c800_12be:
	TEST	BYTE SS:[123H],40H
	JZ	LAB_c800_12c8
	SHR	BX,1

LAB_c800_12c8:
	RET

FUN_c800_12c9:
	CALL	FUN_c800_13b2
	CMP	BL,[BP+113H]
	JLE	LAB_c800_12d8
	MOV	AL,14H
	CALL	FUN_c800_1478
	RET

LAB_c800_12d8:
	TEST	BYTE SS:[123H],40H
	JZ	LAB_c800_12e5
	SHL	BL,1
	AND	BL,1FH

LAB_c800_12e5:
	RET

LAB_c800_12e6:
	CALL	FUN_c800_13b2
	CMP	BX,BYTE 1
	JL	LAB_c800_12f3
	CMP	BX,BYTE 11H
	JLE	LAB_c800_12f8

LAB_c800_12f3:
	MOV	AL,10H
	CALL	FUN_c800_1478

LAB_c800_12f8:
	RET


FUN_c800_12f9:
	TEST	DH,1
	JZ	LAB_c800_1310
	CALL	FUN_c800_13b2
	CMP	BX,BYTE 5
	JZ	LAB_c800_1310
	CMP	BX,BYTE 0BH
	JZ	LAB_c800_1310
	MOV	AL,0EH
	CALL	FUN_c800_1478

LAB_c800_1310:
	RET


FUN_c800_1311:
	TEST	DH,2
	JZ	LAB_c800_1323
	CALL	FUN_c800_13e5
	TEST	BL,0F8H
	JZ	LAB_c800_1323
	MOV	AL,0AH
	CALL	FUN_c800_1478

LAB_c800_1323:
	RET


FUN_c800_1324:
	PUSH	CX
	XOR	AL,AL
	MOV	CX,1AH
	MOV	DI,184H
	REP	STOSB
	POP	CX
	DEC	SI
	JMP	FUN_c800_1422

FUN_c800_1334:
	CLC
	MOV	CX,SS:[184H]
	JCXZ	LAB_c800_1343
	CALL	FUN_c800_1344
	CALL	FUN_c800_1385
	STC
LAB_c800_1343:
	RET

FUN_c800_1344:
	MOV	CX,4EH
	MOV	AX,2020H
	MOV	DI,132H
	REP	STOSB
	MOV	CX,SS:[184H]
	XOR	DI,DI
LAB_c800_1356:
	MOV	SI,SS:[DI+187H]
	MOV	BYTE ES:[SI],5EH
	ADD	DI,BYTE 3
	LOOP	LAB_c800_1356
	MOV	BYTE ES:[SI+1],24H
	PUSH	CS
	POP	DS
	MOV	DX,LAB_c800_1970
	MOV	AH,9
	INT	21H
	PUSH	ES
	POP	DS
	MOV	DX,132H
	MOV	AH,9
	INT	21H
	PUSH	CS
	POP	DS
	MOV	DX,LAB_c800_1970
	MOV	AH,9
	INT	21H
	RET

FUN_c800_1385:
	MOV	CX,SS:[184H]
	XOR	SI,SI
	MOV	DL,30H

LAB_c800_138e:
	INC	DL
	MOV	AH,2
	INT	21H
	PUSH	DX
	MOV	AL,SS:[SI+186H]
	XOR	AH,AH
	MOV	DI,AX
	MOV	DX,CS:[DI+LAB_c800_0b59]
	MOV	AX,CS
	MOV	DS,AX
	MOV	AH,9
	INT	21H
	POP	DX
	ADD	SI,BYTE 3
	LOOP	LAB_c800_138e
	RET

FUN_c800_13b2:
	MOV	SS:[120H],SI
	TEST	DH,1
	JZ	LAB_c800_13e2
	MOV	BL,DL
	XOR	BH,BH
LAB_c800_13c0:
	CALL	FUN_c800_142b
	TEST	DH,1
	JZ	LAB_c800_13e1
	XOR	DH,DH
	MOV	AX,BX
	MOV	BX,DX
	MUL	WORD CS:[MULTIPLIER]
	JO	LAB_c800_13db
	JS	LAB_c800_13db
	ADD	BX,AX
	JNO	LAB_c800_13c0

LAB_c800_13db:
	CALL	FUN_c800_140d
	MOV	BX,7FFFH

LAB_c800_13e1:
	RET

LAB_c800_13e2:
	JMP	LAB_c800_146b

FUN_c800_13e5:
	MOV	SS:[120H],SI
	TEST	DH,2
	JZ	LAB_c800_146b
	XOR	BX,BX
LAB_c800_13f1:
	OR	BL,DL
	CALL	FUN_c800_142b
	TEST	DH,2
	JZ	LAB_c800_140c
	PUSH	CX
	MOV	CL,4
	SHL	BX,CL
	POP	CX
	TEST	BH,0FFH
	JZ	LAB_c800_13f1
	CALL	FUN_c800_140d
	MOV	BX,7FFFH

LAB_c800_140c:
	RET


FUN_c800_140d:
	CALL	FUN_c800_142b
	TEST	DH,0CH
	JNZ	FUN_c800_140d
	RET

FUN_c800_1416:
	CALL	FUN_c800_1425
	CMP	DL,2CH
	JNZ	LAB_c800_1421
	CALL	FUN_c800_1422
LAB_c800_1421:
	RET

FUN_c800_1422:
	CALL	FUN_c800_142b

FUN_c800_1425:
	CMP	DL,20H
	JZ	FUN_c800_1422
	RET

FUN_c800_142b:
	JCXZ	LAB_c800_1464
	INC	SI
	MOV	AL,ES:[SI]
	DEC	CX
	CMP	AL,61H
	JC	LAB_c800_1438
	SUB	AL,20H

LAB_c800_1438:
	MOV	DH,3
	MOV	DL,AL
	SUB	DL,30H
	CMP	AL,30H
	JL	LAB_c800_1447
	CMP	AL,39H
	JLE	LAB_c800_146a

LAB_c800_1447:
	MOV	DH,2
	ADD	DL,0F9H
	CMP	AL,41H
	JL	LAB_c800_1456
	CMP	AL,46H
	JLE	LAB_c800_146a
	JMP	SHORT LAB_c800_146b

LAB_c800_1456:
	MOV	DL,AL
	MOV	DH,4
	CMP	AL,20H
	JZ	LAB_c800_146a
	CMP	AL,2CH
	JZ	LAB_c800_146a
	JMP	SHORT LAB_c800_146b

LAB_c800_1464:
	XOR	DL,DL
	MOV	DH,8
	XOR	AL,AL

LAB_c800_146a:
	RET

LAB_c800_146b:
	MOV	AL,0CH
	CALL	FUN_c800_1486
	MOV	SP,SS:[11CH]
	JMP	FUN_c800_1334


FUN_c800_1478:
	XCHG	SS:[120H],SI
	CALL	FUN_c800_1486
	XCHG	SS:[120H],SI
	RET

FUN_c800_1486:
	MOV	DI,SS:[184H]
	ADD	DI,DI
	ADD	DI,SS:[184H]
	MOV	SS:[DI+186H],AL
	MOV	SS:[DI+187H],SI
	INC	WORD SS:[184H]
	RET

FUN_c800_14a2:
	PUSH	AX
	MOV	CL,4
	SHR	AL,CL
	CALL	FUN_c800_14ae
	POP	AX
	JMP	SHORT FUN_c800_14ae
	NOP

FUN_c800_14ae:
	AND	AL,0FH
	ADD	AL,90H
	DAA
	ADC	AL,40H
	DAA
	MOV	DL,AL
	MOV	AH,2
	INT	21H
	RET

MULTIPLIER:
	DW	10
	DB	11H				; Unknown

LAB_c800_14c0:
	DB	13,10,'Press "y" to begin formatting drive $'
LAB_c800_14e7:
	DB	13,10,'Super Bios Formatter Rev. 2.4 (C) Copyright Western Digital Corp. 1987'
	DB	13,10,10,'Current Drive is $'
LAB_c800_1544:
	DB	':, Select new Drive or RETURN for current.',13,10,'$'
LAB_c800_1571:
	DB	13,10,'Current Interleave is $'
LAB_c800_158a:
	DB	', Select new Interleave or RETURN for current.',13,10,'$'
LAB_c800_15bb:
	DB	13,10,'Are you dynamically configuring the drive - answer Y/N $'
LAB_c800_15f5:
	DB	13,10,'Key in disk characteristics as follows:ccc h rrr ppp ee o'
	DB	13,10,'where'
	DB	13,10,'ccc = total number of cylinders (1-4 digits)'
	DB	13,10,'h = number of heads (1-2 digits)'
	DB	13,10,'rrr = starting reduced write cylinder (1-4 digits)'
	DB	13,10,'ppp = write precomp cylinder (1-4 digits)'
	DB	13,10,'ee = max correctable error burst length (1-2 digits)'
	DB	13,10,'     range = 5 to 11 bits, default = 11 bits'
	DB	13,10,' o = CCB option byte, step rate select (1 hex digit)'
	DB	13,10,'     range = 0 to 7, default = 5'
	DB	13,10,'     refer to controller and drive specification for step rates'
	DB	13,10,'$'
LAB_c800_17e6:
	DB	13,10,'Are you virtually configuring the drive - answer Y/N $'
LAB_c800_181e:
	DB	13,10,'Key in cylinder number for virtual drive split as vvvv ...'
	DB	13,10,'where vvvv = number of cylinders for drive C: (1-4 digits)'
	DB	13,10,'$'
LAB_c800_1899:
	DB	13,10,'Formatting . . .'
	DB	13,10,'$'

LAB_c800_18ae:
	DW	LAB_c800_1962
	DW	LAB_c800_1939
	DW	LAB_c800_1914
	DW	LAB_c800_18d8
	DW	LAB_c800_1903
	DW	LAB_c800_1951
	DW	LAB_c800_18ee
	DW	LAB_c800_192b
	DW	LAB_c800_18c2
	DW	LAB_c800_18ee

LAB_c800_18c2:
	DB	LAB_c800_18c3_END - LAB_c800_18c3
LAB_c800_18c3:
	DB	'CORRECTABLE ECC ERROR'
LAB_c800_18c3_END	EQU	$

LAB_c800_18d8:
	DB	LAB_c800_18d9_END - LAB_c800_18d9
LAB_c800_18d9:
	DB	'FLAGGED AS BAD SECTOR'
LAB_c800_18d9_END	EQU	$

LAB_c800_18ee:
	DB	LAB_c800_18ef_END - LAB_c800_18ef
LAB_c800_18ef:
	DB	'FLAGGED AS BAD TRACK'
LAB_c800_18ef_END	EQU	$

LAB_c800_1903:
	DB	LAB_c800_1904_END - LAB_c800_1904
LAB_c800_1904:
	DB	'MISSING ID FIELD'
LAB_c800_1904_END	EQU	$

LAB_c800_1914:
	DB	LAB_c800_1915_END - LAB_c800_1915
LAB_c800_1915:
	DB	'MISSING DATA ADDR MARK'
LAB_c800_1915_END	EQU	$

LAB_c800_192b:
	DB	LAB_c800_193b_END - LAB_c800_193b
LAB_c800_193b:
	DB	'PROGRAM ERROR'
LAB_c800_193b_END	EQU	$

LAB_c800_1939:
	DB	LAB_c800_193a_END - LAB_c800_193a
LAB_c800_193a:
	DB	'UNCORRECTABLE ECC ERROR'
LAB_c800_193a_END	EQU	$

LAB_c800_1951:
	DB	LAB_c800_1952_END - LAB_c800_1952
LAB_c800_1952:
	DB	'UNREADABLE TRACK'
LAB_c800_1952_END	EQU	$

LAB_c800_1962:
	DB	LAB_c800_1963_END - LAB_c800_1963
LAB_c800_1963:
	DB	'USER-SUPPLIED'
LAB_c800_1963_END	EQU	$

LAB_c800_1970:
	DB	13,10,'$'
LAB_c800_1973:
	DB	': Aggregate virtual size exceeds disk cylinder size',13,10,'$'
LAB_c800_19a9:
	DB	': Invalid drive',13,10,'$'
LAB_c800_19bb:
	DB	': Too many virtual drives',13,10,'$'
LAB_c800_19d7:
	DB	': Interleave factor must be 1 - 16',13,10,'$'
LAB_c800_19fc:
	DB	': Interleave factor must be 1 - 25',13,10,'$'
LAB_c800_1a21:
	DB	': Invalid CCB option value',13,10,'$'
LAB_c800_1a3e:
	DB	': Illegal character',13,10,'$'
LAB_c800_1a54:
	DB	': Error burst length must be 5 or 11',13,10,'$'
LAB_c800_1a7b:
	DB	': Sector number must be 1-17',13,10,'$'
LAB_c800_1a9a:
	DB	': Cylinder size exceeds maximum',13,10,'$'
LAB_c800_1abc:
	DB	': Number of heads exceeds maximum',13,10,'$'
LAB_c800_1ae0:
	DB	' : pool size exceeds maximum',13,10,'$'
LAB_c800_1aff:
	DB	13,10,'Do you want to format bad tracks - answer Y/N $'
LAB_c800_1b30:
	DB	13,10,'Key in bad track list as follows: ccc h ...'
	DB	13,10,'where '
	DB	13,10,'ccc = bad track cylinder no (1-4 digits)'
	DB	13,10,'h = bad track head number (1-2 digits)'
	DB	13,10,'$'
LAB_c800_1bba:
	DB	13,10,'                               BAD TRACK MAP'
	DB	13,10,'TRACK ADDR          PROBLEM          TRACK ADDR          PROBLEM          '
	DB	13,10,'$'
LAB_c800_1c37:
	DB	13,10,'The surface analysis processor detected no disk errors'
	DB	13,10,'$'
LAB_c800_1c72:
	DB	13,10,'Dynamic memory space exhausted - cannot complete surface analysis'
	DB	13,10,'$'
LAB_c800_1cb8:
	DB	13,10,'Too many disk errors - cannot complete alt track/sector assignments'
	DB	13,10,'$'
LAB_c800_1d00:
	DB	13,10,' Screen full - hit any key to continue'
	DB	13,10,'$'
LAB_c800_1d2b:
	DB	13,10,'More ? Y/N $'
LAB_c800_1d39:
	DB	' with interleave $'
LAB_c800_1d4b:
	DB	13,10,'Format Successful$'
LAB_c800_1d5f:
	DB	13,10,10,'System will now restart'
	DB	13,10,10,7,'Insert DOS diskette in drive A:'
	DB	13,10,'Press any key when ready.  $'
LAB_c800_1dba:
	DB	13,10,'Error---completion code $'
LAB_c800_1dd5:
	DB	13,10,'Nothing Done Exit$'

	DB	426 dup(0)
	DB	108 dup(0FFH)
