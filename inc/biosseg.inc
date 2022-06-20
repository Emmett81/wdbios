INT_0AH_IRQ2_OFFSET	EQU	28H
INT_0AH_IRQ2_SEGMENT	EQU	2AH
INT_0DH_IRQ5_OFFSET	EQU	34H
INT_0DH_IRQ5_SEGMENT	EQU	36H
INT_13H_VECTOR		EQU	4CH
INT_13H_OFFSET		EQU	4CH
INT_13H_SEGMENT		EQU	4EH
INT_19H_OFFSET		EQU	64H
INT_19H_SEGMENT		EQU	66H
INT_40H_OFFSET		EQU	100H
INT_40H_SEGMENT		EQU	102H
INT_41H_VECTOR		EQU	104H
INT_41H_OFFSET		EQU	104H
INT_41H_SEGMENT		EQU	106H
INT_46H_OFFSET		EQU	118H
INT_46H_SEGMENT		EQU	11AH
INT_47H_OFFSET		EQU	11CH
INT_47H_SEGMENT		EQU	11EH

;----- Start of fixed disk data - second controller -----
SECOND_DISK_AREA	EQU	120H
INT_48H_OFFSET		EQU	120H
SECOND_FIXED_DISKS	EQU	121H		; Contains the number of drives
						; for the second controller
INT_48H_SEGMENT		EQU	122H

;----- End of fixed disk data - second controller -----

DISK_AREA_PTR		EQU	442H		; During interrupt handling, contains
						; address of active drive's data area,
						; either FIRST_DISK_AREA or
						; SECOND_DISK_AREA
LAB_0000_0442		EQU	442H
LAB_0000_0443		EQU	443H

SAVED_INT13H_CX		EQU	444H		; Input value of CX during Int 13H call
SAVED_INT13H_CL		EQU	444H
SAVED_INT13H_CH		EQU	445H
SAVED_INT13H_AL		EQU	446H		; Input value of AL during Int 13H call
LAB_0000_0447		EQU	447H
TIMER_TICKS		EQU	46CH		; Updated every 55ms by timer handler
POST_RESET_FLAG		EQU	472H		; Specifies action of BIOS at POST
						; 0000: Cold boot (full test)
						; 1234: Warm boot (skips memory test)

;----- Start of fixed disk data - first controller -----
FIRST_DISK_AREA		EQU	474H
LAST_OPERATION_FIXED_DISK EQU	474H
TOTAL_FIXED_DISKS	EQU	475H		; Contains the total number of
						; fixed disks, for both controllers

;----- End of fixed disk data - first controller ------

BOOT_SECTOR_OFFSET	EQU	7C00H
BOOT_SECTOR_MAGIC_OFF	EQU	7DFEH
