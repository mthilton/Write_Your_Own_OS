; This is the Bootstrapping asm file. First we do check to see if
; we were started with the proper boot loader. Then we check to see if 
; 64-bit mode is supported. This OS is 64-bit only. If 64-bit mode is
; not enabled, we crash and fail. Then we set up our virtual memory
; by mapping l4-l2 page tables. The l2 page table addresses memory directly.
; Finally we load the GDT thus enabling 64-bit mode with virtual memory.
; This then starts the 64-bit start routine

global start ; Allows the file to be accessed by other files
extern long_mode_start

; This section has all of the 'source code' for the file. 
; This is where instructions are stored in our memory 
section .text
bits 32       ; sets the bit mode to 32 (will change to 64 if supported)
start:
    ; Creation of the stack for function calls 
    mov esp, stack_top

    ; These are checks to make sure that things were stared properly
    call check_multiboot ; Ensure we actually got multiboot, checking the checksum
    call check_cpuid     ; Geting the cpu info to see if we have access to long mode
    call check_long_mode ; Checking to see if the long mode flag is set

    ; This sets up paging (Vitual Memory)
    call setup_page_tables
    call enable_paging

    ; Load the GDT and run the 64-bit start routine
    lgdt[gdt64.pointer]
    jmp gdt64.code_segment:long_mode_start

    hlt 
    

; subroutine that errors if we did not properly use multiboot2 as our bootloader
; We check to see if the eax reg has a magic value, if it does then we just return
; otherwise we run our error handler.
; It is known that multiboot2 sets the eax reg to be the magic number if successful
check_multiboot:
    cmp eax, 0x36d76289
    jne .no_multiboot
    ret
.no_multiboot:
    mov al, "M"
    jmp error

; Checks the cpu id if it is avalible
; To check, we use the flags register and attempt to flip bit 21
check_cpuid:
    pushfd           ; Copy the flags from the flag regs to a gpr
    pop eax
    mov ecx, eax     ; copy the flags so we can compare them later
    xor eax, 1 << 21 ; Attempt to flip the 21st bit
    push eax         ; Put the result back into the flags reg
    popfd
    pushfd           ; Copy the flags back to the gpr, if the bit is still flipped, then the
    pop eax          ; cpu does not support cpuid. If supported, the cpu would have unflipped the bit
    push ecx         ; Restore the flags to their original state
    popfd
    cmp eax, ecx     ; Check the flipped bit
    je .no_cpuid     ; If eq, jump to the no_cpuid error
    ret              
.no_cpuid:
    mov al, "C"
    jmp error

; Check for long mode. We need to check to see if this cpu supports extended cpuid.
; If it does, then check for long mode support, if it does not, then it does
; not support long mode. Long mode gives us support for 64-bit OS's
check_long_mode:
    mov eax, 0x80000000 ; Since cpuid takes this reg as implicit input, set eax with a magic num
    cpuid               ; Call cpuid. If it returns a number greater than what was input, then we
    cmp eax, 0x80000001 ; know that it supports long mode (64-bit mode)
    jb .no_long_mode    ; jb - jump if below, jump if carry flag is set
    
    mov eax, 0x80000001 ; This tells cpuid to fetch us the extended cpu info
    cpuid               ; The Info is stored in the edx register
    test edx, 1 << 29   ; If the 29th bit is set, then long mode is supported
    jz .no_long_mode

    ret                 
.no_long_mode:
    mov al, "L"
    jmp error

; Link the page tables together by saving the address to the next table at the address of 
; the first address of the previous table. Note that the Least significant 12 bits will
; always be zero (log2 (4096)... for some reason proves this). Therefor we use those to
; store flags, ie present and writable. A l1 table is not necessary becuase we can map 
; all pages in the level 2 to physical by enabling huge page size (2MiB). This allows us 
; to map 1 GiB of physical memory (2 MiB * 512). The remaining 9 bits will be used to store
; the offset
setup_page_tables:
    mov eax, page_table_l3             ; Copy the address of the l3 page table to eax 
    or eax, 0b11                       ; Sets the present & wrtiable flags 
    mov [page_table_l4], eax           ; Save it to the first entry of the l4 table 

    mov eax, page_table_l2             ; Copy the address of the l2 page table to eax 
    or eax, 0b11                       ; Sets the present & wrtiable flags 
    mov [page_table_l3], eax           ; Save it to the first entry of the l3 table 

    mov ecx, 0                         ; Counter for loop to map 1GiB of mem to physical mem
.loop:

    mov eax, 0x200000                  ; 2MiB
    mul ecx                            ; Takes the val in eax and multiplies it with our counter
    or eax, 0b10000011                 ; Set present (0th), writable (1st), huge page (8th bit)
    mov [page_table_l2 + ecx * 8], eax ; Saves the page to the proper entry in the table

    inc ecx;
    cmp ecx, 512                       ; Check to see if the whole table is mapped
    jne .loop                          ; If not, continue looping

    ret

; Enable paging by passing our page table to the cpu. The CPU looks for this info 
; in the cr3 register. Then we need to enable Physical Address Extention (PAE) which
; is neccesarry for 64-bit paging. To do this, we need to set the PAE flag (5th bit)
; in the cr4 reg. Afterwards, we enable long mode by manipulating the Model Specific 
; Register (MSR). Set a GPR to a specific number telling the CPU that we would like to
; access the Extended Feature Enable Register (EFER). Then we read the reg by calling 
; rdmsr. Set the bit for long mode (8th bit), then write it back using wrmsr. Finally,
; enable paging by setting cr0's 31st bit.
enable_paging:
    ; Pass the page to the cpu
    mov eax, page_table_l4
    mov cr3, eax

    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ret

; Error Handler
error:
    ; print 'ERR: x' where x is the error code
    mov dword [0xb8000], 0x4f524f45
    mov dword [0xb8000 + 4], 0x4f3a4f52
    mov dword [0xb8000 + 8], 0x4f204f20
    mov byte [0xb8000 + 12], al
    hlt

; This section allocates all of the meory to be reserved for various things
; This is all unintialized data. According to wikipedia, this segment of memory 
; holds all of the global/static vars that are either unitialized or initalized
; to 0
section .bss
; This sets up the memory for the page table
align 4096
page_table_l4:
    resb 4096
page_table_l3:
    resb 4096
page_table_l2:
    resb 4096
; This resevres memeory for the stack
stack_bottom:
    resb 4096 * 4
stack_top:

; Without this next section, we are only operating in a 32-bit compatiblity mode
; In order to enable true 64-bit, we need to create a Global Descriptor Table (GDT)
; This table's full functionallity is actually obsoleted by the use of paging, however
; it allows us to set the 64-bit flag, which is required for 64-bit operation
; This is a Readonly setion of memory and it allows us to set the following flags:
; Executable (43rd bit), Descriptor tag for code and data (44th bit), present (47th bit), 
; and 64-bit mode (53rd bit). We also need to store a pointer to this table which also
; holds 2 bytes of the length of the table
; Syntax - $ = current memory address
section .rodata
gdt64:
    dq 0                                             ; Required zero entry
.code_segment: equ $ - gdt64                         ; The offset of the code segment in the gdt
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; Code Segment
.pointer:
    dw $ - gdt64 - 1                                 ; Length of the table
    dq gdt64                                         ; Stores the pointer itself
