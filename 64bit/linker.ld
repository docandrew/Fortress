/* The bootloader will look at this image and start execution at the symbol
   designated as the entry point. */
ENTRY(_start)

/* Tell where the various sections of the object files will be put in the final
   kernel image. */
SECTIONS
{
	. = 0x00100000;					/*load kernel at 0x0010000*/
	
	kernelstart = .;				/*exports the "kernelstart" symbol so we can use it in our D code*/

	.multiboot : {
		*(.multiboot)
	}

	.text : {
		*(.text .text.*)
	}

	.rodata : {
		*(.rodata .rodata.*)
	}

	.data : {						/*this is to combine all the D typeinfo stuff in one ELF section*/
		*(.data .data.*)
	}

	stackandpagetables = .;			/*exports the "stackandpagetables" symbol*/
	.bss : {
		sbss = .;
		*(COMMON)
		*(.bss)
		ebss = .;
	}
	kernelend = .;					/*exports the "kernelend" symbol*/
}