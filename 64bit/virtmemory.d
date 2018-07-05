module virtmemory;

extern(C) __gshared void invalidatePage(size_t addr);	//work-around for inline asm invlpg not working w/ 64-bit

import util;
import assertpanic;
import screen;
import physmemory;
//import std.typecons;		//for BitFlags

/**
 * h/t Phil Opp https://os.phil-opp.com for recursive page table assistance
 */

public enum PAGE_SIZE = 4096;

public enum NUM_PAGE_TABLE_ENTRIES = 512;

/**
 * Flags for Page Table Entries
 * 
 */
public enum PAGEFLAGS : ulong
{
	empty = 0,
	unused = 0,
	present = 1 << 0,
	writable = 1 << 1,
	user = 1 << 2,
	writeThrough = 1 << 3,
	cacheDisabled = 1 << 4,
	accessed = 1 << 5,
	dirty = 1 << 6,
	huge = 1 << 7,
	global = 1 << 8,
	NXE = cast(ulong)1 << 63,
}

//TODO: create some more default settings here
// immutable PTEFlags PTEUnused;													//default no flags set (unused PTE)
immutable ulong KERNELDATA = PAGEFLAGS.writable | PAGEFLAGS.NXE;
immutable ulong KERNELCODE = PAGEFLAGS.writable;
immutable ulong USERDATA = PAGEFLAGS.writable | PAGEFLAGS.user | PAGEFLAGS.NXE;
immutable ulong USERCODE = PAGEFLAGS.writable | PAGEFLAGS.user;

//public alias size_t VirtualAddress;

alias PML4 = PageTable!(4);
alias PDP = PageTable!(3);
alias PD = PageTable!(2);
alias PT = PageTable!(1);
alias P4 = PML4;
alias P3 = PDP;
alias P2 = PD;
alias P1 = PT;

/**
 * getP4Index returns the index into the 
 * Page-Map Level 4 table (p4) that points to the
 * Page Directory Pointer Table
 */
size_t getP4Index(size_t virtualAddress)
{
	return (virtualAddress >> 39) & 0x1FF;
}

/**
 * getP3Index returns the index into the 
 * Page Directory Pointer Table (p3) that 
 * points to the Page Directory
 */
size_t getP3Index(size_t virtualAddress)
{
	return (virtualAddress >> 30) & 0x1FF;
}

/**
 * getP2Index returns the index into the 
 * Page Directory (p2) that points to the
 * Page Table
 */
size_t getP2Index(size_t virtualAddress)
{
	return (virtualAddress >> 21) & 0x1FF;
}

/**
 * getP1Index returns the index into the 
 * page table (p1) that points to the
 * physical frame base address
 */
size_t getP1Index(size_t virtualAddress)
{
	return (virtualAddress >> FRAME_SHIFT) & 0x1FF;
}

/**
 * getOffset returns the offset into the page pointed
 * to by this virtual address (lower 12 bits)
 */
size_t getOffset(size_t virtualAddress)
{
	return virtualAddress & 0x0000_0000_0000_0FFF;
}

/**
 * virtualToPhysical takes a virtual address and returns
 * the corresponding physical address
 */
public size_t virtualToPhysical(size_t virtualAddress)
{
	//walk page tables
	//First make sure this is a valid address (sign-extended 48-bit virtual address)
	kassert(virtualAddress < 0x0000_8000_0000_0000 || virtualAddress > 0xFFFF_8000_0000_0000);

	//get indices to each page table from virtual address
	//only 9 bits are used for each index (2^9 = 512)
	//12 bits are used as offset into the page (2^12 = 4096)
	size_t p4index = virtualAddress.getP4Index;
	size_t p3index = virtualAddress.getP3Index;
	size_t p2index = virtualAddress.getP2Index;
	size_t p1index = virtualAddress.getP1Index;
	
	size_t offset = virtualAddress.getOffset;

	P3 *p3 = getPML4.getNextTable(p4index);
	if(p3 == null) return 0; //kassert(false);
	
	P2 *p2 = p3.getNextTable(p3index);
	if(p2 == null) return 0; //kassert(false);

	P1 *p1 = p2.getNextTable(p2index);
	if(p1 == null) return 0; //kassert(false);

	PageTableEntry *pte = (*p1)[p1index];

	if(pte != null)
	{
		return pte.getAddress << FRAME_SHIFT & offset;
	}
	else
	{
		return 0;
	}
}

