/* The bootloader will look at this image and start execution at the symbol
   designated as the entry point. */
OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)
KERNEL_PHYS = 0x00100000;
KERNEL_VIRT = 0xFFFF800000000000;

/* Tell where the various sections of the object files will be put in the final
   kernel image. */
SECTIONS
{
	. = KERNEL_PHYS;

	.bootstrap : {
		KEEP(*(.multiboot))				/* keep multiboot header at beginning of file */
		build/boot.o (.multiboot .text)
		build/trampoline.o (.text)		/* need an elf64 object in low memory that we can use for a 64-bit jump */
	}

	. += KERNEL_VIRT;					/*link kernel at higher half. Use += here so virt -> phys mapping
										  doesn't smash our bootstrap stack & page tables */

	.text ALIGN(4K) : AT(ADDR(.text) - KERNEL_VIRT){
		*(EXCLUDE_FILE(*build/boot.o) .text)
		*(EXCLUDE_FILE(*build/trampoline.o) .text)
		*(.text .text.*)
	}

	.rodata ALIGN(4K) : AT(ADDR(.rodata) - KERNEL_VIRT){
		*(.rodata .rodata.*)
	}

	.data ALIGN(4K) : AT(ADDR(.data) - KERNEL_VIRT){
		*(.data .data.*)
	}

	.bss ALIGN(4K) : AT(ADDR(.bss) - KERNEL_VIRT){
		sbss = .;
		*(COMMON)
		*(.bss .bss.*)
		ebss = .;
	}
	KERNEL_END_VIRT = .;									/* exports */				
	KERNEL_START_VIRT = KERNEL_PHYS + KERNEL_VIRT;
}