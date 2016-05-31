all:
	yasm --arch=x86 -f elf64 boot.asm -o boot.o	
	yasm --arch=x86 -f elf64 boot64.asm -o boot64.o
	yasm --arch=x86 -f elf64 cpuid.asm -o cpuid.o
	dmd -v -c -m64 main.d object.d cpu.d util.d multiboot.d screen.d runtime/typeinfo/ti_uint.d -defaultlib= -noboundscheck -release
	#gcc -m64 -omy_kernel cpuid.o cpu.o util.o multiboot.o screen.o main.o object.o ti_uint.o boot.o -T linker.ld -nostdlib
	ld -n -o my_kernel -T linker.ld cpuid.o cpu.o util.o multiboot.o screen.o main.o object.o ti_uint.o boot.o boot64.o

clean:
	rm *.o
	rm my_kernel
	rm my_kernel.iso

run-raw:
	qemu-system-x86_64 -kernel my_kernel

run:
	qemu-system-x86_64 -m 5G -cdrom my_kernel.iso

iso:
	cp my_kernel isodir/boot/
	grub-mkrescue -o my_kernel.iso isodir
