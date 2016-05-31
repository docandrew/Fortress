; from osdev.org/Bare_Bones_with_NASM & Phil Opp

global stack_ptr
extern long_mode_start

; Declare constants used for creating a multiboot header.
MBALIGN     equ  1<<0                   ; align loaded modules on page boundaries
MEMINFO     equ  1<<1                   ; provide memory map
FLAGS       equ  MBALIGN | MEMINFO      ; this is the Multiboot 'flag' field
MAGIC       equ  0x1BADB002             ; 'magic number' lets bootloader find the header
CHECKSUM    equ -(MAGIC + FLAGS)        ; checksum of above, to prove we are multiboot
 
; Multiboot header
section .multiboot
MultiBootHeader:
	dd MAGIC
	dd FLAGS
	dd CHECKSUM

; Stack setup (see end for location)
STACKSIZE equ 0x4000

section .text
 
; The linker script specifies _start as the entry point to the kernel and the
; bootloader will jump to this position once the kernel has been loaded. It
; doesn't make sense to return from this function as the bootloader is gone.
global _start

; still 32-bit at this point
bits 32
_start:
 
	; To set up a stack, we simply set the esp register to point to the top of
	; our stack (as it grows downwards).
	mov esp, stack_ptr

	; Before we start running checks, store multiboot header and magic # that was passed from GRUB
	mov edi, eax 		; argument 1 (magic #) to kmain2 in boot64.asm (64-bit calling convention)
	mov esi, ebx 		; arg 2 (multiboot header struct address)

	call check_multiboot
	call check_cpuid
	call check_long_mode

	call setup_page_tables
	call enable_paging

	lgdt [gdt64.pointer]

	; update code, data segment selectors
	mov ax, gdt64.data
	mov ss, ax
	mov ds, ax
	mov es, ax

	; jump to long mode
	jmp gdt64.code:long_mode_start

; error handler
error:
	cli
	mov dword [0xb8000], 0x4f524f45
	mov dword [0xb8004], 0x4f3a4f52
	mov dword [0xb8008], 0x4f204f20
	mov byte [0xb800a], al
.errhang	
	hlt
	jmp .errhang

; check if this kernel was loaded by a multiboot loader (like GRUB2) - it needs to be
check_multiboot:
	cmp eax, 0x2BADB002
	jne .no_multiboot
	ret
.no_multiboot:
	mov al, "0"
	jmp error

; check if CPUID available by flipping ID bit (21)
check_cpuid:
	; copy FLAGS to EAX, copy to ECX
	pushfd
	pop eax
	mov ecx, eax

	; try flipping ID bit & push to FLAGS
	xor eax, 1 << 21
	push eax
	popfd

	; copy FLAGS back to EAX, if bit is flipped then CPUID is supported
	pushfd
	pop eax

	; restore FLAGS from old version stored in ECX
	push ecx
	popfd

	; compare EAX and ECX, if equal then bit wasn't flipped, and CPUID is not supported
	xor eax, ecx
	jz .no_cpuid
	ret
.no_cpuid:
	mov al, "1"
	jmp error

check_long_mode:
	mov eax, 0x80000000			; set EAX to 0x80000000 (CPUID instruction will return maximum CPUID input value in EAX)
	cpuid 						; 
	cmp eax, 0x80000001			; if CPUID returns less than this in eax, then long mode not available
	jb .no_long_mode			;
	mov eax, 0x80000001			; since previous CPUID told us 0x80000001 is a valid query, try it
	cpuid 						; will put proc info in EDX w/ bit 29 set for 64-bit
	test edx, 1 << 29			; bit 29 set?
	jz .no_long_mode			; if no, we're done
	ret
.no_long_mode:
	mov al, "2"
	jmp error

setup_page_tables:
	; map first p4 entry to p3 table
	mov eax, p3_table
	or eax, 11b			; present + writable
	mov [p4_table], eax

	; map first p3 entry to p2 table
	mov eax, p2_table
	or eax, 11b			; present + writable
	mov [p3_table], eax

	; map each p2 entry to a 2MiB page
	mov ecx, 0			; counter var

.map_p2_table:
	; map each ecx-th entry to a page that starts at address 2MiB * ECX (identity-mapped - same virtual/physical addresses)
	mov eax, 0x200000				; 2 MiB
	mul ecx 						; start address of ecx-th page
	or eax, 10000011b				; present + writable + huge (2MiB)
	mov [p2_table + ecx * 8], eax 	; map ecx-th entry	

	inc ecx 						; increase counter
	cmp ecx, 512 					; 512 pages
	jne .map_p2_table				; map the next entry
	ret

enable_paging:
	mov eax, p4_table				; mov p4 table address into CR3
	mov cr3, eax

	; enable PAE (physical address extensions)
	mov eax, cr4
	or eax, 1 << 5
	mov cr4, eax

	; set long mode bit in EFER (extended feature) register
	mov ecx, 0xC0000080
	rdmsr
	or eax, 1 << 8
	wrmsr

	; enable paging in CR0 register
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax
	ret


section .bss
align 4096
p4_table:
	resb 4096
p3_table:
	resb 4096
p2_table:
	resb 4096
p1_table:
	resb 4096
	
stack:
	resb STACKSIZE
stack_ptr:

section .rodata
gdt64:
	dq 0;
.code: equ $ - gdt64
	dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53)	; code segment, 64-bit, present, read/write, executable
.data: equ $ - gdt64
	dq (1<<44) | (1<<47) | (1<<41) 						; data segment, present, read/write
.pointer:
	dw $ - gdt64 - 1
	dq gdt64