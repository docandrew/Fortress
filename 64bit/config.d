module Config;

/**
 * System parameters.
 * TODO: version these eventually with version(x86_64), etc.
 */
public enum FRAME_SIZE = 4096;				//2^12
public enum FRAME_SHIFT = 12;				//left or right shift to convert between page num and start address

/**
* ELF sections will be printed during boot
*/
public enum DebugELF = true;

/**
* Print debugging information in physical
* memory allocator
*/
public enum DebugFrameAlloc = true;

/**
* Timer interrupts will print a "." to screen
*/
public enum DebugTimer = false;

/**
* Screen output will be mirrored to a serial device
*/
public enum SerialConsoleMirror = true;