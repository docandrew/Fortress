/**
 * Contains all implicitly declared types and variables.
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly, Jon
 *
 *          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

// Thanks: JinShil for druntime_level_0

// Design rules:
//  static is presumed to be thread-local, use __gshared instead.

module object;

static assert((void*).sizeof == 8);	//ensure 64-bit mode

alias string = immutable(char)[];
alias size_t = ulong;				//only for 64-bit
alias hash_t = size_t;
alias ptrdiff_t = long;

//extern(C) void _d_run_main() {
//	asm {
//		naked;
//		call kmain;
//	}
//}

extern(C) void _d_dso_registry() {}
extern(C) __gshared void* _Dmodule_ref;
extern(C) __gshared void* kmain(uint, void *);
extern(C) __gshared void* _d_arraybounds;
extern(C) __gshared void* _d_assert;
extern(C) __gshared void* _d_unittest;
extern(C) __gshared void* _d_newclass;
extern(C) __gshared void* _d_throwc;

//required support classes by the compiler
class Object {

}

class Throwable {}

class Exception : Throwable {}

class Error : Throwable {
	this(string msg) {}
}

class TypeInfo 
{
	//override string toString() const pure @safe nothrow
 //   {
 //       return typeid(this).name;
 //   }

 //   override size_t toHash() @trusted const
 //   {
 //       try
 //       {
 //           auto data = this.toString();
 //           return rt.util.hash.hashOf(data.ptr, data.length);
 //       }
 //       catch (Throwable)
 //       {
 //           // This should never happen; remove when toString() is made nothrow

 //           // BUG: this prevents a compacting GC from working, needs to be fixed
 //           return cast(size_t)cast(void*)this;
 //       }
 //   }

 //   override int opCmp(Object o)
 //   {
 //       if (this is o)
 //           return 0;
 //       TypeInfo ti = cast(TypeInfo)o;
 //       if (ti is null)
 //           return 1;
 //       return dstrcmp(this.toString(), ti.toString());
 //   }

 //   override bool opEquals(Object o)
 //   {
 //       /* TypeInfo instances are singletons, but duplicates can exist
 //        * across DLL's. Therefore, comparing for a name match is
 //        * sufficient.
 //        */
 //       if (this is o)
 //           return true;
 //       auto ti = cast(const TypeInfo)o;
 //       return ti && this.toString() == ti.toString();
 //   }

 //   /// Returns a hash of the instance of a type.
 //   size_t getHash(in void* p) @trusted nothrow const { return cast(size_t)p; }

 //   /// Compares two instances for equality.
 //   bool equals(in void* p1, in void* p2) const { return p1 == p2; }

 //   /// Compares two instances for &lt;, ==, or &gt;.
 //   int compare(in void* p1, in void* p2) const { return _xopCmp(p1, p2); }

 //   /// Returns size of the type.
 //   @property size_t tsize() nothrow pure const @safe @nogc { return 0; }

 //   /// Swaps two instances of the type.
 //   void swap(void* p1, void* p2) const
 //   {
 //       size_t n = tsize;
 //       for (size_t i = 0; i < n; i++)
 //       {
 //           byte t = (cast(byte *)p1)[i];
 //           (cast(byte*)p1)[i] = (cast(byte*)p2)[i];
 //           (cast(byte*)p2)[i] = t;
 //       }
 //   }

 //   /// Get TypeInfo for 'next' type, as defined by what kind of type this is,
 //   /// null if none.
 //   @property inout(TypeInfo) next() nothrow pure inout @nogc { return null; }

 //   /// Return default initializer.  If the type should be initialized to all zeros,
 //   /// an array with a null ptr and a length equal to the type size will be returned.
 //   // TODO: make this a property, but may need to be renamed to diambiguate with T.init...
 //   const(void)[] init() nothrow pure const @safe @nogc { return null; }

 //   /// Get flags for type: 1 means GC should scan for pointers,
 //   /// 2 means arg of this type is passed in XMM register
 //   @property uint flags() nothrow pure const @safe @nogc { return 0; }

 //   /// Get type information on the contents of the type; null if not available
 //   const(OffsetTypeInfo)[] offTi() const { return null; }
 //   /// Run the destructor on the object and all its sub-objects
 //   void destroy(void* p) const {}
 //   /// Run the postblit on the object and all its sub-objects
 //   void postblit(void* p) const {}


 //   /// Return alignment of type
 //   @property size_t talign() nothrow pure const @safe @nogc { return tsize; }

 //   /** Return internal info on arguments fitting into 8byte.
 //    * See X86-64 ABI 3.2.3
 //    */
 //   version (X86_64) int argTypes(out TypeInfo arg1, out TypeInfo arg2) @safe nothrow
 //   {
 //       arg1 = this;
 //       return 0;
 //   }

 //   /** Return info used by the garbage collector to do precise collection.
 //    */
 //   @property immutable(void)* rtInfo() nothrow pure const @safe @nogc { return null; }

 	//!!!!!!!!!!!! EVERYTHING BELOW IS FORTRESS' BARE-BONES IMPLEMENTATION !!!!!!!!!!!!!!!!!!

 	//override string toString() const pure @safe nothrow
 	//{
 	//	return typeid(this).name;
 	//}

	const(void)[] init() nothrow pure const @safe @nogc
	{
		return null;
	}

	size_t getHash(in void * p) @trusted nothrow const {
		return cast(size_t)p;
	}
}

class TypeInfo_Typedef : TypeInfo {
	//void*[5] compilerProvidedData;

	override const(void)[] init() const 
	{
		return m_init.length ? m_init : base.init();
	}

	TypeInfo base;
	string name;
	void[] m_init;
}

class TypeInfo_Enum : TypeInfo_Typedef {
}

class TypeInfo_Const : TypeInfo {
	//void*[13] compilerProvidedData;
}

class TypeInfo_Struct : TypeInfo {
	void*[15] compilerProvidedData;		//was void*[13] but version X86_64 in object.d has two more TypeInfo fields in class
}

class TypeInfo_Interface : TypeInfo {
	TypeInfo_Class info;
}

class TypeInfo_Class : TypeInfo {
	void*[17] compilerProvidedData;
}

//Needed by ModuleInfo for 64-bit
class TypeInfo_l : TypeInfo {

}

struct ModuleInfo {} 
