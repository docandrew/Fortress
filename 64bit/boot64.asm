
global long_mode_start

section .text
bits 64
long_mode_start:
	; Jump to our 64-bit code
	extern kmain
	call kmain

	cli
.hang:
	hlt
	jmp .hang