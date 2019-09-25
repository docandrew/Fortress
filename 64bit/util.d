//utility functions
//TODO: consider splitting string stuff and bit-fiddling into separate modules

module util;

import config;
import virtmemory;
import std.traits;

/**
 * isPowerOfTwo
 *
 * Returns: true if a = 2^X, false otherwise.
 */
bool isPowerOfTwo(size_t a)
{
	size_t ret;

	asm
	{
		popcnt RAX, a;
		mov ret, RAX;
	}

	return (ret == 1);
}

/**
 * addSaturate is a saturated addition function
 *
 * Params:
 *  a = must be unsigned
 *  b = must be unsigned
 *
 * Returns: a + b if no overflow, T.max otherwise.
 *
 * TODO: add some unittests here, not 100% sure about
 * implicit conversions goofing this up.
 */
 pure @safe T addSaturate(T)(T a, T b)
 {
	 static assert(isUnsigned!T);

	 T c = cast(T)(a + b);
	 if(c < a)
	 {
		 c = T.max;
	 }
	 return c;
 }

/**
 * Round up to next frame/page/align boundary. If address
 * is already on this boundary, it is returned.
 *
 * Params:
 *  multiple = must be a power of 2. By default this is FRAME_SIZE
 */
pure @safe size_t roundUp(size_t address, size_t multiple = FRAME_SIZE)
{
	//TODO: consider checking if multiple is a power of 2
	// perhaps force it to be immutable so we can check at compile time.
	//kassert(multiple.isPowerOfTwo);

	if(address % multiple == 0)
	{
		return address;
	}
	else
	{
		return (address & ~(multiple-1)) + multiple;
	}
	// if(multiple == 0){
	// 	return address;
	// }

	// ulong remainder = address % multiple;
	// if(remainder == 0){
	// 	return address;
	// }

	// return address + multiple - remainder;
}

/**
 * Round down to previous frame/page/align boundary. If address
 * is already on this boundary, it is returned.
 *
 * Params:
 *  multiple = must be a power of 2. By default this is FRAME_SIZE
 */
pure @safe size_t roundDown(size_t address, size_t multiple = virtmemory.FRAME_SIZE)
{
	//return roundUp(address, multiple) - multiple;
	return (address & ~(multiple-1));
}

pure nothrow @nogc bool isBitSet(T)(T value, uint index)
{
	if(((1 << index) & value) != 0)
	{
		return true;
	}
	return false;
}

// return null-terminated hex string representation of integer
// used for addresses
char[11] intToStringz(uint r)
{
	immutable char[16] digits = "0123456789ABCDEF";
	char[11] result;
	//result[2] =  digits[(r & 0xf000000000000000) >> 60];
	//result[3] =  digits[(r & 0x0f00000000000000) >> 56];
	//result[4] =  digits[(r & 0x00f0000000000000) >> 52];
	//result[5] =  digits[(r & 0x000f000000000000) >> 48];
	//result[6] =  digits[(r & 0x0000f00000000000) >> 44];
	//result[7] =  digits[(r & 0x00000f0000000000) >> 40];
	//result[8] =  digits[(r & 0x000000f000000000) >> 36];
	//result[9] =  digits[(r & 0x0000000f00000000) >> 32];

	result[0] = '0';
	result[1] = 'x';
	result[2] = digits[(r & 0xf0000000) >> 28];
	result[3] = digits[(r & 0x0f000000) >> 24];
	result[4] = digits[(r & 0x00f00000) >> 20];
	result[5] = digits[(r & 0x000f0000) >> 16];
	result[6] = digits[(r & 0x0000f000) >> 12];
	result[7] = digits[(r & 0x00000f00) >> 8];
	result[8] = digits[(r & 0x000000f0) >> 4];
	result[9] = digits[(r & 0x0000000f)];
	result[10] = '\0';	//null-terminate

	return result;
}

