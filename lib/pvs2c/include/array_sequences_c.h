//Code generated using pvs2ir
#ifndef _array_sequences_h 
#define _array_sequences_h

#include <stdio.h>

#include <stdlib.h>

#include <inttypes.h>

#include <stdbool.h>

#include <stdarg.h>

#include <string.h>

#include <fcntl.h>

#include <math.h>

#include <sys/mman.h>

#include <sys/stat.h>

#include <sys/types.h>

#include <gmp.h>

#include "pvslib.h"

#include "exp2_c.h"

#include "integertypes_c.h"

//cc -O3 -Wall -o array_sequences -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include array_sequences_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t array_sequences__T_t;
//arrayseq

struct array_sequences_array_0_s { uint32_t count;
        uint32_t size;
         uint32_t max;
         array_sequences__T_t elems[]; };
typedef struct array_sequences_array_0_s * array_sequences_array_0_t;

extern array_sequences_array_0_t new_array_sequences_array_0(uint32_t size);

extern void release_array_sequences_array_0(array_sequences_array_0_t x, type_actual_t array_sequences__T);

extern array_sequences_array_0_t copy_array_sequences_array_0(array_sequences_array_0_t x);

extern bool_t equal_array_sequences_array_0(array_sequences_array_0_t x, array_sequences_array_0_t y, type_actual_t array_sequences__T);
extern char * json_array_sequences_array_0(array_sequences_array_0_t x, type_actual_t array_sequences__T);

typedef struct actual_array_sequences_array_0_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t array_sequences__T;} * actual_array_sequences_array_0_t;
extern void release_array_sequences_array_0_ptr(pointer_t x, type_actual_t array_sequences_array_0);

extern bool_t equal_array_sequences_array_0_ptr(pointer_t x, pointer_t y, type_actual_t T);

extern char * json_array_sequences_array_0_ptr(pointer_t x, type_actual_t T);

actual_array_sequences_array_0_t actual_array_sequences_array_0(type_actual_t array_sequences__T);

 

extern array_sequences_array_0_t update_array_sequences_array_0(array_sequences_array_0_t x, uint32_t i, array_sequences__T_t v, type_actual_t array_sequences__T);

extern array_sequences_array_0_t upgrade_array_sequences_array_0(array_sequences_array_0_t x, uint32_t i, array_sequences__T_t v, type_actual_t array_sequences__T);


//arrayseq

struct array_sequences__arrayseq_s {
        uint32_t count; 
        uint32_t length;
        array_sequences_array_0_t seq;};
typedef struct array_sequences__arrayseq_s * array_sequences__arrayseq_t;

extern array_sequences__arrayseq_t new_array_sequences__arrayseq(void);

extern void release_array_sequences__arrayseq(array_sequences__arrayseq_t x, type_actual_t array_sequences__T);

extern array_sequences__arrayseq_t copy_array_sequences__arrayseq(array_sequences__arrayseq_t x);

extern bool_t equal_array_sequences__arrayseq(array_sequences__arrayseq_t x, array_sequences__arrayseq_t y, type_actual_t array_sequences__T);
extern char * json_array_sequences__arrayseq(array_sequences__arrayseq_t x, type_actual_t array_sequences__T);

typedef struct actual_array_sequences__arrayseq_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t array_sequences__T;} * actual_array_sequences__arrayseq_t;
extern void release_array_sequences__arrayseq_ptr(pointer_t x, type_actual_t array_sequences__arrayseq);

extern bool_t equal_array_sequences__arrayseq_ptr(pointer_t x, pointer_t y, actual_array_sequences__arrayseq_t T);

extern char * json_array_sequences__arrayseq_ptr(pointer_t x,  actual_array_sequences__arrayseq_t T);

actual_array_sequences__arrayseq_t actual_array_sequences__arrayseq(type_actual_t array_sequences__T);

 

extern array_sequences__arrayseq_t update_array_sequences__arrayseq_length(array_sequences__arrayseq_t x, uint32_t v);

extern array_sequences__arrayseq_t update_array_sequences__arrayseq_seq(array_sequences__arrayseq_t x, array_sequences_array_0_t v, type_actual_t array_sequences__T);



extern array_sequences__arrayseq_t array_sequences__empty_aseq(type_actual_t array_sequences__T);

extern bool_t array_sequences__full_aseqp(type_actual_t array_sequences__T, array_sequences__arrayseq_t ivar_1);

extern array_sequences_array_0_t array_sequences__aseq_appl(type_actual_t array_sequences__T, array_sequences__arrayseq_t ivar_1);

extern array_sequences__arrayseq_t array_sequences__aseq_add(type_actual_t array_sequences__T, array_sequences__T_t ivar_1, array_sequences__arrayseq_t ivar_2);
#endif