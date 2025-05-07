const AudioProducerEntry = @import("./AudioProducerEntry.zig");

const std = @import("std");

const win = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", {});
    @cInclude("windows.h");
    @cInclude("dwmapi.h");
});

fn windowDetected(hwnd: win.HWND, list_raw: win.LPARAM) callconv(.C) win.BOOL {
    // This code is inspired by window_capture_utils.cc from WebRTC.
    var pid: win.DWORD = 0;

    // The return value is a thread ID, we are not interested in this. We'd
    // rather have the PID.
    _ = win.GetWindowThreadProcessId(hwnd, &pid);

    if (pid == win.GetCurrentProcessId()) {
        // Don't add this window or child windows to the list.
        return win.TRUE;
    }

    const ex_style = win.GetWindowLongA(hwnd, win.GWL_EXSTYLE);

    const owner = win.GetWindow(hwnd, win.GW_OWNER);

    if (owner != 0 and (ex_style & win.WS_EX_APPWINDOW) == 0) {
        // Not a real top window.
        return win.TRUE;
    }

    // We are only interested in Windows that want to show themselves.
    if (win.IsWindowVisible(hwnd) == win.FALSE or win.IsIconic(hwnd) == win.TRUE) {
        // If this line is removed, you'll get a bunch of Default IME entries.
        return win.TRUE;
    }

    if (win.SendMessageTimeoutA(hwnd, win.WM_NULL, 0, 0, win.SMTO_ABORTIFHUNG, 50, 0) == 0) {
        // We have found a suspended (or even hung) program. It is likely we do not want
        // to present it to the user.
        return win.TRUE;
    }

    var is_cloaked: i32 = 0;
    if (win.DwmGetWindowAttribute(hwnd, win.DWMWA_CLOAKED, &is_cloaked, @sizeOf(@TypeOf(is_cloaked))) == win.S_OK) {
        // UWP apps that are running but not visible become cloaked by DWM. So even
        // if WM_VISIBLE is set and all that, the window may still be invisible.
        // DWM knows better than the window style.
        if (is_cloaked != 0) {
            return win.TRUE;
        }
    }

    var list: *AudioProducerEntry.List = @ptrFromInt(@as(usize, @bitCast(list_raw)));

    var result = std.mem.zeroes(AudioProducerEntry);
    _ = std.fmt.bufPrint(&result.process_id, "{d}\x00", .{pid}) catch {};

    // We want the wide char one because GetWindowTextA won't get us correct encoding for ÖÄÅ.
    // So instead we just run a conversion procedure to UTF-8 later down.
    var wide_title = std.mem.zeroes([256]u16);
    const wide_title_len = win.GetWindowTextW(hwnd, &wide_title, result.name.len);

    if (wide_title_len == 0) {
        // We are not interested in windows that don't even have a title.
        return win.TRUE;
    }

    var class_name = std.mem.zeroes([256]u8);
    const class_name_len: u32 = @bitCast(win.GetClassNameA(hwnd, &class_name, class_name.len));
    const class_name_slice = class_name[0..class_name_len];

    if (std.mem.eql(u8, class_name_slice, "Progman")) {
        return win.TRUE;
    }

    // UTF-16 to UTF-8. The builtin Zig ones crash. Probably there are some Windows quirks that it
    // is not used to.
    const title_len: u32 = @bitCast(win.WideCharToMultiByte(win.CP_UTF8, 0, &wide_title, wide_title_len, &result.name, result.name.len, 0, 0));

    // Make sure things are null-terminated.
    result.name[title_len] = 0;
    result.name[result.name.len - 1] = 0;
    result.process_id[result.process_id.len - 1] = 0;

    list.append(result) catch {
        return win.FALSE;
    };
    return win.TRUE;
}

pub fn enumerateAudioProducers(list: *AudioProducerEntry.List) !void {
    _ = win.EnumWindows(windowDetected, @bitCast(@intFromPtr(list)));
}
