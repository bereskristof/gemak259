const std = @import("std");
const Allocator = std.mem.Allocator;

const cl = @cImport(
    @cInclude("../include/CL/opencl.h"),
);

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
    pub fn build(self: *Program, device: DeviceId) !void {
        const build_return: i32 = cl.clBuildProgram(
            self.this,
            1,
            &device.this,
            "-w -cl-std=CL3.0",
            null,
            null,
        );
        return switch (build_return) {
            cl.CL_SUCCESS => {},
            cl.CL_BUILD_PROGRAM_FAILURE => {
                const stderr = std.io.getStdErr().writer();
                stderr.print("OpenCL compile error!\n", .{}) catch {}; // TODO: Query the problem
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

pub const ImageDesc = struct {
    this: cl.cl_image_desc = .{
        .image_type = cl.CL_MEM_OBJECT_IMAGE2D,
        .image_width = 20,
        .image_height = 20,
        .image_depth = 0,
        .image_array_size = 0,
        .image_row_pitch = 0,
        .image_slice_pitch = 0,
        .num_mip_levels = 0,
        .num_samples = 0,
        .unnamed_0 = .{ .mem_object = null },
    },
};

pub const Mem = extern struct {
    this: cl.cl_mem,

    pub fn release(self: Mem) void {
        if (self.this) |this| {
            _ = cl.clReleaseMemObject(this);
        }
    }
};

/// https://registry.khronos.org/OpenCL/sdk/3.0/docs/man/html/clCreateImageWithProperties.html
pub fn createImage(context: Context, mem_flags: u64, image_desc: ImageDesc, data: []const u8) !Mem {
    var create_return: i32 = 0;
    const image = Mem{
        .this = cl.clCreateImage(
            context.this,
            mem_flags,
            &cl.cl_image_format{
                .image_channel_order = cl.CL_RGB,
                .image_channel_data_type = cl.CL_UNORM_INT8,
            },
            &image_desc.this,
            @ptrCast(@constCast(data.ptr)),
            &create_return,
        ),
    };
    return switch (create_return) {
        cl.CL_SUCCESS => image,
        cl.CL_OUT_OF_RESOURCES => ClError.OutOfResources,
        cl.CL_OUT_OF_HOST_MEMORY => ClError.OutOfMemory,
        else => {
            std.debug.print("CLERR: {d}\n", .{create_return});
            return ClError.GenericError;
        },
        // else => unreachable,
    };
}
