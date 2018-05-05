/+dub.sdl:
name "processusage"
dependency "resusage" path="../"
+/
import std.stdio;
import std.conv;
import resusage.memory;

void main(string[] args)
{
    if (args.length < 2) {
        auto memInfo = processMemInfo();
        writeln("Virtual memory used by this process: ", memInfo.usedVirtMem);
        writeln("Physical memory used by this process: ", memInfo.usedRAM);
    } else {
        string pidStr = args[1];
        auto pid = to!int(pidStr);
        auto memInfo = processMemInfo(pid);
        writeln("Virtual memory used by process: ", memInfo.usedVirtMem);
        writeln("Physical memory used by process: ", memInfo.usedRAM);
    }
}
