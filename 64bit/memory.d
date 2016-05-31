module memory;

immutable auto PAGE_SIZE = 4096;

struct Frame
{
	size_t frameNumber;

	Frame containingAddress(size_t address)
	{
		return address / PAGE_SIZE;
	}
}