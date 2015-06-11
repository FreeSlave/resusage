# Resusage

Obtaining of virtual memory, RAM and CPU usage by the whole system or by single process.

[![Build Status](https://travis-ci.org/MyLittleRobo/resusage.svg?branch=master)](https://travis-ci.org/MyLittleRobo/resusage)

Currently works on Linux and Windows.

## Documentation

Ddoc:

    dub build --build=docs
    
Ddox:

    dub build --build=ddox

## Examples

### Total usage

Prints total amount of virtual and physical memory and their current usage in the system, in bytes.

    dub run resusage:totalusage 

### Process usage

Prints amount of virtual and physical memory used by process.

    dub run resusage:processusage -- `pidof process`

### CPU Watcher

Watch system CPU time:

    dub run resusage:cpuwatcher

Watch process CPU time:

    dub run resusage:cpuwatcher -- `pidof process`

## Platform notes and implementation details

### Windows

In order to provide some functionality **resusage** dynamically loads the following libraries at startup:
 
1. Psapi.dll to get memory (physical and virtual) used by specific process.
2. Pdh.dll to calculate CPU time used by system.

If specific library could be loaded, corresponding functions will always throw *WindowsException*.
