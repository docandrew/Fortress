module process;

import virtmemory;

enum Status
{
    RUNNING,
    READY,
    SLEEPING,
    WAITING,
    RECEIVE,
    SUSPENDED
}

enum ProcessTypes
{
	KERNELTHREAD,
	USERPROCESS,
}
__gshared uint nextPid = 0;

struct Process
{
    uint pid;
    uint priority;
    uint status;
    bool isKernelThread;
	string name;
    
    size_t stack;

    AddressSpace *addressSpace;

    //return PID of created process
	uint create()
	{
	   	pid = getpid();
	   	return pid;
	}
}

uint getpid()
{
	//TODO: fix this
	return nextPid++;
}