# Resusage

Obtaining of virtual memory, RAM and CPU usage by the whole system or by single process.

[![Build Status](https://travis-ci.org/FreeSlave/resusage.svg?branch=master)](https://travis-ci.org/FreeSlave/resusage) [![Windows Build Status](https://ci.appveyor.com/api/projects/status/github/FreeSlave/resusage?branch=master&svg=true)](https://ci.appveyor.com/project/FreeSlave/resusage)

Currently works on Linux and Windows.

FreeBSD support is partial - only system-wide memory information and per-process CPU usage can be retrieved now.

## Generating documentation

Ddoc:

    dub build --build=docs

Ddox:

    dub build --build=ddox

## Brief

```d
// import module
import resusage.memory;

// or the whole package
import resusage;

// get system memory usage
SystemMemInfo sysMemInfo = systemMemInfo(); 

// access properties
sysMemInfo.totalRAM;
sysMemInfo.usedRAM;
sysMemInfo.freeRAM;

sysMemInfo.totalVirtMem;
sysMemInfo.usedVirtMem;
sysMemInfo.freeVirtMem;

// actualize values after some amount of time
sysMemInfo.update();

// get memory usage of the current process
ProcessMemInfo procMemInfo = processMemInfo();

// or pass process ID to get info about specific process
int pid = ...;
ProcessMemInfo procMemInfo = processMemInfo(pid);

// access properties
procMemInfo.usedVirtMem;
procMemInfo.usedRAM;

// actualize values after some amount of time
procMemInfo.update();

//import module
import resusage.cpu;

// create watcher to watch system CPU
auto cpuWatcher = new SystemCPUWatcher();

// get actual value when needed
double percent = cpuWatcher.current();

// create CPU watcher for current process
auto cpuWatcher = new ProcessCPUWatcher();

// or for process with given id
int pid = ...;
auto cpuWatcher = new ProcessCPUWatcher(pid);

// get actual value when needed
double percent = cpuWatcher.current();
```

## Examples

### [Total usage](examples/totalusage.d)

Prints total amount of virtual and physical memory (in bytes) and their current usage in the system (in percents).

    dub examples/totalusage.d

### [Process usage](examples/processusage.d)

Prints amount of virtual and physical memory currently used by process, in bytes.

    dub examples/processusage.d `pidof process`

### [CPU Watcher](examples/cpuwatcher.d)

Watch system CPU time:

    dub examples/cpuwatcher.d

Watch process CPU time:

    dub examples/cpuwatcher.d `pidof process`

Spawn prcoess and watch for its CPU time:

    dub examples/cpuwatcher.d --spawn firefox

Adjust the rate of output:

    dub examples/cpuwatcher.d --rate=1 --spawn firefox

### [CPU self watcher](examples/cpuselfwatcher.d)

Consume CPU time and report CPU usage by this process:

    dub examples/cpuselfwatcher --threads=2

E.g. if you have 4 cores and run this example with 2 threads it will report 50% CPU time.

## Platform notes and implementation details

### Windows

In order to provide some functionality **resusage** dynamically loads the following libraries at startup:
 
1. [GetProcessMemoryInfo](https://msdn.microsoft.com/en-us/library/windows/desktop/ms683219(v=vs.85).aspx) to get memory (physical and virtual) used by specific process.
2. [Pdh.dll](https://msdn.microsoft.com/en-us/library/windows/desktop/aa373083(v=vs.85).aspx) to calculate CPU time used by system.

If Psapi.dll or Pdh.dll could not be loaded, corresponding functions will always throw *WindowsException*.

### Linux

Uses [sysinfo](https://linux.die.net/man/2/sysinfo), [clock_gettime](https://linux.die.net/man/3/clock_gettime) and proc stats.

### FreeBSD

Uses [sysctl](https://www.freebsd.org/cgi/man.cgi?query=sysctl&apropos=0&sektion=3&arch=default&format=html) to get RAM and 
[libkvm](https://www.freebsd.org/cgi/man.cgi?query=kvm_open&apropos=0&sektion=3&arch=default&format=html) to get swap memory to calculate virtual memory.
Uses clock_gettime to evaluate CPU usage.
