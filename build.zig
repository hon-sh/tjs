const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce Position Independent Code");

    const mod_opts: std.Build.Module.CreateOptions = .{
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .pic = pic,
        .link_libc = true,
    };

    const lib = b.addLibrary(.{
        .name = "tjs",
        .linkage = linkage,
        .root_module = b.createModule(mod_opts),
    });

    addIncludePaths(b, lib);

    lib.addCSourceFiles(.{
        .files = &.{
            "src/builtins.c",
            "src/curl-utils.c",
            "src/curl-websocket.c",
            "src/error.c",
            "src/eval.c",
            "src/mem.c",
            "src/modules.c",
            "src/sha1.c",
            "src/signals.c",
            "src/timers.c",
            "src/utils.c",
            "src/version.c",
            "src/vm.c",
            "src/worker.c",
            "src/ws.c",
            "src/xhr.c",
            "src/mod_dns.c",
            "src/mod_engine.c",
            "src/wasm.c",
            // "src/mod_ffi.c",
            "src/mod_sqlite3.c",
            "src/mod_fs.c",
            "src/mod_fswatch.c",
            "src/mod_os.c",
            "src/mod_process.c",
            "src/mod_streams.c",
            "src/mod_sys.c",
            "src/mod_udp.c",
            "src/bundles/c/core/core.c",
            "src/bundles/c/core/polyfills.c",
            "src/bundles/c/core/run-main.c",
            "src/bundles/c/core/run-repl.c",
            "src/bundles/c/core/worker-bootstrap.c",
            "deps/quickjs/cutils.c",
        },
        .flags = &.{
            "-DTJS__PLATFORM=\"zig\"",
        },
    });

    b.installArtifact(lib);

    const lib_qjs = mkqjs(b, mod_opts);
    const lib_sql = mksql(b, mod_opts);

    const exe = b.addExecutable(.{
        .name = "tjs",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            // .pic = pic,
            .link_libc = true,
        }),
    });
    addIncludePaths(b, exe);
    exe.addCSourceFile(.{
        .file = b.path("src/cli.c"),
        .flags = &.{
            "-DTJS__PLATFORM=\"zig\"",
        },
    });
    exe.linkLibrary(lib);
    exe.linkLibrary(lib_qjs);
    exe.linkLibrary(lib_sql);

    // exe.linkSystemLibrary("curl");
    exe.linkSystemLibrary2("curl", .{
        .preferred_link_mode = .static,
    });

    exe.addLibraryPath(b.path("build/deps/libuv"));
    exe.linkSystemLibrary2("uv", .{
        .preferred_link_mode = .static,
    });

    exe.addLibraryPath(b.path("build/deps/wasm3/source"));
    exe.linkSystemLibrary("m3");

    b.installArtifact(exe);
}

fn addIncludePaths(b: *std.Build, lib: anytype) void {
    lib.addIncludePath(b.path("src"));
    lib.addIncludePath(b.path("deps/quickjs"));
    lib.addIncludePath(b.path("deps/libuv/include"));
    lib.addIncludePath(b.path("deps/wasm3/source"));
    lib.addIncludePath(b.path("deps/sqlite3"));
}

fn mkqjs(b: *std.Build, mod_opts: std.Build.Module.CreateOptions) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "qjs",
        .linkage = .static,
        .root_module = b.createModule(mod_opts),
    });
    lib.addCSourceFiles(.{
        .root = b.path("deps/quickjs"),
        .files = &.{
            "cutils.c",
            "libregexp.c",
            "libunicode.c",
            "quickjs.c",
            "xsum.c",
        },
    });

    return lib;
}

fn mksql(b: *std.Build, mod_opts: std.Build.Module.CreateOptions) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "sqlite3",
        .linkage = .static,
        .root_module = b.createModule(mod_opts),
    });
    lib.addCSourceFiles(.{
        .root = b.path("deps/sqlite3"),
        .files = &.{
            "sqlite3.c",
        },
    });

    return lib;
}
