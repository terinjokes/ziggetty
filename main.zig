// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const net = std.net;
const os = std.os;
const fs = std.fs;
const heap = std.heap;

const SYS_sendfile = 40;

pub fn main() !void {
    var act = os.Sigaction{
        .sigaction = os.SIG_IGN,
        .mask = os.empty_sigset,
        .flags = (os.SA_SIGINFO | os.SA_RESTART | os.SA_RESETHAND),
    };
    os.sigaction(os.SIGCHLD, &act, null);

    var opt = net.StreamServer.Options{
        .kernel_backlog = 128,
        .reuse_address = false,
    };
    var srv = net.StreamServer.init(opt);
    var addr = try net.Address.parseIp6("::", 8080);

    try srv.listen(addr);

    while (true) {
        var conn = try srv.accept();
        var pid = try os.fork();
        switch (pid) {
            0 => blk: {
                var mem: [512]u8 = undefined;
                const allocator = &heap.FixedBufferAllocator.init(mem[0..mem.len]).allocator;
                var f = try fs.cwd().openFile("index.html", .{});
                var stat = try f.stat();

                const hdr = std.fmt.allocPrint(
                    allocator,
                    "HTTP/1.1 200 OK\r\nServer: ziggetty\r\nConnection: closed\r\nContent-Length: {}\r\n\r\n",
                    .{stat.size},
                ) catch unreachable;

                try conn.file.write(hdr);
                _ = sendfile(conn.file.handle, f.handle, 0, stat.size);
                conn.file.close();
                os.exit(0);
            },
            else => blk: {
                conn.file.close();
            },
        }
    }
}

fn sendfile(outfd: i32, infd: i32, offset: u64, count: usize) usize {
    return syscall4(SYS_sendfile, @bitCast(usize, @as(isize, outfd)), @bitCast(usize, @as(isize, infd)), offset, count);
}

fn syscall4(number: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4)
        : "rcx", "r11", "memory"
    );
}
