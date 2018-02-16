module keyboard;

import cpuio;
import screen;

//TODO: use different maps here.
//has the key, then the shifted version of it.
__gshared char[178] scancodeToChar = [
'\?','\?',		//0 unused
'\?','\?',		//ESC
'1','!',
'2','@',
'3','#',
'4','$',
'5','%',
'6','^',
'7','&',
'8','*',
'9','(',
'0',')',
'-','_',
'=','+',
'\b','\b',		//backspace
'\t','\t',		//tab
'q','Q',
'w','W',
'e','E',
'r','R',
't','T',
'y','Y',
'u','U',
'i','I',
'o','O',
'p','P',
'[','{',
']','}',
'\n','\n',
'\?','\?',		//left ctrl
'a','A',
's','S',
'd','D',
'f','F',
'g','G',
'h','H',
'j','J',
'k','K',
'l','L',
';',':',
'\'','\"',
'`','~',
'\?','\?',		//left shift
'\\','|',
'z','Z',
'x','X',
'c','C',
'v','V',
'b','B',
'n','N',
'm','M',
',','<',
'.','>',
'/','\?',
'\?','\?',		//right shift
'\?','\?',		//keypad * or */PrtScrn
'\?','\?',		//left alt
' ',' ',		//space bar
'\?','\?',		//caps lock
'\?','\?',		//F1
'\?','\?',		//F2
'\?','\?',		//F3
'\?','\?',		//F4
'\?','\?',		//F5
'\?','\?',		//F6
'\?','\?',		//F7
'\?','\?',		//F8
'\?','\?',		//F9
'\?','\?',		//F10
'\?','\?',		//NumLock
'\?','\?',		//ScrollLock
'7','\?',		//Keypad-7/Home
'8','\?',		//Keypad-8/Up
'9','\?',		//Keypad-9/PgUp
'-','\?',		//Keypad -
'4','\?',		//Keypad-4/left
'5','\?',		//Keypad-5
'6','\?',		//Keypad-6/Right
'+','\?',		//Keypad +
'1','\?',		//Keypad-1/End
'2','\?',		//Keypad-2/Down
'3','\?',		//Keypad-3/PgDn
'4','\?',		//Keypad-0/Insert
'.','\?',		//Keypad ./Del
'\?','\?',		//Alt-SysRq
'\?','\?',		//F11 or F12. Depends
'\?','\?',		//non-US
'\?','\?',		//F11
'\?','\?'		//F12
];

enum SCANCODES
{
	CAPSLOCK = 0x3a,
	LSHIFT = 0x2a,
	RSHIFT = 0x36
}

__gshared bool shifted = false;
__gshared bool caps = false;

//TODO: make use of different keymaps
//TODO: figure out Unicode entries
//TODO: wrap this in some kind of nicer interface / struct
//TODO: prevent keyloggers
public __gshared void readKey()
{
	//kprintf("asdf");
	ubyte scanCode = inPort!(ubyte)(0x60);
	//kprintf("%d",cast(int)scanCode);

	if((scanCode & 128) == 128){
		//released key
		scanCode = cast(ubyte)(scanCode - 128);

		switch(scanCode){
			case SCANCODES.CAPSLOCK:
				caps = caps? false : true;
				break;
			case SCANCODES.LSHIFT:
				shifted = false;
				break;
			case SCANCODES.RSHIFT:
				shifted = false;
				break;
			default:
		}
	}
	else{
		//pressed key
		switch(scanCode){
			case SCANCODES.LSHIFT:
				shifted = true;
				break;
			case SCANCODES.RSHIFT:
				shifted = true;
				break;
			case SCANCODES.CAPSLOCK:
				break;
			default:
				int charIndex = ((shifted || caps)? (scanCode * 2) + 1 : (scanCode * 2));
		
				char l = scancodeToChar[charIndex];
				print(l);
		}

		//kprintf("scanCode: %d, char: %c", cast(int)scanCode, l);
	}
}