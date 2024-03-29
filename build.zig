const std = @import("std");

pub fn build(b: *std.Build) void {
    const kernel_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_add = blk: {
            var features = std.Target.Cpu.Feature.Set.empty;
            features.addFeature(@intFromEnum(std.Target.x86.Feature.soft_float));
            break :blk features;
        },
        .cpu_features_sub = blk: {
            const Feature = std.Target.x86.Feature;
            var features = std.Target.Cpu.Feature.Set.empty;
            features.addFeature(@intFromEnum(Feature.mmx));
            features.addFeature(@intFromEnum(Feature.sse));
            features.addFeature(@intFromEnum(Feature.sse2));
            features.addFeature(@intFromEnum(Feature.avx));
            features.addFeature(@intFromEnum(Feature.avx2));
            break :blk features;
        },
    });
    const kernel_optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });
    const kernel = b.addExecutable(.{
        .name = "kernel",
        .target = kernel_target,
        .optimize = kernel_optimize,
        .root_source_file = .{ .path = "kernel.zig" },
        .strip = true,
        .single_threaded = true, 
    });
    kernel.entry = .{ .symbol_name = "_start" };
    const install_kernel = b.addInstallArtifact(kernel, .{});


    const build_boot_sector = b.addSystemCommand(&.{
        "fasm",
    });
    build_boot_sector.addFileArg(.{
        .path = "boot_sector.S",
    });
    const boot_sector = build_boot_sector.addOutputFileArg("boot_sector.bin");
    // depend on the install step since we need the kernel elf thingy
    build_boot_sector.step.dependOn(&install_kernel.step);
    build_boot_sector.extra_file_dependencies = &.{
        "load_elf.inc"
    };

    b.getInstallStep().dependOn(&b.addInstallBinFile(boot_sector, "boot_sector.bin").step);

    const run_qemu_step = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-hda",
    });
    run_qemu_step.addFileArg(boot_sector);
    run_qemu_step.addArgs(&.{
        // get good debug info for interrupts
        "-d",
        "int",
        "--no-reboot",
        "--no-shutdown",
        "-M",
        "smm=off",
    });

    if (b.option(bool, "debugcon", "") orelse true) {
        run_qemu_step.addArgs(&.{
            "-debugcon",
            "stdio"
        });
    }
    if (b.option(bool, "gdb", "") orelse false) {
        run_qemu_step.addArgs(&.{
            "-s",
            "-S",
        });
    }

    const run_step = b.step("run", "");
    run_step.dependOn(b.getInstallStep());
    run_step.dependOn(&build_boot_sector.step);
    run_step.dependOn(&run_qemu_step.step);
}
