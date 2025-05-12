const std = @import("std");
const Allocator = std.mem.Allocator;

const cl = @cImport({
    @cInclude("../include/CL/opencl.h");
});

pub const ClError = error{
    OutOfMemory, // The host could not allocate the resources
    OutOfResources, // The device could not allocate the resources
    PlatformNotFound, // Zero platforms are available (cl_khr_icd only)
    InvalidPlatform, // Platform is not a valid platform
    InvalidDevice,
    InvalidContext,
    DeviceNotFound, // No OpenCL devices that matched device_type were found.
    InvalidValue, // Various invalid usage related errors
    DeviceNotAvailable, // Device in devices is currently not available
    InvalidKernelName,
    InvalidProgramExecutable,
    InvalidKernel,
    InvalidCommandQueue,
    GenericError,
};

pub const PlatformId = extern struct {
    this: cl.cl_platform_id,
};

pub const mem_read_write: u64 = cl.CL_MEM_READ_WRITE;
pub const mem_write_only: u64 = cl.CL_MEM_WRITE_ONLY;
pub const mem_read_only: u64 = cl.CL_MEM_READ_ONLY;
pub const mem_use_host_ptr: u64 = cl.CL_MEM_USE_HOST_PTR;
pub const mem_alloc_host_ptr: u64 = cl.CL_MEM_ALLOC_HOST_PTR;
pub const mem_copy_host_ptr: u64 = cl.CL_MEM_COPY_HOST_PTR;

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clGetPlatformIDs.html
pub fn getPlatformIds(a: Allocator) ![]const PlatformId {
    var num_platform: u32 = 0;
    const fetch_return: i32 = cl.clGetPlatformIDs(
        0,
        null,
        &num_platform,
    );
    switch (fetch_return) {
        cl.CL_SUCCESS => {},
        cl.CL_PLATFORM_NOT_FOUND_KHR => return ClError.PlatformNotFound,
        cl.CL_OUT_OF_HOST_MEMORY => return ClError.OutOfMemory,
        cl.CL_INVALID_VALUE => unreachable,
        else => unreachable,
    }

    const platforms = try a.alloc(PlatformId, num_platform);
    errdefer a.free(platforms);

    const get_return: i32 = cl.clGetPlatformIDs(
        num_platform,
        @ptrCast(platforms.ptr),
        null,
    );
    return switch (get_return) {
        cl.CL_SUCCESS => platforms,
        cl.CL_PLATFORM_NOT_FOUND_KHR => ClError.PlatformNotFound,
        cl.CL_OUT_OF_HOST_MEMORY => error.OutOfMemory,
        cl.CL_INVALID_VALUE => unreachable,
        else => unreachable,
    };
}

pub const DeviceId = extern struct {
    this: cl.cl_device_id,

    /// NOTE: Does nothing for root device, basically useless
    pub fn release(self: DeviceId) void {
        if (self.this) |this| {
            _ = cl.clReleaseDevice(this); // All errors are ignored
        }
    }
};

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clGetDeviceIDs.html
pub fn getDeviceIds(a: Allocator, platform: PlatformId) ![]const DeviceId {
    var num_devices: u32 = 0;
    const fetch_return: i32 = cl.clGetDeviceIDs(
        platform.this,
        cl.CL_DEVICE_TYPE_ALL,
        0,
        null,
        &num_devices,
    );
    switch (fetch_return) {
        cl.CL_SUCCESS => {},
        cl.CL_INVALID_PLATFORM => return ClError.InvalidPlatform,
        cl.CL_DEVICE_NOT_FOUND => return ClError.DeviceNotFound,
        cl.CL_OUT_OF_RESOURCES => return ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => return ClError.OutOfMemory,
        cl.CL_INVALID_DEVICE_TYPE => unreachable,
        cl.CL_INVALID_VALUE => unreachable,
        else => unreachable,
    }

    const devices = try a.alloc(DeviceId, num_devices);
    errdefer a.free(devices);

    const get_return: i32 = cl.clGetDeviceIDs(
        platform.this,
        cl.CL_DEVICE_TYPE_ALL,
        num_devices,
        @ptrCast(devices.ptr),
        null,
    );
    return switch (get_return) {
        cl.CL_SUCCESS => devices,
        cl.CL_INVALID_PLATFORM => return ClError.InvalidPlatform,
        cl.CL_DEVICE_NOT_FOUND => return ClError.DeviceNotFound,
        cl.CL_OUT_OF_RESOURCES => return ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => return ClError.OutOfMemory,
        cl.CL_INVALID_DEVICE_TYPE => unreachable,
        cl.CL_INVALID_VALUE => unreachable,
        else => unreachable,
    };
}