// return null-terminated hex string representation of integer
// used for addresses
char[19] longToStringz(ulong r)
{
	immutable char[16] digits = "0123456789ABCDEF";
	char[19] result;
	
	result[0] = '0';
	result[1] = 'x';
	
	result[2] =  digits[(r & 0xf000000000000000) >> 60];
	result[3] =  digits[(r & 0x0f00000000000000) >> 56];
	result[4] =  digits[(r & 0x00f0000000000000) >> 52];
	result[5] =  digits[(r & 0x000f000000000000) >> 48];
	result[6] =  digits[(r & 0x0000f00000000000) >> 44];
	result[7] =  digits[(r & 0x00000f0000000000) >> 40];
	result[8] =  digits[(r & 0x000000f000000000) >> 36];
	result[9] =  digits[(r & 0x0000000f00000000) >> 32];
	result[10] = digits[(r & 0x00000000f0000000) >> 28];
	result[11] = digits[(r & 0x000000000f000000) >> 24];
	result[12] = digits[(r & 0x0000000000f00000) >> 20];
	result[13] = digits[(r & 0x00000000000f0000) >> 16];
	result[14] = digits[(r & 0x000000000000f000) >> 12];
	result[15] = digits[(r & 0x0000000000000f00) >> 8];
	result[16] = digits[(r & 0x00000000000000f0) >> 4];
	result[17] = digits[(r & 0x000000000000000f)];
	result[18] = '\0';	//null-terminate

	return result;
}

// return null-terminated decimal representation of integer
// sized for ordinary number types (not addresses)
// TODO: make a version of this that works for longs
@trusted void itoa(char *buf, int d)
{
	int sizeOfString = 1;	//need 1 char for null-terminate
	int negative = 0;

	if(d < 0)
	{
		buf[0] = '-';
		d = -d;
		negative = 1;
		sizeOfString++;		//add extra char for negative sign
	}

	//figure out how many digits the output buffer will have so we know where to start writing chars within buffer (work back to front)
	//TODO: consider changing this to binary search
	if(d < 10)
	{
		sizeOfString += 1;
	}
	else if(d > 9 && d < 100)
	{
		sizeOfString += 2;
	}
	else if(d > 99 && d < 1000)
	{
		sizeOfString += 3;
	}
	else if(d > 999 && d < 10000)
	{
		sizeOfString += 4;
	}
	else if(d > 9999 && d < 100_000)
	{
		sizeOfString += 5;
	}
	else if(d > 99999 && d < 1_000_000)
	{
		sizeOfString += 6;
	}
	else if(d > 999_999 && d < 10_000_000)
	{
		sizeOfString += 7;
	}
	else if(d > 9_999_999 && d < 100_000_000)
	{
		sizeOfString += 8;
	}
	else if(d > 99_999_999 && d < 1_000_000_000)
	{
		sizeOfString += 9;
	}
	else
	{
		sizeOfString += 10;
	}

	//writeln("size: ", sizeOfString);

	buf[sizeOfString - 1] = '\0';
	//writeln("wrote null-terminate to position ", sizeOfString - 1);

	for(int i = sizeOfString - 2; i >= negative; i--)
	{
		char digit = cast(char)((d % 10) + 48);
		buf[i] = digit;
		//writeln("wrote ", digit, " to position ", i);
		d /= 10;
	}
}

//// return null-terminated hex string representation of 64-bit long
//char[19] longToStringz(ulong r)
//{
//	immutable char[16] digits = "0123456789ABCDEF";
//	char[19] result;
//	result[0] = '0';
//	result[1] = 'x';
//	result[2] =  digits[(r & 0xf000000000000000) >> 60];
//	result[3] =  digits[(r & 0x0f00000000000000) >> 56];
//	result[4] =  digits[(r & 0x00f0000000000000) >> 52];
//	result[5] =  digits[(r & 0x000f000000000000) >> 48];
//	result[6] =  digits[(r & 0x0000f00000000000) >> 44];
//	result[7] =  digits[(r & 0x00000f0000000000) >> 40];
//	result[8] =  digits[(r & 0x000000f000000000) >> 36];
//	result[9] =  digits[(r & 0x0000000f00000000) >> 32];

//	result[2] = digits[(r & 0xf0000000) >> 28];
//	result[3] = digits[(r & 0x0f000000) >> 24];
//	result[4] = digits[(r & 0x00f00000) >> 20];
//	result[5] = digits[(r & 0x000f0000) >> 16];
//	result[6] = digits[(r & 0x0000f000) >> 12];
//	result[7] = digits[(r & 0x00000f00) >> 8];
//	result[8] = digits[(r & 0x000000f0) >> 4];
//	result[9] = digits[(r & 0x0000000f)];
//	result[10] = '\0';	//null-terminate

//	return result;
//}