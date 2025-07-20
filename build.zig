const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce Position Independent Code");

    const mod_opts: std.Build.Module.CreateOptions = .{
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .pic = pic,
        .link_libc = true,
    };

    const lib_tjs = mktjs(b, mod_opts);
    const lib_qjs = mkqjs(b, mod_opts);
    const lib_sql = mksql(b, mod_opts);
    const lib_uv = mkuv(b, mod_opts);
    const lib_m3 = mkm3(b, mod_opts);

    // mkcurl

    b.step("i-tjs", "").dependOn(&lib_tjs.step);
    b.step("i-uv", "").dependOn(&lib_uv.step);
    b.step("i-m3", "").dependOn(&lib_m3.step);

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
    exe.linkLibrary(lib_tjs);
    exe.linkLibrary(lib_qjs);
    exe.linkLibrary(lib_sql);

    // exe.linkSystemLibrary("curl");
    exe.linkSystemLibrary2("curl", .{
        .preferred_link_mode = .static,
    });

    exe.linkLibrary(lib_uv);
    // exe.addLibraryPath(b.path("build/deps/libuv"));
    // exe.linkSystemLibrary2("uv", .{
    //     .preferred_link_mode = .static,
    // });

    exe.linkLibrary(lib_m3);
    // exe.addLibraryPath(b.path("build/deps/wasm3/source"));
    // exe.linkSystemLibrary("m3");

    b.installArtifact(exe);
}

fn addIncludePaths(b: *std.Build, lib: anytype) void {
    lib.addIncludePath(b.path("src"));
    lib.addIncludePath(b.path("deps/quickjs"));
    lib.addIncludePath(b.path("deps/libuv/include"));
    lib.addIncludePath(b.path("deps/wasm3/source"));
    lib.addIncludePath(b.path("deps/sqlite3"));
}

fn mktjs(b: *std.Build, mod_opts: std.Build.Module.CreateOptions) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "tjs",
        .linkage = .static,
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
    return lib;
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

fn mkuv(b: *std.Build, mod_opts: std.Build.Module.CreateOptions) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "uv",
        .linkage = .static,
        .root_module = b.createModule(mod_opts),
    });
    lib.addIncludePath(b.path("deps/libuv/include"));
    lib.addIncludePath(b.path("deps/libuv/src"));

    // thanks to https://github.com/mitchellh/zig-libuv/blob/main/build.zig
    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    const os_tag = mod_opts.target.?.result.os.tag;
    if (os_tag != .windows) {
        flags.appendSlice(&.{
            "-D_FILE_OFFSET_BITS=64",
            "-D_LARGEFILE_SOURCE",
        }) catch @panic("oom");
    }
    if (os_tag == .linux) {
        flags.appendSlice(&.{
            "-D_GNU_SOURCE",
            "-D_POSIX_C_SOURCE=200112",
        }) catch @panic("oom");
    }
    if (os_tag.isDarwin()) {
        flags.appendSlice(&.{
            "-D_DARWIN_UNLIMITED_SELECT=1",
            "-D_DARWIN_USE_64_BIT_INODE=1",
        }) catch @panic("oom");
    }

    lib.addCSourceFiles(.{
        .root = b.path("deps/libuv"),
        .files = &.{
            "src/fs-poll.c",
            "src/idna.c",
            "src/inet.c",
            "src/random.c",
            "src/strscpy.c",
            "src/strtok.c",
            "src/thread-common.c",
            "src/threadpool.c",
            "src/timer.c",
            "src/uv-common.c",
            "src/uv-data-getter-setters.c",
            "src/version.c",
        },
        .flags = flags.items,
    });

    if (os_tag != .windows) {
        lib.addCSourceFiles(.{
            .root = b.path("deps/libuv"),
            .files = &.{
                "src/unix/async.c",
                "src/unix/core.c",
                "src/unix/dl.c",
                "src/unix/fs.c",
                "src/unix/getaddrinfo.c",
                "src/unix/getnameinfo.c",
                "src/unix/loop-watcher.c",
                "src/unix/loop.c",
                "src/unix/pipe.c",
                "src/unix/poll.c",
                "src/unix/process.c",
                "src/unix/random-devurandom.c",
                "src/unix/signal.c",
                "src/unix/stream.c",
                "src/unix/tcp.c",
                "src/unix/thread.c",
                "src/unix/tty.c",
                "src/unix/udp.c",
            },
            .flags = flags.items,
        });
    }

    if (os_tag == .linux or os_tag.isDarwin()) {
        lib.addCSourceFiles(.{
            .root = b.path("deps/libuv"),
            .files = &.{
                "src/unix/proctitle.c",
            },
            .flags = flags.items,
        });
    }

    if (os_tag == .linux) {
        lib.addCSourceFiles(.{
            .root = b.path("deps/libuv"),
            .files = &.{
                "src/unix/linux.c",
                "src/unix/procfs-exepath.c",
                "src/unix/random-getrandom.c",
                "src/unix/random-sysctl-linux.c",
            },
            .flags = flags.items,
        });
    }

    if (os_tag.isDarwin() or os_tag.isBSD()) {
        lib.addCSourceFiles(.{
            .root = b.path("deps/libuv"),
            .files = &.{
                "src/unix/bsd-ifaddrs.c",
                "src/unix/kqueue.c",
            },
            .flags = flags.items,
        });
    }

    if (os_tag.isDarwin() or os_tag == .openbsd) {
        lib.addCSourceFiles(.{
            .root = b.path("deps/libuv"),
            .files = &.{
                "src/unix/random-getentropy.c",
            },
            .flags = flags.items,
        });
    }

    if (os_tag.isDarwin()) {
        lib.addCSourceFiles(.{
            .root = b.path("deps/libuv"),
            .files = &.{
                "src/unix/darwin-proctitle.c",
                "src/unix/darwin.c",
                "src/unix/fsevents.c",
            },
            .flags = flags.items,
        });
    }

    return lib;
}

