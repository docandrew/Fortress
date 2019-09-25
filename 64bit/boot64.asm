
; This code is linked in the upper half of memory
bits 64

; exported so trampoline.asm can jump here
global higher_half_start

; from main.d
extern kmain
extern bootstrapStackBottom
extern bootstrapStackTop

; from boot.asm
extern bootstrap_stack_top32
extern bootstrap_stack_bottom32   

KERNEL_BASE equ 0xFFFF800000000000

section .text
higher_half_start:
	; update stack pointer to upper-half virt memory (still mapped to previous phys location)
	mov rsp, qword (bootstrap_stack_top32 + KERNEL_BASE)

    ; there were some issues with linker relocations between the 32-bit boot.asm and 64-bit main.d
    ; so we use this code as a go-between to get the stack location in main.d
    mov rax, qword bootstrapStackTop                        ; put addr of bootstrap_stack_top in rax
    mov qword [rax], rsp                                    ; copy rsp (pointing to top of stack) to bootstrap_stack_top
    
    push rdi                                                ; save rdi
    mov rax, qword bootstrapStackBottom                     ; put addr of bootstrap_stack_bottom in rax
    mov rdi, qword (bootstrap_stack_bottom32 + KERNEL_BASE) ; calculate address for bottom of stack in higher-half
    mov qword [rax], rdi                                    ; copy it to bootstrap_stack_bottom
    pop rdi                                                 ; restore rdi

	; call into D code
	mov rax, qword kmain
	call rax
.hang:
	hlt
	jmp .hang
