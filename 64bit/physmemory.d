module physmemory;

/**
 * PhysMemory is an abstraction of the physical memory present in the 
 * system. Fortress uses the term "Frame" to refer to a page of memory
 * with a physical address.
 *
 *
 */

import config;
import multiboot;
import util;
//import List;
import screen;  //for testing
import assertpanic;

/**
 * physicalMemory is the only allowable instance
 */
public __gshared PhysicalMemory physicalMemory;

/**
 * Frame number containing this address
 */
public size_t frameNumber(size_t address)
{
	return address >> FRAME_SHIFT;
}

/**
 * Start address of this frame number
 */
public size_t startAddress(size_t frameNum)
{
		return frameNum << FRAME_SHIFT;
}

/**
 * PhysicalMemory should be instantiated only once. It manages
 * the available memory in the system for use by Fortress/user
 * code.
 */
public struct PhysicalMemory
{
	//TODO: make these private
	//Frame[MAX_PHYSICAL_FRAMES] frames;
	size_t nextFreeFrame;			//address of next Frame to allocate
	size_t numUsableFrames;			//number of physical frames in memory
	size_t lastAllocatedFrame;		//address of last frame we allocated
	size_t lastUsableFrame;			//address of last usable frame in system

	size_t areaStart;				//frame-aligned address of start of the current area
	size_t areaEnd;					//frame-aligned address of end of the current area

	size_t kernelStart;					//kernel location in memory, can't allocate here
	size_t kernelEnd;
	MemoryAreas *multibootMemoryMap;
	
	size_t getUsable()
	{
		return numUsableFrames * FRAME_SIZE;
	}

	/**
	 * Constructor for Physical Memory struct - 
	 * Params:
	 *  multibootMemoryMap = see multiboot 
	 * TODO: Make a version that accepts a UEFI map.
	 */
	this(MemoryAreas *myMultibootMemoryMap, size_t myKernelStart, size_t myKernelEnd)
	{ 
		bool setupFirstArea = true;
		kernelStart = myKernelStart;
		kernelEnd = myKernelEnd;
		
		multibootMemoryMap = myMultibootMemoryMap;
		//kprintf(" Kstart: %x, Kend: %x", kernelStart, kernelEnd);
		
		foreach(MultibootMemoryMap area; *multibootMemoryMap)
		{
			kprintf(" Memory: %x-%x %S", area.addr, area.addr + area.length - 1, MULTIBOOT_MEM_TYPES[area.type]);
			uint framesInThisArea;

			//determine usable memory frames
			if(area.type == multiboot.MEM_TYPES.AVAILABLE && area.length >= FRAME_SIZE)
			{
				size_t alignedStart = roundUp(area.addr);
				size_t alignedEnd = roundDown(area.addr + area.length);		//TODO: might need to subtract one here. Bug?
				size_t trueLength = alignedEnd - alignedStart;
				framesInThisArea = cast(uint)(trueLength / FRAME_SIZE);

				//if we haven't set up the first memory area yet, do so now.
				if(setupFirstArea)
				{
					nextFreeFrame = alignedStart;
					areaStart = alignedStart;
					areaEnd = alignedEnd;
					setupFirstArea = false;
				}
				
				lastUsableFrame = alignedEnd;								//update this as we iterate through memory areas
				numUsableFrames += framesInThisArea;
				kprintf(" frames: %d", framesInThisArea);
			}
			kprintfln("");
		}
		//multibootMemoryMap.reset();
	}

	/**
	 * allocate returns the address of a free physical frame in memory
	 * 
	 * Implemented using a moving frame pointer
	 */
	size_t allocateFrame()
	{
		//skip physical address 0, since physical and virtual address 0
		// mean "null" or unused in the virtual memory module
		if(nextFreeFrame == 0)
		{
			nextFreeFrame += FRAME_SIZE;
		}

		if(nextFreeFrame >= areaEnd)
		{
			nextFreeFrame = updateFreeArea();
		}

		//Don't allocate in the middle of our kernel!
		if(nextFreeFrame >= kernelStart && nextFreeFrame <= kernelEnd)
		{
			kprintfln("Attempted allocation in kernel, skipping");
			nextFreeFrame = roundUp(kernelEnd);

			//since we advanced it to the end of the kernel, need to make
			// sure we are still in a good memory area
			if(nextFreeFrame >= areaEnd)
			{
				nextFreeFrame = updateFreeArea();
			}
		}
	
		static if(config.DebugFrameAlloc)
		{
			kprintfln("Alloc Frame: %x", nextFreeFrame);
		}

		size_t retFrame = nextFreeFrame;
		lastAllocatedFrame = retFrame;
		nextFreeFrame += FRAME_SIZE;
		return retFrame;
	}

	/**
	 * updateFreeArea returns a frame-aligned address of the next 
	 * area of free memory as indicated by the Multiboot memory map
	 */
	size_t updateFreeArea()
	{
		//find next area of available memory 
		multibootMemoryMap.reset();
		foreach(MultibootMemoryMap area; *multibootMemoryMap)
		{
			if(area.addr > nextFreeFrame && area.type == multiboot.MEM_TYPES.AVAILABLE && area.length >= FRAME_SIZE)
			{
				areaStart = roundUp(area.addr);
				areaEnd = roundDown(area.addr + area.length);
				
				static if(config.DebugFrameAlloc)
				{
					kprintfln(" Allocator advanced to area: %x", areaStart);
				}
				
				return areaStart;
			}
		}

		panic("Out of Memory");
		return 0;					//never reached
	}

	/**
	 * free returns a frame to the free list
	 * not implemented currently, just leaks memory
	 */
	void freeFrame(size_t physicalAddress)
	{
		kprintfln(" freeFrame %x", physicalAddress);
		// frames[Frame.frameNumber(address)].flags = FrameStatus.FREE;
		// lastAllocatedFrame = Frame.frameNumber(address);
	}
}