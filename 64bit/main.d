extern(C) __gshared int getCpuVendor(char* buf);
extern(C) __gshared int getDebug(uint* buf);

/**
 * Addresses exported by linker.ld
 */
extern(C) __gshared size_t KERNEL_START_VIRT;		//from linker.ld
extern(C) __gshared size_t KERNEL_END_VIRT;

/**
 * Bootstrap stack boundaries set in boot64.asm
 */
extern(C) __gshared size_t bootstrapStackTop;
extern(C) __gshared size_t bootstrapStackBottom;

// background image
//extern immutable ubyte[] fortressBG;

// __gshared size_t kernelStartVirt;
// __gshared size_t kernelEndVirt;
// __gshared size_t kernelStartPhys;
// __gshared size_t kernelEndPhys;

//__gshared AreaFrameAllocator frameAllocator;

import assertpanic;
import config;
import screen;
import util;
import cpu;
import cpuio;
import interrupt;
import BootstrapFrameAllocator;
import virtmemory;
import multiboot;
import elf;
import serial;
import timer;
import video;

// fancy background image for linear framebuffer mode
import fortress_bg;

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
	kassert(magic == elf.MULTIBOOT_MAGIC);		//ensure this was loaded by a multiboot-compliant loader

	clearScreen();
	
	static if(config.SerialConsoleMirror)
	{
		COM1.setConfig();
	}

	println("Fortress 64-bit Operating System v0.0.2 BETA\n", 0b00010010);

	kprintfln("Multiboot Struct at: %x, end: %x", cast(size_t)multibootInfoAddress, 
                                                  cast(size_t)multibootInfoAddress + multibootInfo.sizeof);

	size_t kernelStartVirt = cast(size_t)&KERNEL_START_VIRT;
	size_t kernelEndVirt = cast(size_t)&KERNEL_END_VIRT;
	size_t kernelStartPhys = kernelStartVirt - KERNEL_BASE;
	size_t kernelEndPhys = kernelEndVirt - KERNEL_BASE;
    //size_t bootstrapStackTop = bootstrap_stack_top;
    //size_t bootstrapStackBottom = bootstrap_stack_bottom;

	kprintfln("Virtual kernel area: %x - %x", kernelStartVirt, kernelEndVirt);
	kprintfln("Physical kernel area: %x - %x", kernelStartPhys, kernelEndPhys);
    kprintfln("Bootstrap Stack: %x - %x", bootstrapStackBottom, bootstrapStackTop);
	kprintfln("Detecting System Capabilities...");

	//TODO: make getCpuVendor use 64-bit calling conventions
	cpuidMaxLevel = getCpuVendor(cast(char *)cpuidBuffer);
	kprintf("CPU Vendor: ");
	printz(cast(char *)cpuidBuffer, 0b010);
	kprintfln(" Max CPUID level: %d", cpuidMaxLevel);

	printSupportedExtensions(cpuidMaxLevel);
	println("Multiboot Info: ");

	if(multibootInfo.flags.isBitSet(0))
	{
		print(" lower mem: "); 
        print(multibootInfo.mem_lower); 
        print(" kb, upper mem: "); 
        print(multibootInfo.mem_upper); println(" kb");
	}

	//identify boot device
	if(multibootInfo.flags.isBitSet(1))
	{
		kprintfln(" boot device: %x", multibootInfo.boot_device);
	}

    if(multibootInfo.flags.isBitSet(11))
    {
        kprintfln("VESA available:");
        kprintfln(" Control info: %x", multibootInfo.vbe_control_info);
        kprintfln(" Mode info: %x", multibootInfo.vbe_mode_info);
        kprintfln(" Current mode: %d", multibootInfo.vbe_mode);
    }

    if(multibootInfo.flags.isBitSet(12))
    {
        kprintfln("Framebuffer available:");
        kprintfln(" FB Address: %x", multibootInfo.framebuffer_addr);
        kprintfln(" FB Width: %d", multibootInfo.framebuffer_width);
        kprintfln(" FB Height: %d", multibootInfo.framebuffer_height);
        kprintfln(" FB Type: %d", multibootInfo.framebuffer_type);
        kprintfln(" FB Bpp: %d", multibootInfo.framebuffer_bpp);
        kprintfln(" FB Pitch: %d", multibootInfo.framebuffer_pitch);
    }
	
	//Initialize memory management.
	kprintfln("Initializing Memory ");
	MemoryAreas bootMemMap = MemoryAreas(multibootInfo);
	BootstrapFrameAllocator.init(&bootMemMap, kernelStartPhys, kernelEndPhys);
	kprintfln(" Available Memory: %d GB", cast(uint)(BootstrapFrameAllocator.getUsable() / 1_000_000_000));

	//check kernel ELF sections
    static if(config.DebugELF)
    {
        ELFObject kernelObj = ELFObject(&multibootInfo.ELFsec);
        kernelObj.dumpELF();
    }

	setupInterrupts();						//needed to handle page faults

	AddressSpace mySpace = AddressSpace(virtmemory.getPML4());
    //testVMM(&mySpace);

	kprintfln("Initalizing 8253 Timer");
	timer.init();
    kprintfln("Timer initialized.");

    static if(config.framebufferVideo)
    {
        size_t lfbAddr = video.init(mySpace, multibootInfo);
        if(lfbAddr != 0)
        {
            uint w = multibootInfo.framebuffer_width;
            uint h = multibootInfo.framebuffer_height;
            switch(multibootInfo.framebuffer_bpp)
            {
                case 8:
                    video.drawTestPattern!(ubyte)(cast(ubyte *)lfbAddr, w, h);
                    break;
                case 16:
                    //video.drawTestPattern!(ushort)(cast(ushort *)lfbAddr, w, h);
                    foreach(i; 0..(w*h*(multibootInfo.framebuffer_bpp/8)))
                    {
                        (cast(ubyte *)lfbAddr)[i] = fortressBG[i];
                    }
                    //video.clear!(ushort)(cast(ushort *)lfbAddr, w, h, 0x2B12);
                    video.renderString!(ushort)(cast(ushort *)lfbAddr, 
                        "Fortress 64-bit Operating System v0.0.2 BETA", 0,0,w,h,0xFFFF,0x0000);
                    break;
                default:
                    // 24-bpp won't really work with this setup, so need to come up with a different way.
                    break;
            }
        }
        else
        {
            kprintfln(" Unable to map linear framebuffer.");
            // default to text mode?
        }
    }

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
    //try unmapping a huge page
    // int *myint1 = cast(int*)0xFFFF_8000_3000_0000;
    // int *myint2 = cast(int*)0x0000_0000_3000_0000;
    // *myint1 = 742;
    // kprintf("Should be able to read: %d", *myint1);
    // mySpace.unmap(0x0000_0000_3000_0000);
    //kprintf("page fault: %d", *myint2);

	//test VM subsystem
	size_t addr = 0x0000_0000A_8000_0000; //42 * 512 * 512 * 4096;
	size_t freshFrame = BootstrapFrameAllocator.allocateFrame();
	size_t *ttt = cast(size_t*)freshFrame;
	*ttt = 0xCAFEBABE;
    kprintfln("addr: %x, mapping to: %x", addr, freshFrame);
	//kprintfln("addr: %x, phys: %x map to: %x", addr, activePageTable.virtToPhys(addr), freshFrame);
	activePageTable.mapPage(freshFrame, addr, PAGEFLAGS.present);
	kprintfln("phys: %x", activePageTable.virtToPhys(addr));
	kprintfln("as phys addr %x: %x", freshFrame, cast(ulong)*ttt);
	kprintfln("as virt addr %x: %x", addr, cast(ulong)*(cast(size_t*)addr));
	kprintfln("next free frame: %x", BootstrapFrameAllocator.allocateFrame());

	// //unmap page
	kprintfln("contents? (mapped): %x", *cast(ulong*)addr);
	activePageTable.unmap(addr);
	kprintfln("phys after unmap: %x", activePageTable.virtToPhys(addr));

	//for an intentional page fault:
    //kprintfln("contents? (unmapped): %x", *cast(ulong*)addr);
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