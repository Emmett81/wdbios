%ifndef __DRVPAR2_INC__
%define __DRVPAR2_INC__

	AT	ROMVARS.driveType4Params+DRVPARAMS.wCylinder,		dw	981
	AT	ROMVARS.driveType4Params+DRVPARAMS.bHeads,		db	5
	AT	ROMVARS.driveType4Params+DRVPARAMS.wReducedWrite,	dw	982
	AT	ROMVARS.driveType4Params+DRVPARAMS.wWritePrecomp,	dw	982
	AT	ROMVARS.driveType4Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType4Params+DRVPARAMS.bControlByte,	db	7	; 3ms step
	AT	ROMVARS.driveType4Params+DRVPARAMS.bStandardTimeout,	db	213
	AT	ROMVARS.driveType4Params+DRVPARAMS.bFormattingTimeout,	db	3
	AT	ROMVARS.driveType4Params+DRVPARAMS.rgbReserved,		db	5 dup 0

	AT	ROMVARS.driveType5Params+DRVPARAMS.wCylinder,		dw	987
	AT	ROMVARS.driveType5Params+DRVPARAMS.bHeads,		db	7
	AT	ROMVARS.driveType5Params+DRVPARAMS.wReducedWrite,	dw	988
	AT	ROMVARS.driveType5Params+DRVPARAMS.wWritePrecomp,	dw	988
	AT	ROMVARS.driveType5Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType5Params+DRVPARAMS.bControlByte,	db	7	; 3ms step
	AT	ROMVARS.driveType5Params+DRVPARAMS.bStandardTimeout,	db	219
	AT	ROMVARS.driveType5Params+DRVPARAMS.bFormattingTimeout,	db	3
	AT	ROMVARS.driveType5Params+DRVPARAMS.rgbReserved,		db	5 dup 0

	AT	ROMVARS.driveType6Params+DRVPARAMS.wCylinder,		dw	612
	AT	ROMVARS.driveType6Params+DRVPARAMS.bHeads,		db	4
	AT	ROMVARS.driveType6Params+DRVPARAMS.wReducedWrite,	dw	613
	AT	ROMVARS.driveType6Params+DRVPARAMS.wWritePrecomp,	dw	613
	AT	ROMVARS.driveType6Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType6Params+DRVPARAMS.bControlByte,	db	7	; 3ms step
	AT	ROMVARS.driveType6Params+DRVPARAMS.bStandardTimeout,	db	100
	AT	ROMVARS.driveType6Params+DRVPARAMS.bFormattingTimeout,	db	2
	AT	ROMVARS.driveType6Params+DRVPARAMS.rgbReserved,		db	5 dup 0

	AT	ROMVARS.driveType7Params+DRVPARAMS.wCylinder,		dw	615
	AT	ROMVARS.driveType7Params+DRVPARAMS.bHeads,		db	4
	AT	ROMVARS.driveType7Params+DRVPARAMS.wReducedWrite,	dw	616
	AT	ROMVARS.driveType7Params+DRVPARAMS.wWritePrecomp,	dw	616
	AT	ROMVARS.driveType7Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType7Params+DRVPARAMS.bControlByte,	db	7	; 3ms step
	AT	ROMVARS.driveType7Params+DRVPARAMS.bStandardTimeout,	db	103
	AT	ROMVARS.driveType7Params+DRVPARAMS.bFormattingTimeout,	db	2
	AT	ROMVARS.driveType7Params+DRVPARAMS.rgbReserved,		db	5 dup 0

%endif ; ! __DRVPAR2_INC__
