const std = @import("std");

const This = @This();

const UnsupportedFileError = error{
    Unsupported,
    WrongMagicNumber,
    CorruptedHeaderData,
    OutOfMemory,
    UnreadableString,
    DamagedData,
};

const BitWidth = enum(u2) {
    single = 1,
    double = 2,
};

const ImageInfo = struct {
    size: usize,
    byte_size: usize,
    width: u64,
    height: u64,
    white_value: u16,
    bit_width: BitWidth,
};

image_info: ImageInfo,
data: []const u8,

alloc: std.mem.Allocator,

pub fn initFromFile(a: std.mem.Allocator, file_path: []const u8) !This {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(file_path, .{});
    defer file.close();

    const file_data = try file.readToEndAlloc(a, 1 << 30);
    defer a.free(file_data);
    return try init(a, file_data);
}

pub fn init(a: std.mem.Allocator, file_data: []const u8) UnsupportedFileError!This {
    if (file_data.len < 3 or file_data[0] != 'P' or !std.ascii.isWhitespace(file_data[2])) {
        return UnsupportedFileError.WrongMagicNumber;
    }
    return switch (file_data[1]) {
        '3' => initP3(a, file_data),
        '6' => initP6(a, file_data),
        '1', '2', '4', '5', '7' => UnsupportedFileError.Unsupported,
        else => return UnsupportedFileError.WrongMagicNumber,
    };
}

fn initP3(a: std.mem.Allocator, file_data: []const u8) UnsupportedFileError!This {
    var data_start: usize = 0;
    const image_info = try readP3Header(&data_start, file_data);

    const rgb_data = a.alloc(u8, image_info.byte_size) catch return UnsupportedFileError.OutOfMemory;
    errdefer a.free(rgb_data);
    var rgb_i: usize = 0;
    var iterator = HeaderIterator.init(file_data[data_start..]);
    while (iterator.next()) |word| {
        const value = std.fmt.parseUnsigned(u8, word, 10) catch return UnsupportedFileError.UnreadableString;
        rgb_data[rgb_i] = value;
        rgb_i += 1;
    }
    if (rgb_i != image_info.byte_size) return UnsupportedFileError.DamagedData;

    return .{
        .image_info = image_info,
        .data = rgb_data,
        .alloc = a,
    };
}

fn initP6(a: std.mem.Allocator, file_data: []const u8) UnsupportedFileError!This {
    var data_start: usize = 0;
    const image_info = try readP3Header(&data_start, file_data);

    const rgb_data = a.alloc(u8, image_info.byte_size) catch return UnsupportedFileError.OutOfMemory;
    errdefer a.free(rgb_data);
    var read_data: usize = 0;
    for (file_data[data_start..], 0..) |byte, i| {
        rgb_data[i] = byte;
        read_data = i;
    }
    if (read_data != image_info.byte_size - 1) return UnsupportedFileError.DamagedData;

    return .{
        .image_info = image_info,
        .data = rgb_data,
        .alloc = a,
    };
}

fn readP3Header(header_size: *usize, file_data: []const u8) UnsupportedFileError!ImageInfo {
    var iterator = HeaderIterator.init(file_data[3..]); // Skips 'P3_'
    const width_str = iterator.next() orelse "";
    const height_str = iterator.next() orelse "";
    const max_color_value_str = iterator.next() orelse "";

    header_size.* = iterator.head + 3; // FIXME: This is ugly as shit // +3 due to 'P3_' skip

    const width = std.fmt.parseInt(u64, width_str, 10) catch return UnsupportedFileError.CorruptedHeaderData;
    const height = std.fmt.parseInt(u64, height_str, 10) catch return UnsupportedFileError.CorruptedHeaderData;
    const max_color_value = std.fmt.parseInt(u16, max_color_value_str, 10) catch return UnsupportedFileError.CorruptedHeaderData;

    return .{
        .size = width * height,
        .byte_size = 3 * (width * height) * (if (max_color_value >= 256) @as(usize, 2) else @as(usize, 1)),
        .width = width,
        .height = height,
        .white_value = max_color_value,
        .bit_width = if (max_color_value >= 256) .double else .single,
    };
}

pub fn print(self: This) !void {
    const stderr = std.io.getStdErr();
    const out = stderr.writer();
    for (self.data, 0..) |byte, i| {
        try out.print("{X:02} ", .{byte});
        switch (i % 6) {
            2 => _ = try out.write(" "),
            5 => _ = try out.write("\n"),
            else => {},
        }
    }
}

pub fn deinit(self: *This) void {
    self.alloc.free(self.data);
}

const HeaderIterator = struct {
    file_data: []const u8,
    head: usize,

    pub fn init(file_data: []const u8) HeaderIterator {
        return .{
            .file_data = file_data,
            .head = 0,
        };
    }

    pub fn next(self: *HeaderIterator) ?[]const u8 {
        var is_comment = false;
        var start: usize = self.head;
        var end: usize = self.head;
        if (self.head >= self.file_data.len) {
            return null;
        }
        for (self.file_data[self.head..], self.head..) |char, i| {
            switch (char) {
                '#' => is_comment = true,
                '\n', '\r' => {
                    if (is_comment) {
                        is_comment = false;
                        start = i + 1;
                    } else {
                        end = i;
                        break;
                    }
                },
                ' ', '\t', '\x0B', '\x0C' => {
                    if (!is_comment) {
                        end = i;
                        break;
                    }
                },
                else => continue,
            }
        }
        self.head = end + 1;
        if (start == end) {
            return null;
        }
        return self.file_data[start..end];
    }
};
