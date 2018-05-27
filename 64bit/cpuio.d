module cpuio;
 
//x86 I/O ports
enum PIC1 = 0x20;
enum PIC2 = 0xA0;
enum PIC1Command	= PIC1;
enum PIC1Data		= PIC1+1;
enum PIC2Command	= PIC2;
enum PIC2Data		= PIC2+1;

enum PICEnd			= 0x20;

enum Timer0		= 0x40;
enum Timer1 	= 0x41;
enum Timer2 	= 0x42;
enum TimerMode	= 0x43;

//TODO: wrap this, make it safer, add access control
void outPort(T)(ushort port, T data) if (is(T == ubyte) || is(T == ushort) || is(T == uint))
{
	uint val = data;
	
	asm pure nothrow{
		mov DX, port;
		mov EAX, val;
	}

	static if(is(T == ubyte)){
		asm{
			out DX, AL;
		}
	}

	else static if(is(T == ushort)){
		asm{
			out DX, AX;
		}
	}

	else static if(is(T == uint)){
		asm{
			out DX, EAX;
		}
	}
}

T inPort(T)(ushort port) if (is(T == ubyte) || is(T == ushort) || is(T == uint))
{
	T ret;

	static if(is(T == ubyte)){
		asm{
			mov DX, port;
			in AL, DX;
			mov ret, AL;
		}
	}

	else static if(is(T == ushort)){
		asm{
			mov DX, port;
			in AX, DX;
			mov ret, AX;
		}
	}

	else static if(is(T == uint)){
		asm{
			mov DX, port;
			in EAX, DX;
			mov ret, EAX;
		}
	}

	return ret;
}