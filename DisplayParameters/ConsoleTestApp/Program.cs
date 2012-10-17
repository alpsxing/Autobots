using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using DisplayParameters;
using System.Threading;

namespace ConsoleTestApp
{
	class Program
	{
		static void Main(string[] args)
		{
			CommonOperation co = new CommonOperation();
			for (int i = 0; i < 1000; i++)
			{
				if (co.SendData("double", 1.0 + i / 3.0) == false)
					break;
				if (co.SendData("int", 2 + i * 2) == false)
					break;
				if (co.SendData("string", "test" + i) == false)
					break;
			}
		}
	}
}
