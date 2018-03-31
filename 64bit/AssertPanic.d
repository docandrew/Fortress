module AssertPanic;

import screen;

/**
 *
 * Module UnitTests:
 * provides kernel-level Design-by-Contract primitives
 * such as assert, 
 *
 */

public void kassert(bool condition, string file = __FILE__, int line = __LINE__)
{
	if(!condition)
	{
		panic("Assertion failure", file, line);
	}
}

public void panic(string message, string file = __FILE__, int line = __LINE__)
{
	kprintfln("KERNEL PANIC: %S in %S:%d", message, file, line);
	//TODO: disable interrupts
	while(true){}
}