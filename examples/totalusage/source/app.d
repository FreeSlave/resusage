import std.stdio;
import resusage;

void main()
{
    writeln("Total virtual memory: ", totalVirtualMemory());
    writeln("Virtual memory currently used: ", virtualMemoryUsed());
    writeln("Total physical memory: ", totalPhysicalMemory());
    writeln("Physical memory currently used: ", physicalMemoryUsed());
}
