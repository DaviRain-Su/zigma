const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Version from build option or default
    const version = b.option([]const u8, "version", "Version string") orelse "0.1.0-dev";

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);

    const mod = b.createModule(.{
        .root_source_file = b.path("deps/mlx-serve/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
        .imports = &.{
            .{ .name = "build_options", .module = build_options.createModule() },
        },
    });

    // 添加 mlx-serve 模块
    const serve_dep = b.dependency("mlx_serve", .{
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("mlx_serve", serve_dep.module("mlx_serve"));

    // mlx-c include/lib paths (homebrew)
    mod.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    mod.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    mod.linkSystemLibrary("mlxc", .{});
    mod.linkSystemLibrary("webp", .{});

    // Jinja2 template engine (from llama.cpp's common/jinja + nlohmann/json).
    mod.addObjectFile(b.path("deps/mlx-serve/lib/jinja_cpp/libjinja.a"));
    mod.addIncludePath(b.path("deps/mlx-serve/lib/jinja_cpp"));

    // stb_image for JPEG/PNG decoding in the vision pipeline
    mod.addCSourceFile(.{ .file = b.path("deps/mlx-serve/lib/stb_image_impl.c"), .flags = &.{"-O2"} });
    mod.addIncludePath(b.path("deps/mlx-serve/lib"));

    mod.linkFramework("IOKit", .{});
    mod.linkFramework("CoreFoundation", .{});

    const exe = b.addExecutable(.{
        .name = "zigma",
        .root_module = mod,
    });

    b.installArtifact(exe);

    // 默认运行命令
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run Zigma server");
    run_step.dependOn(&run_cmd.step);
}
