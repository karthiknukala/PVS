//Code generated using pvs2ir
#ifndef _finite_sequences_h 
#define _finite_sequences_h

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

#include "real_defs_c.h"

//cc -O3 -Wall -o finite_sequences -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include finite_sequences_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t finite_sequences__T_t;
//finite_sequence

struct finite_sequences_funtype_0_s;
        typedef struct finite_sequences_funtype_0_s * finite_sequences_funtype_0_t;

struct finite_sequences_funtype_0_ftbl_s {finite_sequences__T_t (* fptr)(struct finite_sequences_funtype_0_s *, mpz_ptr_t);
        finite_sequences__T_t (* mptr)(struct finite_sequences_funtype_0_s *, mpz_ptr_t);
        void (* rptr)(struct finite_sequences_funtype_0_s *);
        struct finite_sequences_funtype_0_s * (* cptr)(struct finite_sequences_funtype_0_s *);};
typedef struct finite_sequences_funtype_0_ftbl_s * finite_sequences_funtype_0_ftbl_t;

struct finite_sequences_funtype_0_hashentry_s {uint32_t keyhash; mpz_ptr_t key; finite_sequences__T_t value;}; 
typedef struct finite_sequences_funtype_0_hashentry_s finite_sequences_funtype_0_hashentry_t;

struct finite_sequences_funtype_0_htbl_s {uint32_t size; uint32_t num_entries; finite_sequences_funtype_0_hashentry_t * data;}; 
typedef struct finite_sequences_funtype_0_htbl_s * finite_sequences_funtype_0_htbl_t;

struct finite_sequences_funtype_0_s {uint32_t count;
        finite_sequences_funtype_0_ftbl_t ftbl;
        finite_sequences_funtype_0_htbl_t htbl;};
typedef struct finite_sequences_funtype_0_s * finite_sequences_funtype_0_t;

extern void release_finite_sequences_funtype_0(finite_sequences_funtype_0_t x, type_actual_t finite_sequences__T);

extern finite_sequences_funtype_0_t copy_finite_sequences_funtype_0(finite_sequences_funtype_0_t x);

extern uint32_t lookup_finite_sequences_funtype_0(finite_sequences_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash);

extern finite_sequences_funtype_0_t dupdate_finite_sequences_funtype_0(finite_sequences_funtype_0_t a, mpz_ptr_t i, finite_sequences__T_t v, type_actual_t finite_sequences__T);

extern finite_sequences_funtype_0_t update_finite_sequences_funtype_0(finite_sequences_funtype_0_t a, mpz_ptr_t i, finite_sequences__T_t v, type_actual_t finite_sequences__T);

extern bool_t equal_finite_sequences_funtype_0(finite_sequences_funtype_0_t x, finite_sequences_funtype_0_t y, type_actual_t finite_sequences__T);

extern char* json_finite_sequences_funtype_0(finite_sequences_funtype_0_t x, type_actual_t finite_sequences__T);


//finite_sequence

struct finite_sequences__finite_sequence_s {
        uint32_t count; 
        mpz_t length;
        finite_sequences_funtype_0_t seq;};
typedef struct finite_sequences__finite_sequence_s * finite_sequences__finite_sequence_t;

extern finite_sequences__finite_sequence_t new_finite_sequences__finite_sequence(void);

extern void release_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x, type_actual_t finite_sequences__T);

extern finite_sequences__finite_sequence_t copy_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x);

extern bool_t equal_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x, finite_sequences__finite_sequence_t y, type_actual_t finite_sequences__T);
extern char * json_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x, type_actual_t finite_sequences__T);

typedef struct actual_finite_sequences__finite_sequence_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t finite_sequences__T;} * actual_finite_sequences__finite_sequence_t;
extern void release_finite_sequences__finite_sequence_ptr(pointer_t x, type_actual_t finite_sequences__finite_sequence);

extern bool_t equal_finite_sequences__finite_sequence_ptr(pointer_t x, pointer_t y, actual_finite_sequences__finite_sequence_t T);

