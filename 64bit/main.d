extern(C) __gshared int getCpuVendor(char* buf);
extern(C) __gshared int getDebug(uint* buf);

extern(C) __gshared ulong KERNEL_START_VIRT;		//from linker.ld
extern(C) __gshared ulong KERNEL_END_VIRT;			//from linker.ld

enum KERNEL_VIRT = 0xFFFF_8000_0000_0000;			//start of higher-half

__gshared size_t kernelStartVirt;
__gshared size_t kernelEndVirt;
__gshared size_t kernelStartPhys;
__gshared size_t kernelEndPhys;

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
	MultibootInfoStruct multibootInfo = *multibootInfoAddress; 		//get copy (TODO: unmap original)
	//kprintfln("Multiboot?: %x", magic);
	kassert(magic == 0x2badb002);		//ensure this was loaded by a multiboot-compliant loader

	clearScreen();
	
	static if(config.SerialConsoleMirror)
	{
		COM1.setConfig();
	}

	println("Fortress 64-bit Operating System v0.0.2 BETA\n", 0b00010010);

	kprintfln("Multiboot Struct at: %x, end: %x", cast(size_t)multibootInfoAddress, cast(size_t)multibootInfoAddress + multibootInfo.sizeof);

	kernelStartVirt = cast(size_t)&KERNEL_START_VIRT;
	kernelEndVirt = cast(size_t)&KERNEL_END_VIRT;
	kernelStartPhys = kernelStartVirt - KERNEL_VIRT;
	kernelEndPhys = kernelEndVirt - KERNEL_VIRT;
	kprintfln("Virtual kernel area: %x - %x", kernelStartVirt, kernelEndVirt);
	kprintfln("Physical kernel area: %x - %x", kernelStartPhys, kernelEndPhys);
	kprintfln("Detecting System Capabilities...");
	//kprintfln("Stack and Page Tables: %x", cast(size_t)&stackandpagetables);

	//TODO: make getCpuVendor use 64-bit calling conventions
	cpuidMaxLevel = getCpuVendor(cast(char *)cpuidBuffer);
	kprintf("CPU Vendor: ");
	printz(cast(char *)cpuidBuffer, 0b010);
	kprintfln(" Max CPUID level: %d", cpuidMaxLevel);

	//printSupportedExtensions(cpuidMaxLevel);
	println("Multiboot Info: ");

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
	physicalMemory = PhysicalMemory(&bootMemMap, kernelStartPhys, kernelEndPhys);
	kprintfln(" Available Memory: %d GB", cast(uint)(physicalMemory.getUsable() / 1_000_000_000));

	//check kernel ELF sections
	ELFObject kernelObj = ELFObject(&multibootInfo.ELFsec);
	kernelObj.dumpELF();

	setupInterrupts();						//needed to handle page faults

	AddressSpace mySpace = AddressSpace(virtmemory.getPML4Phys());
	testVMM(&mySpace);

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

void testVMM(AddressSpace *activePageTable)
{
	//test VM subsystem
	size_t addr = 0x0000_0000A_8000_0000; //42 * 512 * 512 * 4096;
	size_t freshFrame = physicalMemory.allocateFrame();
	size_t *ttt = cast(size_t*)0x1000;
	*ttt = 0xCAFEBABE;
	kprintfln("addr: %x, phys: %x map to: %x", addr, activePageTable.virtualToPhysical(addr), freshFrame);
	activePageTable.mapPage(freshFrame, addr, PAGEFLAGS.present);
	kprintfln("phys: %x", activePageTable.virtualToPhysical(addr));
	kprintfln("as phys: %x", cast(ulong)*ttt);
	kprintfln("as virt: %x", cast(ulong)*(cast(size_t*)addr));
	kprintfln("next free frame: %x", physicalMemory.allocateFrame());

	// //unmap page
	kprintfln("contents? (mapped): %x", *cast(ulong*)addr);
	activePageTable.unmap(addr);
	kprintfln("phys after unmap: %x", activePageTable.virtualToPhysical(addr));
	kprintfln("contents? (unmapped): %x", *cast(ulong*)addr);
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