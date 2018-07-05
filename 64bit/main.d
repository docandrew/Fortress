extern(C) __gshared int getCpuVendor(char* buf);
extern(C) __gshared int getDebug(uint* buf);
extern(C) __gshared ulong kernelStart;
extern(C) __gshared ulong kernelEnd;
extern(C) __gshared ulong stackandpagetables;

//__gshared AreaFrameAllocator frameAllocator;

import assertpanic;
import config;
import screen;
import util;
import cpu;
import cpuio;
import interrupt;
import physmemory;
import virtmemory;
import multiboot;
import elf;
import serial;
import timer;

/**
 * kmain is the main entry point for the Fortress kernel, called from boot64.asm
 * Params:
 *  magic = the magic number (0x2badb002) passed by a multiboot-compliant loader
 *  multibootInfoAddress = pointer to multiboot info structure (see multiboot specification)
 */
extern(C) __gshared void kmain(uint magic, MultibootInfoStruct *multibootInfoAddress)
{
	char[13] cpuidBuffer;
	int cpuidMaxLevel;
	MultibootInfoStruct multibootInfo = *multibootInfoAddress; 		//get copy (could use original?)
	//kprintfln("Multiboot?: %x", magic);
	kassert(magic == 0x2badb002);		//ensure this was loaded by a multiboot-compliant loader

	clearScreen();
	
	static if(config.SerialConsoleMirror)
	{
		COM1.setConfig();
		//COM1.write("test config");
	}

	println("Fortress 64-bit Operating System v0.0.2 BETA\n", 0b00010010);

	kprintfln("Multiboot Struct at: %x, end: %x", cast(size_t)multibootInfoAddress, cast(size_t)multibootInfoAddress + multibootInfo.sizeof);

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
	// if(multibootInfo.flags.isBitSet(2))
	// {
	// 	//print(" command line: ");
	// 	//printlnz(cast(char *)multibootInfo.cmdline);
	// 	kprintfln(" command line: %s", cast(char *)multibootInfo.cmdline);
	// }
	
	//Initialize memory management
	kprintfln("Initializing Memory ");
	MemoryAreas bootMemMap = MemoryAreas(multibootInfo);
	//kprintfln(" memory maps start: %x end: %x", cast(size_t)bootMemMap.mmap, cast(size_t)bootMemMap.mmap + bootMemMap.mmapLength);
	physicalMemory = PhysicalMemory(&bootMemMap, cast(size_t)&kernelStart, cast(size_t)&kernelEnd);
	kprintfln(" Available Memory: %d GB", cast(uint)(physicalMemory.getUsable() / 1_000_000_000));

	//check kernel ELF sections
	static if(config.DebugELF)
	{
		kprintfln("Checking Kernel ELF Sections");
		kassert(multibootInfo.flags.isBitSet(5));
		dumpELF(multibootInfo);
	}

	//Allocate a few frames
	// for(int i = 0; i < 10; i++)
	// {
	// 	physicalMemory.allocateFrame();
	// }
	setupInterrupts();	//needed to handle page faults

	//test VM subsystem
	// size_t addr = 0x0000_0000A_8000_0000; //42 * 512 * 512 * 4096;
	// size_t freshFrame = physicalMemory.allocateFrame();
	// kprintfln("addr: %x, phys: %x map to: %x", addr, virtualToPhysical(addr), freshFrame);
	// mapPage(freshFrame, addr, PAGEFLAGS.present);
	// kprintfln("phys: %x", virtualToPhysical(addr));
	// kprintfln("next free frame: %x", physicalMemory.allocateFrame());

	// //unmap page
	// kprintfln("contents? (mapped): %x", *cast(ulong*)addr);
	// unmap(addr);
	// kprintfln("phys after unmap: %x", virtualToPhysical(addr));
	// kprintfln("contents? (unmapped): %x", *cast(ulong*)addr);

	kprintfln("Initalizing 8253 Timer");
	timer.init();

	//Trigger a page fault for testing
	//int *testFault = cast(int *)0xFFFF_FFFF_FFFF_FF00;
	//*testFault = 45;

	//TODO: eventually turn this into the idle process.
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