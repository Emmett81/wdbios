; This file contains some equates for easily accessing the hardware


;----------- Equates for status port (reading 322h)
; This means that the status port's bit assignment is like this:
; Bits		  7   6   5   4   3   2   1   0
; Jumpers	S18 S17 S16 S15 OP3 OP2 OP1 OP0

OP0	equ	01h	; S1-1
OP1	equ	02h	; S1-2
OP2	equ	04h	; S1-3
OP3	equ	08h	; S1-4

S15	equ	10h	; S1-5
S16	equ	20h	; S1-6
S17	equ	40h	; S1-7
S18	equ	80h	; S1-8
