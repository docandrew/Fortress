extern(C) __gshared int getCpuVendor(char* buf);
extern(C) __gshared int getDebug(uint* buf);
extern(C) __gshared ulong kernelStart;
extern(C) __gshared ulong kernelEnd;
extern(C) __gshared ulong stackandpagetables;

__gshared AreaFrameAllocator frameAllocator;

import screen;
import util;
import cpu;
import cpuio;
import interrupt;
import memory;
import multiboot;
import elf;

extern(C) __gshared void kmain(uint magic, ulong multibootInfoAddress)
{
	char[13] cpuidBuffer;
	int cpuidMaxLevel;
	MultibootInfoStruct multibootInfo = * cast(MultibootInfoStruct *)multibootInfoAddress; //get copy

	clearScreen();

	println("Fortress 64-bit Operating System v0.0.2 BETA\n", 0b00010010);
	
	//kprintfln("Multiboot?: %x", magic);
	kassert(magic == 0x2badb002);		//ensure this was loaded by a multiboot-compliant loader

	kprintfln("Multiboot Struct at: %x, end: %x", cast(size_t)multibootInfoAddress, cast(size_t)multibootInfoAddress + multibootInfo.sizeof);

	//TODO: check for this first before making copy of data at multibootInfoAddress

	print("Kernel area: ");
	print(cast(ulong)&kernelStart);
	print(" - ");
	println(cast(ulong)&kernelEnd);
	println("Detecting System Capabilities...");

	print("Stack and Page Tables: ");
	println(cast(ulong)&stackandpagetables);

	//TODO: make getCpuVendor use 64-bit calling conventions
	cpuidMaxLevel = getCpuVendor(cast(char *)cpuidBuffer);
	print("CPU Vendor: ");
	printz(cast(char *)cpuidBuffer, 0b010);
	kprintfln(" Max CPUID level: %d", cpuidMaxLevel);

	//printSupportedExtensions(cpuidMaxLevel);
	//printDebugInfo();
	println("Multiboot Info: ");
	//print(" flags: ");
	//println(multibootInfo.flags);

	//check memory. per multiboot manual: "Lower memory starts at address 0, and upper memory starts at 
	//address 1 megabyte. The maximum possible value for lower memory is 640 kilobytes. The value returned 
	//for upper memory is maximally the address of the first upper memory hole minus 1 megabyte. It is not 
	//guaranteed to be this value."
	if(multibootInfo.flags.isBitSet(0))
	{
		print(" lower mem: "); print(multibootInfo.mem_lower); print(" kb, upper mem: "); print(multibootInfo.mem_upper); println(" kb");
	}
	//identify boot device
	if(multibootInfo.flags.isBitSet(1))
	{
		kprintfln(" boot device: %x", multibootInfo.boot_device);
		//foreach(int i; 0 .. 4)
		//{
		//	print(cast(uint)multibootInfo.boot_device[i]);
		//	print("/");
		//}
	}

	//TODO: check modules
	//if(multibootInfo.flags.isBitSet(2))
	//{
	//	//print(" command line: ");
	//	//printlnz(cast(char *)multibootInfo.cmdline);
	//	kprintfln(" command line: %s", cast(char *)multibootInfo.cmdline);
	//}
	
	//Print memory info
	//frameAllocator = AreaFrameAllocator(multibootInfo);
	MemoryAreas mem = MemoryAreas(multibootInfo);
	kprintfln(" memory maps start: %x end: %x", cast(size_t)mem.mmap, cast(size_t)mem.mmap + mem.mmapLength);
	//foreach(MultibootMemoryMap area; mem)
	//{
	//	//kprintfln(" start: %x length: %x type: %d", area.addr, area.length, area.type);
	//}

	//check kernel ELF sections
	kassert(multibootInfo.flags.isBitSet(5));
	
	ELFSectionHeader *elfsec = &multibootInfo.ELFsec;
	char *stringTable;

	kprintfln(" ELF sections: %d, section size: %d, address: %x, str table idx: %d", elfsec.num, elfsec.size, elfsec.addr, elfsec.shndx);
		
	ELF64SectionHeader *sechdr;

	//find section header string table:
	if(elfsec.num > 0 && elfsec.shndx != SHN_UNDEF)
	{
		sechdr = cast(ELF64SectionHeader *)(elfsec.addr + (elfsec.shndx * elfsec.size));	//find string table section
		stringTable = cast(char *)sechdr.sh_addr;											//find string table itself
	}

	//kprintfln(" ELF section %d, type: %d, size: %d, offset: %x", elfsec.shndx, sechdr.sh_type, cast(uint)sechdr.sh_size, cast(uint)sechdr.sh_offset);
	//kprintfln(" addr of string table: %x: string table: ", cast(ulong)stringTable);
	//printchars(stringTable + 11, 72);

	//iterate through section headers
	foreach(i; 0 .. elfsec.num)
	{
		sechdr = cast(ELF64SectionHeader *)(elfsec.addr + (i * elfsec.size));
		kprintfln(" #%d, addr: %x, type: %d, size: %x, name: %s", i, sechdr.sh_addr, sechdr.sh_type, cast(uint)sechdr.sh_size, stringTable + sechdr.sh_name);
	}

	AreaFrameAllocator frameAllocator = AreaFrameAllocator(mem, kernelStart, kernelEnd, 
														cast(size_t)multibootInfoAddress, cast(size_t)multibootInfoAddress + multibootInfo.sizeof, 
														cast(size_t)mem.mmap, cast(size_t)mem.mmap + mem.mmapLength, 
														cast(size_t)elfsec.addr, cast(size_t)elfsec.addr + (elfsec.num * elfsec.size));



	setupInterrupts();

	while(true)
	{
		//TODO: implement a sleep timer or something
		asm
		{
			hlt;
		}
	}
}

void printSupportedExtensions(int cpuidMaxLevel)
{
	print("Supported Extensions: ");
	foreach(i; 0 .. 31)
	{
		if(cpuidMaxLevel.isBitSet(i))
		{
			print(cpu.cpuFeatures[i],0b1001);
			print(" ");
		}
	}
	println("");
}

void printDebugInfo()
{
	uint[10] registers;
	string[10] regnames = ["eip","ebp","esp","eax","ebx","ecx","edx","efl","edi","esi"];
	
	println("Debug Info: ");
	//getDebugTest2(cast(uint *)registers);
	//getDebug(cast(uint *)registers);
	
	foreach(i; 0 .. 10)
	{
		print(regnames[i]);
		print(": ");
		printz(cast(char *)intToStringz(registers[i]));
		print(" ");

		if(i % 2 != 0)
		{
			println("");
		}
	}
}