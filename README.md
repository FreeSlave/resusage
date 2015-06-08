# Resusage

Obtaining of virtual memory, RAM and CPU usage by the whole system or by single process.

[![Build Status](https://travis-ci.org/MyLittleRobo/resusage.svg?branch=master)](https://travis-ci.org/MyLittleRobo/resusage)

Currently works only on Linux.

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
