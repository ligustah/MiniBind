module test;

import minid.api;
import test_bind;

import tango.io.Stdout;

class Blubb
{
	private int _bla;
	
	void bla(int i)
	{
		_bla = i;
	}
	
	void bla(double d)
	{
		_bla = cast(int)d;
	}
	
	void bla(char[] blubb)
	{
		_bla = blubb.length;
	}
	
	int bla()
	{
		return _bla;
	}
	
	void blupp(int i, double d)
	{
		Stdout.formatln("i = {}, d = {}", i, d);
	}
	
	int blubb()
	{
		return 5;
	}
}

void main()
{
		MDVM vm;
	
	auto t = openVM(&vm);
	
	loadStdlibs(t, MDStdlib.All);
	init(t);
	
	runFile(t, "test.md");
}