/**
 * map allocates a physical frame and maps it into the virtual address
 * space indicated. Will mark page as present.
 *
 * Params:
 *  virtualAddress - must be page aligned
 *  flags - see PAGEFLAGS enum
 *
 * Returns true if successful, false otherwise
 */
 public bool map(size_t virtualAddress, ulong flags)
 {
	 if(virtualAddress % PAGE_SIZE != 0)
	 {
		 return false;
	 }

	 return mapPage(physicalMemory.allocateFrame(), virtualAddress, flags | PAGEFLAGS.present);
 }

/**
 * mapPage maps a frame of physical memory into the virtual address space
 * pointed to by the current page table. Does not automatically mark page
 * as present unless PAGEFLAGS.present is passed as one of the flags.
 * 
 * Params:
 *  physicalAddress
 *  virtualAddress
 *  flags
 * 
 * Returns: true if mapping was successful.
 *
 */
public bool mapPage(size_t physicalAddress, size_t virtualAddress, ulong flags)
{
	if(physicalAddress % 4096 != 0 || virtualAddress % 4096 != 0)
	{
		return false;
	}

	//TODO: consider convenience functions for getting P3, P2, P1
	// in PageTable struct
	P1 *p1 = getPML4.createNextTable(virtualAddress.getP4Index)
					.createNextTable(virtualAddress.getP3Index)
					.createNextTable(virtualAddress.getP2Index);

	if((*p1)[virtualAddress.getP1Index].isZero())
	{
		p1.tableEntries[virtualAddress.getP1Index] = cast(PageTableEntry)(physicalAddress >> FRAME_SHIFT | flags);
		return true;
	}
	else
	{
		return false;
	}
}

/**
 * unmap removes page-table entry for this
 * virtual -> physical mapping.
 *
 * It only removes the PTE (P1) entry.
 */
public bool unmap(size_t virtualAddress)
{
	//TODO: Consider just checking for page-alignment
	virtualAddress = roundDown(virtualAddress);
	kprintfln("unmapping virtual address: %x", virtualAddress);

	P1 *p1 = getPML4.getNextTable(virtualAddress.getP4Index)
					.getNextTable(virtualAddress.getP3Index)
					.getNextTable(virtualAddress.getP2Index);	//walk page tables to find PTE
	
	if(p1 == null)	//p1 not present for huge pages
	{
		return false;
	}

	size_t physAddr = (*p1)[virtualAddress.getP1Index].physAddr << FRAME_SHIFT;	//get physical frame address from PTE
																				//(frame address rounded to boundary)
	(*p1)[virtualAddress.getP1Index].zeroize();									//clear entry
	physicalMemory.freeFrame(physAddr);											//return frame to free list

	//void *va = cast(void*)&virtualAddress;
	//invalidate TLB entry.
	invalidatePage(virtualAddress);

	return true;
}

public size_t physicalToVirtual(size_t physicalAddress)
{
	//walk page tables
	return 0;
}

/**
* getPML4 returns the address of the recursively-mapped
* PML4 page directory
*/
public PML4* getPML4()
{
	return cast(PML4*)0xFFFF_FFFF_FFFF_F000;
}

//Each table has 512 entries of 64-bits each (x64)
struct PageTable(int level) if (level > 0 && level <= 4)
{
	
	PageTableEntry[NUM_PAGE_TABLE_ENTRIES] tableEntries;

	/**
	 * opIndex(N) returns a pointer to the Nth page table entry
	 * for this particular table
	 */
	PageTableEntry *opIndex(size_t a)
	{
		return &(tableEntries[a]);
	}

