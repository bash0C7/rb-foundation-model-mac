#include <ruby.h>
#include <stdlib.h>
#include "FoundationModelMac-Swift.h"

static VALUE eFmm, eUnavail, eGen;

static void fmm_dfree(void *p) {
    if (p) fmm_session_free(p);
}

static const rb_data_type_t fmm_dt = {
    "AppleFoundationModel::Session::Native",
    { NULL, fmm_dfree, NULL, },
    NULL, NULL, RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE rb_fmm_availability(VALUE self) {
    char *r = fmm_availability_check();
    if (!r) return Qnil;
    VALUE s = rb_utf8_str_new_cstr(r);
    free(r);
    return s;
}

static VALUE rb_fmm_alloc(VALUE klass) {
    return TypedData_Wrap_Struct(klass, &fmm_dt, NULL);
}

static VALUE rb_fmm_init(int argc, VALUE *argv, VALUE self) {
    VALUE instr;
    rb_scan_args(argc, argv, "01", &instr);
    char *err = NULL;
    const char *c_instr = NIL_P(instr) ? NULL : StringValueCStr(instr);
    void *p = fmm_session_new(c_instr, &err);
    if (err) {
        VALUE m = rb_utf8_str_new_cstr(err);
        free(err);
        rb_raise(eGen, "%s", StringValueCStr(m));
    }
    DATA_PTR(self) = p;
    return self;
}

static VALUE rb_fmm_respond(VALUE self, VALUE prompt) {
    void *p = DATA_PTR(self);
    char *err = NULL;
    char *res = fmm_session_respond(p, StringValueCStr(prompt), &err);
    if (err) {
        VALUE m = rb_utf8_str_new_cstr(err);
        free(err);
        rb_raise(eGen, "%s", StringValueCStr(m));
    }
    VALUE r = rb_utf8_str_new_cstr(res);
    free(res);
    return r;
}

static void stream_cb(const char *chunk) {
    rb_yield(rb_utf8_str_new_cstr(chunk));
}

static VALUE rb_fmm_stream(VALUE self, VALUE prompt) {
    void *p = DATA_PTR(self);
    char *err = NULL;
    fmm_session_stream(p, StringValueCStr(prompt), stream_cb, &err);
    if (err) {
        VALUE m = rb_utf8_str_new_cstr(err);
        free(err);
        rb_raise(eGen, "%s", StringValueCStr(m));
    }
    return Qnil;
}

void Init_foundation_model_mac(void) {
    VALUE mod = rb_define_module("AppleFoundationModel");
    eFmm     = rb_const_get(mod, rb_intern("Error"));
    eUnavail = rb_const_get(mod, rb_intern("UnavailableError"));
    eGen     = rb_const_get(mod, rb_intern("GenerationError"));

    rb_define_singleton_method(mod, "__availability_reason", rb_fmm_availability, 0);

    VALUE cNative = rb_define_class_under(mod, "__Native", rb_cObject);
    rb_define_alloc_func(cNative, rb_fmm_alloc);
    rb_define_method(cNative, "initialize", rb_fmm_init,    -1);
    rb_define_method(cNative, "respond",    rb_fmm_respond,  1);
    rb_define_method(cNative, "stream",     rb_fmm_stream,   1);
}
