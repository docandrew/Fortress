module multiboot;

import assertpanic;
import util;

//Multiboot Boot information struct (defined here for ELF)
// See: https://www.gnu.org/software/grub/manual/multiboot/multiboot.html

// Copyright (C) 1999,2003,2007,2008,2009  Free Software Foundation, Inc.
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to
//deal in the Software without restriction, including without limitation the
//rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//sell copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.

//enum MultibootSearch 		= 8192;				//bytes from start of file where header should be located
//enum MultibootHeaderMagic 	= 0x1BADB002;		//contained in boot.asm
//enum MultibootLoaderMagic 	= 0x2BADB002;		//expected in EAX if this kernel was loaded by multiboot loader
//enum MultibootUnsupported 	= 0x0000FFFC;		//bits in flags field we don't support
//enum MultibootModAlign 		= 0x00001000;		//alignment of multiboot modules
//enum MultibootInfoAlign		= 0x00000004;		//alignment of multiboot info structure

//Flags set in multiboot header (unused here, would be in boot.asm)
//enum MultibootPageAlign		= 0x00000001;		//align all boot modules on i386 (4Kb) page boundaries
//enum MultibootMemoryInfo	= 0x00000002;		//must pass memory info to OS
//enum MultibootVideoMode		= 0x00000004;		//must pass video info to OS
//enum MultibootAoutKludge	= 0x00010000;		//indicates use of address fields in the header

public enum MEM_TYPES
{
	UNKNOWN = 0,
	AVAILABLE = 1,
	UNUSABLE = 2,
	ACPI = 3,
	RESERVED = 4,
	DEFECTIVE = 5
}
public __gshared string[6] MULTIBOOT_MEM_TYPES = ["?", "available", "unusable", "ACPI info", "reserved", "defective"];

//Flags set in 'flags' member of MultibootInfoDef
enum MultibootInfoFlags : uint
{
	Memory				= 1 << 0,		//is there basic upper/lower memory info?
	BootDevice			= 1 << 1,		//is there a boot device set?
	CmdLine				= 1 << 2,		//is a command line defined?
	Modules				= 1 << 3,		//are there modules available?

	//next two flags are mutually exclusive
	AoutSyms			= 1 << 4,		//is there a symbol table loaded?
	ELFSectionHeader	= 1 << 5,		//is there an ELF section header?

	MemoryMap			= 1 << 6,		//is there a full memory map?
	DriveTable			= 1 << 7,		//is there drive info?
	ConfigTable			= 1 << 8,		//is there a config table?
	BootLoaderName		= 1 << 9,		//is there a boot loader name?
	APMTable 			= 1 << 10,		//is there an APM table?
	VideoInfo			= 1 << 11,		//is there VBE info?
	FrameBufferInfo		= 1 << 12		//is there FrameBuffer info?
}


// 32-bit addressing
// NOTE: all fields are 32-bit addresses.
// A pointer to this structure will be loaded in EBX by Multiboot/GRUB
struct MultibootInfoStruct
{
	align(1):					//packed
								//BYTE  
	uint flags;					// 0 bitfield describing which of following fields are present
	uint mem_lower;				// 4 amount of lower memory
	uint mem_upper;				// 8 amount of upper memory
	//byte[4] boot_device;		//12 partition numbers
	uint boot_device;			//12 partition numbers
	uint cmdline;				//16 pointer to command-line to be passed to kernel (stringz)
	uint mods_count;			//20 number of kernel modules
	uint mods_addr;				//24 pointer to kernel modules
	ELFSectionHeader ELFsec;	//28-40 ELF Section Headers
	//uint num;					//28 ELF-specific. The next 4 symbols are really "syms"
	//uint size;					//32 ELF-specific
	//uint addr;					//36 ELF-specific
	//uint shndx;					//40 ELF-specific. String table used as index of names.
	uint mmap_length;			//44 length of buffer containing memory map
	uint mmap_addr;				//48 pointer to memory map buffer
	uint drives_length;			//52 length of buffer containing drive info
	uint drives_addr;			//56 pointer to drive info buffer
	uint config_table;			//60 pointer to ROM config table returned by BIOS GET CONFIG call
	uint boot_loader_name;		//64 pointer to stringz containing boot loader info
	uint apm_table;				//68 pointer to APM (advanced power management) table
	uint vbe_control_info;		//72 Video info
	uint vbe_mode_info;			//76 Video info
	ushort vbe_mode;			//80 Video info
	ushort vbe_interface_seg;	//82 Video info
	ushort vbe_interface_off;	//84 Video info
	ushort vbe_interface_len;	//86 Video info
}

