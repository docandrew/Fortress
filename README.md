# Fortress
Experimental 64-bit Operating System written in D

For X86-64

Uses ELF object files, expects Multiboot.

This doesn't do much yet, but has some code for formatted printing, etc. which does not rely on the GC that others may find useful. Also, the Multiboot header parsing code took a lot of work, particularly the ELF section parsing.

Ultimate goal is to have a simple multi-threaded OS that forces strict application, user and geographic-level restrictions on resource access.

Build using DMD, Linux.

Runs using QEmu, typically through Makefile (I know, I know...)

To build:
>make

To generate .iso (which could be used to burn a bootable CD-R or USB stick):
>make iso

Note that the above command relies on grub-mkrescue, which needs mtools and xorriso installed or it will silently fail to produce the .iso.
"make iso" also needs the grub-pc-bin package installed to work correctly.

To launch QEmu w/ appropriate arguments for aforementioned .iso:
>make run

Or to just run off the kernel binary:
>make run-raw
