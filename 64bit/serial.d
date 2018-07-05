module serial;

import cpuio;
import screen;

//TODO: actual TX/RX of bits right now through the serial port
// probably isn't done correctly. No checking of the TX/RX registers
// or interrupts or anything else is done. It works OK for now for
// debugging through QEMU, but more needs to be done.

/**
 * List of default serial ports and their port addresses
 * TODO: use ACPI/EFI/something to find true addresses
 */
// enum ushort COM1 = 0x3F8;
// enum ushort COM2 = 0x2F8;
// enum ushort COM3 = 0x3E8;
// enum ushort COM4 = 0x2E8;

public alias COM1 = SerialPort!(0x3F8);
public alias COM2 = SerialPort!(0x2F8);
public alias COM3 = SerialPort!(0x3E8);
public alias COM4 = SerialPort!(0x2E8);

/**
 * Supported baud rates
 */
enum BaudRate : ubyte
{
    rate115200 = 1, 
    rate57600 = 2,
    rate38400 = 3,
    rate19200 = 6,
    rate9600 = 12,
    rate4800 = 24,
    rate2400 = 48,
    rate1200 = 96
}

/**
 * Data bits
 */
enum Data : ubyte
{
    FIVE = 0,
    SIX = 1,
    SEVEN = 2,
    EIGHT = 3
}

/**
 * Serial parity types
 */
enum Parity : ubyte
{
    NONE = 0,
    ODD = 1,
    EVEN = 3,
    MARK = 5,
    SPACE = 7
}

/**
 * This holds line control parameters for the serial port
 * Stop bit, parity, data bits
 *
 * Reference the Data and Parity enums for what values
 * should be set here for the individual fields.
 */
struct LineProtocol
{
    import std.bitmanip : bitfields;
    union
    {
        /**
         * Used for setting/getting this struct as a single ubyte 
         */
        ubyte all;

        mixin(bitfields!(
            ubyte, "dataBits", 	2,
            bool, "stopBit", 	1,
            ubyte, "parity",    3,
            ubyte, "",          2));
    }
}

/**
 * Interrupt Enable Register
 * 
 * Note: does not currently support
 *  sleep or low power modes
 */
struct InterruptEnable
{
    import std.bitmanip : bitfields;

    union
    {
        /**
         * Used for setting/getting this struct as a single ubyte 
         */
        ubyte all;

        mixin(bitfields!(
            bool, "dataAvailable",  1,
            bool, "txEmpty",        1,
            bool, "rxChange",       1,
            bool, "mdodemChange",   1,
            ubyte, "",              4
        ));
    }
}

/**
 * Interrupt Identification Register
 */
struct InterruptIdentification
{
    enum Changes
    {
        modemStatus = 0,
        txEmpty = 1,
        dataAvailable = 2,
        lineStatus = 3,
        charTimeout = 6
    }

    import std.bitmanip : bitfields;

    union
    {
        /**
         * Used for setting/getting this struct as a single ubyte 
         */
        ubyte all;

        mixin(bitfields!(
            bool, "interruptPending",   1,
            ubyte, "changes",           3,
            bool, "",                   1,
            bool, "",                   1,
            ubyte, "fifo",              2
        ));
    }
}

/**
 * FIFO Control Register
 */
 struct FIFOControl
 {
    import std.bitmanip : bitfields;
    
    union
    {
        /**
         * Used for setting/getting this struct as a single ubyte 
         */
        ubyte all;
    
        mixin(bitfields!(
            bool, "enable",            1,
            bool, "rxClear",           1,
            bool, "txClear",           1,
            bool, "dmaMode",           1,
            bool, "",                  1,
            bool, "",                  1,
            ubyte, "fifoInterrupt",    2
        ));
    }
 }

 /**
  * Modem Control Register
  */
struct ModemControl
{
    import std.bitmanip : bitfields;

    union
    {
        /**
         * Used for setting/getting this struct as a single ubyte 
         */
        ubyte all;

        mixin(bitfields!(
            bool, "terminalReady",      1,
            bool, "RTS",                1,
            bool, "aux1",               1,
            bool, "aux2",               1,
            bool, "loopback",           1,
            bool, "",                   1,
            bool, "",                   1,
            bool, "",                   1
        ));
    }
}

