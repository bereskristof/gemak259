const std = @import("std");
const StringSliceList = std.ArrayList(MemSlice);

const MemSlice = struct {
    start: usize,
    end: usize,
};

pub const ArgError = error{
    ConflictingInputs,
    AllocationError,
    InvalidInput,
    UnknownArgument,
};

pub const Tool = enum {
    Default,
    Help,
    Version,
    Blur,
    Gauss,
    Unsharp,
    Median,
};

pub const Properties = struct {
    const This = @This();

    const SourceType = enum {
        files,
        stdin,
        none,
    };

    allocator: std.mem.Allocator,
    mem_source: ?[]u8,

    source: union(SourceType) {
        files: StringSliceList,
        stdin,
        none,
    },
    output_dir: []u8,
    kernel_size: u8,
    tool: Tool,
    silent: bool,
    timed: bool,

    pub fn init(allocator: std.mem.Allocator) ArgError!This {
        var props = Properties{
            .allocator = allocator,
            .mem_source = null,
            .source = .{ .none = {} },
            .output_dir = allocator.alloc(u8, 2) catch return ArgError.AllocationError,
            .kernel_size = 5,
            .tool = .Default,
            .silent = false,
            .timed = false,
        };
        errdefer props.deinit();
        std.mem.copyForwards(u8, props.output_dir, "./");
        try props.parseArgs();
        return props;
    }

    pub fn deinit(self: *This) void {
        self.allocator.free(self.output_dir);
        if (self.source == .files) {
            self.source.files.deinit();
        }
        if (self.mem_source) |src| {
            self.allocator.free(src);
        }
    }

    pub fn getFile(self: This, i: usize) ?[]const u8 {
        if (self.source != .files or self.mem_source == null or i >= self.source.files.items.len) {
            return null;
        }
        const slice = self.source.files.items[i];
        return self.mem_source.?[slice.start..slice.end];
    }

    fn addFile(self: *This, file: []const u8) ArgError!void {
        switch (self.source) {
            .files => {},
            .stdin => return ArgError.ConflictingInputs,
            .none => self.source = .{ .files = StringSliceList.init(self.allocator) },
        }
        if (self.mem_source) |src| {
            const new_mem = self.allocator.realloc(src, src.len + file.len) catch return ArgError.AllocationError;
            std.mem.copyForwards(u8, new_mem[src.len..], file);
            self.mem_source = new_mem;
            self.source.files.append(MemSlice{ .start = src.len, .end = new_mem.len }) catch return ArgError.AllocationError;
        } else {
            const new_mem = self.allocator.alloc(u8, file.len) catch return ArgError.AllocationError;
            std.mem.copyForwards(u8, new_mem, file);
            self.mem_source = new_mem;
            self.source.files.append(MemSlice{ .start = 0, .end = new_mem.len }) catch return ArgError.AllocationError;
        }
    }

    fn setStdin(self: *This) ArgError!void {
        if (self.source == .files)
            return ArgError.ConflictingInputs;
        self.source = .{ .stdin = {} };
    }

    fn setOutputDir(self: *This, dir: []const u8) ArgError!void {
        const mem = self.allocator.alloc(u8, dir.len) catch return ArgError.AllocationError;
        errdefer self.allocator.free(mem);
        std.mem.copyForwards(u8, mem, dir);
        self.allocator.free(self.output_dir);
        self.output_dir = mem;
    }

    fn setKernelSize(self: *This, k_str: []const u8) ArgError!void {
        const k = std.fmt.parseUnsigned(u8, k_str, 10) catch return ArgError.UnknownArgument;
        if (k % 2 == 0) return ArgError.InvalidInput;
        self.kernel_size = k;
    }

    fn setTool(self: *This, tool: Tool) void {
        if (tool == .Help or tool == .Version) {
            self.tool = tool;
        } else if (self.tool == .Default) {
            self.tool = tool;
        }
    }

    fn setSilent(self: *This) void {
        self.silent = true;
    }

    fn setTimed(self: *This) void {
        self.timed = true;
    }

    fn parseArgs(self: *This) ArgError!void {
        var args = std.process.argsWithAllocator(self.allocator) catch {
            return ArgError.AllocationError;
        };
        defer args.deinit();

        _ = args.next(); // Filename arg
        var opt_arg: u8 = '\x00';
        while (args.next()) |arg| {
            if (opt_arg != '\x00') { // Argument had space (-o DIR)
                try self.parseOpts(opt_arg, arg);
                opt_arg = '\x00';
            } else if (std.mem.startsWith(u8, arg, "-")) {
                const stop = try self.parseFlags(arg);
                if (stop != 0) {
                    if (stop + 1 < arg.len) { // Argument has no space (-oDIR)
                        try self.parseOpts(arg[stop], arg[(stop + 1)..]);
                    } else { // Argument has space (-o DIR), parsed next iteration
                        opt_arg = arg[stop];
                    }
                }
            } else {
                try self.parsePositional(arg);
            }
        }
        if (opt_arg != '\x00') {
            return ArgError.InvalidInput;
        }
    }

    fn parseFlags(self: *This, flag_list: []const u8) ArgError!usize {
        for (flag_list[1..], 1..) |char, i| {
            switch (char) {
                'h' => self.setTool(.Help),
                'v' => self.setTool(.Version),
                'i' => try self.setStdin(),
                'f' => self.setSilent(),
                't' => self.setTimed(),
                'o', 'k' => return i,
                else => return ArgError.UnknownArgument,
            }
        }
        return 0;
    }

    fn parseOpts(self: *This, flag: u8, opt: []const u8) ArgError!void {
        switch (flag) {
            'o' => try self.setOutputDir(opt),
            'k' => try self.setKernelSize(opt),
            else => unreachable,
        }
    }

    fn parsePositional(self: *This, arg: []const u8) ArgError!void {
        if (self.tool == .Default) {
            if (std.mem.eql(u8, arg, "blur")) {
                self.setTool(.Blur);
            } else if (std.mem.eql(u8, arg, "gauss")) {
                self.setTool(.Gauss);
            } else if (std.mem.eql(u8, arg, "median")) {
                self.setTool(.Median);
            } else if (std.mem.eql(u8, arg, "unsharp")) {
                self.setTool(.Unsharp);
            } else {
                return ArgError.UnknownArgument;
            }
        } else {
            try self.addFile(arg);
        }
    }

    pub fn print(self: This) void {
        switch (self.source) {
            .files => {
                std.debug.print("Source: Filenames\n", .{});
                var i: usize = 0;
                while (self.getFile(i)) |file| : (i += 1) {
                    std.debug.print("  File: {s}\n", .{file});
                }
            },
            .stdin => std.debug.print("Source: stdin\n", .{}),
            .none => std.debug.print("Source: null\n", .{}),
        }
        std.debug.print("Output dir: {s}\n", .{self.output_dir});
        std.debug.print("Kernel: {}\n", .{self.kernel_size});
        std.debug.print("Tool: {s}\n", .{@tagName(self.tool)});
        std.debug.print("Silent: {}\n", .{self.silent});
    }
};
