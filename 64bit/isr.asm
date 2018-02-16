bits 64

extern isr 					; isr() in interrupt.d
extern irq 					; irq() in interrupt.d

global isr0
global isr1
global isr2
global isr3
global isr4
global isr5
global isr6
global isr7
global isr8
global isr9
global isr10
global isr11
global isr12
global isr13
global isr14
global isr15
global isr16
global isr17
global isr18
global isr19
global isr20
global isr21
global isr22
global isr23
global isr24
global isr25
global isr26
global isr27
global isr28
global isr29
global isr30
global isr31

global isr128				; 0x80 is used for Linux syscalls, might as well duplicate that here

global irq0;
global irq1;
global irq2;
global irq3;
global irq4;
global irq5;
global irq6;
global irq7;
global irq8;
global irq9;
global irq10;
global irq11;
global irq12;
global irq13;
global irq14;
global irq15;

;
; PROCESSOR EXCEPTIONS
;

; divide by 0
isr0:
	cli
	push long 0				; dummy error code
	push long 0				; number of interrupt
	jmp isrCommon

; debug exception
isr1:
	cli
	push long 0
	push long 1
	jmp isrCommon

; NMI
isr2:
	cli
	push long 0
	push long 2
	jmp isrCommon

; breakpoint
isr3:
	cli
	push long 0
	push long 3
	jmp isrCommon

; into detected overflow
isr4:
	cli
	push long 0
	push long 4
	jmp isrCommon

; out of bounds
isr5:
	cli
	push long 0
	push long 5
	jmp isrCommon

; invalid opcode
isr6:
	cli
	push long 0
	push long 6
	jmp isrCommon

; no co-processor
isr7:
	cli
	push long 0
	push long 7
	jmp isrCommon

; double fault
isr8:
	cli
	; returns error code
	push long 3
	jmp isrCommon

; coprocessor segment overrun
isr9:
	cli
	push long 0
	push long 9
	jmp isrCommon

; bad TSS exception
isr10:
	cli
	; returns error code
	push long 10
	jmp isrCommon

; segment not present
isr11:
	cli
	; returns error code
	push long 11
	jmp isrCommon

; stack fault
isr12:
	cli
	; returns error code
	push long 12
	jmp isrCommon

; GPF exception
isr13:
	cli
	; returns error code
	push long 13
	jmp isrCommon

; page fault
isr14:
	cli
	; returns error code
	push long 14
	jmp isrCommon

; unknown interrupt
isr15:
	cli
	push long 0
	push long 15
	jmp isrCommon

; coprocessor fault
isr16:
	cli
	push long 0
	push long 16
	jmp isrCommon

; alignment check exception
isr17:
	cli
	push long 0
	push long 17
	jmp isrCommon

; machine check exception
isr18:
	cli
	push long 0
	push long 18
	jmp isrCommon

; Interrupts 19-31: reserved
isr19:
	cli
	push long 0
	push long 19
	jmp isrCommon

isr20:
	cli
	push long 0
	push long 20
	jmp isrCommon

isr21:
	cli
	push long 0
	push long 21
	jmp isrCommon

isr22:
	cli
	push long 0
	push long 22
	jmp isrCommon

isr23:
	cli
	push long 0
	push long 23
	jmp isrCommon

isr24:
	cli
	push long 0
	push long 24
	jmp isrCommon

isr25:
	cli
	push long 0
	push long 25
	jmp isrCommon

isr26:
	cli
	push long 0
	push long 26
	jmp isrCommon

isr27:
	cli
	push long 0
	push long 27
	jmp isrCommon

isr28:
	cli
	push long 0
	push long 28
	jmp isrCommon

isr29:
	cli
	push long 0
	push long 29
	jmp isrCommon

isr30:
	cli
	push long 0
	push long 30
	jmp isrCommon

isr31:
	cli
	push long 0
	push long 31
	jmp isrCommon

;
; HARDWARE IRQs
;
irq0:
	cli
	push long 0
	push long 32
	jmp irqCommon

irq1:
	cli
	push long 0
	push long 33
	jmp irqCommon

irq2:
	cli
	push long 0
	push long 34
	jmp irqCommon

irq3:
	cli
	push long 0
	push long 35
	jmp irqCommon

irq4:
	cli
	push long 0
	push long 36
	jmp irqCommon

irq5:
	cli
	push long 0
	push long 37
	jmp irqCommon

irq6:
	cli
	push long 0
	push long 38
	jmp irqCommon

irq7:
	cli
	push long 0
	push long 39
	jmp irqCommon

irq8:
	cli
	push long 0
	push long 40
	jmp irqCommon

irq9:
	cli
	push long 0
	push long 41
	jmp irqCommon

irq10:
	cli
	push long 0
	push long 42
	jmp irqCommon

irq11:
	cli
	push long 0
	push long 43
	jmp irqCommon

irq12:
	cli
	push long 0
	push long 44
	jmp irqCommon

irq13:
	cli
	push long 0
	push long 45
	jmp irqCommon

irq14:
	cli
	push long 0
	push long 46
	jmp irqCommon

irq15:
	cli
	push long 0
	push long 47
	jmp irqCommon

;
; KERNEL DEFINED INTERRUPTS, SYSCALLS
;

isr128:
	cli
	push long 0
	push long 0x80
	jmp isrCommon

isrCommon:
	pop rdi 				; first argument to isr(), interrupt number
	pop rsi 				; second argument to isr(), error code (if CPU sets one)
	
	push rdi
	push rsi
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	; compiler preserves rbx, rbp, r12-r15
	; TODO: use FS for thread-local storage
	; TODO: save xmm registers
	push rax
	mov rax, isr 			; call isr() in interrupt.d
	call rax				; call isr()
	pop rax
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	pop rsi
	pop rdi

	iretq

irqCommon:
	pop rdi
	pop rsi

	push rdi
	push rsi
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	; compiler preserves rbx, rbp, r12-r15
	; TODO: use FS for thread-local storage
	; TODO: save xmm registers
	push rax
	mov rax, irq 			; call irq() in interrupt.d
	call rax				; call irq()
	pop rax
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	pop rsi
	pop rdi

	iretq	