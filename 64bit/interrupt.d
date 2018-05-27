module interrupt;

//TODO: consider specializing this as 8259.d or similar
//TODO: implement APIC, xAPIC and x2APIC

import cpuio;
import AssertPanic;
import screen;
import VirtMemory;
import keyboard;
import Timer;

enum EXCEPTION
{
	DIVIDE_BY_ZERO,
	DEBUG,
	NMI,
	BREAKPOINT,
	OVERFLOW,
	BOUND_EXCEED,
	INVALID_OPCODE,
	NO_MATH_COPROCESSOR,
	DOUBLE_FAULT,
	SEGMENT_OVERRUN,
	INVALID_TSS,
	SEGMENT_NOT_PRESENT,
	STACK_SEGMENT_FAULT,
	GENERAL_PROTECTION,
	PAGE_FAULT,
	RESERVED,
	FP_ERROR,
	ALIGNMENT_CHECK,
	MACHINE_CHECK,
	SIMD_FP_EXCEPTION,
	VIRTUALIZATION_EXCEPTION
}

enum IRQ
{
	TIMER,
	KEYBOARD,
	INVALID,
	COM2,
	COM1,
	LPT2,
	FLOPPY,
	LPT1,
	RTC,		//real-time clock
	ACPI,
	PERIPHERAL1,
	PERIPHERAL2,
	PS2MOUSE,
	COPROCESSOR,
	ATA1,
	ATA2
}

extern(C) __gshared void isr0();
extern(C) __gshared void isr1();
extern(C) __gshared void isr2();
extern(C) __gshared void isr3();
extern(C) __gshared void isr4();
extern(C) __gshared void isr5();
extern(C) __gshared void isr6();
extern(C) __gshared void isr7();
extern(C) __gshared void isr8();
extern(C) __gshared void isr9();
extern(C) __gshared void isr10();
extern(C) __gshared void isr11();
extern(C) __gshared void isr12();
extern(C) __gshared void isr13();		//GPF
extern(C) __gshared void isr14();
extern(C) __gshared void isr15();
extern(C) __gshared void isr16();
extern(C) __gshared void isr17();
extern(C) __gshared void isr18();
extern(C) __gshared void isr19();
extern(C) __gshared void isr20();
extern(C) __gshared void isr21();
extern(C) __gshared void isr22();
extern(C) __gshared void isr23();
extern(C) __gshared void isr24();
extern(C) __gshared void isr25();
extern(C) __gshared void isr26();
extern(C) __gshared void isr27();
extern(C) __gshared void isr28();
extern(C) __gshared void isr29();
extern(C) __gshared void isr30();
extern(C) __gshared void isr31();

//HW IRQs are remapped to interrupt vectors 32-47
extern(C) __gshared void irq0();
extern(C) __gshared void irq1();
extern(C) __gshared void irq2();
extern(C) __gshared void irq3();
extern(C) __gshared void irq4();
extern(C) __gshared void irq5();
extern(C) __gshared void irq6();
extern(C) __gshared void irq7();
extern(C) __gshared void irq8();
extern(C) __gshared void irq9();
extern(C) __gshared void irq10();
extern(C) __gshared void irq11();
extern(C) __gshared void irq12();
extern(C) __gshared void irq13();
extern(C) __gshared void irq14();
extern(C) __gshared void irq15();

extern(C) __gshared void isr128();

__gshared IDTEntry[256] idt;
__gshared IDTPointer idtp;

//void function() interruptHandlers[];

/**
 * Struct describing an entry into the long-mode Interrupt Descriptor Table
 * fields:
 *  ubyte ist: interrupt stack table: allows switching to a new stack, index into the Task State Segment (TSS)
 *
 */
struct IDTEntry
{
	align(1):
	ushort offset_1; 	// offset bits 0..15
	ushort selector; 	// a code segment selector in GDT or LDT
	ubyte ist;       	// bits 0..2 holds Interrupt Stack Table offset, rest of bits zero.
	ubyte type_attr; 	// type and attributes
	ushort offset_2; 	// offset bits 16..31
	uint offset_3; 		// offset bits 32..63
	uint zero = 0;     	// reserved
}

/**
 * Pointer to the Interrupt Descriptor Table, along with size of table
 */
struct IDTPointer
{
	align(1):
	ushort size;
	ulong base;
}

/**
 * Install ISRs, IRQs, then finally the IDT holding them all.
 */
