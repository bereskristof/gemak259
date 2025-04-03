const std = @import("std");
const Allocator = std.mem.Allocator;

const cl = @cImport(
    @cInclude("../include/CL/opencl.h"),
);

const ClError = error{
    OutOfMemory, // The host could not allocate the resources
    OutOfResources, // The device could not allocate the resources
    PlatformNotFound, // Zero platforms are available (cl_khr_icd only)
    InvalidPlatform, // Platform is not a valid platform
    InvalidDevice,
    InvalidContext,
    DeviceNotFound, // No OpenCL devices that matched device_type were found.
    InvalidValue, // Various invalid usage related errors
    DeviceNotAvailable, // Device in devices is currently not available
};

pub const PlatformId = extern struct {
    this: cl.cl_platform_id,
};

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
pub fn createContext(devices: []const DeviceId) !Context {
    var create_return: i32 = 0;
    const context = Context{
        .this = cl.clCreateContext(
            null,
            @truncate(devices.len),
            @ptrCast(devices.ptr),
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