//Boot modules for kernel
struct KernelModule
{
	align(1):					//packed
							//BYTE
	uint mod_start;			// 0 start address of kernel module
	uint mod_end;			// 4 end address of kernel module
	uint string;			// 8 pointer to null-term string description of kernel module
	uint reserved;			//12 expected value = 0
}

//Section header table for ELF
struct ELFSectionHeader
{
	align(1):					//packed
							//BYTE
	uint num;				// 0 number of entries
	uint size;				// 4 size of each entry
	uint addr;				// 8 address of entry
	uint shndx;				//12 string table used as index of names
}

//Memory-map given by BIOS to Multiboot
struct MultibootMemoryMap
{
	align(1):					//packed
							//BYTE
	uint size;				//-4 size of this structure, used to skip to next region
	ulong addr;				// 0 base address of memory region
	ulong length;			// 8 length of memory region in bytes
	uint type;				//16 value of 1 indicates available RAM, otherwise reserved
}

//Structure describing a drive
struct Drive
{
	align(1):					//packed
							//BYTE
	uint size;				// 0 size of this structure, depends on number of ports
	uint drive_number;		// 4 BIOS drive number
	byte drive_mode;		// 5 access mode: 0 if CHS, 1 if LBA
	ushort drive_cylinders;	// 6 # of cylinders
	ubyte drive_heads;		// 8 # of heads
	ubyte drive_sectors;	// 9 # of sectors per track
	ushort* drive_ports;	//10- array of unsigned two-byte numbers containing I/O 
							//   ports for the drive, terminated with 0
}

//APM BIOS Interface Struct
// See: https://www.gnu.org/software/grub/manual/multiboot/multiboot.html#Boot-information-format
struct APMTable
{
	align(1):					//packed
	ushort apmversion;
	ushort cseg;
	ushort offset;
	ushort cseg_16;
	ushort dseg;
	ushort flags;
	ushort cseg_len;
	ushort cseg_16_len;
	ushort dseg_len;
}


//public __gshared MultiBootInfoDef MultiBootInfo;

/**
 * Using memory map from GRUB or other Multiboot loader, 
 * this provides an iterator over the usable physical 
 * memory areas. 
 */
struct MemoryAreas
{
	MultibootMemoryMap *mmap;				//address of the Multiboot Memory Map struct
	uint mmapLength;						//length of this entire memory map
	MultibootMemoryMap *currentArea;

	this(ref MultibootInfoStruct multibootInfo)
	{	
		//ensure GRUB passed us a memory map
		kassert(multibootInfo.flags.isBitSet(6));
		
		//print(" mmap address: "); print(multibootInfo.mmap_addr); 
		//print(" mmap length: "); println(multibootInfo.mmap_length);

		mmap = cast(MultibootMemoryMap *)multibootInfo.mmap_addr;
		mmapLength = cast(MultibootMemoryMap *)multibootInfo.mmap_length;
		currentArea = mmap;
	}

	@property MultibootMemoryMap front()
	{
		return *currentArea;
	}

	@property MultibootMemoryMap popFront()
	{
		MultibootMemoryMap ret = *currentArea;
		currentArea = cast(MultibootMemoryMap *)(cast(ulong)currentArea + currentArea.size + currentArea.size.sizeof);
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

	void reset()
	{
		currentArea = mmap;
	}
}