public void setupInterrupts()
{
	installISRs();
	
	remapIRQs();
	installIRQs();

	installIDT();
}

/**
 * Put an individual interrupt gate/vector into the interrupt descriptor table
 */
private void idtSetGate(ubyte num, size_t base, ushort sel, ubyte flags)
{
	idt[num] = IDTEntry(cast(ushort)(base & 0xFFFF),				//offset bits 0..15
						sel,										//selector of the interrupt function (zero for kernel)
						cast(ubyte)0,								//IST - interrupt stack table entry
						flags,										//type_attr, bits: Present, DPL (2 bits), Storage Segment, Type(4 bits)
						cast(ushort)((base >> 16) & 0xFFFF),
						cast(uint)((base >> 32) & 0xFFFFFFFF));
}

/**
 * Load interrupt descriptor table into CPU using the LIDT instruction.
 */
private void installIDT()
{
	idtp.size = cast(ushort)((idt[0].sizeof * 256) - 1);
	idtp.base = cast(ulong)&idt;
	void *idtpAddr = cast(void*)(&idtp);

	asm
	{
		mov RAX, idtpAddr;
		lidt [RAX];
		sti;
	}
}

private void remapIRQs()
{
	outPort!(ubyte)(cpuio.PIC1Command, 0x11);
	outPort!(ubyte)(cpuio.PIC2Command, 0x11);
	outPort!(ubyte)(cpuio.PIC1Data, 0x20);
	outPort!(ubyte)(cpuio.PIC2Data, 0x28);
	outPort!(ubyte)(cpuio.PIC1Data, 0x04);
	outPort!(ubyte)(cpuio.PIC2Data, 0x02);
	outPort!(ubyte)(cpuio.PIC1Data, 0x01);
	outPort!(ubyte)(cpuio.PIC2Data, 0x01);
	outPort!(ubyte)(cpuio.PIC1Data, 0x00);
	outPort!(ubyte)(cpuio.PIC2Data, 0x00);
}

/**
 * Put function pointers into interrupt descriptor table
 * calls: idtSetGate(), installIDT()
 */
void installISRs()
{
	//exceptions
	idtSetGate(0, cast(size_t)&isr0, 0x08, 0x8E);			//0x08 = kernel code segment, 0x8E = interrupt present, type = interrupt gate
	idtSetGate(1, cast(size_t)&isr1, 0x08, 0x8E);
	idtSetGate(2, cast(size_t)&isr2, 0x08, 0x8E);
	idtSetGate(3, cast(size_t)&isr3, 0x08, 0x8E);
	idtSetGate(4, cast(size_t)&isr4, 0x08, 0x8E);
	idtSetGate(5, cast(size_t)&isr5, 0x08, 0x8E);
	idtSetGate(6, cast(size_t)&isr6, 0x08, 0x8E);
	idtSetGate(7, cast(size_t)&isr7, 0x08, 0x8E);
	idtSetGate(8, cast(size_t)&isr8, 0x08, 0x8E);
	idtSetGate(9, cast(size_t)&isr9, 0x08, 0x8E);
	idtSetGate(10, cast(size_t)&isr10, 0x08, 0x8E);
	idtSetGate(11, cast(size_t)&isr11, 0x08, 0x8E);
	idtSetGate(12, cast(size_t)&isr12, 0x08, 0x8E);
	idtSetGate(13, cast(size_t)&isr13, 0x08, 0x8E);
	idtSetGate(14, cast(size_t)&isr14, 0x08, 0x8E);
	idtSetGate(15, cast(size_t)&isr15, 0x08, 0x8E);
	idtSetGate(16, cast(size_t)&isr16, 0x08, 0x8E);
	idtSetGate(17, cast(size_t)&isr17, 0x08, 0x8E);
	idtSetGate(18, cast(size_t)&isr18, 0x08, 0x8E);
	idtSetGate(19, cast(size_t)&isr19, 0x08, 0x8E);
	idtSetGate(20, cast(size_t)&isr20, 0x08, 0x8E);
	idtSetGate(21, cast(size_t)&isr21, 0x08, 0x8E);
	idtSetGate(22, cast(size_t)&isr22, 0x08, 0x8E);
	idtSetGate(23, cast(size_t)&isr23, 0x08, 0x8E);
	idtSetGate(24, cast(size_t)&isr24, 0x08, 0x8E);
	idtSetGate(25, cast(size_t)&isr25, 0x08, 0x8E);
	idtSetGate(26, cast(size_t)&isr26, 0x08, 0x8E);
	idtSetGate(27, cast(size_t)&isr27, 0x08, 0x8E);
	idtSetGate(28, cast(size_t)&isr28, 0x08, 0x8E);
	idtSetGate(29, cast(size_t)&isr29, 0x08, 0x8E);
	idtSetGate(30, cast(size_t)&isr30, 0x08, 0x8E);
	idtSetGate(31, cast(size_t)&isr31, 0x08, 0x8E);

	//syscalls
	idtSetGate(128, cast(size_t)&isr128, 0x08, 0x8E);
}