fn mkm3(b: *std.Build, mod_opts: std.Build.Module.CreateOptions) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "m3",
        .linkage = .static,
        .root_module = b.createModule(mod_opts),
    });

    const m3_flags = [_][]const u8{
        "-Wall",
        "-Wextra",
        "-Wpedantic",
        "-Wparentheses",
        "-Wundef",
        "-Wpointer-arith",
        "-Wstrict-aliasing=2",
        "-std=gnu11",
    };

    lib.root_module.addCMacro("d_m3HasTracer", "");
    lib.root_module.addCMacro("d_m3HasWASI", ""); // wasi=simple
    lib.root_module.sanitize_c = false; // fno-sanitize=undefined

    // if (libwasm3.rootModuleTarget().isWasm()) {
    //     if (libwasm3.rootModuleTarget().os.tag == .wasi) {
    //         libwasm3.defineCMacro("d_m3HasWASI", null);
    //         libwasm3.linkSystemLibrary("wasi-emulated-process-clocks");
    //     }
    // }

    lib.addIncludePath(b.path("deps/wasm3/source"));
    lib.addCSourceFiles(.{
        .root = b.path("deps/wasm3"),
        .files = &.{
            "source/m3_api_libc.c",
            "source/extensions/m3_extensions.c",
            "source/m3_api_meta_wasi.c",
            "source/m3_api_tracer.c",
            "source/m3_api_uvwasi.c",
            "source/m3_api_wasi.c",
            "source/m3_bind.c",
            "source/m3_code.c",
            "source/m3_compile.c",
            "source/m3_core.c",
            "source/m3_env.c",
            "source/m3_exec.c",
            "source/m3_function.c",
            "source/m3_info.c",
            "source/m3_module.c",
            "source/m3_parse.c",
        },
        .flags = &m3_flags,
    });
    // .flags = if (libwasm3.rootModuleTarget().isWasm())
    //     &cflags ++ [_][]const u8{
    //         "-Xclang",
    //         "-target-feature",
    //         "-Xclang",
    //         "+tail-call",
    //     }
    // else
    //     &cflags,

    lib.linkSystemLibrary("m");

    return lib;
}
