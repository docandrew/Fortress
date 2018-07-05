module Config;

/**
 * ELF sections will be printed during boot
 */
enum DebugELF = true;

/**
 * Print debugging information in physical
 * memory allocator
 */
enum DebugFrameAlloc = true;

/**
 * Timer interrupts will print a "." to screen
 */
enum DebugTimer = false;

/**
 * Screen output will be mirrored to a serial device
 */
enum SerialConsoleMirror = true;