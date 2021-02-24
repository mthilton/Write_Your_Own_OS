# Directory Structure

This is the structure of the directory with explantaions as to what the purpose of each directory is.

## Structure

``` bash
Write_Your_Own_OS
├── DirectoryStructure.md
├── LICENSE
├── README.md
├── bldenv # Holds the Dockerfile for the build Enviornment.
│   └── Dockerfile
├── src # Holds the sorces for the actual OS
│   └── impl
│       └── x86-64
│           └── boot
│               ├── header.asm
│               └── main.asm
└── target # Holds Linking information. 
           # Currtenly only supports x86-64 but can be 
           # expanded to support any arch
    ├── linker.ld
    └── x86-64
```
