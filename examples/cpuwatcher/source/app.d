import std.stdio;
import std.conv;
import core.thread;
import core.time;

import resusage.cpu;

void main(string[] args)
{
    CPUWatcher cpuWatcher;
    if (args.length < 2) {
        cpuWatcher = new SystemCPUWatcher();
        writeln("Watching system cpu");
    } else {
        string pidStr = args[1];
        cpuWatcher = new ProcessCPUWatcher(to!int(pidStr));
        writeln("Watching cpu for process ", pidStr);
    }
    
    while(true) {
        Thread.sleep(dur!("seconds")(3));
        double percent = cpuWatcher.current();
        writefln("%s%%", percent);
    }
}
