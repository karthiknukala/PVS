SDK=$(shell xcrun --show-sdk-path)
CFLAGS := -g -O2 -Wall -pedantic -std=gnu99 -mtune=native -mcpu=apple-a14 -I ../include
LDFLAGS = -dylib -flat_namespace -undefined suppress -arch arm64 -platform_version macos 11.0.0 12.0 -L $(SDK)/usr/lib -L./ -lc -lm -lgmp

src := pvslib.c xor_def_c.c transpose_c.c identity_c.c sets_c.c real_defs_c.c modulo_arithmetic_c.c exp2_c.c integertypes_c.c sequences_c.c finite_sequences_c.c more_finseq_c.c array_sequences_c.c ordstruct_adt_c.c ordinals_c.c lex2_c.c list_adt_c.c strings_c.c gen_strings_c.c bytestrings_c.c lift_adt_c.c file_c.c empty_bv_c.c integer_bv_ops_c.c

obj := $(src:.c=.o)

.c.o : ; $(CC) ${CFLAGS} -c $< -o $@

all : ../lib/libpvs-prelude.dylib ../lib/libpvs-prelude.a

../lib/libpvs-prelude.dylib : ${obj}
	$(LD) $(LDFLAGS) -o $@ ${obj}

../lib/libpvs-prelude.a : $(obj)
	$(AR) r $@ ${obj}

clean :
	-rm $(obj)
	-rm ../lib/libpvs-prelude.dylib ../lib/libpvs-prelude.a
