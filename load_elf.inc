; stolen from https://github.com/N00byEdge/bootelf/blob/master/elf_load.asm

; vi: ft=fasm

ELF_LOC = KERNEL_LOAD_ADDR
ELF_ENTRY = 0x18
ELF_PHOFF = 0x20
ELF_PHENTSIZE = 0x36
ELF_PHNUM = 0x38

PHDR_TYPE = 0
PHDR_OFFSET = 0x8
PHDR_VADDR = 0x10
PHDR_FILESZ = 0x20
PHDR_MEMSZ = 0x28


mov ebx, ELF_LOC
mov edx, [rbx + ELF_PHOFF]
add edx, ebx
movzx ebp, WORD [rbx + ELF_PHNUM]

do_phdr:
	cmp DWORD [rdx + PHDR_TYPE], 1
	jne next_phdr

	mov rdi, [rdx + PHDR_VADDR]
	mov esi, [rdx + PHDR_OFFSET]
	add esi, ebx

	mov ecx, [rbx + PHDR_FILESZ]
	mov eax, ecx
	rep movsb

	mov rcx, [rdx + PHDR_MEMSZ]
	sub rcx, rax
	xor al, al
	rep stosb

next_phdr:
	movzx eax, WORD [rbx + ELF_PHENTSIZE]
	add edx, eax
	dec ebp
	jnz do_phdr
	mov al, 'A'
	out 0xe9, al
	jmp QWORD [rbx + ELF_ENTRY]
