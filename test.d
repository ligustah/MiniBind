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

enum Test : byte
{
	A,
	B,
	C
}
class TestClass
{
	private char[] _text;
	
	this(char[] test)
	{
		this._text = test;
	}
	
	this()
	{
		this._text = "default";
	}
	
	this(char[] a, char[] b)
	{
		this._text = a ~ b;
	}
	
	public int test()
	{
		Stdout(_text).newline;
		
		return _text.length;
	}
}

void init(MDThread* t)
{
	TestEnum.init(t);
	TestClassObj.init(t);
}

struct TestEnum
{
static:
	void init(MDThread* t)
	{
		newNamespace(t, "Test");
		
		pushInt(t, Test.A); fielda(t, -2, "A");
		pushInt(t, Test.B); fielda(t, -2, "B");
		pushInt(t, Test.C); fielda(t, -2, "C");
		
		newGlobal(t, "Test");
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
		TestClass inst;
		
		if(numParams == 1 && TypesMatch!(char[])(t))
		{
			// getting parameters
			char[] test = superGet!(char[])(t, 1);
			
			inst = new TestClass(test);
		}
		
		if(numParams == 0)
		{
			inst = new TestClass();
		}
		
		if(numParams == 2 && TypesMatch!(char[], char[])(t))
		{
			// getting parameters
			char[] a = superGet!(char[])(t, 1);
			char[] b = superGet!(char[])(t, 2);
			
			inst = new TestClass(a, b);
		}
		
		if(inst is null) throwException(t, "No such constructor");
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

char[][] testcases = 
[
	"local t = TestClass(\"single string\"); t.test()",
	"local t = TestClass(\"ab\", \"c\"); t.test()",
	"local t = TestClass(); t.test()",
	"local t = TestClass(5); t.test()"
];

void main()
{
	auto test = new TestClass("native instance");
	
	test.test();
	
	MDVM vm;
	auto t = openVM(&vm);
	
	_init(t);
	init(t);
	
	loadString(t, "vararg[0].test()");
	pushNull(t);
	superPush(t, test);
	rawCall(t, -3, 0);
	
	foreach(c; testcases)
		runString(t, c);
	
	closeVM(&vm);
}