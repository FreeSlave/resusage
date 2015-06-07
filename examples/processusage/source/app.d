import std.stdio;
import std.conv;
import resusage;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Virtual memory used by this process: ", virtualMemoryUsedByProcess());
        writeln("Physical memory used by this process: ", physicalMemoryUsedByProcess());
    } else {
        string pidStr = args[1];
        version(linux)
        {
            import core.sys.posix.sys.types;
            pid_t pid = to!pid_t(pidStr);
            writeln("Virtual memory used by process: ", virtualMemoryUsedByProcess(pid));
            writeln("Physical memory used by process: ", physicalMemoryUsedByProcess(pid));
        }
    }
}
