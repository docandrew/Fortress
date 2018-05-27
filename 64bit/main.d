extern(C) __gshared int getCpuVendor(char* buf);
extern(C) __gshared int getDebug(uint* buf);
extern(C) __gshared ulong kernelStart;
extern(C) __gshared ulong kernelEnd;
extern(C) __gshared ulong stackandpagetables;

//__gshared AreaFrameAllocator frameAllocator;

import AssertPanic;
import Config;
import screen;
import util;
import cpu;
import cpuio;
import interrupt;
import PhysMemory;
import multiboot;
import elf;
import Timer;

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
	
	//Initialize memory management
	MemoryAreas bootMemMap = MemoryAreas(multibootInfo);
	kprintfln("Initializing Memory ");
	kprintfln(" memory maps start: %x end: %x", cast(size_t)bootMemMap.mmap, cast(size_t)bootMemMap.mmap + bootMemMap.mmapLength);
	physicalMemory.initialize(bootMemMap);
	kprintfln(" Available Memory: %x", physicalMemory.getUsable());

	//check kernel ELF sections
	static if(Config.DebugELF)
	{
		kprintfln("Checking Kernel ELF Sections");
		kassert(multibootInfo.flags.isBitSet(5));
		dumpELF(multibootInfo);
	}

	setupInterrupts();
	kprintfln("Initalizing 8253 Timer");
	Timer.init();

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