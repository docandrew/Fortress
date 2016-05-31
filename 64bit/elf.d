module elf;

/*
ELF object files contain:
file header
section table
program header table
contents of sections or segments, including loadable data, relocations, string and symbol tables

Elf64_Addr 8 8 Unsigned program address
Elf64_Off 8 8 Unsigned file offset
Elf64_Half 2 2 Unsigned medium integer
Elf64_Word 4 4 Unsigned integer
Elf64_Sword 4 4 Signed integer
Elf64_Xword 8 8 Unsigned long integer
Elf64_Sxword 8 8 Signed long integer
unsigned char 1 1 Unsigned small integer

*/

/*
 *  FILE HEADER
 */

enum ELFID
{
	MAG0 = 0,		//file identification (should contain '\x7F', 'E', 'L', 'F')
	MAG1 = 1,
	MAG2 = 2,
	MAG3 = 3,
	CLASS = 4,		//file class
	DATA = 5,		//data encoding
	VERSION = 6,	//file version
	OSABI = 7,		//OS / ABI identification
	ABIVERSION = 8,	//ABI version
	PAD = 9,		//start of padding bytes
	NIDENT = 16	//size of e_ident;
}

//object file classes
enum ELFCLASS32 = 1;
enum ELFCLASS64 = 2;

//data encodings
enum ELFDATA2LSB = 1;
enum ELFDATA2MSB = 2;

//OS & ABI identifiers
enum ELFOSABI_SYSV = 0;
enum ELFOSABI_HPUX = 1;
enum ELFOSABI_STANDALONE = 255;

//object file types
enum ET_NONE = 0;			//no file type
enum ET_REL = 1;			//relocatable object file
enum ET_EXEC = 2;			//executable file
enum ET_DYN = 3;			//shared object file
enum ET_CORE = 4;			//core file
enum ET_LOOS = 0xFE00;		//environment-specific use
enum ET_HIOS = 0xFEFF;		
enum ET_LOPROC = 0xFF00;	//processor-specific use
enum ET_HIPROC = 0xFFFF;	

struct ELFFileHeader
{
	align(1):					//packed

	char[16] 	e_ident;		//ELF identification, use as e_ident[EI.MAG0], etc.
	ushort 		e_type;			//object file type
	ushort 		e_machine;		//machine type
	uint 		e_version;		//object file version
	ulong 		e_entry;		//entry point address
	ulong		e_phoff;		//program header offset
	ulong		e_shoff;		//section header offset
	uint		e_flags;		//processor specific flags
	ushort		e_ehsize;		//ELF header size
	ushort		e_phentsize;	//size of program header entry
	ushort		e_phnum;		//number of program header entries
	ushort		e_shentsize;	//size of section header entry
	ushort		e_shnum;		//number of section header entries
	ushort		e_shstrndx;		//section name string table index
}

/*
 * SECTION HEADER
 */

//Section Header Numbers
 enum SHN_UNDEF = 0;		//mark an undefined or meaningless section reference
 enum SHN_LOPROC = 0xFF00;	//processor-specific use
 enum SHN_HIPROC = 0xFF1F;	
 enum SHN_LOOS = 0xFF20;	//environment-specific use
 enum SHN_HIOS = 0xFF3F;	
 enum SHN_ABS = 0xFFF1;		//corresponding reference is an absolute value
 enum SHN_COMMON = 0xFFF2;	//indicates a symbol declared as a common block (Fortran COMMON or C tentative declaration)

//Section Types
enum SHT_NULL = 0;				//mark a section header as inactive. Rest of header undefined
enum SHUT_PROGBITS = 1;			//holds information solely defined by program
enum SHT_SYMTAB = 2;			//holds symbol table
enum SHT_STRTAB = 3;			//holds a string table
enum SHT_RELA = 4;				//holds relocation entries with explicit addends (such as ELF32_Rela)
enum SHT_HASH = 5;				//holds a symbol hash table
enum SHT_DYNAMIC = 6;			//holds information for dynamic linking
enum SHT_NOTE = 7;				//holds information that marks the file somehow
enum SHT_NOBITS = 8;			//section occupies no space in file but otherwise resembles SHT_PROGBITS
enum SHT_REL = 	9;				//holds relocation entries without explicit addends (such as ELF32_Rel)
enum SHT_SHLIB = 10;			//reserved but unspecified semantics
enum SHT_DYNSYM = 11;			//holds a symbol table
enum SHT_LOPROC = 0x70000000;	//reserved for processor-specific semantics
enum SHT_HIPROC = 0x7FFFFFFF;	
enum SHT_LOUSER = 0x80000000;	//specifies lower bound of range of indexes reserved for application programs
enum SHT_HIUSER = 0x8FFFFFFF;	//specifies upper bound of range of indexes reserved for application programs

// ELF64 Section Header will be 64-bytes in size (0x40)
// Section header table is array of these structures
 struct ELF64SectionHeader
 {
 	align(1):				//packed

	uint 	sh_name; 		/* Section name (offset in bytes to section name string table)*/
	uint 	sh_type; 		/* Section type */
	ulong 	sh_flags;		/* Section attributes */
	ulong	sh_addr; 		/* Virtual address in memory (technically a size_t, not ulong)*/
	ulong	sh_offset; 		/* Offset in file */
	ulong 	sh_size; 		/* Size of section */
	uint 	sh_link; 		/* Link to other section */
	uint 	sh_info; 		/* Miscellaneous information */
	ulong 	sh_addralign; 	/* Address alignment boundary */
	ulong 	sh_entsize; 	/* Size of entries, if section has table */
 }