/**
 * Line Status Register
 */
 struct LineStatus
{
    import std.bitmanip : bitfields;
    
    union
    {
        /**
         * Used for setting/getting this struct as a single ubyte 
         */
        ubyte all;
    
        mixin(bitfields!(
            bool, "dataAvailable",      1,
            bool, "overrunError",       1,
            bool, "parityError",        1,
            bool, "framingError",       1,
            bool, "breakSignal",        1,
            bool, "THREmpty",           1,
            bool, "THREmptyIdle",       1,
            bool, "FIFOError",          1
        ));
    }
}

/**
 * Represents a single RS-232 serial port
 * 
  * DLAB is divisor latch. Setting it to 1
 * will allow offsets 0-1 to set the divisor for baud rate
 *
 * IO Port Offsets are:
 * +0 (DLAB=0)  : Data Register
 * +1 (DLAB=0)  : Interrupt Enable
 * +2           : Interrupt ID / FIFO control
 * +3           : Line Control Register (MSB = DLAB)
 * +4           : Modem Control Register
 * +5           : Line Status Register
 * +6           : Modem Status Register
 * +7           : Scratch Register
 */
struct SerialPort(ushort myPort)
{
    //Port numbers for various UART control registers
    static immutable ushort portNum = myPort;
    static immutable ushort data = myPort;
    static immutable ushort interruptEnable = cast(ushort)(myPort + 1);
    static immutable ushort fifoControl = cast(ushort)(myPort + 2);
    static immutable ushort lineControl = cast(ushort)(myPort + 3);
    static immutable ushort modemControl = cast(ushort)(myPort + 4);
    static immutable ushort lineStatus = cast(ushort)(myPort + 5);

    /**
     * setConfig specifies the baud rate and line protocol of this
     * serial port.
     *
     * Params:
     *  rate is the divisor, actual baudRate will be 115200 / rate (default=1)
     *  protocol is the line protocol.  (default=3 [8N1])
     *  fifo is the FIFO control register setting. 
     *   (default=FIFO will be enabled, cleared, and a 14-byte FIFO interrupt 
     *    trigger level is set by default.)
     */
    public static void setConfig(BaudRate rate = BaudRate.rate115200, 
                LineProtocol protocol = cast(LineProtocol)3, 
                FIFOControl fifo = cast(FIFOControl)0xC7, 
                ModemControl modem = cast(ModemControl)0x0B)
    {
        outPort!(ubyte)(interruptEnable,    0x00);              //disable interrupts  
        outPort!(ubyte)(lineControl,        0x80);              //enable baud rate divisor
        outPort!(ubyte)(data,               cast(ubyte)rate);   //set divisor low byte
        outPort!(ubyte)(interruptEnable,    0x00);              //set divisor high byte
        outPort!(ubyte)(lineControl,        protocol.all);
        outPort!(ubyte)(fifoControl,        fifo.all);  
        outPort!(ubyte)(modemControl,       modem.all);
        outPort!(ubyte)(interruptEnable,    0x01);              //enable interrupts
    }

    /**
     * write sends a single character through this serial port
     * 
     * TODO: see if this should block or not
     * TODO: implement buffered I/O
     */
    public static void write(string s)
    {
        foreach(char c; s)
        {
            write(c);
        }
    }

    private static bool isTransmitEmpty()
    {
        return (inPort!(ubyte)(lineStatus) & 0x20) == 0;       //check for bit 5 set (tx register empty)
    }

    /**
     * write sends a single character through this serial port
     * TODO: see if this should block or not
     *
     * TODO: implement buffered I/O
     */
    public static void write(char a)
    {
        //while(!isTransmitEmpty()){}
        outPort!(ubyte)(data, a);
    }

    private static bool hasReceived()
    {
        return (inPort!(ubyte)(lineStatus) & 0x01) == 1;    //check for bit 1 set (data available)
    }

    /**
     * read a single character from the serial port
     * TODO: see if this should block
     */
    public static char read()
    {
        //while(!hasReceived()){}
        return inPort!(ubyte)(data);
    }
}