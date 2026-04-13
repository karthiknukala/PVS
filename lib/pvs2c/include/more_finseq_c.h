//Code generated using pvs2ir
#ifndef _more_finseq_h 
#define _more_finseq_h

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

#include "finite_sequences_c.h"

//cc -O3 -Wall -o more_finseq -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include more_finseq_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t more_finseq__T_t;
//seq

struct more_finseq_funtype_0_s;
        typedef struct more_finseq_funtype_0_s * more_finseq_funtype_0_t;

struct more_finseq_funtype_0_ftbl_s {more_finseq__T_t (* fptr)(struct more_finseq_funtype_0_s *, mpz_ptr_t);
        more_finseq__T_t (* mptr)(struct more_finseq_funtype_0_s *, mpz_ptr_t);
        void (* rptr)(struct more_finseq_funtype_0_s *);
        struct more_finseq_funtype_0_s * (* cptr)(struct more_finseq_funtype_0_s *);};
typedef struct more_finseq_funtype_0_ftbl_s * more_finseq_funtype_0_ftbl_t;

struct more_finseq_funtype_0_hashentry_s {uint32_t keyhash; mpz_ptr_t key; more_finseq__T_t value;}; 
typedef struct more_finseq_funtype_0_hashentry_s more_finseq_funtype_0_hashentry_t;

struct more_finseq_funtype_0_htbl_s {uint32_t size; uint32_t num_entries; more_finseq_funtype_0_hashentry_t * data;}; 
typedef struct more_finseq_funtype_0_htbl_s * more_finseq_funtype_0_htbl_t;

struct more_finseq_funtype_0_s {uint32_t count;
        more_finseq_funtype_0_ftbl_t ftbl;
        more_finseq_funtype_0_htbl_t htbl;};
typedef struct more_finseq_funtype_0_s * more_finseq_funtype_0_t;

extern void release_more_finseq_funtype_0(more_finseq_funtype_0_t x, type_actual_t more_finseq__T);

extern more_finseq_funtype_0_t copy_more_finseq_funtype_0(more_finseq_funtype_0_t x);

extern uint32_t lookup_more_finseq_funtype_0(more_finseq_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash);

extern more_finseq_funtype_0_t dupdate_more_finseq_funtype_0(more_finseq_funtype_0_t a, mpz_ptr_t i, more_finseq__T_t v, type_actual_t more_finseq__T);

extern more_finseq_funtype_0_t update_more_finseq_funtype_0(more_finseq_funtype_0_t a, mpz_ptr_t i, more_finseq__T_t v, type_actual_t more_finseq__T);

extern bool_t equal_more_finseq_funtype_0(more_finseq_funtype_0_t x, more_finseq_funtype_0_t y, type_actual_t more_finseq__T);

extern char* json_more_finseq_funtype_0(more_finseq_funtype_0_t x, type_actual_t more_finseq__T);


//seq

struct more_finseq__seq_s {
        uint32_t count; 
        mpz_t length;
        more_finseq_funtype_0_t seq;};
typedef struct more_finseq__seq_s * more_finseq__seq_t;

extern more_finseq__seq_t new_more_finseq__seq(void);

extern void release_more_finseq__seq(more_finseq__seq_t x, type_actual_t more_finseq__T);

extern more_finseq__seq_t copy_more_finseq__seq(more_finseq__seq_t x);

extern bool_t equal_more_finseq__seq(more_finseq__seq_t x, more_finseq__seq_t y, type_actual_t more_finseq__T);
extern char * json_more_finseq__seq(more_finseq__seq_t x, type_actual_t more_finseq__T);

typedef struct actual_more_finseq__seq_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t more_finseq__T;} * actual_more_finseq__seq_t;
extern void release_more_finseq__seq_ptr(pointer_t x, type_actual_t more_finseq__seq);

extern bool_t equal_more_finseq__seq_ptr(pointer_t x, pointer_t y, actual_more_finseq__seq_t T);

extern char * json_more_finseq__seq_ptr(pointer_t x,  actual_more_finseq__seq_t T);

actual_more_finseq__seq_t actual_more_finseq__seq(type_actual_t more_finseq__T);

 

extern more_finseq__seq_t update_more_finseq__seq_length(more_finseq__seq_t x, mpz_ptr_t v);

extern more_finseq__seq_t update_more_finseq__seq_seq(more_finseq__seq_t x, more_finseq_funtype_0_t v, type_actual_t more_finseq__T);



extern more_finseq__seq_t more_finseq__add(type_actual_t more_finseq__T, more_finseq__T_t ivar_1, more_finseq__seq_t ivar_2);
#endif