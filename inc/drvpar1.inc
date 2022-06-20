%ifndef __DRVPAR1_INC__
%define __DRVPAR1_INC__

	AT	ROMVARS.driveType0Params+DRVPARAMS.wCylinder,		dw	612
	AT	ROMVARS.driveType0Params+DRVPARAMS.bHeads,		db	4
	AT	ROMVARS.driveType0Params+DRVPARAMS.wReducedWrite,	dw	450
	AT	ROMVARS.driveType0Params+DRVPARAMS.wWritePrecomp,	dw	450
	AT	ROMVARS.driveType0Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType0Params+DRVPARAMS.bControlByte,	db	5	; 70ms step
	AT	ROMVARS.driveType0Params+DRVPARAMS.bStandardTimeout,	db	100
	AT	ROMVARS.driveType0Params+DRVPARAMS.bFormattingTimeout,	db	2
	AT	ROMVARS.driveType0Params+DRVPARAMS.rgbReserved,		db	5 dup 0

	AT	ROMVARS.driveType1Params+DRVPARAMS.wCylinder,		dw	306
	AT	ROMVARS.driveType1Params+DRVPARAMS.bHeads,		db	4
	AT	ROMVARS.driveType1Params+DRVPARAMS.wReducedWrite,	dw	153
	AT	ROMVARS.driveType1Params+DRVPARAMS.wWritePrecomp,	dw	0
	AT	ROMVARS.driveType1Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType1Params+DRVPARAMS.bControlByte,	db	5	; 70ms step
	AT	ROMVARS.driveType1Params+DRVPARAMS.bStandardTimeout,	db	50
	AT	ROMVARS.driveType1Params+DRVPARAMS.bFormattingTimeout,	db	1
	AT	ROMVARS.driveType1Params+DRVPARAMS.rgbReserved,		db	5 dup 0

	AT	ROMVARS.driveType2Params+DRVPARAMS.wCylinder,		dw	615
	AT	ROMVARS.driveType2Params+DRVPARAMS.bHeads,		db	2
	AT	ROMVARS.driveType2Params+DRVPARAMS.wReducedWrite,	dw	450
	AT	ROMVARS.driveType2Params+DRVPARAMS.wWritePrecomp,	dw	450
	AT	ROMVARS.driveType2Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType2Params+DRVPARAMS.bControlByte,	db	5	; 70ms step
	AT	ROMVARS.driveType2Params+DRVPARAMS.bStandardTimeout,	db	103
	AT	ROMVARS.driveType2Params+DRVPARAMS.bFormattingTimeout,	db	2
	AT	ROMVARS.driveType2Params+DRVPARAMS.rgbReserved,		db	5 dup 0

	AT	ROMVARS.driveType3Params+DRVPARAMS.wCylinder,		dw	615
	AT	ROMVARS.driveType3Params+DRVPARAMS.bHeads,		db	4
	AT	ROMVARS.driveType3Params+DRVPARAMS.wReducedWrite,	dw	450
	AT	ROMVARS.driveType3Params+DRVPARAMS.wWritePrecomp,	dw	450
	AT	ROMVARS.driveType3Params+DRVPARAMS.bMaxEccBurst,	db	11
	AT	ROMVARS.driveType3Params+DRVPARAMS.bControlByte,	db	5	; 70ms step
	AT	ROMVARS.driveType3Params+DRVPARAMS.bStandardTimeout,	db	103
	AT	ROMVARS.driveType3Params+DRVPARAMS.bFormattingTimeout,	db	2
	AT	ROMVARS.driveType3Params+DRVPARAMS.rgbReserved,		db	5 dup 0

%endif ; ! __DRVPAR1_INC__