pub const Context = extern struct {
    this: cl.cl_context,

    pub fn release(self: Context) void {
        if (self.this) |this| {
            _ = cl.clReleaseContext(this); // All errors are ignored
        }
    }
};

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clCreateContext.html
pub fn createContext(device: DeviceId) !Context {
    var create_return: i32 = 0;
    const device_ptr = &device;
    const context = Context{
        .this = cl.clCreateContext(
            null,
            @truncate(1),
            @ptrCast(device_ptr),
            null,
            null,
            &create_return,
        ),
    };
    return switch (create_return) {
        cl.CL_SUCCESS => context,
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        cl.CL_INVALID_VALUE => ClError.InvalidValue,
        cl.CL_DEVICE_NOT_AVAILABLE => ClError.DeviceNotAvailable,
        cl.CL_INVALID_PLATFORM => unreachable,
        cl.CL_INVALID_PROPERTY => unreachable,
        else => unreachable,
    };
}

pub const CommandQueue = extern struct {
    this: cl.cl_command_queue,

    pub fn release(self: CommandQueue) void {
        if (self.this) |this| {
            _ = cl.clReleaseCommandQueue(this); // All errors are ignored
        }
    }
};

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clCreateCommandQueueWithProperties.html
pub fn createCommandQueue(context: Context, device: DeviceId) !CommandQueue {
    var create_return: i32 = 0;
    const queue = CommandQueue{
        .this = cl.clCreateCommandQueueWithProperties(
            context.this,
            device.this,
            null,
            &create_return,
        ),
    };
    return switch (create_return) {
        cl.CL_SUCCESS => queue,
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        cl.CL_INVALID_CONTEXT => ClError.InvalidContext,
        cl.CL_INVALID_DEVICE => ClError.InvalidDevice,
        cl.CL_INVALID_VALUE => ClError.InvalidValue,
        cl.CL_INVALID_QUEUE_PROPERTIES => unreachable,
        cl.CL_INVALID_PLATFORM => unreachable,
        cl.CL_INVALID_PROPERTY => unreachable,
        else => unreachable,
    };
}

pub const Program = extern struct {
    this: cl.cl_program,

    pub fn release(self: Program) void {
        if (self.this) |this| {
            _ = cl.clReleaseProgram(this);
        }
    }

    /// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clBuildProgram.html
    pub fn build(self: *Program, device: DeviceId, kernel_size: usize) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const a = gpa.allocator();
        const line = try std.fmt.allocPrint(a, "-w -cl-std=CL3.0 -D KERNEL_SIZE={d}\x00", .{kernel_size});
        defer a.free(line);
        const build_return: i32 = cl.clBuildProgram(
            self.this,
            1,
            &device.this,
            line.ptr,
            null,
            null,
        );
        return switch (build_return) {
            cl.CL_SUCCESS => {},
            cl.CL_BUILD_PROGRAM_FAILURE => {
                const stderr = std.io.getStdErr().writer();
                stderr.print("OpenCL compile error!\n", .{}) catch {}; // TODO: Query the problem
                printProgramBuildInfo(self.*, device);
                return ClError.GenericError;
            },
            cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
            cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
            cl.CL_INVALID_DEVICE => ClError.InvalidDevice,
            cl.CL_COMPILER_NOT_AVAILABLE => ClError.GenericError,
            cl.CL_INVALID_OPERATION => ClError.GenericError,
            else => unreachable,
        };
    }
};

fn printProgramBuildInfo(
    program: Program,
    device: DeviceId,
) void {
    var build_log_size: usize = 0;
    const build_return: i32 = cl.clGetProgramBuildInfo(
        program.this,
        device.this,
        cl.CL_PROGRAM_BUILD_LOG,
        0,
        null,
        &build_log_size,
    );
    switch (build_return) {
        cl.CL_SUCCESS => {},
        else => return,
    }
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();
    const build_log = a.alloc(u8, build_log_size) catch return;
    defer a.free(build_log);
    const get_return: i32 = cl.clGetProgramBuildInfo(
        program.this,
        device.this,
        cl.CL_PROGRAM_BUILD_LOG,
        build_log_size,
        @ptrCast(build_log.ptr),
        null,
    );
    switch (get_return) {
        cl.CL_SUCCESS => {},
        else => return,
    }
    const stderr = std.io.getStdErr().writer();
    stderr.print("OpenCL build log:\n", .{}) catch {};
    stderr.print("{s}\n", .{build_log}) catch {};
}

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clCreateProgramWithSource.html
pub fn createProgramWithSource(context: Context, source: []const u8) !Program {
    var create_return: i32 = 0;
    const program = Program{
        .this = cl.clCreateProgramWithSource(
            context.this,
            1,
            @ptrCast(@constCast(&source.ptr)),
            null,
            &create_return,
        ),
    };
    return switch (create_return) {
        cl.CL_SUCCESS => program,
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        else => unreachable,
    };
}

