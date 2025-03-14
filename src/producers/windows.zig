const AudioProducerEntry = @import("./AudioProducerEntry.zig");

const std = @import("std");

const win = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", {});
    @cInclude("windows.h");
});

 fn windowDetected(hwnd: win.HWND, list_raw: win.LPARAM) callconv(.C) win.BOOL {
    // We are only interested in Windows that want to show themselves.
    if (win.IsWindowVisible(hwnd) == 0) {
        // If this line is removed, you'll get a bunch of Default IME entries.
        return win.TRUE;
    }

    const ex_style = win.GetWindowLongA(hwnd, win.GWL_EXSTYLE);

    // The Windows docs says that NOACTIVE and TOOLWINDOW are 
    // two common ways to prevent an icon from showing up.
    // We also use NOREDIRECTIONBITMAP since the UWP Media Player and Settings background
    // processes set those to true. The docs confirm that NOREDIRECTIONBITMAP is to be used for
    // windows that are not rendered to the main desktop conventionally.
    if (ex_style & win.WS_EX_NOACTIVATE == win.WS_EX_NOACTIVATE) {
        return win.TRUE;
    }
    if (ex_style & win.WS_EX_TOOLWINDOW == win.WS_EX_TOOLWINDOW) {
        return win.TRUE;
    }
    if (ex_style & win.WS_EX_NOREDIRECTIONBITMAP == win.WS_EX_NOREDIRECTIONBITMAP) {
        return win.TRUE;
    }

    var list: *AudioProducerEntry.List = @ptrFromInt(@as(usize, @bitCast(list_raw)));
    const tid = win.GetWindowThreadProcessId(hwnd, 0);

    const thread_handle = win.OpenThread(win.THREAD_QUERY_INFORMATION, win.FALSE, tid);

    const pid = win.GetProcessIdOfThread(thread_handle);

    if (pid == win.GetCurrentProcessId()) {
        // Don't add this window or child windows to the list.
        return win.TRUE;
    }

    var result: AudioProducerEntry = undefined;
    _ = std.fmt.bufPrint(&result.process_id, "{d}\x00", .{pid}) catch {};
    if (win.GetWindowTextA(hwnd, &result.name, result.name.len) == 0) {
        // We are not interested in windows that don't even have a title.
        return win.TRUE;
    }

    // Make sure things are null-terminated.
    result.name[result.name.len - 1] = 0;
    result.process_id[result.process_id.len - 1] = 0;

    list.append(result) catch {
        return win.FALSE;
    };
    return win.TRUE;

}

pub fn scanForAudioProducers(list: *AudioProducerEntry.List) void {
    _ = win.EnumWindows(windowDetected, @bitCast(@intFromPtr(list)));
}
