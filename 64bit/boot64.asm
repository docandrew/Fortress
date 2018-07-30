
; This code is linked in the upper half of memory

global higher_half_start

%define kernelVirt 0xFFFF800000000000

extern kmain					; from main.d
extern stack_ptr				; from boot.asm

section .text
bits 64
higher_half_start:
	; update stack pointer to upper-half virt memory (still mapped to previous phys location)
	mov rsp, (stack_ptr + kernelVirt)

	; call into D code
	mov rax, QWORD kmain
	call rax
.hang:
	hlt
	jmp .hang
