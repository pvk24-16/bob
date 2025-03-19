const std = @import("std");
pub const c = @cImport({
    @cInclude("CoreAudio/CoreAudio.h");
    @cInclude("AudioUnit/AudioUnit.h");
});
pub const log = std.log.scoped(.coreaudio);

pub fn cf_string_to_charptr(string_ref: c.CFStringRef, allocator: std.mem.Allocator, Error: type) ![]u8 {
    const length: c.CFIndex = c.CFStringGetLength(string_ref);
    const byteSize: c.CFIndex = c.CFStringGetMaximumSizeForEncoding(length, c.kCFStringEncodingUTF8) + 1;
    var str = allocator.alloc(u8, @intCast(byteSize)) catch {
        return Error.out_of_memory;
    };
    @memset(str[0..@intCast(byteSize)], 0);
    if (c.CFStringGetCString(string_ref, @ptrCast(str), byteSize, c.kCFStringEncodingUTF8) != 1) {
        allocator.free(str);
        return Error.convert_string;
    }
    return @ptrCast(str);
}
