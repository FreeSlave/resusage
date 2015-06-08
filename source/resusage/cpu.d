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
    
    private struct PlatformSystemCPUWatcher
    {
        @trusted init() {
            readProcStat(lastTotalUser, lastTotalUserLow, lastTotalSys, lastTotalIdle);
        }
        
        @safe double current()
        {
            ulong totalUser, totalUserLow, totalSys, totalIdle;
            readProcStat(totalUser, totalUserLow, totalSys, totalIdle);
            
            double percent;
            
            if (totalUser < lastTotalUser || totalUserLow < lastTotalUserLow ||
                totalSys < lastTotalSys || totalIdle < lastTotalIdle){
                //Overflow detection. Just skip this value.
                return lastPercent;
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
            
            lastPercent = percent;
            return percent;
        }
        
    private:
        ulong lastTotalUser, lastTotalUserLow, lastTotalSys, lastTotalIdle;
        double lastPercent;
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

    private struct PlatformProcessCPUWatcher
    {
        @trusted init(int pid) {
            _proc = toStringz("/proc/" ~ to!string(pid) ~ "/stat");
            lastCPU = clock();
            timesHelper(_proc, lastUserCPU, lastSysCPU);
        }
        
        @trusted init() {
            _proc = "/proc/self/stat".ptr;
            lastCPU = clock();
            timesHelper(_proc, lastUserCPU, lastSysCPU);
        }
        
        @safe double current()
        {
            clock_t nowCPU, nowUserCPU, nowSysCPU;
            double percent;
            
            nowCPU = clock();
            timesHelper(_proc, nowUserCPU, nowSysCPU);
            
            if (nowCPU <= lastCPU || nowUserCPU < lastUserCPU || nowSysCPU < lastSysCPU) {
                //Overflow detection. Just skip this value.
                return lastPercent;
            } else {
                percent = (nowSysCPU - lastSysCPU) + (nowUserCPU - lastUserCPU);
                percent /= (nowCPU - lastCPU);
                percent /= totalCPUs;
                percent *= 100;
            }
            lastCPU = nowCPU;
            lastUserCPU = nowUserCPU;
            lastSysCPU = nowSysCPU;
            lastPercent = percent;
            return percent;
        }
        
    private:
        double lastPercent;
        const(char)* _proc;
        clock_t lastCPU, lastUserCPU, lastSysCPU;
    }
}

///System CPU watcher.
final class SystemCPUWatcher : CPUWatcher
{
    /**
     * Watch system.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe this() {
        _watcher.init();
    }
    
    /**
     * CPU time used by all processes in the system, in percents.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe override double current() {
        return _watcher.current();
    }
    
private:
    PlatformSystemCPUWatcher _watcher;
}

///CPU watcher for single process.
final class ProcessCPUWatcher : CPUWatcher
{
    /**
     * Watch process by id.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe this(int pid) {
        _watcher.init(pid);
    }
    ///ditto, but watch this process.
    @safe this() {
        _watcher.init();
    }
    /**
     * CPU time used by underlying process, in percents.
     * Throws:
     *  ErrnoException on Linux if an error occured.
     */
    @safe override double current() {
        return _watcher.current();
    }
    
private:
    PlatformProcessCPUWatcher _watcher;
}

