; vi: ft=fasm

format binary as "bin"
use16
org 0x7c00

KERNEL_LOAD_ADDR = 0x7c00 + 512

; zero out some segment registers
xor ax, ax
mov es, ax
mov ds, ax
cld

; load kernel code into KERNEL_LOAD_ADDR
mov si, read_kernel_from_drive_info
read_kernel_loop:
	mov ah, 0x42
	

	clc
	int 0x13
	; TODO: see if there is a better way to do this
	jc done_read_kernel_loop

	add WORD [read_kernel_load_segment], 512 / 16
	inc DWORD [read_kernel_sector_low]

	cmp ah, 0
	jz read_kernel_loop
done_read_kernel_loop:

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
PAGE_SIZE_BIT = 1 shl 7

PAE_BIT = 1 shl 5
PSE_BIT = 1 shl 4

LONG_MODE_BIT = 1 shl 8
EFER_MSR_ADDR = 0xC0000080
PROTECTED_MODE_BIT = 1 shl 0
PAGE_BIT = 1 shl 31

PDT_COUNT = 512
PT_COUNT = 512

; PML4T
mov DWORD [0x1000], 0x2000 or PAGE_PRESENT_BIT or PAGE_READ_WRITE_BIT
; PDPT
mov DWORD [0x2000], 0x3000 or PAGE_PRESENT_BIT or PAGE_READ_WRITE_BIT
; create 512 PDT entries for 1gb of memory
mov edi, PAGE_PRESENT_BIT or PAGE_READ_WRITE_BIT or PAGE_SIZE_BIT
mov esi, 0x3000
mov ecx, 512
create_pdt_loop:
	mov DWORD [esi], edi
	add edi, 2 * 1024 * 1024 ; 2MiB
	add esi, 8 ; next PDT entry
	loop create_pdt_loop

mov eax, cr4
or eax, PAE_BIT or PSE_BIT
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
	dw 1
	read_kernel_load_offset: dw KERNEL_LOAD_ADDR
	read_kernel_load_segment: dw 0x00
	read_kernel_sector_low: dd 1
	read_kernel_sector_high: dd 0

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
dd 1 ; number of sectors in partition

db 510-($-$$) dup 0x00
db 0x55, 0xAA
org KERNEL_LOAD_ADDR
kernel_file: file "%KERNEL_ELF_FILE_PATH%"
stack_begin:
	rb 1024
stack_end:
KERNEL_SIZE = $ - kernel_file
; pad to nearest sector boundary
SECTOR_BOUNDARY_OFFSET = ($$ - $) mod 512

; for whatever reason fasm returns the result of `mod` as a negative number
if SECTOR_BOUNDARY_OFFSET < 0
	db (512 + SECTOR_BOUNDARY_OFFSET) dup 0x00
end if
