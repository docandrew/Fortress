all:
	yasm --arch=x86 -f elf64 boot.asm -o build/boot.o	
	yasm --arch=x86 -f elf64 boot64.asm -o build/boot64.o
	yasm --arch=x86 -f elf64 cpuid.asm -o build/cpuid.o
	yasm --arch=x86 -f elf64 isr.asm -o build/isr.o
	dmd -betterC -v -c -g -m64 -od=./build assertpanic.d main.d cpu.d cpuio.d elf.d util.d interrupt.d keyboard.d multiboot.d process.d physmemory.d virtmemory.d screen.d serial.d timer.d -noboundscheck -release
#	gcc -m64 -omy_kernel cpuid.o cpu.o util.o multiboot.o screen.o main.o boot.o -T linker.ld -nostdlib
#	
#	strip out D runtime & typeinfo stuff until -betterC does it
#	 h/t  theartofmachinery.com/2016/12/18/d_without_runtime.html
#	objcopy -R '.data.*[0-9]TypeInfo_*' -R '.[cd]tors.*' -R .text.d_dso_init -R minfo -R .eh_frame -R deh -R .data.DW.ref.__dmd_personality_v0 --strip-unneeded multiboot.o
#	objcopy -R '.data.*[0-9]TypeInfo_*' -R '.[cd]tors.*' -R .text.d_dso_init -R minfo -R .eh_frame -R deh -R .data.DW.ref.__dmd_personality_v0 -R _d_dso_registry --strip-unneeded cpu.o	
#	objcopy -R '.data.*[0-9]TypeInfo_*' -R '.[cd]tors.*' -R .text.d_dso_init -R minfo -R .eh_frame -R deh -R .data.DW.ref.__dmd_personality_v0 -R _d_dso_registry --strip-unneeded memory.o
#	objcopy -R '.data.*[0-9]TypeInfo_*' -R '.[cd]tors.*' -R .text.d_dso_init -R minfo -R .eh_frame -R deh -R .data.DW.ref.__dmd_personality_v0 -R _d_dso_registry --strip-unneeded interrupt.o
#	objcopy -R '.data.*[0-9]TypeInfo_*' -R '.[cd]tors.*' -R .text.d_dso_init -R minfo -R .eh_frame -R deh -R .data.DW.ref.__dmd_personality_v0 -R _d_dso_registry --strip-unneeded keyboard.o

#	ld -n -o my_kernel -T linker.ld assertpanic.o cpuid.o cpu.o cpuio.o elf.o interrupt.o isr.o keyboard.o process.o physmemory.o virtmemory.o util.o multiboot.o screen.o timer.o main.o boot.o boot64.o
	ld -n -o my_kernel -T linker.ld build/*.o

clean:
	rm build/*.o
	rm isodir/boot/my_kernel
	rm my_kernel
	rm my_kernel.iso

run-raw:
	qemu-system-x86_64 -kernel my_kernel

run:
	qemu-system-x86_64 -s -m 4G -cdrom my_kernel.iso -serial stdio

iso:
	cp my_kernel isodir/boot/
	grub-mkrescue -o my_kernel.iso isodir
