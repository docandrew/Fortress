module PhysMemory;

import multiboot;
import util;
//import List;
import screen;  //for testing
import AssertPanic;

//public alias size_t Frame;

//TODO: put these in Config.d
public enum PAGE_SIZE = 2097152;
public enum FRAME_SIZE = 2097152;				//2^21
public enum FRAME_SHIFT = 21;				//left or right shift to convert between page num and start address

public enum MAX_PHYSICAL_FRAMES = 65536;

public enum FrameStatus
{
	UNUSABLE, FREE, ALLOCATED
}

public __gshared PhysicalMemory physicalMemory;

/**
 * Round up to next page size
 *
 */
size_t roundUp(size_t address, size_t multiple = FRAME_SIZE)
{
	if(multiple == 0){
		return address;
	}

	ulong remainder = address % multiple;
	if(remainder == 0){
		return address;
	}

	return address + multiple - remainder;
}

/**
 * Frame or page of physical memory
 * TODO: add flags
 */
struct Frame
{
	ubyte flags;

	static size_t frameNumber(size_t address)
	{
		return address >> FRAME_SHIFT;
	}

	static size_t startAddress(size_t frameNum)
	{
		return frameNum << FRAME_SHIFT;
	}
}

struct PhysicalMemory
{
	/**
	 * We keep an array of frame nodes for underlying storage
	 * These are linked into the unusedFrameNodes list.
	 * As we find free physical frames, we link those into the
	 * freeFrames list. When we allocate a physical frame, we
	 * unlink it from freeFrames and link it into the usedFrames
	 * list.
	 */
	Frame[MAX_PHYSICAL_FRAMES] frames;
	size_t usableFrames;

	size_t getUsable()
	{
		return usableFrames * PAGE_SIZE;
	}

	//TODO: make a version that accepts a UEFI map.
	void initialize(ref MemoryAreas multibootMemoryMap)
	{ 
		//make all frames unavailable to start
		foreach(i; 0..MAX_PHYSICAL_FRAMES)
		{
			frames[i].flags = FrameStatus.UNUSABLE;
		}
		//kprintfln("flags: %d", frames[0].flags);
		
		foreach(MultibootMemoryMap area; multibootMemoryMap)
		{
			kprintf(" start: %x length: %x type: %d", area.addr, area.length, area.type);
			uint framesInThisArea = 0;

			if(area.type == 1 && area.length >= PAGE_SIZE)
			{
				//Need to align by page size
				size_t start = area.addr;
				size_t end = area.addr + area.length;

				size_t pageStart = roundUp(area.addr);
				size_t pageEnd = pageStart + PAGE_SIZE;

				do
				{
					size_t containingFrame = Frame.frameNumber(pageStart);
					//kprintf(" %x ", containingFrame);
					frames[containingFrame].flags = 1;
					framesInThisArea++;
					pageStart += PAGE_SIZE;
					pageEnd += PAGE_SIZE;
				}while(pageEnd < end);

				usableFrames += framesInThisArea;
			}

			kprintfln(" frames: %d", framesInThisArea);
		}	
	}

	//Return start address of free frame
	size_t allocateFrame()
	{
		//This sucks - need to keep a list for quicker access
		foreach(i; 0..MAX_PHYSICAL_FRAMES)
		{
			if(frames[i].flags == FrameStatus.FREE)
			{
				frames[i].flags = FrameStatus.ALLOCATED;
				return Frame.startAddress(i);
			}
		}
		panic("Out of Memory");
		return 0;
	}

	//Return frame to free list
	void freeFrame(size_t address)
	{
		frames[Frame.frameNumber(address)].flags = FrameStatus.FREE;
	}
}