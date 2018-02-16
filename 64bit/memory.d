module memory;

import multiboot;
import util;
import screen;  //for testing

/**
 * MemoryArea is just an alias for MultibootMemoryMap for readability
 * see multiboot.d for details.
 */
public alias MultibootMemoryMap MemoryArea;

public alias size_t Frame;

public enum PAGE_SIZE = 4096;
public enum PHYSICAL_MEMORY_BITS = 48;

static size_t physicalPageContainingAddress(size_t address)
{
	size_t retFrame = Frame(address / PAGE_SIZE);
	return retFrame;
}

/**
 * Get memory map from GRUB, this provides an iterator over the usable physical memory areas, defined in multiboot module.
 * 
 */
struct MemoryAreas
{
	MultibootMemoryMap *mmap;				//address of the Multiboot Memory Map struct
	uint mmapLength;						//length of this entire memory map
	MemoryArea *currentArea;

	this(ref MultibootInfoStruct multibootInfo)
	{	
		//ensure GRUB passed us a memory map
		kassert(multibootInfo.flags.isBitSet(6));
		
		//print(" mmap address: "); print(multibootInfo.mmap_addr); print(" mmap length: "); println(multibootInfo.mmap_length);

		mmap = cast(MemoryArea *)multibootInfo.mmap_addr;
		mmapLength = cast(MemoryArea *)multibootInfo.mmap_length;
		currentArea = mmap;
	}

	@property MemoryArea front()
	{
		return *currentArea;
	}

	@property MemoryArea popFront()
	{
		MemoryArea ret = *currentArea;
		currentArea = cast(MemoryArea *)(cast(ulong)currentArea + currentArea.size + currentArea.size.sizeof);
		return ret;
	}

	@property bool empty()
	{
		if(cast(ulong)currentArea < cast(ulong)mmap + mmapLength){
			return false;
		}
		
		//reset to beginning in case next person wants to iterate over list.
		currentArea = mmap;	
		return true;
	}
}

/**
 * physical memory allocator, allocates 4KiB frames
 */
static struct AreaFrameAllocator
{
	//48-bit addressable space
	ulong[] pageBitmap;

	MemoryAreas areas;
	MemoryArea currentArea;

	Frame nextFreeFrame;

	//keep track of which frames are in use so we don't allocate over them
	Frame kernelStart;
	Frame kernelEnd;
	Frame multibootStart;
	Frame multibootEnd;
	Frame memMapStart;
	Frame memMapEnd;
	Frame elfStart;
	Frame elfEnd;

	this(MemoryAreas areas_, size_t kernelStart_, size_t kernelEnd_, size_t multibootStart_, size_t multibootEnd_, size_t memMapStart_, size_t memMapEnd_, size_t elfStart_, size_t elfEnd_)
	{
		areas = areas_;
		currentArea = areas.popFront();

		kernelStart = frameContainingAddress(kernelStart_);
		kernelEnd = frameContainingAddress(kernelEnd_);
		multibootStart = frameContainingAddress(multibootStart_);
		multibootEnd = frameContainingAddress(multibootEnd_);
		memMapStart = frameContainingAddress(memMapStart_);
		memMapEnd = frameContainingAddress(memMapEnd_);
		elfStart = frameContainingAddress(elfStart_);
		elfEnd = frameContainingAddress(elfEnd_);
	}

	bool isFrameOccupied(Frame myFrame)
	{

	}

	/**
	 * allocateFrame() - finds free 4KiB memory frame and returns it
	 * Returns: number of free frame
	 * Panics if no frame available
	 *
     * TODO: make bitmap or stack with available frames.
     * Iterate through memory map, push frames as we go, check against 
     * 
	 */
	size_t allocateFrame()
	{
		//get last frame of current area
		size_t areaEndAddress = currentArea.addr + currentArea.length - 1;

		Frame currentAreaLastFrame = frameContainingAddress(areaEndAddress);
		Frame frame = nextFreeFrame;

		//make sure we aren't at the end of this memory area
		if(frame > currentAreaLastFrame){
			kassert(!areas.empty());
		
			currentArea = areas.popFront();							//jump to next memory area
			areaEndAddress = currentArea.addr + currentArea.length - 1		//try frame from this new memory area
		}

		//now ensure this next frame isn't one of our occupied areas.
		// if it is, 
		if(frame >= kernelStart && frame <= kernelEnd) {
			frame = kernelEnd + 1;
		}
		if(frame >= multibootStart && frame <= multibootEnd) {
			nextFreeFrame = multibootEnd.number + 1;
		}
		if(frame >= memMapStart && frame <= memMapEnd) {
			nextFreeFrame = memMapEnd.number + 1;
		}
		if(frame >= elfStart && frame <= elfEnd) {
			nextFreeFrame = elfEnd.number + 1;
		}
		
		nextFreeFrame.number += 1;
	}

	bool deallocateFrame(Frame dframe)
	{
		return false;
	}
}