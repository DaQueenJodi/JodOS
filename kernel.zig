export fn _start() void {
    outb(0xe9, 'A');
    while (true) {}
}

fn outb(comptime port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]\n\t"
        :
        : [val] "{al}" (val),
          [port] "i" (port),
    );
}
