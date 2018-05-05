/+dub.sdl:
name "totalusage"
dependency "resusage" path="../"
+/
import std.stdio;
import resusage.memory;

void main()
{
    auto memInfo = systemMemInfo();

    writefln("Total virtual memory: %s bytes", memInfo.totalVirtMem);
    writefln("Virtual memory currently in use: %s bytes (%s %%)", memInfo.usedVirtMem, memInfo.usedVirtMemPercent);
    writefln("Total physical memory (RAM): %s bytes", memInfo.totalRAM);
    writefln("Physical memory (RAM) currently in use: %s bytes (%s %%)", memInfo.usedRAM, memInfo.usedRAMPercent);
}
