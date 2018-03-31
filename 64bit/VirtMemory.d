module VirtMemory;

import util;
import AssertPanic;
import screen;

public size_t virtualToPhysical(size_t virtualAddress)
{
	//walk page tables
	return 0;
}

public size_t physicalToVirtual(size_t physicalAddress)
{
	//walk page tables
	return 0;
}

public void pageFaultHandler(ulong err)
{
	size_t faultAddress;
	bool present;
	bool rw;
	bool supervisor;

	present = err.isBitSet(0);
	rw = err.isBitSet(1);
	supervisor = err.isBitSet(2);

	//When we get a page fault, the CR2 register has
	// the address that caused the exception
	asm
	{
		//TODO: fix this compiler bug that thinks CR2 is only 32-bits
		mov RAX, CR2;
		mov faultAddress[RBP], RAX;
	}

	kprintf(" Address: %x ", faultAddress);
	panic(" Page Fault.");
	if(!rw && !present)
	{
		//page not present in memory
		//check swap file
	}
}