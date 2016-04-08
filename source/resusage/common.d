/**
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov).
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov 2015
 */

module resusage.common;

package:
static if( __VERSION__ < 2066 ) enum nogc = 1;

import std.process : thisProcessID;

version(Windows) {
    import core.sys.windows.windows;
    import std.windows.syserror;
    
    extern(Windows) @nogc DWORD GetProcessId(in HANDLE Process) @system nothrow;

    extern(Windows) @nogc HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL  bInheritHandle, DWORD dwProcessId) @system nothrow;
    private enum PROCESS_QUERY_INFORMATION = 0x0400;
    @trusted HANDLE openProcess(int pid) {
        return wenforce(OpenProcess(PROCESS_QUERY_INFORMATION, TRUE, pid), "Could not open process");
    }
} else version(linux) {

    import core.sys.posix.sys.types;
    import core.sys.posix.unistd;
    import core.sys.linux.config;
    
    import core.stdc.stdio : FILE, fopen, fclose, fscanf;
    import std.conv : to;
    import std.string : toStringz;

    immutable(char*) procSelf = "/proc/self/stat";
    
    @system const(char)* procOfPid(int pid) {
        return toStringz("/proc/" ~ to!string(pid) ~ "/stat");
    }
}
