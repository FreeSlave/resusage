module resusage.common;

package:
version(Windows) {
    import core.sys.windows.windows;
    import std.windows.syserror;

    extern(Windows) HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL  bInheritHandle, DWORD dwProcessId) @system nothrow;

    @trusted HANDLE openProcess(int pid) {
        return wenforce(OpenProcess(0x0400, TRUE, pid), "Could not open process");
    }
} else version(linux) {

    import core.sys.posix.sys.types;
    import core.sys.posix.unistd;
    import core.sys.linux.config;
    
    import std.c.stdio : FILE, fopen, fclose, fscanf;
    import std.conv : to;
    import std.string : toStringz;

    immutable(char*) procSelf = "/proc/self/stat";
    
    @system const(char)* procOfPid(int pid) {
        return toStringz("/proc/" ~ to!string(pid) ~ "/stat");
    }
}
