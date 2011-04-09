module bindings

import io
import os
import math

class Buffer : StringBuffer
{
	ind = 0
	
	function tab(by : int)
	{
		:ind += math.sign(by)
	}
	
	function opCall(text)
	{
		:append("\t".repeat(:ind))
		:append(text)
		:append("\r\n")
	}
}

function paramsOf(t)
{
	local type = t[t.find("(") + 1 .. #t - 1]
	
	if(!#type)
		return []
	
	local types = type.split(",")
	types.apply(\v->v.strip())
	types.apply(\v->v.split())
	types.apply(\v->{type = v[0], name = v[1]})
	return types
}

function returnTypeOf(t)
{
	return t[0..t.find("(")]
}

function myReduce(arr : array, start, func : function)
{
	if(!#arr)
		arr = [start] ~ arr
	
	return arr.reduce(func)
}

class GenInit
{
	cl
	
	this(cl : GenClass)
	{
		:cl = cl
	}
	
	function generate(b : Buffer)
	{
		b $ ""
		b $ format $ "void init(MDThread* t)"
		b $ "{"
		b.tab(1)
			b $ format $ "CreateClass(t, \"{}\", (CreateClass* c)", :cl.name
			b $ "{"
			b.tab(1)
				b $ "c.method(\"constructor\", &constructor);"
				b $ ""
				foreach(f; :cl.funcs.funcs)
					b $ format $ "c.method(\"{}\", &{0});", f.name
			b.tab(-1)
			b $ "});"
			b $ ""
			b $ format $ "newFunction(t, &BasicClassAllocator!(1, 0), \"{}.allocator\");", :cl.name
			b $ format $ "setAllocator(t, -2);"
			b $ ""
			b $ format $ "setWrappedClass(t, typeid({}));", :cl.name
			b $ format $ "newGlobal(t, \"{}\");", :cl.name
		b.tab(-1)
		b $ "}"
	}
}

class GenCtors
{
	cl
	ctors
	
	this(cl : GenClass, ctors : array)
	{
		:cl = cl
		:ctors = ctors
		:ctors.each(\i,c{
			c.params = paramsOf(c.type)
		})
	}
	
	function generate(b : Buffer)
	{
		local ctor = :ctors[0]
		b $ ""
		b $ "uword constructor(MDThread* t)"
		b $ "{"
		b.tab(1)
			b $ "auto numParams = stackSize(t) - 1;"
			b $ format $ "checkInstParam(t, 0, \"{}\");", :cl.name
			b $ ""
			b $ "// getting parameters"
			foreach(i, param; ctor.params)
			{
				b $ format $ "{} {} = superGet!({0})(t, {});", param.type, param.name, i + 1
			}
			b $ ""
			b $ format $ "{} inst = new {0}({});", :cl.name, string.joinArray(ctor.params.map(\p->p.name), ", ")
			b $ "pushNativeObj(t, inst);"
			b $ "setExtraVal(t, 0, 0);"
			b $ "setWrappedInstance(t, inst, 0);"
			b $ "return 0;"
		b.tab(-1)
		b $ "}"
	}
}

class GenFuncs
{
	cl
	funcs
	
	this(cl : GenClass, funcs : array)
	{
		:cl = cl
		:funcs = funcs
		:funcs.each(\i,c{
			c.params = paramsOf(c.type)
			c.returns = returnTypeOf(c.type)
		})
	}
	
	function generate(b : Buffer)
	{
		foreach(f; :funcs)
		{
			b $ ""
			b $ format $ "uword {}(MDThread* t)", f.name
			b $ "{"
			b.tab(1)
				b $ format $ "{} inst = getThis(t);", :cl.name
				b $ ""
				foreach(i, param; f.params)
				{
					b $ format $ "{} {} = superGet!({0})(t, {});", param.type, param.name, i + 1
				}
				b $ ""
				b $ "//call the function"
				if(f.returns == "void")
				{
					b $ format $ "inst.{}({});", f.name, string.joinArray(f.params.map(\p->p.name), ",")
					b $ "return 0;"
				}
				else
				{
					b $ format $ "{} returns = inst.{}({});", f.returns, f.name, string.joinArray(f.params.map(\p->p.name), ",")
					b $ format $ "superPush!({})(t, returns);", f.returns
					b $ "return 1;"
				}
			b.tab(-1)
			b $ "}"
		}
	}
}

class GenClass
{
	name
	funcs
	ctors
	init
		
	this(name : string, members : array)
	{
		:name = name
		:ctors = GenCtors(this, members.filter $ \i,v->v.kind == "constructor")
		:funcs = GenFuncs(this, members.filter $ \i,v->v.kind == "function")
		:init = GenInit(this)
	}
	
	function generate(b : Buffer)
	{
		b $ format $ "struct {}Obj", :name
		b $ "{"
		b $ "static:"
		b.tab $ 1
			b $ format $ "private {} getThis(MDThread* t)", :name
			b $ "{"
			b.tab $ 1
				b $ format $ "return cast({})getNativeObj(t, getExtraVal(t, -1, 0));", :name
			b.tab $ -1
			b $ "}"
			:ctors.generate(b)
			:funcs.generate(b)
			:init.generate(b)
			
		b.tab $ -1
		b $ "}"
	}
}

local randomStringPool = [toChar(x) for x in 0 .. 128 if toChar(x).isAlNum()]

local function randomString(len : int = 10)
{	
	local buf = StringBuffer()
	for(i : 0 .. len)
	{
		buf.append(randomStringPool[math.rand(#randomStringPool)])
	}
	return buf.toString()
}

function whereis(prog, checkExts : bool = false)
{
	local path = os.getEnv("PATH")
	local exts = ["exe", "bat"]
	
	foreach(p; path.split(";"))
	{
		foreach(ext; exts)
		{
			local fp = io.join(p, format("{}.{}", prog, ext))
			if(io.exists $ fp)
				return fp
		}
	}
}

function getJSON(filename)
{
	local tmpFile = randomString() ~ ".json"
	local args = []
	args ~= whereis("dmd")
	args ~= "-X"
	args ~= format $ "-Xf{}", tmpFile
	args ~= "-c"
	args ~= "-o-"
	args ~= "-I..\\minid"
	args ~= filename
	
	local proc = os.Process()
	
	writefln $ "running {}", args
	proc.execute(args, os.getEnv())
	local reason, code = proc.wait()
	
	if(code)
	{
		throw "compiler error"
	}
	
	//writeln $ io.readFile $ tmpFile
	
	local json = loadJSON $ io.readFile $ tmpFile
	
	io.remove(tmpFile)
	
	return json
}

//printClasses(json)

function main(filename = null, vararg)
{
	local buf = Buffer()
	
	if(!io.exists(filename))
	{
		writeln $ "Error: file does not exist"
		return -1
	}
	local tab = getJSON(filename)[0]
	local i = 0
	
	foreach(mem; tab.members)
	{
		writeln $ mem
		if(mem.kind != "class") continue
		
		local t = GenClass(mem.name, mem.members)
		
		t.generate(buf)
			
		writeln $ buf.toString()
	}
}