	/**
	 * zeroize all page table entries in this table
	 */
	public void zeroize()
	{
		foreach(PageTableEntry entry; tableEntries)
		{
			entry.zeroize();
		}
	}

	/**
	 * getNextTable returns the address of the next level of table
	 * i.e. if called on PML4E, will return PDPE
	 * PDPE->PDE
	 * PDE->PTE
	 * 
	 * This template is only instantiated if Page Table Level > 1,
	 * so calling getNextTable() on a PTE will fail at compile time.
	 */
	static if(level > 1)
	{
		auto getNextTable(size_t index)
		{
			kassert(index < 512);	//might not be necessary, depending on caller, index should be only 9 bits wide

			if(this[index].present && !this[index].huge)
			{
				//for recursive mapping
				return cast(PageTable!(level-1)*)((cast(size_t)&this << 9) | (index << FRAME_SHIFT));
			}
			else
			{
				return null;
			}
	 	}
	}

	/**
	 * createNextTable returns the address of the next level of table
	 * or, if one doesn't exist, it will create it. This allocates
	 * memory using PhysicalMemory.allocateFrame() and makes the new
	 * PageTableEntry point to it.
	 */
	static if(level > 1)
	{
		auto createNextTable(size_t index)
		{
			kassert(index < 512);

			if(getNextTable(index) == null)						//next level doesn't exist, allocate new one
			{
				size_t newTableAddr = physicalMemory.allocateFrame();
				PageTableEntry newPTE;
				newPTE.physAddr = newTableAddr >> FRAME_SHIFT;
				newPTE.present = true;
				newPTE.writable = true;
				tableEntries[index] = newPTE;
				return cast(PageTable!(level-1)*)newTableAddr;
			}
			else
			{
				return getNextTable(index);
			}
		}
	}
}

/**
 * PageTableEntry is a single entry in the page tables.
 * On x86_64, it is a 64-bit long value with fields
 * indicating the type of page and what physical address
 * it points to.
 */
struct PageTableEntry
{
	import std.bitmanip;

	//huge field must be 0 in P1 and P4
	mixin(bitfields!(
		bool, "present", 		1,
		bool, "writable", 		1,
		bool, "user",	 		1,
		bool, "writeThrough", 	1,
		bool, "cacheDisabled", 	1,
		bool, "accessed", 		1,
		bool, "dirty", 			1,
		bool, "huge", 			1,
		bool, "global", 		1,
		ubyte, "fortPageA", 	3,
		ulong, "physAddr",	 	40,
		ubyte, "fortPageB",		11,
		bool, "NXE",			1));

	/**
	 * getAddress() returns the base address stored in this page table entry
	 *
	 * Note that this does no error checking for whether the page is present
	 * or not.
	 */
	public size_t getAddress()
	{
		return physAddr << FRAME_SHIFT;
	}

	/**
	 * zeroize resets all fields of this page table entry to 0,
	 * essentially marking it as unused.
	 */
	public void zeroize()
	{
		this = cast(PageTableEntry)0;
	}

	/**
	 * isZero indicates if this entry is all zeros (unused)
	 */
	public bool isZero()
	{
		return this == cast(PageTableEntry)0;
	}
}

public void pageFaultHandler(ulong err)
{
	size_t faultAddress;
	bool present;
	bool rw;
	bool supervisor;
	bool nx;

	present = err.isBitSet(0);			//If set, protection violation. If not set, caused by a non-present page
	rw = err.isBitSet(1);				//write caused the fault if set, read if not set
	supervisor = err.isBitSet(2);		//fault occurred in user mode if set
	nx = err.isBitSet(3);				//instruction fetch in No-Execute page if set

	//When we get a page fault, the CR2 register has
	// the address that caused the exception
	asm
	{
		mov RAX, CR2;
		mov faultAddress[RBP], RAX;
	}

	kprintfln(" Address: %x page fault.", faultAddress);
	
	if(!present)
	{
		kprintfln(" Page not present.");
		//page not present in memory
		//check swap file
	}
	//TODO: find out why fault occurred
	panic(" Kernel Page Fault. Terminating.");
	return;
}