pub const Kernel = extern struct {
    this: cl.cl_kernel,

    pub fn release(self: Kernel) void {
        if (self.this) |this| {
            _ = cl.clReleaseKernel(this);
        }
    }
};

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clCreateKernel.html
pub fn createKernel(program: Program, kernel_name: [:0]const u8) !Kernel {
    var create_return: i32 = 0;
    const kernel = Kernel{
        .this = cl.clCreateKernel(
            program.this,
            kernel_name,
            &create_return,
        ),
    };
    return switch (create_return) {
        cl.CL_SUCCESS => kernel,
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        cl.CL_INVALID_KERNEL_NAME, cl.CL_INVALID_KERNEL_DEFINITION => ClError.InvalidKernelName,
        cl.CL_INVALID_PROGRAM_EXECUTABLE => ClError.InvalidProgramExecutable,
        else => unreachable,
    };
}

pub const Mem = extern struct {
    this: cl.cl_mem,

    pub fn release(self: Mem) void {
        if (self.this) |this| {
            _ = cl.clReleaseMemObject(this);
        }
    }
};

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clCreateBuffer.html
pub fn createBuffer(
    context: Context,
    mem_flags: u64,
    data: []const u8,
) !Mem {
    var create_return: i32 = 0;
    const buffer = Mem{
        .this = cl.clCreateBuffer(
            context.this,
            mem_flags,
            data.len,
            @ptrCast(@constCast(data.ptr)),
            &create_return,
        ),
    };
    return switch (create_return) {
        cl.CL_SUCCESS => buffer,
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        else => ClError.GenericError,
    };
}

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clSetKernelArg.html
pub fn setMemKernelArg(self: Kernel, index: u32, arg_value: Mem) !void {
    const set_return: i32 = cl.clSetKernelArg(
        self.this,
        index,
        @sizeOf(Mem),
        @ptrCast(&arg_value.this),
    );
    return switch (set_return) {
        cl.CL_SUCCESS => {},
        cl.CL_INVALID_KERNEL => ClError.InvalidKernel,
        cl.CL_INVALID_VALUE => ClError.InvalidValue,
        cl.CL_INVALID_MEM_OBJECT => ClError.InvalidValue,
        else => unreachable,
    };
}

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clSetKernelArg.html
pub fn setU32KernelArg(self: Kernel, index: u32, arg_value: u32) !void {
    const set_return: i32 = cl.clSetKernelArg(
        self.this,
        index,
        @sizeOf(u32),
        @ptrCast(&arg_value),
    );
    return switch (set_return) {
        cl.CL_SUCCESS => {},
        cl.CL_INVALID_KERNEL => ClError.InvalidKernel,
        cl.CL_INVALID_VALUE => ClError.InvalidValue,
        cl.CL_INVALID_MEM_OBJECT => ClError.InvalidValue,
        else => unreachable,
    };
}

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clEnqueueNDRangeKernel.html
pub fn enqueueNDRangeKernel(
    queue: CommandQueue,
    kernel: Kernel,
    global_work_size: []const u64,
) !void {
    const calculated_global_work_size: [2]usize = [_]usize{ nextPowerOfTwo(global_work_size[0]), nextPowerOfTwo(global_work_size[1]) };
    const local_work_size: [2]usize = [_]usize{ 16, 16 }; // TODO: Replace with system based value
    const enqueue_return: i32 = cl.clEnqueueNDRangeKernel(
        queue.this,
        kernel.this,
        @intCast(global_work_size.len),
        null,
        @ptrCast(@constCast(&calculated_global_work_size)),
        @ptrCast(@constCast(&local_work_size)),
        0,
        null,
        null,
    );
    return switch (enqueue_return) {
        cl.CL_SUCCESS => {},
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        cl.CL_INVALID_COMMAND_QUEUE => ClError.InvalidCommandQueue,
        cl.CL_INVALID_KERNEL => ClError.InvalidKernel,
        cl.CL_INVALID_WORK_GROUP_SIZE => ClError.InvalidValue,
        cl.CL_INVALID_WORK_ITEM_SIZE => ClError.InvalidValue,
        cl.CL_INVALID_VALUE => ClError.InvalidValue,
        else => unreachable,
    };
}

fn nextPowerOfTwo(x: usize) usize {
    var i: usize = x;
    var l: u6 = 1;
    for (0..7) |_| {
        i |= i >> l;
        l *|= 2;
    }
    return i + 1;
}

pub fn enqueueReadBuffer(
    a: std.mem.Allocator,
    queue: CommandQueue,
    buffer: Mem,
    size: usize,
    blocking_read: bool,
) ![]const u8 {
    const data = a.alloc(u8, size) catch return ClError.OutOfMemory;
    errdefer a.free(data);
    const enqueue_return: i32 = cl.clEnqueueReadBuffer(
        queue.this,
        buffer.this,
        if (blocking_read) cl.CL_TRUE else cl.CL_FALSE,
        0,
        size,
        @ptrCast(data.ptr),
        0,
        null,
        null,
    );
    return switch (enqueue_return) {
        cl.CL_SUCCESS => data,
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        cl.CL_INVALID_COMMAND_QUEUE => ClError.InvalidCommandQueue,
        cl.CL_INVALID_MEM_OBJECT => ClError.InvalidValue,
        cl.CL_INVALID_VALUE => ClError.InvalidValue,
        else => unreachable,
    };
}
