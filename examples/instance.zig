const std = @import("std");
const wasmer = @import("wasmer");
const assert = std.debug.assert;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;

const wat =
    \\(module
    \\  (type $add_one_t (func (param i32) (result i32)))
    \\  (func $add_ont_f (type $add_one_t) (param $value i32) (result i32)
    \\    local.get $value
    \\    i32.const 1
    \\    i32.add)
    \\  (export "add_one" (func $add_one_f)))
;

pub fn main() !void {
    var wat_bytes = wasmer.ByteVec.fromSlice(wat);
    defer wat_bytes.deinit();

    var wasm_bytes: wasmer.ByteVec = undefined;
    wasmer.wat2wasm(&wat_bytes, &wasm_bytes);
    defer wasm_bytes.deinit();

    std.log.info("creating the store...", .{});

    const engine = try wasmer.Engine.init();
    defer engine.deinit();
    const store = try wasmer.Store.init(engine);
    defer store.deinit();

    std.log.info("compiling module...", .{});

    const module = try wasmer.Module.init(store, wasm_bytes.toSlice());
    defer module.deinit();

    std.log.info("instantiating module...", .{});

    const instance = try wasmer.Instance.init(store, module, &.{});
    defer instance.deinit();

    std.log.info("retrieving exports...", .{});

    const add_one = instance.getExportFunc("add_one") orelse {
        std.log.err("failed to retrieve \"add_one\" export from instance", .{});
        return error.ExportNotFound;
    };
    defer add_one.deinit();

    std.log.info("calling \"add_one\" export fn...", .{});

    const res = try add_one.call(i32, .{@as(i32, 1)});
    assert(res == 2);

    std.log.info("result of \"add_one(1)\" = {}", .{res});
}
