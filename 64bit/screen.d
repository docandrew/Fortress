module screen;

import util;

__gshared ubyte* videoMemory = cast(ubyte *)0xb8000;
__gshared uint index;

void moveCursor(uint x, uint y)
{
	if(x < 80 && y < 25)
	{
		index = (160 * y) + (2 * x);
	}
	else
	{
		index = 0;
		//TODO: throw exception here
	}
}

uint getIndex()
{
	return index;
}

uint getLine()
{
	return index / 160;
}

uint getColumn()
{
	return index % 160;
}


//TODO: Implement some decent string handling and get rid of all this silliness
//TODO: make the screen display portion of a larger text buffer
@system void scrollUp(uint lines = 1)
{
	foreach(idx; 0 .. 80 * 25 * 2)
	{
		videoMemory[idx] = videoMemory[idx + (160 * lines)];
	}
	//now blank out the empty lines at the end
	foreach(idx; 80 * (25-lines) * 2 .. 80 * 25)
	{
		videoMemory[idx * 2] = ' ';
		videoMemory[idx * 2 + 1] = 0;
	}
	moveCursor(0, 25 - lines);
}

// Clear video memory buffer & move cursor to top left
@system void clearScreen(ubyte clearColor = 0b111)
{
	foreach(idx; 0 .. 80*25)
	{
		videoMemory[idx * 2] = ' ';
		videoMemory[idx * 2 + 1] = clearColor;
	}
	index = 0;
}

// Output single character to the video memory buffer
//@trusted void print(char val, uint x, uint y, ubyte color = 0b111)
//{
//	moveCursor(x, y);
//	videoMemory[index] = val;
//	videoMemory[index+1] = color;
//}

// Output single character to video memory buffer and move cursor
@trusted void print(char val, ubyte color = 0b111)
{
	if(val == '\n' || val == '\r')
	{
		index = (getLine() * 160) + 160;

		if(index >= 80 * 25 * 2)
		{
			scrollUp();
		}
	}
	else if(val == '\t')
	{
		index += 4;

		if(index >= 80 * 25 * 2)
		{
			scrollUp();
		}
	}
	else if(val == '\0')
	{
		//null char, do nothing.
	}
	else
	{
		videoMemory[index] = val;
		videoMemory[index+1] = color;
		index+=2;
	}
}

void kprintfln(T...)(immutable string format, T args)
{
	kprintf(format, args);
	print('\n');
}

void kprintf(T...)(immutable string format, T args)
{
	//write("passed format: ", format);
	//writeln("called with ", args.length, " arguments");
	char[20] intbuffer;

	int formatIndex = 0;

	foreach(i, arg; args)
	{
		//writeln(i, ": ", typeid(T[i]), " ", arg);

		//iterate through format string now
		do
		{
			char c = format[formatIndex];

			//OK, found a format specifier. Time to use this argument.
			if(c == '%')
			{
				formatIndex++;
				c = format[formatIndex];
				switch(c)
				{
					case 'd':
					{
						static if(is(typeof(arg) : int)){			//ensure that argument is capable of being passed to itoa()
							itoa(intbuffer.ptr, arg);
							printz(intbuffer.ptr);
						}
						break;
					}
					case 's':
					{
						static if(is(typeof(arg) : char*)){			//make sure no type mismatch between 
							printz(arg);
						}
						break;
					}
					case 'S':
					{
						static if(is(typeof(arg) : string)){
							print(arg);
						}
						break;
					}
					case 'x':
					{
						//print as hex 
						static if(is(typeof(arg) : long)){
							print(arg);
						}
						break;
					}
					case 'c':
					{
						//char
						static if(is(typeof(arg) : char)){
							print(arg);
						}

					}
					default:
					{
						break;
					}
				}
				formatIndex++;
				
				//now we need to skip to the next argument (break out of the do-while loop)
				break;
			}
			else
			{
				print(c);
				formatIndex++;
			}
		}while(formatIndex < format.length);
	}
	
	//OK, no more arguments left, now just print the rest of the string
	for(; formatIndex < format.length; formatIndex++)
	{
		print(format[formatIndex]);
	}
}

// Print string
@trusted void print(string msg, ubyte color = 0b111)
{
	foreach(char c; msg)
	{
		print(c, color);
	}
}

// Print string
@trusted void println(string msg, ubyte color = 0b111)
{
	print(msg, color);
	print('\n');
}

@trusted void print(uint msg, ubyte color = 0b111)
{
	printz(cast(char *)intToStringz(msg));
}

@trusted void print(ulong msg, ubyte color = 0b111)
{
	printz(cast(char *)longToStringz(msg));
}

@trusted void println(uint msg, ubyte color = 0b111)
{
	print(msg, color);
	print('\n');
}

@trusted void println(ulong msg, ubyte color = 0b111)
{
	print(msg, color);
	print('\n');
}

// Print numBytes of a char* string (non-null terminated)
@system void printchars(char* msg, uint numBytes)
{
	foreach(i; 0 .. numBytes)
	{
		print(msg[i]);
	}
}

// Print null-terminated strings (yuk)
@trusted void printz(char* msg, ubyte color = 0b111)
{
	uint charIndex = 0;
	char c = msg[charIndex];

	while(c != '\0')
	{
		print(c, color);
		charIndex++;
		c = msg[charIndex];
	}
}

@trusted void printlnz(char* msg, ubyte color = 0b111)
{
	printz(msg, color);
	print('\n');
}