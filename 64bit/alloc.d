module alloc;

import util;

struct BumpAllocator
{
    size_t heapStart;
    size_t heapEnd;
    shared size_t next;

    this(size_t start, size_t end)
    {
        heapStart = start;
        heapEnd = end;
    }

    void *alloc(size_t size, ulong alignment)
    {
        size_t start = roundUp(size, alignment);
        size_t end = addSaturate!(size_t)(start, size);

        if(end <= heapEnd)
        {
            next = heapEnd;
            return cast(void*)start;
        }
        else
        {
            return null;
            //TODO: consider panic or exception here
        }
    }

    void free(void* ptr)
    {
        //leaks
    }
}

// T objAlloc(T, Args...)(Args args)
// {
//     import std.conv : emplace;

//     auto size = __traits(classInstanceSize, T);     //class size in bytes

//     auto memory = kalloc(size);
//     if(!memory)
//     {
//         //throw or return null
//     }

//     //call T's constructor, emplace instance on allocated memory
//     return emplace!(T, Args)(memory, args);
// }

// void objFree(T)(T obj)
// {
//     destroy(obj);
//     kfree(cast(void*)obj);
// }

/**
 * kalloc allocates heap memory of at least size bytes,
 * aligned as specified.
 *
 * Params:
 *  size = the request, in bytes to be allocated
 *  alignment = must be a power of 2
 */
void *kalloc(Allocator)(size_t size, ulong alignment)
{
    //TODO: consider using popcnt to verify power-of-2 alignment
    return Allocator.alloc(size, alignment);
}

void kfree(Allocator)(void *ptr)
{
    Allocator.free(ptr);
}