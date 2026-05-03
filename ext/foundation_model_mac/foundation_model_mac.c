#include <ruby.h>
#include "FoundationModelMac-Swift.h"

static VALUE rb_foundation_model_mac_generate(int argc, VALUE *argv, VALUE self) {
    VALUE kwargs;
    rb_scan_args(argc, argv, ":", &kwargs);

    static ID kwarg_keys[2];
    if (kwarg_keys[0] == 0) {
        kwarg_keys[0] = rb_intern("prompt");
        kwarg_keys[1] = rb_intern("instructions");
    }

    VALUE values[2];
    rb_get_kwargs(kwargs, kwarg_keys, 1, 1, values);

    VALUE prompt_v = values[0];
    VALUE instructions_v = values[1];

    const char *prompt = StringValueCStr(prompt_v);
    const char *instructions = (instructions_v == Qundef || NIL_P(instructions_v))
        ? NULL
        : StringValueCStr(instructions_v);

    char *result = foundation_model_mac_generate(prompt, instructions);
    if (result == NULL) {
        return rb_utf8_str_new_cstr("");
    }
    VALUE rb_result = rb_utf8_str_new_cstr(result);
    foundation_model_mac_free(result);
    return rb_result;
}

static VALUE rb_session_create(int argc, VALUE *argv, VALUE self) {
    VALUE kwargs;
    rb_scan_args(argc, argv, ":", &kwargs);

    static ID kwarg_keys[1];
    if (kwarg_keys[0] == 0) {
        kwarg_keys[0] = rb_intern("instructions");
    }

    VALUE values[1];
    rb_get_kwargs(kwargs, kwarg_keys, 0, 1, values);
    VALUE instructions_v = values[0];

    const char *instructions = (instructions_v == Qundef || NIL_P(instructions_v))
        ? NULL
        : StringValueCStr(instructions_v);

    uint64_t handle = foundation_model_mac_session_create(instructions);
    return ULL2NUM(handle);
}

static VALUE rb_session_respond(VALUE self, VALUE handle_v, VALUE prompt_v) {
    uint64_t handle = NUM2ULL(handle_v);
    const char *prompt = StringValueCStr(prompt_v);
    char *result = foundation_model_mac_session_respond(handle, prompt);
    if (result == NULL) {
        return rb_utf8_str_new_cstr("");
    }
    VALUE rb_result = rb_utf8_str_new_cstr(result);
    foundation_model_mac_free(result);
    return rb_result;
}

static VALUE rb_session_destroy(VALUE self, VALUE handle_v) {
    uint64_t handle = NUM2ULL(handle_v);
    foundation_model_mac_session_destroy(handle);
    return Qnil;
}

static VALUE rb_session_exists(VALUE self, VALUE handle_v) {
    uint64_t handle = NUM2ULL(handle_v);
    return foundation_model_mac_session_exists(handle) ? Qtrue : Qfalse;
}

void Init_foundation_model_mac(void) {
    VALUE module = rb_define_module("AppleFoundationModel");
    rb_define_singleton_method(module, "generate", rb_foundation_model_mac_generate, -1);

    VALUE native = rb_define_module_under(module, "Native");
    rb_define_singleton_method(native, "session_create", rb_session_create, -1);
    rb_define_singleton_method(native, "session_respond", rb_session_respond, 2);
    rb_define_singleton_method(native, "session_destroy", rb_session_destroy, 1);
    rb_define_singleton_method(native, "session_exists", rb_session_exists, 1);
}
