// Copyright (c) 2020, Terin Stock
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const os = std.os;
const fs = std.fs;
const heap = std.heap;

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
                var buf: [512]u8 = undefined;

                var f = try fs.cwd().openFile("index.html", .{});
                var stat = try f.stat();

                const hdr = std.fmt.bufPrint(
                    buf[0..buf.len],
                    "HTTP/1.1 200 OK\r\nServer: ziggetty\r\nConnection: closed\r\nContent-Length: {}\r\n\r\n",
                    .{stat.size},
                ) catch unreachable;
                try conn.file.write(hdr);

                // TODO: remove this cast
                const size = @intCast(usize, stat.size);
                const sent = try sendfile(conn.file.handle, f.handle, null, size);
                conn.file.close();
                os.exit(0);
            },
            else => blk: {
                conn.file.close();
            },
        }
    }
}

const SendFileError = error{
    InputOutput,
    NoMem,
    Overflow,
    Unseekable,
    WouldBlock,
} || os.UnexpectedError;

fn sendfile(outfd: os.fd_t, infd: os.fd_t, offset: ?*u64, count: usize) SendFileError!usize {
    while (true) {
        var rc: usize = undefined;
        var err: usize = undefined;
        if (builtin.os == .linux) {
            rc = _sendfile(outfd, infd, offset, count);
            err = os.errno(rc);
        } else {
            @compileError("sendfile unimplemented for this target");
        }

        switch (err) {
            0 => return @intCast(usize, rc),
            else => return os.unexpectedErrno(err),

            os.EBADF => unreachable,
            os.EINVAL => unreachable,
            os.EFAULT => unreachable,
            os.EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdWritable(outfd);
                continue;
            } else {
                return error.WouldBlock;
            },
            os.EIO => return error.InputOutput,
            os.ENOMEM => return error.NoMem,
            os.EOVERFLOW => return error.Overflow,
            os.ESPIPE => return error.Unseekable,
        }
    }
}

fn _sendfile(outfd: i32, infd: i32, offset: ?*u64, count: usize) usize {
    if (@hasDecl(os, "SYS_sendfile64")) {
        return std.os.linux.syscall4(os.SYS_sendfile64, @bitCast(usize, @as(isize, outfd)), @bitCast(usize, @as(isize, infd)), @ptrToInt(offset), count);
    } else {
        return std.os.linux.syscall4(os.SYS_sendfile, @bitCast(usize, @as(isize, outfd)), @bitCast(usize, @as(isize, infd)), @ptrToInt(offset), count);
    }
}
