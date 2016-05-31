.section .multiboot

#multiboot magic ID number
.set MAGIC,	0xBADB002

#request alignment and memory map
.set FLAGS,	1 | 2

.align 4
.long MAGIC
.long FLAGS
.long -(FLAGS | MAGIC) #Checksum
