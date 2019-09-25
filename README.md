# Fortress
Experimental 64-bit Operating System written in D

For x86-64

This doesn't do much yet, but has some code for formatted printing, etc. which 
does not rely on the GC that others may find useful. This is just for fun...
for now!

My ultimate goal is to have a simple multi-threaded OS that forces strict 
application, user and geographic-level restrictions on resource access. Instead
of a discretionary access control model based on multiple users, my objective
for Fortress is to instead control what particular applications are allowed to
do (like AppArmor).

Latest Changes
--------------
Added code to use a linear framebuffer, so we are into the 20th century now
with cool 1024x768x16 graphics!

Reworked memory map, got rid of recursive page mapping.

Kernel boots into higher-half.

Serial output works, and is useful for debugging when using the framebuffer
instead of text output. For VirtualBox, you can enable the serial port and
change port mode to "Raw File", so all of Fortress' text output goes to that
file for later analysis.

Build Requirements
------------------
Fortress is built on Linux (WSL in Windows also works). It needs a fairly 
recent version of DMD (at least since `-betterC` was introduced). You'll also 
require yasm on Linux and GNU binutils for the ld linker.

Build Instructions
------------------
    >make

To generate .iso (which could be used to burn a bootable CD-R or USB stick):

    >make iso

Note that the above command relies on **grub-mkrescue**, which needs 
**mtools** and 
**xorriso** installed or 
it will silently fail to produce the .iso. "make iso" also needs the 
**grub-pc-bin** package installed to work correctly.

To launch QEMU w/ appropriate arguments for aforementioned .iso:

    >make run

Or to just run off the kernel binary:

    >make run-raw

It runs in VirtualBox as well, when booting from the .iso.

Contributor Notes
-----------------
This is written in D using the -betterC flag to prevent use of garbage
collection, but there are some other gotchas in addition to the 

D symbols referenced in .asm files needs to be `extern(C) __gshared`

The extern(C) is so that the name is not mangled. gshared is required
because thread-local storage (TLS) is not functional in the early
stages of loading the kernel. The -vtls flag is passed to DMD as an
extra sanity check, forgetting gshared on a global can be very
frustrating to debug!

A lot of debug statements are wrapped in static if() blocks, check
config.d for compile-time flags that can be set for additional
debugging information.

Instead of the Intel/AMD convention of PML4E, PDPT, PDT, PD, I
call the page tables by `P4`, `P3`, `P2` and `P1` throughout
the code.

Operation
---------
Entry point to kernel is boot.asm, which then calls code in 
trampoline.asm to jump to the kernel in higher-half memory in 
boot64.asm. This calls kmain in main.d, and we're in D
code from this point on with some minor jaunts into asm for some 
help setting up interrupts, invalidating pages, reloading CR3 with
a new page table, etc.

Memory Map
----------
Multiboot struct saved at:
0xFFFF_8000_0001_0000

Kernel Lives at:
0xFFFF_8000_0010_0000

Linear Framebuffer (Kernel Base + wherever GRUB puts it):
0xFFFF_8000_E000_0000

From here is TBD! Next steps include working out memory allocation,
userspace and filesystem.
