; vi: ft=fasm

format binary as "bin"
use16
org 0x7c00

KERNEL_SECTORS_COUNT = (KERNEL_SIZE / 512) + 1
KERNEL_LOAD_ADDR = 0x7c00 + 512

; zero out some segment registers
xor ax, ax
mov es, ax
mov ds, ax
cld

; load kernel code into KERNEL_LOAD_ADDR
mov ah, 0x42
mov si, read_kernel_from_drive_info
clc
int 0x13
jc disk_error

; we're using qemu so we know the A20 line is enabled
; TODO: fix this later

; enter long mode
; set up page tables at 0x1000
; clear the existing tables
mov edi, 0x1000
mov cr3, edi
xor eax, eax
mov ecx, 4096
rep stosd
mov edi, cr3

; set up the tables like osdev.wiki has them, for now at least: https://wiki.osdev.org/Setting_Up_Long_Mode#Entering_Long_Mode
; PML4T at 0x1000
; PDPT at 0x2000
; PDT at 0x3000
; PT at 0x4000

PAGE_PRESENT_BIT = 1 shl 0
PAGE_READ_WRITE_BIT = 1 shl 1
PAE_BIT = 1 shl 5
LONG_MODE_BIT = 1 shl 8
EFER_MSR_ADDR = 0xC0000080
PROTECTED_MODE_BIT = 1 shl 0
PAGE_BIT = 1 shl 31

PDT_COUNT = 512

; PML4T
mov DWORD [0x1000], 0x2000 or PAGE_PRESENT_BIT or PAGE_READ_WRITE_BIT
; PDPT
mov DWORD [0x2000], 0x3000 or PAGE_PRESENT_BIT or PAGE_READ_WRITE_BIT
; PDT
mov DWORD [0x3000], 0x4000 or PAGE_PRESENT_BIT or PAGE_READ_WRITE_BIT

; PT
mov edi, 0x4000 ; start of the PT
mov ecx, 512
mov ebx, PAGE_PRESENT_BIT or PAGE_READ_WRITE_BIT
; set all 512 entries of the PT 
set_entry:
	mov DWORD [edi], ebx
	add ebx, 0x1000
	add edi, 8 ; next PT entry
	loop set_entry
; enable PAE-paging
mov eax, cr4
or eax, PAE_BIT
mov cr4, eax
; enable long mode
mov ecx, EFER_MSR_ADDR
rdmsr
or eax, LONG_MODE_BIT
wrmsr

; enable paging and protected mode
mov eax, cr0
or eax, PAGE_BIT or PROTECTED_MODE_BIT
mov cr0, eax

cli
lgdt [GDTR]

; set up the stack
mov esp, stack_end

jmp 0x08:elf_stuff

disk_error:
	clc
	mov ah, 0x1
	int 0x13
	jnc error
	mov al, ':'
	out 0xe9, al
	mov al, '('
	out 0xe9, al
	@@: jmp @b
error:
	mov al, 'E'
	out 0xe9, al
	@@: jmp @b
	


GDT:
	null_entry: dq 0
	code_entry: dq 0x00A09A0000000000
	data_entry: dq 0x0000920000000000

GDTR:
	dw $ - GDT - 1
	dd GDT

read_kernel_from_drive_info:
	db 0x10
	db 0
	dw KERNEL_SECTORS_COUNT
	dd 0x00:KERNEL_LOAD_ADDR
	dq 1

use64
elf_stuff:
	include "load_elf.inc"

db 440-($-$$) dup 0x00

unique_disk_id_signature: db 0x1, 0x2, 0x3, 0x4
reserved: db 0x00, 0x00
first_partition_table:
db 0x80 ; bootable
db 3 dup 0x00 ; chs address start, hopefully ignored
db 0x01 ; fat12
db 3 dup 0x00 ; chs address end, hopefully also ignored
dd 0x01 ; the LBA start address
dd KERNEL_SECTORS_COUNT ; number of sectors in partition

db 510-($-$$) dup 0x00
db 0x55, 0xAA
org KERNEL_LOAD_ADDR
kernel_file: file "zig-out/bin/kernel"
stack_begin:
	rb 1024
stack_end:
KERNEL_SIZE = $ - kernel_file

db (512*KERNEL_SECTORS_COUNT)-($-$$) dup 0x00
