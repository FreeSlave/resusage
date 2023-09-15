/**
 * The amount of virtual and physycal memory used by system or process.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov).
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
    if (total) {
        return part / cast(double)total * 100.0;
    }
    return 0.0;
}

version(ResUsageDocs)
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

        extern(Windows) @nogc BOOL dummy(HANDLE Process, PROCESS_MEMORY_COUNTERS* ppsmemCounters, DWORD cb) @system nothrow { return 0; }

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
        scope(exit) fclose(f);
        errnoEnforce(fscanf(f,
                     "%*d " ~//pid
                     "%*s " ~//comm
                     "%*c " ~//state
                     "%*d " ~//ppid
                     "%*d " ~//pgrp
                     "%*d " ~//session
                     "%*d " ~//tty_nr
                     "%*d " ~//tpgid
                     "%*u " ~//flags
                     "%*lu " ~//minflt
                     "%*lu " ~//cminflt
                     "%*lu " ~//majflt
                     "%*lu " ~//cmajflt
                     "%*lu " ~//utime
                     "%*lu " ~//stime
                     "%*ld " ~//cutime
                     "%*ld " ~//cstime
                     "%*ld " ~//priority
                     "%*ld " ~//nice
                     "%*ld " ~//num_threads
                     "%*ld " ~//itrealvalue
                     "%*llu " ~//starttime
                     "%lu " ~//vsize
                     "%ld ", //rss
               &vsize, &rss
              ) == 2);
    }

    struct SystemMemInfo
    {
        @nogc @safe ulong totalRAM() const nothrow {
            ulong total = memInfo.totalram;
            total *= memInfo.mem_unit;
            return total;
        }
        @nogc @safe ulong freeRAM() const nothrow {
            ulong free = memInfo.freeram;
            free *= memInfo.mem_unit;
            return free;
        }
        @nogc @safe double freeRAMPercent() const nothrow {
            return percent(totalRAM, freeRAM);
        }
        @nogc @safe ulong usedRAM() const nothrow {
            return totalRAM() - freeRAM();
        }
        @nogc @safe double usedRAMPercent() const nothrow {
            return percent(totalRAM, usedRAM);
        }

        @nogc @safe ulong totalVirtMem() const nothrow {
            ulong total = memInfo.totalram + memInfo.totalswap;
            total *= memInfo.mem_unit;
            return total;
        }
        @nogc @safe ulong freeVirtMem() const nothrow {
            ulong free = memInfo.freeram + memInfo.freeswap;
            free *= memInfo.mem_unit;
            return free;
        }
        @nogc @safe double freeVirtMemPercent() const nothrow {
            return percent(totalVirtMem, freeVirtMem);
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return totalVirtMem() - freeVirtMem();
        }
        @nogc @safe double usedVirtMemPercent() const nothrow {
            return percent(totalVirtMem, usedVirtMem);
        }

        @trusted void update() {
            errnoEnforce(sysinfo(&memInfo) == 0);
        }
    private:
        sysinfo_ memInfo;
    }

    struct ProcessMemInfo
    {
        @nogc @trusted ulong usedRAM() const nothrow {
            return rss * PAGE_SIZE;
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return vsize;
        }

        @trusted void update() {
            memoryUsedHelper(proc, vsize, rss);
        }

        @nogc @safe int processID() const nothrow {
            return pid;
        }

    private:
        void initialize() {
            pid = thisProcessID;
            proc = procSelf;
        }

        void initialize(int procId) {
            pid = procId;
            proc = procOfPid(pid);
        }

        int pid;
        const(char)* proc;
        c_ulong vsize;
        c_long rss;
    }

    __gshared size_t PAGE_SIZE;

    shared static this()
    {
        PAGE_SIZE = sysconf(_SC_PAGESIZE);
    }

} else version(FreeBSD) {

    private {
        import core.sys.posix.fcntl;

        struct kvm_t;

        struct kvm_swap {
            char[32] ksw_devname;
            int ksw_used;
            int ksw_total;
            int ksw_flags;
            int ksw_reserved1;
            int ksw_reserved2;
        };

        extern(C) @nogc @system nothrow {
            int sysctl(const(int)* name, uint namelen, void *oldp, size_t *oldlenp, const(void)* newp, size_t newlen);
            int sysctlbyname(const(char)* name, void *oldp, size_t *oldlenp, const(void)* newp, size_t newlen);

            kvm_t *kvm_open(const(char)*, const(char)*, const(char)*, int, const(char)*);
            int kvm_close(kvm_t *);
            int kvm_getswapinfo(kvm_t*, kvm_swap*, int, int);

            int getpagesize();
        }

    }

    struct SystemMemInfo
    {
        @nogc @safe ulong totalRAM() const nothrow {
            return _totalRam;
        }
        @nogc @safe ulong freeRAM() const nothrow {
            return _freeRam;
        }
        @nogc @safe double freeRAMPercent() const nothrow {
            return percent(totalRAM, freeRAM);
        }
        @nogc @safe ulong usedRAM() const nothrow {
            return totalRAM() - freeRAM();
        }
        @nogc @safe double usedRAMPercent() const nothrow {
            return percent(totalRAM, usedRAM);
        }

        @nogc @safe ulong totalVirtMem() const nothrow {
            return _totalVirtMem;
        }
        @nogc @safe ulong freeVirtMem() const nothrow {
            return _freeVirtMem;
        }
        @nogc @safe double freeVirtMemPercent() const nothrow {
            return percent(totalVirtMem, freeVirtMem);
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return totalVirtMem() - freeVirtMem();
        }
        @nogc @safe double usedVirtMemPercent() const nothrow {
            return percent(totalVirtMem, usedVirtMem);
        }

        @trusted void update() {
            kvm_t* kvmh = errnoEnforce(kvm_open(null, "/dev/null", "/dev/null", O_RDONLY, "kvm_open"));
            scope(exit) kvm_close(kvmh);
            kvm_swap k_swap;

            errnoEnforce(kvm_getswapinfo(kvmh, &k_swap, 1, 0) != -1);

            ulong pageSize = cast(ulong)getpagesize();

            static @trusted int ctlValueByName(const(char)* name) {
                int value;
                size_t len = int.sizeof;
                errnoEnforce(sysctlbyname(name, &value, &len, null, 0) == 0);
                return value;
            }

            int totalPages = ctlValueByName("vm.stats.vm.v_page_count");
            int freePages = ctlValueByName("vm.stats.vm.v_free_count");

            _totalRam = cast(ulong)totalPages * pageSize;
            _freeRam = cast(ulong)freePages * pageSize;

            _totalVirtMem = cast(ulong)k_swap.ksw_total * pageSize + _totalRam;
            _freeVirtMem = cast(ulong)(k_swap.ksw_total - k_swap.ksw_used) * pageSize + _freeRam;

        }
    private:
        ulong _totalRam;
        ulong _freeRam;

        ulong _totalVirtMem;
        ulong _freeVirtMem;
    }

    struct ProcessMemInfo
    {
        @nogc @safe ulong usedRAM() const nothrow {
            return 0;
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return 0;
        }

        @trusted void update() {

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

        int pid;
    }
} else version(OSX) {
    struct SystemMemInfo
    {
        @nogc @safe ulong totalRAM() const nothrow {
            return 0;
        }
        @nogc @safe ulong freeRAM() const nothrow {
            return 0;
        }
        @nogc @safe double freeRAMPercent() const nothrow {
            return 0;
        }
        @nogc @safe ulong usedRAM() const nothrow {
            return 0;
        }
        @nogc @safe double usedRAMPercent() const nothrow {
            return 0;
        }

        @nogc @safe ulong totalVirtMem() const nothrow {
            return 0;
        }
        @nogc @safe ulong freeVirtMem() const nothrow {
            return 0;
        }
        @nogc @safe double freeVirtMemPercent() const nothrow {
            return percent(totalVirtMem, freeVirtMem);
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return totalVirtMem() - freeVirtMem();
        }
        @nogc @safe double usedVirtMemPercent() const nothrow {
            return percent(totalVirtMem, usedVirtMem);
        }
        @trusted void update() {
        }
    }

    struct ProcessMemInfo
    {
        @nogc @safe ulong usedRAM() const nothrow {
            return 0;
        }
        @nogc @safe ulong usedVirtMem() const nothrow {
            return 0;
        }

        @trusted void update() {
        }

        @nogc @safe int processID() const nothrow {
            return pid;
        }

    private:
        void initialize() {
        }

        void initialize(int procId) {
        }

        int pid;
        const(char)* proc;
    }
}
