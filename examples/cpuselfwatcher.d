/+dub.sdl:
name "cpuselfwatcher"
dependency "resusage" path="../"
+/
import std.stdio;
import core.thread;
import core.time;
import std.parallelism;
import std.getopt;
import std.exception;
import resusage.cpu;

void work()
{
    for (size_t i=0; i<size_t.max; ++i) {

    }
}

int main(string[] args)
{
    ushort threads = 1;
    getopt(args, "threads", "Count of threads to run", &threads);
    if (!threads) {
        stderr.writeln("thread count must be not zero");
        return 1;
    }
    if (threads > totalCPUs) {
        stderr.writefln("thread count should not exceed total number of CPU (%s)", totalCPUs);
        return 1;
    }
    auto cpuWatcher = new ProcessCPUWatcher();
    typeof(task!work())[] tasks;
    for (ushort i = 1; i<threads; ++i)
    {
        auto workTask = task!work();
        workTask.executeInNewThread();
        tasks ~= workTask;
    }
    for (size_t i=0; i<size_t.max; ++i) {
        if (i && (i % 2^^28) == 0) {
            writefln("%s%%", cpuWatcher.current());
        }
    }
    for (size_t i=0; i<tasks.length; ++i) {
        tasks[i].yieldForce;
    }
    return 0;
}
