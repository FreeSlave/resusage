import std.stdio;
import resusage.memory;

void main()
{
    auto totalVirtMem = totalVirtualMemory();
    auto virtMemUsed = virtualMemoryUsed();
    
    auto totalPhysMem = totalPhysicalMemory();
    auto physMemUsed = physicalMemoryUsed();
    
    writefln("Total virtual memory: %s bytes", totalVirtMem);
    writefln("Virtual memory currently in use: %s bytes (%s %%)", virtMemUsed, virtMemUsed/cast(double)totalVirtMem * 100);
    writefln("Total physical memory: %s bytes", totalPhysMem);
    writefln("Physical memory currently in use: %s bytes (%s %%)", physMemUsed, physMemUsed/cast(double)totalPhysMem * 100);
}