void installIRQs()
{
	remapIRQs();

	idtSetGate(32, cast(size_t)&irq0, 0x08, 0x8E);
	idtSetGate(33, cast(size_t)&irq1, 0x08, 0x8E);
	idtSetGate(34, cast(size_t)&irq2, 0x08, 0x8E);
	idtSetGate(35, cast(size_t)&irq3, 0x08, 0x8E);
	idtSetGate(36, cast(size_t)&irq4, 0x08, 0x8E);
	idtSetGate(37, cast(size_t)&irq5, 0x08, 0x8E);
	idtSetGate(38, cast(size_t)&irq6, 0x08, 0x8E);
	idtSetGate(39, cast(size_t)&irq7, 0x08, 0x8E);
	idtSetGate(40, cast(size_t)&irq8, 0x08, 0x8E);
	idtSetGate(41, cast(size_t)&irq9, 0x08, 0x8E);
	idtSetGate(42, cast(size_t)&irq10, 0x08, 0x8E);
	idtSetGate(43, cast(size_t)&irq11, 0x08, 0x8E);
	idtSetGate(44, cast(size_t)&irq12, 0x08, 0x8E);
	idtSetGate(45, cast(size_t)&irq13, 0x08, 0x8E);
	idtSetGate(46, cast(size_t)&irq14, 0x08, 0x8E);
	idtSetGate(47, cast(size_t)&irq15, 0x08, 0x8E);
}

/**
 * Interrupt service handler / Exception Handler
 */
public extern(C) __gshared void isr(ulong num, ulong err)
{
	kprintfln("HW Exception: %d, error code %d", cast(uint)num, cast(uint)err);
	
	switch(num)
	{
		case EXCEPTION.DIVIDE_BY_ZERO:
			panic("Divide by Zero");
			break;
		case EXCEPTION.GENERAL_PROTECTION:
			panic("GPF");
			break;
		case EXCEPTION.PAGE_FAULT:
			VirtMemory.pageFaultHandler(err);
			break;
		default:
			panic("Unhandled Interrupt");
	}
}

/**
 * Hardware IRQ service handler
 * TODO: consider way of having other code install the ISRs instead of having everything
 *  jump to this section.
 */
public extern(C) __gshared void irq(ulong num, ulong err)
{
	//irqs 0-15 are mapped to interrupt service routines 32-47
	uint irq = cast(uint)num - 32;

	switch(irq){
		case IRQ.TIMER:
			Timer.clockHandler();
			break;
		case IRQ.KEYBOARD:
			//ubyte scanCode = inPort!(ubyte)(0x60);
			//kprintf("%d",cast(int)scanCode);
			readKey();	//in keyboard.d
			break;
		case IRQ.INVALID:
			panic("IRQ 2 recieved.");
			break;
		case IRQ.COM2:
			goto default;
		case IRQ.COM1:
			goto default;
		case IRQ.LPT2:
			goto default;
		case IRQ.FLOPPY:
			goto default;
		case IRQ.LPT1:
			goto default;
		case IRQ.RTC:
			goto default;
		case IRQ.ACPI:
			goto default;
		case IRQ.PERIPHERAL1:
			goto default;
		case IRQ.PERIPHERAL2:
			goto default;
		case IRQ.PS2MOUSE:
			goto default;
		case IRQ.COPROCESSOR:
			goto default;
		case IRQ.ATA1:
			goto default;
		case IRQ.ATA2:
			goto default;
		default:
			kprintfln("IRQ: %d", cast(uint)irq);
	}

	//tell the slave controller that the interrupt is done
	if(num >= 40)
	{
		outPort!(ubyte)(cpuio.PIC2Command, cpuio.PICEnd);
	}

	//tell the master controller that the interrupt is done
	outPort!(ubyte)(cpuio.PIC1Command, cpuio.PICEnd);
}