extern char * json_finite_sequences__finite_sequence_ptr(pointer_t x,  actual_finite_sequences__finite_sequence_t T);

actual_finite_sequences__finite_sequence_t actual_finite_sequences__finite_sequence(type_actual_t finite_sequences__T);

 

extern finite_sequences__finite_sequence_t update_finite_sequences__finite_sequence_length(finite_sequences__finite_sequence_t x, mpz_ptr_t v);

extern finite_sequences__finite_sequence_t update_finite_sequences__finite_sequence_seq(finite_sequences__finite_sequence_t x, finite_sequences_funtype_0_t v, type_actual_t finite_sequences__T);




struct finite_sequences_closure_2_s;
        typedef struct finite_sequences_closure_2_s * finite_sequences_closure_2_t;

struct finite_sequences_closure_2_s {uint32_t count;
         finite_sequences_funtype_0_ftbl_t ftbl;
         finite_sequences_funtype_0_htbl_t htbl;
        type_actual_t fvar_1;
        mpz_t fvar_2; type_actual_t finite_sequences__T;};

finite_sequences__T_t f_finite_sequences_closure_2(struct finite_sequences_closure_2_s * closure, mpz_ptr_t bvar);

finite_sequences__T_t m_finite_sequences_closure_2(struct finite_sequences_closure_2_s * closure, mpz_ptr_t bvar);

extern finite_sequences__T_t h_finite_sequences_closure_2(mpz_ptr_t ivar_5, type_actual_t finite_sequences__T, mpz_ptr_t ivar_1);

finite_sequences_closure_2_t new_finite_sequences_closure_2(void);

void release_finite_sequences_closure_2(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T);

finite_sequences_closure_2_t copy_finite_sequences_closure_2(finite_sequences_closure_2_t x);




struct finite_sequences_closure_3_s;
        typedef struct finite_sequences_closure_3_s * finite_sequences_closure_3_t;

struct finite_sequences_closure_3_s {uint32_t count;
         finite_sequences_funtype_0_ftbl_t ftbl;
         finite_sequences_funtype_0_htbl_t htbl;
        type_actual_t fvar_1;
        mpz_t fvar_2;
        finite_sequences__finite_sequence_t fvar_3;
        finite_sequences__finite_sequence_t fvar_4;
        mpz_t fvar_5; type_actual_t finite_sequences__T;};

finite_sequences__T_t f_finite_sequences_closure_3(struct finite_sequences_closure_3_s * closure, mpz_ptr_t bvar);

finite_sequences__T_t m_finite_sequences_closure_3(struct finite_sequences_closure_3_s * closure, mpz_ptr_t bvar);

extern finite_sequences__T_t h_finite_sequences_closure_3(mpz_ptr_t ivar_16, type_actual_t finite_sequences__T, mpz_ptr_t ivar_7, finite_sequences__finite_sequence_t ivar_2, finite_sequences__finite_sequence_t ivar_1, mpz_ptr_t ivar_3);

finite_sequences_closure_3_t new_finite_sequences_closure_3(void);

void release_finite_sequences_closure_3(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T);

finite_sequences_closure_3_t copy_finite_sequences_closure_3(finite_sequences_closure_3_t x);


//^

struct finite_sequences_record_4_s {
        uint32_t count; 
        mpz_t project_1;
        mpz_t project_2;};
typedef struct finite_sequences_record_4_s * finite_sequences_record_4_t;

extern finite_sequences_record_4_t new_finite_sequences_record_4(void);

extern void release_finite_sequences_record_4(finite_sequences_record_4_t x, type_actual_t finite_sequences__T);

extern finite_sequences_record_4_t copy_finite_sequences_record_4(finite_sequences_record_4_t x);

extern bool_t equal_finite_sequences_record_4(finite_sequences_record_4_t x, finite_sequences_record_4_t y, type_actual_t finite_sequences__T);
extern char * json_finite_sequences_record_4(finite_sequences_record_4_t x, type_actual_t finite_sequences__T);

typedef struct actual_finite_sequences_record_4_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t finite_sequences__T;} * actual_finite_sequences_record_4_t;
extern void release_finite_sequences_record_4_ptr(pointer_t x, type_actual_t finite_sequences_record_4);

