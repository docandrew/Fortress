BITS 64

section .text
global getCpuVendor
global getDebug

; int getCpuVendor(char * buf)
getCpuVendor:
	; save registers
	push rbp
	mov rbp, rsp
	sub rsp, 0x10

	;with eax = 0, cpuid returns vendor string in ebx, edx, ecx
	xor eax, eax				; zero out eax for cpuid
	cpuid

	;put vendor string into destination buffer
	; eax will contain the max input value for CPUID info
	mov [rdi], ebx
	mov [rdi+4], edx
	mov [rdi+8], ecx
	mov BYTE [rdi+0xc], 0x0		; null terminate string

	leave
	ret 	;return from func

; TODO: combine w/ getCpuFeatures function, load data into some sort of struct

; TODO: convert to 64-bit calling convention
;getDebug:
;	push ebp
;	mov ebp, esp
;	mov eax, DWORD [ebp+0x8];

;	;put register data in destination buffer
;	push ebx					; save ebx since we are about to put the EIP in it
;	call getEIP					; EIP will be pushed on stack, copied to EBX in getEIP
;	mov [eax], ebx				; put EIP in first return
;	pop ebx						; get our ebx back;

;	mov [eax+4], ebp
;	mov [eax+8], esp
;	mov [eax+0x0c], eax
;	mov [eax+0x10], ebx
;	mov [eax+0x14], ecx
;	mov [eax+0x18], edx
;	pushfd						; push EFLAGS on stack
;	pop edx 					; pop EFLAGS back to edx
;	mov [eax+0x1c], edx
;	mov [eax+0x20], edi
;	mov [eax+0x24], esi;

;	xor eax, eax 				; zero out result
;	pop ebp 					; C calling convention
;	ret 						; return from function;

;getEIP:
;	mov ebx, [esp]
;	ret
	