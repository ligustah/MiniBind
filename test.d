module test;

import tango.io.Stdout;
import minid.bind;
import minid.api;

private void _init(MDThread* t)
{
	getRegistry(t);
	pushString(t, "minid.bind.initialized");

	if(!opin(t, -1, -2))
	{
		newTable(t);       fielda(t, -3, "minid.bind.WrappedClasses");
		newTable(t);       fielda(t, -3, "minid.bind.WrappedInstances");
		pushBool(t, true); fielda(t, -3);
		pop(t);
	}
	else
		pop(t, 2);
}

class TestClass
{
	private char[] _text;
	
	this(char[] test)
	{
		this._text = test;
	}
	
	public int test()
	{
		Stdout(_text).newline;
		
		return _text.length;
	}
}

struct TestClassObj
{
static:
	private TestClass getThis(MDThread* t)
	{
		return cast(TestClass)getNativeObj(t, getExtraVal(t, -1, 0));
	}
	
	uword constructor(MDThread* t)
	{
		auto numParams = stackSize(t) - 1;
		checkInstParam(t, 0, "TestClass");
		
		// getting parameters
		char[] test = superGet!(char[])(t, 1);
		
		TestClass inst = new TestClass(test);
		pushNativeObj(t, inst);
		setExtraVal(t, 0, 0);
		setWrappedInstance(t, inst, 0);
		return 0;
	}
	
	uword test(MDThread* t)
	{
		TestClass inst = getThis(t);
		
		
		//call the function
		int returns = inst.test();
		superPush!(int)(t, returns);
		return 1;
	}
	
	void init(MDThread* t)
	{
		_init(t);
		
		CreateClass(t, "TestClass", (CreateClass* c)
		{
			c.method("constructor", &constructor);
			
			c.method("test", &test);
		});
		
		newFunction(t, &BasicClassAllocator!(1, 0), "TestClass.allocator");
		setAllocator(t, -2);

		setWrappedClass(t, typeid(TestClass));
		newGlobal(t, "TestClass");
	}
}

void main()
{
	auto test = new TestClass("blubb");
	
	test.test();
	
	MDVM vm;
	auto t = openVM(&vm);
	
	TestClassObj.init(t);
	
	loadString(t, "vararg[0].test()");
	pushNull(t);
	superPush(t, test);
	rawCall(t, -3, 0);
	
	runString(t, "local t = TestClass(\"moep\"); t.test()");
	
	closeVM(&vm);
}