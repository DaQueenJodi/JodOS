format elf
use64
org 0x7c00 + 512

mov rdi, hello_world_str
mov rsi, hello_world_str_len

print_loop:
	xor r9, r9
	mov al, [rdi + r9]
	out 0xe9, al

	inc r9
	cmp r9, rsi
	jnz print_loop

hang: jmp hang

hello_world_str: db "Hello World!"
hello_world_str_len = $-hello_world_str
