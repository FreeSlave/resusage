import std.stdio;
import std.conv;
import resusage.memory;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Virtual memory used by this process: ", virtualMemoryUsedByProcess());
        writeln("Physical memory used by this process: ", physicalMemoryUsedByProcess());
    } else {
        string pidStr = args[1];

        auto pid = to!int(pidStr);
        writeln("Virtual memory used by process: ", virtualMemoryUsedByProcess(pid));
        writeln("Physical memory used by process: ", physicalMemoryUsedByProcess(pid));
    }
}
