const std = @import("std");

pub fn build(b: *std.Build) void {

    const build_boot_sector = b.addSystemCommand(&.{
        "fasm",
    });
    build_boot_sector.addFileArg(.{
        .path = "boot_sector.S",
    });
    const boot_sector = build_boot_sector.addOutputFileArg("boot_sector.bin");

    b.getInstallStep().dependOn(&b.addInstallBinFile(boot_sector, "boot_sector.bin").step);

    const run_qemu_step = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-hda",
    });
    run_qemu_step.addFileArg(boot_sector);


    if (b.option(bool, "debugcon", "") orelse true) {
        run_qemu_step.addArgs(&.{
            "-debugcon",
            "stdio"
        });
    }
    const run_step = b.step("run", "");
    run_step.dependOn(&build_boot_sector.step);
    run_step.dependOn(&run_qemu_step.step);
}
