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

void Init_foundation_model_mac(void) {
    VALUE module = rb_define_module("AppleFoundationModel");
    rb_define_singleton_method(module, "generate", rb_foundation_model_mac_generate, -1);
}
