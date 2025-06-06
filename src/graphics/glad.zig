//! Zig generates unique types for each C import instance.
//! For this reason, headers should be imported only once.
pub usingnamespace @cImport({
    @cInclude("glad/glad.h");
});
