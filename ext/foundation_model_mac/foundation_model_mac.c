#include <ruby.h>
#include <ruby/thread.h>
#include "FoundationModelMac-Swift.h"

static VALUE eGenerationError;
static ID id_active_stream;

static void session_free(void *session) {
    if (session) foundation_model_mac_session_free(session);
}

static const rb_data_type_t session_type = {
    "AppleFoundationModel::Native",
    { NULL, session_free, NULL, },
    NULL, NULL, RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE take_string(char *buffer) {
    VALUE string = rb_utf8_str_new_cstr(buffer);
    foundation_model_mac_free(buffer);
    return string;
}

static VALUE rb_unavailable_reason(VALUE self) {
    char *reason = foundation_model_mac_unavailable_reason();
    return reason ? take_string(reason) : Qnil;
}

static VALUE rb_native_alloc(VALUE klass) {
    return TypedData_Wrap_Struct(klass, &session_type, NULL);
}

static VALUE rb_native_initialize(int argc, VALUE *argv, VALUE self) {
    VALUE instructions;
    rb_scan_args(argc, argv, "01", &instructions);
    DATA_PTR(self) = foundation_model_mac_session_new(NIL_P(instructions) ? NULL : StringValueCStr(instructions));
    return self;
}

struct stream_args {
    VALUE self;
    void *stream;
    char *chunk;
    char *error;
};

static void *next_without_gvl(void *data) {
    struct stream_args *args = data;
    args->chunk = foundation_model_mac_stream_next(args->stream, &args->error);
    return NULL;
}

static void cancel_stream(void *stream) {
    foundation_model_mac_stream_cancel(stream);
}

static VALUE stream_each(VALUE data) {
    struct stream_args *args = (struct stream_args *)data;
    for (;;) {
        rb_thread_call_without_gvl(next_without_gvl, args, cancel_stream, args->stream);
        char *chunk = args->chunk;
        char *error = args->error;
        args->chunk = NULL;
        args->error = NULL;
        if (error) rb_exc_raise(rb_exc_new_str(eGenerationError, take_string(error)));
        if (!chunk) return Qnil;
        rb_yield(take_string(chunk));
    }
}

static VALUE stream_close(VALUE data) {
    struct stream_args *args = (struct stream_args *)data;
    foundation_model_mac_free(args->chunk);
    foundation_model_mac_free(args->error);
    foundation_model_mac_stream_cancel(args->stream);
    char *chunk;
    char *error = NULL;
    while ((chunk = foundation_model_mac_stream_next(args->stream, &error))) {
        foundation_model_mac_free(chunk);
    }
    foundation_model_mac_free(error);
    foundation_model_mac_stream_free(args->stream);
    rb_ivar_set(args->self, id_active_stream, Qnil);
    return Qnil;
}

static VALUE rb_native_stream(int argc, VALUE *argv, VALUE self) {
    VALUE prompt, options;
    rb_scan_args(argc, argv, "1:", &prompt, &options);

    ID keyword = rb_intern("stop_at");
    VALUE stop_at = Qundef;
    if (!NIL_P(options)) rb_get_kwargs(options, &keyword, 0, 1, &stop_at);

    long stop_count = 0;
    const char **stops = NULL;
    if (stop_at != Qundef && !NIL_P(stop_at)) {
        Check_Type(stop_at, T_ARRAY);
        stop_count = RARRAY_LEN(stop_at);
        stops = ALLOCA_N(const char *, stop_count);
        for (long i = 0; i < stop_count; i++) {
            VALUE stop = RARRAY_AREF(stop_at, i);
            stops[i] = StringValueCStr(stop);
        }
    }

    struct stream_args args = { self, NULL, NULL, NULL };
    args.stream = foundation_model_mac_stream_start(DATA_PTR(self), StringValueCStr(prompt), stops, stop_count);
    rb_ivar_set(self, id_active_stream, ULL2NUM((uintptr_t)args.stream));
    rb_ensure(stream_each, (VALUE)&args, stream_close, (VALUE)&args);
    return Qnil;
}

static VALUE rb_native_cancel_stream(VALUE self) {
    VALUE stream = rb_ivar_get(self, id_active_stream);
    if (!NIL_P(stream)) foundation_model_mac_stream_cancel((void *)(uintptr_t)NUM2ULL(stream));
    return Qnil;
}

void Init_foundation_model_mac(void) {
    VALUE module = rb_define_module("AppleFoundationModel");
    eGenerationError = rb_const_get(module, rb_intern("GenerationError"));
    rb_global_variable(&eGenerationError);
    id_active_stream = rb_intern("@__active_stream");

    rb_define_singleton_method(module, "__availability_reason", rb_unavailable_reason, 0);

    VALUE native = rb_define_class_under(module, "Native", rb_cObject);
    rb_define_alloc_func(native, rb_native_alloc);
    rb_define_method(native, "initialize", rb_native_initialize, -1);
    rb_define_method(native, "stream", rb_native_stream, -1);
    rb_define_method(native, "cancel_stream", rb_native_cancel_stream, 0);
}
