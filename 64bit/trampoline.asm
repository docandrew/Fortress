;
; trampoline - this is compiled to an elf64 object that is loaded in lower mem. We need this because in
; boot.asm we can't jump more than 2GB, but the kernel is linked in higher-half memory. We instead
; jump to this, which then does a far call to the higher-half code in memory (boot64.asm)
;
; our assembler will not let us use 64-bit instructions in the 32-bit boot.asm, so we do so here.

global trampoline
extern higher_half_start

section .text
bits 64
trampoline:
	cli     ; no 64-bit interrupt handlers ready yet

	; Far call to our 64-bit code
	mov rax, QWORD higher_half_start
    jmp rax
