; Super-BIOS for WD1002A-WX1
; Copyright (c) 2022, Sergio Aguayo
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from
;    this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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


