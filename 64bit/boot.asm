; Author: Jon Andrew
; with assist/inspiration from osdev.org/Bare_Bones_with_NASM & Phil Opp and others

global bootstrap_stack_bottom32
global bootstrap_stack_top32
global p4_table
global boot_p3_table
global boot_p2_table

extern trampoline

; Declare constants used for creating a multiboot header.
; note that we do not set bit 16 in FLAGS here, so the boot loader will use
; the entry address specified by our linker script.
MBALIGN     equ  0x1                    ; align loaded modules on page boundaries
MEMINFO     equ  0x2                    ; provide memory map
VIDEOMODE   equ  0x4                    ; tell GRUB to set video mode (not used yet)

; Uncomment this line to tell GRUB to use the video mode set in the header
; Will also want to set config.framebufferVideo in config.d
FLAGS       equ  MBALIGN | MEMINFO | VIDEOMODE     ; this is the Multiboot 'flag' field
;FLAGS       equ MBALIGN | MEMINFO       ;

MAGIC       equ  0x1BADB002             ; 'magic number' lets bootloader find the header
CHECKSUM    equ -(MAGIC + FLAGS)        ; checksum of above, to prove we are multiboot
 
; Multiboot header
section .multiboot
MultiBootHeader:
	dd MAGIC
	dd FLAGS
	dd CHECKSUM

; For memory info
    dd 0x0
    dd 0x0
    dd 0x0
    dd 0x0
    dd 0x0

; For setting video mode
    dd 0x0          ; mode type (0-linear, 1-text)
    dd 1024         ; width
    dd 768          ; height
    dd 16           ; bpp depth

; Stack setup (see end for location)
STACKSIZE equ 0x8000

section .text
bootstrap:

; The linker script specifies _start as the entry point to the kernel and the
; bootloader will jump to this position once the kernel has been loaded. It
; doesn't make sense to return from this function as the bootloader is gone.
global _start

; still 32-bit at this point
bits 32
_start:
 
	; To set up a stack, we simply set the esp register to point to the top of
	; our stack (as it grows downwards).
	mov esp, bootstrap_stack_top32

	; Before we start running checks, store multiboot header and magic # that was passed from GRUB
	mov edi, eax 		; argument 1 (magic #) to kmain2 in boot64.asm (64-bit calling convention)
	mov esi, ebx 		; arg 2 (multiboot header struct address)

	call check_multiboot
	call check_cpuid
	call check_long_mode
	call enable_paging

	lgdt [gdt64.pointer]

	; update code, data segment selectors
	mov ax, gdt64.data
	mov ss, ax
	mov ds, ax
	mov es, ax

	; jump to long mode
	; trampoline to 64-bit
	jmp gdt64.code:trampoline

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

enable_paging:
	mov eax, p4_table				; mov p4 table address into CR3
	mov cr3, eax

	; enable PAE, set CR4.PAE (bit 5) = 1
	mov eax, cr4
	or eax, 1 << 5
	mov cr4, eax

	; set long mode bit (8) and NXE (11) in EFER (extended feature) register
	mov ecx, 0xC0000080
	rdmsr
	or eax, 1 << 8
	or eax, 1 << 11
	wrmsr

	; enable paging in CR0 register
	mov eax, cr0
	or eax, 1 << 31
	mov cr0, eax
	ret

; section .rodata
gdt64:
	dq 0;												; 8-byte offset (null) 0x08 offset for code segment
.code: equ $ - gdt64
	dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53)	; code segment, 64-bit, present, read/write, executable
.data: equ $ - gdt64
	dq (1<<44) | (1<<47) | (1<<41)						; data segment, present, read/write
.pointer:
	dw $ - gdt64 - 1
	dq gdt64

; location of our early bootstrap stack
; aligned so it looks pretty
align 4096
stackandpagetables:
bootstrap_stack_bottom32:
	times STACKSIZE db 0
bootstrap_stack_top32:

;p5_table					; future Intel spec (56-bit virtual addresses)

; h/t https://wiki.osdev.org/D_barebone_with_ldc2
; h/t xv6 x86-64 port as well.
; Since the page tables are page-aligned, we can just set each table entry
; to their respective address, since the bottom 12 bits are already 0.
;
; in this bootstrap code, we map all physical memory to both the lower-half
; as well as the higher-half. Later, we'll unmap the lower-half.
;
; We'll use huge (2MiB) pages here to start, then later we will switch
; to a 4k paging system.
;
; This gives us 30-bits of usable addressing while we are using these
; bootstrap page tables. Valid bootstrap addresses:
; 0x0000_0000_0000_0000 - 0x0000_0000_4000_0000
; 0xFFFF_8000_0000_0000 - 0xFFFF_8000_4000_0000
align 4096
p4_table:				        ; PML4E
	dq (boot_p3_table + 0x3)	; p4[0] = p3[0], present | writable
	times 255 dq 0			 
	dq (boot_p3_table + 0x3)	; p4[256] = p3[0], present | writable
	times 254 dq 0

align 4096
boot_p3_table:				    ; PDPE
	dq (boot_p2_table + 0x3)	; p3[0] = p2[0], present | writable
	times 511 dq 0			    ; all other entries non-present

align 4096
boot_p2_table:                  ; PDE, set PDE.PS (bit 7) = 1 for 2MB pages
	%assign i 0
	%rep 512
	dq (i + 0x83)               ; huge, present, writable
	%assign i (i + 0x200000)
	%endrep
;align 4096
;boot_p1_table:				; PD. 512 2MB tables here, identity-mapped first 1GB
;	%rep 512*25
;	dq (i << 12) | 0x03	; TODO: 40 MB is probably overkill 
;	%assign i i+1
;	%endrep