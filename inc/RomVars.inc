%ifndef __ROMVARS_INC__
%define __ROMVARS_INC__

struc DRVPARAMS
	.wCylinder		resb	2		; Cylinders
	.bHeads			resb	1		; Heads
	.wReducedWrite		resb	2		; Starting reduced write current cylinder
	.wWritePrecomp		resb	2		; Starting write precompensation cylinder
	.bMaxEccBurst		resb	1		; Maximum ECC burst length
	.bControlByte		resb	1		; Control byte
	.bStandardTimeout	resb	1		; Standard timeout
	.bFormattingTimeout	resb	1		; Formatting timeout
	.rgbReserved		resb	5		; Reserved (unused)
endstruc

struc ROMVARS
	.wBiosSignature		resb	2		; BIOS signature (AA55h)
	.bBiosLength		resb	1		; BIOS length in 512 btyes blocks
	.rgbBiosEntry		resb	2		; BIOS entry point
	.rgbFormatEntry		resb	3		; BIOS Format entry point
	.szCopyright		resb	48		; Copyright string
	.rgbUnknown		resb	11		; Unknown
	.driveType0Params	resb	DRVPARAMS_size	; Drive type 0 params
	.driveType1Params	resb	DRVPARAMS_size	; Drive type 1 params
	.driveType2Params	resb	DRVPARAMS_size	; Drive type 2 params
	.driveType3Params	resb	DRVPARAMS_size	; Drive type 3 params
	.rgbBiosEntryJump	resb	2		; Jump to entry point
	.driveType4Params	resb	DRVPARAMS_size	; Drive type 4 params
	.driveType5Params	resb	DRVPARAMS_size	; Drive type 5 params
	.driveType6Params	resb	DRVPARAMS_size	; Drive type 6 params
	.driveType7Params	resb	DRVPARAMS_size	; Drive type 7 params
endstruc

%endif ; !__ROMVARS_INC__
