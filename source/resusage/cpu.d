/**
 * CPU time used by system or process.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov).
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov 2015
 *
 * Note: Every function may throw on fail ($(B ErrnoException) on Linux, $(B WindowsException) on Windows).
 */

module resusage.cpu;
import resusage.common;

import std.exception;

///Base interface for cpu watchers
interface CPUWatcher
{
    ///CPU time currently used, in percents.
    @safe double current();
}

version(Windows)
{
    private import core.stdc.string : memcpy;

    private {
        alias HANDLE PDH_HQUERY;
        alias HANDLE PDH_HCOUNTER;
        alias LONG PDH_STATUS;

        struct PDH_FMT_COUNTERVALUE
        {
            DWORD CStatus;
            static union DUMMYUNIONNAME
            {
                LONG     longValue;
                double   doubleValue;
                LONGLONG largeValue;
                LPCSTR   AnsiStringValue;
                LPCWSTR  WideStringValue;
            }
            DUMMYUNIONNAME dummyUnion;
        };

        extern(Windows) @nogc PDH_STATUS openQueryDummy(
            const(wchar)* szDataSource,
            DWORD_PTR dwUserData,
            PDH_HQUERY *phQuery) @system nothrow { return 0; }

        extern(Windows) @nogc PDH_STATUS addCounterDummy(
            PDH_HQUERY Query,
            const(wchar)* szFullCounterPath,
            DWORD_PTR dwUserData,
            PDH_HCOUNTER *phCounter) @system nothrow { return 0; }

        extern(Windows) @nogc PDH_STATUS queryDataDummy(
            PDH_HQUERY hQuery) @system nothrow { return 0; }

        extern(Windows) @nogc PDH_STATUS formattedValueDummy(
            PDH_HCOUNTER hCounter,
            DWORD dwFormat,
            LPDWORD lpdwType,
            PDH_FMT_COUNTERVALUE* pValue) @system nothrow { return 0; }

        alias typeof(&openQueryDummy) func_PdhOpenQuery;
        alias typeof(&addCounterDummy) func_PdhAddCounter;
        alias typeof(&queryDataDummy) func_PdhCollectQueryData;
        alias typeof(&formattedValueDummy) func_PdhGetFormattedCounterValue;

        __gshared func_PdhOpenQuery PdhOpenQuery;
        __gshared func_PdhAddCounter PdhAddCounter;
        __gshared func_PdhCollectQueryData PdhCollectQueryData;
        __gshared func_PdhGetFormattedCounterValue PdhGetFormattedCounterValue;

        __gshared DWORD pdhError;

        enum PDH_FMT_DOUBLE = 0x00000200;
    }

    shared static this()
    {
        debug import std.stdio : writeln;

        HMODULE pdhLib = LoadLibraryA("Pdh");
        if (pdhLib) {
            PdhOpenQuery = cast(func_PdhOpenQuery) GetProcAddress(pdhLib, "PdhOpenQueryW");
            PdhAddCounter = cast(func_PdhAddCounter) GetProcAddress(pdhLib, "PdhAddEnglishCounterW");

            /*
            PdhAddEnglishCounterW is defined only since Windows Vista or Windows Server 2008.
            Load locale-dependent PdhAddCounter on older Windows versions and hope that user has english locale.
            */
            if (PdhAddCounter is null) {
                PdhAddCounter = cast(func_PdhAddCounter) GetProcAddress(pdhLib, "PdhAddCounterW");
                debug writeln("Warning: resusage will use PdhAddCounter, because could not find PdhAddEnglishCounter");
            }

            PdhCollectQueryData = cast(func_PdhCollectQueryData) GetProcAddress(pdhLib, "PdhCollectQueryData");
            PdhGetFormattedCounterValue = cast(func_PdhGetFormattedCounterValue) GetProcAddress(pdhLib, "PdhGetFormattedCounterValue");
        }

        if (!isPdhLoaded()) {
            pdhError = GetLastError();
        }
    }

    private @nogc @trusted bool isPdhLoaded() {
        return PdhOpenQuery && PdhAddCounter && PdhCollectQueryData && PdhGetFormattedCounterValue;
    }

    private struct PlatformSystemCPUWatcher
    {
        @trusted void initialize() {
            if (!isPdhLoaded()) {
                throw new WindowsException(pdhError, "Pdh.dll is not loaded");
            }

            wenforce(PdhOpenQuery(null, 0, &cpuQuery) == ERROR_SUCCESS, "Could not query pdh data");
            wenforce(PdhAddCounter(cpuQuery, "\\Processor(_Total)\\% Processor Time"w.ptr, 0, &cpuTotal) == ERROR_SUCCESS, "Could not add pdh counter");
            wenforce(PdhCollectQueryData(cpuQuery) == ERROR_SUCCESS, "Could not collect pdh query data");
        }

        @trusted double current()
        {
            PDH_FMT_COUNTERVALUE counterVal;
            wenforce(PdhCollectQueryData(cpuQuery) == ERROR_SUCCESS, "Could not collect pdh query data");
            wenforce(PdhGetFormattedCounterValue(cpuTotal, PDH_FMT_DOUBLE, null, &counterVal) == ERROR_SUCCESS, "Could not format pdh counter data");
            return counterVal.dummyUnion.doubleValue;
        }

    private:
        PDH_HQUERY cpuQuery;
        PDH_HCOUNTER cpuTotal;
    }

    private @trusted void timesHelper(int pid, ref ULARGE_INTEGER now, ref ULARGE_INTEGER sys, ref ULARGE_INTEGER user)
    {
        HANDLE handle = openProcess(pid);
        scope(exit) CloseHandle(handle);

        FILETIME ftime, fsys, fuser;
        GetSystemTimeAsFileTime(&ftime);
        memcpy(&now, &ftime, FILETIME.sizeof);

        GetProcessTimes(handle, &ftime, &ftime, &fsys, &fuser);
        memcpy(&sys, &fsys, FILETIME.sizeof);
        memcpy(&user, &fuser, FILETIME.sizeof);
    }

    private struct PlatformProcessCPUWatcher
    {
        @trusted void initialize(int procId) {
            pid = procId;
            timesHelper(pid, lastCPU, lastSysCPU, lastUserCPU);
        }

        @trusted void initialize(HANDLE procHandle) {
            pid = GetProcessId(procHandle);
            timesHelper(pid, lastCPU, lastSysCPU, lastUserCPU);
        }

        @trusted void initialize() {
            pid = thisProcessID();
            timesHelper(pid, lastCPU, lastSysCPU, lastUserCPU);
        }

        @trusted double current()
        {
            ULARGE_INTEGER now, sys, user;
            timesHelper(pid, now, sys, user);

            double percent = (sys.QuadPart - lastSysCPU.QuadPart) + (user.QuadPart - lastUserCPU.QuadPart);
            percent /= (now.QuadPart - lastCPU.QuadPart);

            lastCPU = now;
            lastUserCPU = user;
            lastSysCPU = sys;

            return percent * 100;
        }

        @trusted int processID() const nothrow {
            return pid;
        }

    private:
        int pid;
        ULARGE_INTEGER lastCPU, lastUserCPU, lastSysCPU;
    }
} else version(linux) {
    private @trusted void readProcStat(ref ulong totalUser, ref ulong totalUserLow, ref ulong totalSys, ref ulong totalIdle)
    {
        FILE* f = errnoEnforce(fopen("/proc/stat", "r"));
        scope(exit) fclose(f);
        errnoEnforce(fscanf(f, "cpu %Lu %Lu %Lu %Lu", &totalUser, &totalUserLow, &totalSys, &totalIdle) == 4);
    }

    private struct PlatformSystemCPUWatcher
    {
        @trusted void initialize() {
            readProcStat(lastTotalUser, lastTotalUserLow, lastTotalSys, lastTotalIdle);
        }

        @trusted double current()
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
} else version(FreeBSD) {
    private struct PlatformSystemCPUWatcher
    {
        @trusted void initialize() {

        }

        @trusted double current()
        {
            return 0.0;
        }

    private:

    }
} else version(OSX) {
    private struct PlatformSystemCPUWatcher
    {
        @trusted void initialize() {

        }

        @trusted double current()
        {
            return 0.0;
        }

    private:

    }

    private struct PlatformProcessCPUWatcher
    {
        @trusted void initialize(int pid) {
            _pid = pid;
        }

        @trusted void initialize() {
            _pid = thisProcessID;
        }

        @trusted double current()
        {
            return 0.0;
        }

        @trusted int processID() const nothrow {
            return _pid;
        }

    private:
        int _pid;
    }
}

static if (is(typeof({import core.sys.posix.time : CLOCK_MONOTONIC;})))
{
    private import core.sys.posix.time;
    private import core.time;
    private import core.sys.posix.unistd;
    private import core.stdc.errno;
    extern(C) @nogc int clock_getcpuclockid(pid_t pid, clockid_t *clock_id) nothrow;

    private auto getClockTime(clockid_t clockId)
    {
        timespec spec;
        auto result = clock_gettime(clockId, &spec);
        if (result != 0) {
            if (errno == EINVAL) {
                throw new ErrnoException("clock_gettime failed, the watched process probably died");
            } else {
                throw new ErrnoException("clock_gettime");
            }
        } else {
            return dur!"seconds"(spec.tv_sec) + dur!"nsecs"(spec.tv_nsec);
        }
    }

    private struct PlatformProcessCPUWatcher
    {
        @trusted void initialize(int pid) {
            _pid = pid;
            int result = clock_getcpuclockid(pid, &clockId);
            if (result == 0) {
                lastCPUTime = getClockTime(clockId);
            } else {
                errno = result;
                errnoEnforce(false, "clock_getcpuclockid");
            }
            lastTime = getClockTime(CLOCK_MONOTONIC);
        }

        @trusted void initialize() {
            static if (is(typeof({import core.sys.posix.time : CLOCK_PROCESS_CPUTIME_ID;}))) {
                import core.sys.posix.time : CLOCK_PROCESS_CPUTIME_ID;
                _pid = getpid();
                clockId = CLOCK_PROCESS_CPUTIME_ID;
                lastCPUTime = getClockTime(clockId);
                lastTime = getClockTime(CLOCK_MONOTONIC);
            } else {
                initialize(getpid());
            }
        }

        @trusted double current()
        {
            auto nowTime = getClockTime(CLOCK_MONOTONIC);
            auto nowCPUTime = getClockTime(clockId);
            double percent;

            if (nowTime < lastTime || nowCPUTime < lastCPUTime) {
                //Overflow detection. Just skip this value.
                return lastPercent;
            } else {
                percent = (nowCPUTime - lastCPUTime).total!"hnsecs";
                percent /= (nowTime - lastTime).total!"hnsecs";
                percent *= 100;
            }
            lastTime = nowTime;
            lastCPUTime = nowCPUTime;
            lastPercent = percent;
            return percent;
        }

        @trusted int processID() const nothrow {
            return _pid;
        }

    private:
        int _pid;
        double lastPercent;
        clockid_t clockId;
        Duration lastTime;
        Duration lastCPUTime;
    }
}

///System CPU watcher.
final class SystemCPUWatcher : CPUWatcher
{
    /**
     * Watch system.
     */
    @safe this() {
        _watcher.initialize();
    }

    /**
     * CPU time used by all processes in the system, in percents.
     * This returns the average value amongst all CPUs, thus can't exceed 100.
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
     * Params:
     * pid = ID number of process. Can be process handle on Windows.
     */
    @safe this(int pid) {
        _watcher.initialize(pid);
    }

    version(Windows) {
        @safe this(HANDLE procHandle) {
            _watcher.initialize(procHandle);
        }
    }

    ///ditto, but watch this process.
    @safe this() {
        _watcher.initialize();
    }
    /**
     * CPU time used by underlying process, in percents between 0 and 100.
     */
    @safe override double current() {
        import std.parallelism : totalCPUs;
        return _watcher.current() / totalCPUs;
    }

    /**
     * CPU time used by underlying process. The value range depends on CPU count.
     * E.g. on the system with 4 CPUs it will be between 0 and 400 (considering all units are available for the process).
     */
    @safe double currentTotal() {
        return _watcher.current();
    }

    ///The process ID number.
    @safe int processID() const nothrow {
        return _watcher.processID();
    }

private:
    PlatformProcessCPUWatcher _watcher;
}