extern bool_t equal_finite_sequences_record_4_ptr(pointer_t x, pointer_t y, actual_finite_sequences_record_4_t T);

extern char * json_finite_sequences_record_4_ptr(pointer_t x,  actual_finite_sequences_record_4_t T);

actual_finite_sequences_record_4_t actual_finite_sequences_record_4(type_actual_t finite_sequences__T);

 

extern finite_sequences_record_4_t update_finite_sequences_record_4_project_1(finite_sequences_record_4_t x, mpz_ptr_t v);

extern finite_sequences_record_4_t update_finite_sequences_record_4_project_2(finite_sequences_record_4_t x, mpz_ptr_t v);




struct finite_sequences_closure_5_s;
        typedef struct finite_sequences_closure_5_s * finite_sequences_closure_5_t;

struct finite_sequences_closure_5_s {uint32_t count;
         finite_sequences_funtype_0_ftbl_t ftbl;
         finite_sequences_funtype_0_htbl_t htbl;
        type_actual_t fvar_1;
        mpz_t fvar_2;
        mpz_t fvar_3;
        finite_sequences__finite_sequence_t fvar_4; type_actual_t finite_sequences__T;};

finite_sequences__T_t f_finite_sequences_closure_5(struct finite_sequences_closure_5_s * closure, mpz_ptr_t bvar);

finite_sequences__T_t m_finite_sequences_closure_5(struct finite_sequences_closure_5_s * closure, mpz_ptr_t bvar);

extern finite_sequences__T_t h_finite_sequences_closure_5(mpz_ptr_t ivar_47, type_actual_t finite_sequences__T, mpz_ptr_t ivar_23, mpz_ptr_t ivar_3, finite_sequences__finite_sequence_t ivar_1);

finite_sequences_closure_5_t new_finite_sequences_closure_5(void);

void release_finite_sequences_closure_5(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T);

finite_sequences_closure_5_t copy_finite_sequences_closure_5(finite_sequences_closure_5_t x);




struct finite_sequences_closure_6_s;
        typedef struct finite_sequences_closure_6_s * finite_sequences_closure_6_t;

struct finite_sequences_closure_6_s {uint32_t count;
         finite_sequences_funtype_0_ftbl_t ftbl;
         finite_sequences_funtype_0_htbl_t htbl;
        type_actual_t fvar_1;
        mpz_t fvar_2;
        mpz_t fvar_3;
        finite_sequences__finite_sequence_t fvar_4; type_actual_t finite_sequences__T;};

finite_sequences__T_t f_finite_sequences_closure_6(struct finite_sequences_closure_6_s * closure, mpz_ptr_t bvar);

finite_sequences__T_t m_finite_sequences_closure_6(struct finite_sequences_closure_6_s * closure, mpz_ptr_t bvar);

extern finite_sequences__T_t h_finite_sequences_closure_6(mpz_ptr_t ivar_44, type_actual_t finite_sequences__T, mpz_ptr_t ivar_23, mpz_ptr_t ivar_3, finite_sequences__finite_sequence_t ivar_1);

finite_sequences_closure_6_t new_finite_sequences_closure_6(void);

void release_finite_sequences_closure_6(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T);

finite_sequences_closure_6_t copy_finite_sequences_closure_6(finite_sequences_closure_6_t x);



extern finite_sequences__finite_sequence_t finite_sequences__empty_seq(type_actual_t finite_sequences__T);

extern finite_sequences_funtype_0_t finite_sequences__finseq_appl(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1);

extern finite_sequences__finite_sequence_t finite_sequences__oh(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1, finite_sequences__finite_sequence_t ivar_2);

extern finite_sequences__finite_sequence_t finite_sequences__caret(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1, finite_sequences_record_4_t ivar_2);

extern finite_sequences__finite_sequence_t finite_sequences__doublecaret(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1, finite_sequences_record_4_t ivar_2);

extern finite_sequences__T_t finite_sequences__extract1(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1);
#endif