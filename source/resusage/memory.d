/**
 * The amount of virtual and physycal memory used by system or process.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov).
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov 2015
 * 
 * Note: Every function may throw on fail ($(B ErrnoException) on Linux, $(B WindowsException) on Windows).
 */

module resusage.memory;
import resusage.common;

import std.exception;

///Get system memory information.
@trusted SystemMemInfo systemMemInfo()
{
    SystemMemInfo memInfo;
    memInfo.update();
    return memInfo;
}

///Get memory info for current process.
@trusted ProcessMemInfo processMemInfo() {
    ProcessMemInfo memInfo;
    memInfo.initialize();
    memInfo.update();
    return memInfo;
}

/**
 * Get memory info for specific process.
 * Params:
 *  pid = Process ID of specific process. On Windows also can be process handle.
 */
@trusted ProcessMemInfo processMemInfo(int pid) {
    ProcessMemInfo memInfo;
    memInfo.initialize(pid);
    memInfo.update();
    return memInfo;
}

private @nogc @safe double percent(ulong total, ulong part) pure nothrow {
    return part / cast(double)total * 100.0;
}

version(Docs)
{
    ///System-wide memory information.
    struct SystemMemInfo
    {
        ///Total physycal memory in the system, in bytes.
        @nogc @safe ulong totalRAM() const nothrow;
        
        ///Amout of physycal memory currently available (free), in bytes.
        @nogc @safe ulong freeRAM() const nothrow;
        
        ///Amout of physycal memory currently available (free), in percents of total physycal memory.
        @nogc @safe double freeRAMPercent() const nothrow;
        
        ///Amout of physycal memory currently in use, in bytes.
        @nogc @safe ulong usedRAM() const nothrow;
        
        ///Amout of physycal memory currently in use, in percents of total physycal memory.
        @nogc @safe double usedRAMPercent() const nothrow;
        
        ///Total virtual memory in the system, in bytes.
        @nogc @safe ulong totalVirtMem() const nothrow;
        
        ///Amout of virtual memory currently available (free), in bytes.
        @nogc @safe ulong freeVirtMem() const nothrow;
        
        ///Amout of virtual memory currently available (free), in percents of total virtual memory.
        @nogc @safe double freeVirtMemPercent() const nothrow;
        
        ///Amout of virtual memory currently in use, in bytes.
        @nogc @safe ulong usedVirtMem() const nothrow;
        
        ///Amout of virtual memory currently in use, in percents of total virtual memory.
        @nogc @safe double usedVirtMemPercent() const nothrow;
        
        ///Actualize values.
        @trusted void update();
    }
    
    ///Single process memory information.
    struct ProcessMemInfo
    {
        ///Amount of physycal memory (RAM) currently used by single process, in bytes.
        @nogc @safe ulong usedRAM() const nothrow;
        
        ///Amount of virtual memory currently used by single process, in bytes.
        @nogc @safe ulong usedVirtMem() const nothrow;
        
        ///Actualize values.
        @trusted void update();
        
        ///ID of underlying process.
        @nogc @safe int processID() const nothrow;
        
    private:
        void initialize();
        void initialize(int pid);
    }
} else version(Windows) {

    @trusted ProcessMemInfo processMemInfo(HANDLE procHandle) {
        ProcessMemInfo memInfo;
        memInfo.initialize(procHandle);
        memInfo.update();
        return memInfo;
    }

    private {
        alias ulong DWORDLONG;
        
        struct MEMORYSTATUSEX {
            DWORD     dwLength;
            DWORD     dwMemoryLoad;
            DWORDLONG ullTotalPhys;
            DWORDLONG ullAvailPhys;
            DWORDLONG ullTotalPageFile;
            DWORDLONG ullAvailPageFile;
            DWORDLONG ullTotalVirtual;
            DWORDLONG ullAvailVirtual;
            DWORDLONG ullAvailExtendedVirtual;
        };
        
        extern(Windows) BOOL GlobalMemoryStatusEx(MEMORYSTATUSEX* lpBuffer) @system nothrow;
        
        struct PROCESS_MEMORY_COUNTERS {
            DWORD  cb;
            DWORD  PageFaultCount;
            SIZE_T PeakWorkingSetSize;
            SIZE_T WorkingSetSize;
            SIZE_T QuotaPeakPagedPoolUsage;
            SIZE_T QuotaPagedPoolUsage;
            SIZE_T QuotaPeakNonPagedPoolUsage;
            SIZE_T QuotaNonPagedPoolUsage;
            SIZE_T PagefileUsage;
            SIZE_T PeakPagefileUsage;
        };
        
        struct PROCESS_MEMORY_COUNTERS_EX {
            DWORD  cb;
            DWORD  PageFaultCount;
            SIZE_T PeakWorkingSetSize;
            SIZE_T WorkingSetSize;
            SIZE_T QuotaPeakPagedPoolUsage;
            SIZE_T QuotaPagedPoolUsage;
            SIZE_T QuotaPeakNonPagedPoolUsage;
            SIZE_T QuotaNonPagedPoolUsage;
            SIZE_T PagefileUsage;
            SIZE_T PeakPagefileUsage;
            SIZE_T PrivateUsage;
        };
        
        extern(Windows) @nogc BOOL dummy(in HANDLE Process, PROCESS_MEMORY_COUNTERS* ppsmemCounters, DWORD cb) @system nothrow { return 0; }
        
        alias typeof(&dummy) func_GetProcessMemoryInfo;
        __gshared func_GetProcessMemoryInfo GetProcessMemoryInfo;
        __gshared DWORD psApiError;
    }
    
    @nogc @trusted bool isPsApiLoaded() {
        return GetProcessMemoryInfo !is null;
    }
    
    shared static this()
    {
        HMODULE psApiLib = LoadLibraryA("Psapi");
        if (psApiLib) {
            GetProcessMemoryInfo = cast(func_GetProcessMemoryInfo)GetProcAddress(psApiLib, "GetProcessMemoryInfo");
        }
        
        if (GetProcessMemoryInfo is null) {
            psApiError = GetLastError();
        }
    }
    
    struct SystemMemInfo
    {
        @nogc @safe ulong totalRAM() const nothrow {
            return memInfo.ullTotalPhys;
        }
        @nogc @safe ulong freeRAM() const nothrow {
            return memInfo.ullAvailPhys;
        }
        @nogc @safe double freeRAMPercent() const nothrow {
            return percent(totalRAM, freeRAM);
        }
        @nogc @safe ulong usedRAM() const nothrow {
            return memInfo.ullTotalPhys - memInfo.ullAvailPhys;
        }
        @nogc @safe double usedRAMPercent() const nothrow {
            return percent(totalRAM, usedRAM);
        }
        
        @nogc @safe ulong totalVirtMem() const nothrow {
            return memInfo.ullTotalPageFile;
        }
        @nogc @safe ulong freeVirtMem() const nothrow {
            return memInfo.ullAvailPageFile;
        }
        @nogc @safe double freeVirtMemPercent() const nothrow {
            return percent(totalVirtMem, freeVirtMem);
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return memInfo.ullTotalPageFile - memInfo.ullAvailPageFile;
        }
        @nogc @safe double usedVirtMemPercent() const nothrow {
            return percent(totalVirtMem, usedVirtMem);
        }
        
        @trusted void update() {
            memInfo.dwLength = MEMORYSTATUSEX.sizeof;
            wenforce(GlobalMemoryStatusEx(&memInfo), "Could not get memory status");
        }
    private:
        MEMORYSTATUSEX memInfo;
    }
    
    struct ProcessMemInfo
    {
        @nogc @safe ulong usedRAM() const nothrow {
            return pmc.WorkingSetSize;
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return pmc.PrivateUsage;
        }
        
        @trusted void update() {
            if (!isPsApiLoaded()) {
                throw new WindowsException(psApiError, "Psapi.dll is not loaded");
            }
        
            HANDLE handle = openProcess(pid);
            scope(exit) CloseHandle(handle);
            
            wenforce(GetProcessMemoryInfo(handle, cast(PROCESS_MEMORY_COUNTERS*)&pmc, pmc.sizeof), "Could not get process memory info");
        }
        
        @nogc @safe int processID() const nothrow {
            return pid;
        }
        
    private:
        void initialize() {
            pid = thisProcessID;
        }
    
        void initialize(int procId) {
            pid = procId;
        }
        
        void initialize(HANDLE procHandle) {
            pid = GetProcessId(procHandle);
        }
    
        int pid;
        PROCESS_MEMORY_COUNTERS_EX pmc;
    }
    
} else version(linux) {
    private {
        static if (is(typeof({ import core.sys.linux.sys.sysinfo; }))) {
            import core.sys.linux.sys.sysinfo;
        } else {
            pragma(msg, "core.sys.linux.sys.sysinfo not found, fallback will be used.");
            extern(C) @nogc nothrow:
            struct sysinfo_
            {
                c_long uptime;     /* Seconds since boot */
                c_ulong[3] loads;  /* 1, 5, and 15 minute load averages */
                c_ulong totalram;  /* Total usable main memory size */
                c_ulong freeram;   /* Available memory size */
                c_ulong sharedram; /* Amount of shared memory */
                c_ulong bufferram; /* Memory used by buffers */
                c_ulong totalswap; /* Total swap space size */
                c_ulong freeswap;  /* swap space still available */
                ushort procs;      /* Number of current processes */
                ushort pad;        /* Explicit padding for m68k */
                c_ulong totalhigh; /* Total high memory size */
                c_ulong freehigh;  /* Available high memory size */
                uint mem_unit;     /* Memory unit size in bytes */
                ubyte[20-2 * c_ulong.sizeof - uint.sizeof] _f; /* Padding: libc5 uses this.. */
            }
            int sysinfo(sysinfo_ *info);
        }
    }
    
    private @trusted void memoryUsedHelper(const(char)* proc, ref c_ulong vsize, ref c_long rss)
    {
        FILE* f = errnoEnforce(fopen(proc, "r"));
        pid_t pid;
        errnoEnforce(fscanf(f, 
                     "%d " //pid
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
                     "%*lu " //utime
                     "%*lu " //stime
                     "%*ld " //cutime
                     "%*ld " //cstime
                     "%*ld " //priority
                     "%*ld " //nice
                     "%*ld " //num_threads
                     "%*ld " //itrealvalue
                     "%*llu " //starttime
                     "%lu " //vsize
                     "%ld ", //rss
               &pid, &vsize, &rss
              ));
        rss *= sysconf(_SC_PAGESIZE);
        fclose(f);
    }
    
    
    @trusted ulong totalVirtualMemory()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong totalMem = memInfo.totalram;
        totalMem += memInfo.totalswap;
        totalMem *= memInfo.mem_unit;
        return totalMem;
    }
    
    @trusted ulong virtualMemoryUsed()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong memUsed = memInfo.totalram - memInfo.freeram;
        memUsed += memInfo.totalswap - memInfo.freeswap;
        memUsed *= memInfo.mem_unit;
        return memUsed;
    }
    
    @trusted ulong virtualMemoryUsedByProcess()
    {
        c_ulong vsize;
        c_long rss;
        memoryUsedHelper(procSelf, vsize, rss);
        return vsize;
    }
    
    @trusted ulong virtualMemoryUsedByProcess(int pid)
    {
        c_ulong vsize;
        c_long rss;
        
        memoryUsedHelper(procOfPid(pid), vsize, rss);
        return vsize;
    }
    
    @trusted ulong totalPhysicalMemory()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong totalMem = memInfo.totalram;
        totalMem *= memInfo.mem_unit;
        return totalMem;
    }
    
    @trusted ulong physicalMemoryUsed()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong memUsed = memInfo.totalram - memInfo.freeram;
        memUsed *= memInfo.mem_unit;
        return memUsed;
    }
    
    @trusted ulong physicalMemoryUsedByProcess()
    {
        c_ulong vsize;
        c_long rss;
        memoryUsedHelper(procSelf, vsize, rss);
        return rss;
    }
    
    @trusted ulong physicalMemoryUsedByProcess(int pid)
    {
        c_ulong vsize;
        c_long rss;
        
        memoryUsedHelper(procOfPid(pid), vsize, rss);
        return rss;
    }
}
