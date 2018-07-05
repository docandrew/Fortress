module assertpanic;

import screen;

/**
 * kassert is the Fortress version of D's assert. It will
 * cause a kernel panic if condition is false
 */
public void kassert(bool condition, string file = __FILE__, int line = __LINE__)
{
	if(!condition)
	{
		panic("Assertion failure", file, line);
	}
}

/**
 * panic is used to halt the operating system if a fatal
 * error occurs.
 */
public void panic(string message, string file = __FILE__, int line = __LINE__)
{
	kprintfln("KERNEL PANIC: %S in %S:%d", message, file, line);
	//TODO: disable interrupts
	while(true){}
}