module Config;

/**
 * ELF sections will be printed during boot
 */
public enum DebugELF = false;

/**
 * Print debugging information in physical
 * memory allocator
 */
public enum DebugFrameAlloc = false;

/**
 * Print debugging info regarding internal operation of virtual memory subsystem
 */
public enum DebugVMM = false;

/**
 * Timer interrupts will print a "." to screen
 */
public enum DebugTimer = true;

/**
 * Screen output will be mirrored to a serial device
 */
public enum SerialConsoleMirror = true;

/**
 * Linear VESA Framebuffer instead of EGA text mode
 * Also need to tell GRUB to set video mode in boot.asm
 * if using this option
 */
public enum framebufferVideo = true;