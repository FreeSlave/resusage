import std.stdio;
import std.conv;
import std.getopt;
import std.process;
import core.thread;
import core.time;

import resusage.cpu;

int main(string[] args)
{
    CPUWatcher cpuWatcher;
    bool spawn;
    uint rate = 3;
    getopt(args, "spawn", "spawn process and watch its CPU usage", &spawn,
                 "rate", "how often to print current CPU usage (seconds)", &rate
    );
    Pid pid;
    if (spawn) {
        if (args.length <= 1) {
            stderr.writeln("Expected command line to spawn");
            return 1;
        }
        auto command = args[1..$];
        version(Posix) {
            auto devNull = File("/dev/null", "rw");
            pid = spawnProcess(command, devNull, devNull, devNull);
        } else {
            pid = spawnProcess(command);
        }
        cpuWatcher = new ProcessCPUWatcher(pid.processID);
    } else {
        if (args.length < 2) {
            cpuWatcher = new SystemCPUWatcher();
            writeln("Watching system cpu");
        } else {
            string pidStr = args[1];
            cpuWatcher = new ProcessCPUWatcher(to!int(pidStr));
            writeln("Watching cpu for process ", pidStr);
        }
    }
    while(true) {
        Thread.sleep(dur!("seconds")(rate));
        if (pid) {
            auto result = tryWait(pid);
            if (result.terminated) {
                writeln("The spawned process exited");
                return 0;
            }
        }
        double percent = cpuWatcher.current();
        writefln("%s%%", percent);
    }
}
