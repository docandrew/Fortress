
/**
 * Programmable Interval Timer - Intel 8253
 */
module Timer;

import Config;
import screen;
import cpuio;

//8253 Timer ports
enum Timer0		= 0x40;
enum Timer1 	= 0x41;
enum Timer2 	= 0x42;
enum TimerMode	= 0x43;

__gshared ulong counter;

void init()
{
	// 1.190 Mhz for 1ms interrupt rate
	ushort interval = 1193;		//1193 to fix clock skew

	//set timer 0 to 16-bit counter, rate generator,
	// counter running in binary
	outPort!(ubyte)(TimerMode, 0x34);
	outPort!(ubyte)(Timer0, 0xff & interval);
	outPort!(ubyte)(Timer0, 0xff & (interval >> 8));
}

/**
 * Handler for 1ms timer interrupts
 *  called by ISR
 */
void clockHandler()
{
	counter++;
	if(counter == ulong.max)
	{
		counter = 0;
	}

	static if(Config.DebugTimer)
	{
		if(counter % 1000 == 0)
		{
			kprintf(".");
		}
	}
}