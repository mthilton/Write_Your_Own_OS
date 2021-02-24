global start

section .text
bits 32
start:
    ; print 'Okay Boomer!' using video memory    
    mov dword [0xb8000], 0x2f6b2f4f 
    mov dword [0xb8000 + 4], 0x2f792f61
    mov dword [0xb8000 + 8], 0x2f422f20
    mov dword [0xb8000 + 12], 0x2f6f2f6f
    mov dword [0xb8000 + 16], 0x2f652f6d
    mov dword [0xb8000 + 20], 0x2f212f72
    hlt ; Halt, halts the cpu.... pretty self explanitory
