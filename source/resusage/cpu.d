/**
 * CPU time used by system or process.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov).
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */

module resusage.cpu;

import std.exception;

///Base interface for cpu watchers
interface CPUWatcher
{
    ///CPU time currently used, in percents.
    @safe double current();
}

version(linux)
{
    import core.sys.posix.sys.types;
    import core.sys.linux.config;
    
    import std.c.stdio : FILE, fopen, fclose, fscanf;
    import std.c.time : clock;
    
    import std.conv : to;
    import std.string : toStringz;
    import std.parallelism : totalCPUs;
    
    private @trusted void readProcStat(ref ulong totalUser, ref ulong totalUserLow, ref ulong totalSys, ref ulong totalIdle)
    {
        FILE* f = errnoEnforce(fopen("/proc/stat", "r"));
        errnoEnforce(fscanf(f, "cpu %Lu %Lu %Lu %Lu", &totalUser, &totalUserLow, &totalSys, &totalIdle) == 4);
        fclose(f);
    }
    
    private class LinuxSystemCPUWatcher : CPUWatcher
    {
        @safe this() {
            readProcStat(lastTotalUser, lastTotalUserLow, lastTotalSys, lastTotalIdle);
        }
        
        @safe override double current()
        {
            ulong totalUser, totalUserLow, totalSys, totalIdle;
            readProcStat(totalUser, totalUserLow, totalSys, totalIdle);
            
            double percent;
            
            if (totalUser < lastTotalUser || totalUserLow < lastTotalUserLow ||
                totalSys < lastTotalSys || totalIdle < lastTotalIdle){
                //Overflow detection. Just skip this value.
                percent = -1.0;
            } else {
                auto total = (totalUser - lastTotalUser) + (totalUserLow - lastTotalUserLow) + (totalSys - lastTotalSys);
                percent = total;
                total += (totalIdle - lastTotalIdle);
                percent /= total;
                percent *= 100;
            }
            
            lastTotalUser = totalUser;
            lastTotalUserLow = totalUserLow;
            lastTotalSys = totalSys;
            lastTotalIdle = totalIdle;
            
            
            return percent;
        }
        
    private:
        ulong lastTotalUser, lastTotalUserLow, lastTotalSys, lastTotalIdle;
    }
    
    private @trusted void timesHelper(const char* proc, ref clock_t utime, ref clock_t stime)
    {
        FILE* f = errnoEnforce(fopen(proc, "r"));
        errnoEnforce(fscanf(f, 
                     "%*d " //pid
                     "%*s " //comm
                     "%*c " //state
                     "%*d " //ppid
                     "%*d " //pgrp
                     "%*d " //session
                     "%*d " //tty_nr
                     "%*d " //tpgid
                     "%*u " //flags
                     "%*lu " //minflt
                     "%*lu " //cminflt
                     "%*lu " //majflt
                     "%*lu " //cmajflt
                     "%lu " //utime
                     "%lu " //stime
                     "%*ld " //cutime
                     "%*ld ", //cstime
               &utime, &stime
              ));
        fclose(f);
    }

    private class LinuxProcessCPUWatcher : CPUWatcher
    {
        @safe this(int pid) {
            _proc = toStringz("/proc/" ~ to!string(pid) ~ "/stat");
            init();
        }
        
        @safe this() {
            _proc = "/proc/self/stat".ptr;
            init();
        }
        
        @safe override double current()
        {
            clock_t nowCPU, nowUserCPU, nowSysCPU;
            double percent;
            
            nowCPU = clock();
            timesHelper(_proc, nowUserCPU, nowSysCPU);
            
            if (nowCPU <= lastCPU || nowUserCPU < lastUserCPU || nowSysCPU < lastSysCPU) {
                //Overflow detection. Just skip this value.
                percent = -1.0;
            } else {
                percent = (nowSysCPU - lastSysCPU) + (nowUserCPU - lastUserCPU);
                percent /= (nowCPU - lastCPU);
                percent /= totalCPUs;
                percent *= 100;
            }
            lastCPU = nowCPU;
            lastUserCPU = nowUserCPU;
            lastSysCPU = nowSysCPU;
            return percent;
        }
        
    private:
        @trusted void init() {
            lastCPU = clock();
            timesHelper(_proc, lastUserCPU, lastSysCPU);
        }
        
        const(char)* _proc;
        clock_t lastCPU, lastUserCPU, lastSysCPU;
    }
    
    alias LinuxSystemCPUWatcher PlatformSystemCPUWatcher;
    alias LinuxProcessCPUWatcher PlatformProcessCPUWatcher;
}

///System CPU watcher.
final class SystemCPUWatcher : PlatformSystemCPUWatcher
{
    /**
     * Watch system.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe this() {
        super();
    }
    
    /**
     * CPU time used by all processes in the system, in percents.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe override double current() {
        return super.current();
    }
}

///CPU watcher for single process.
final class ProcessCPUWatcher : PlatformProcessCPUWatcher
{
    /**
     * Watch process by id.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe this(int pid) {
        super(pid);
    }
    ///ditto, but watch this process.
    @safe this() {
        super();
    }
    /**
     * CPU time used by underlying process, in percents.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe override double current() {
        return super.current();
    }
}

