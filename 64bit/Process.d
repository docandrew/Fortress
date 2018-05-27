module Process;

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

    ubyte[12288] pageTables;

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