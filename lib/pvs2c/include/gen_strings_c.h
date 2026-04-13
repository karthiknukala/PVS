//Code generated using pvs2ir
#ifndef _gen_strings_h 
#define _gen_strings_h

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

#include "real_defs_c.h"

#include "strings_c.h"

//cc -O3 -Wall -o gen_strings -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include gen_strings_c.c <your main>.c  -lgmp -lpvs-prelude 
//get

struct gen_strings_funtype_0_s;
        typedef struct gen_strings_funtype_0_s * gen_strings_funtype_0_t;

struct gen_strings_funtype_0_ftbl_s {uint32_t (* fptr)(struct gen_strings_funtype_0_s *, mpz_ptr_t);
        uint32_t (* mptr)(struct gen_strings_funtype_0_s *, mpz_ptr_t);
        void (* rptr)(struct gen_strings_funtype_0_s *);
        struct gen_strings_funtype_0_s * (* cptr)(struct gen_strings_funtype_0_s *);};
typedef struct gen_strings_funtype_0_ftbl_s * gen_strings_funtype_0_ftbl_t;

struct gen_strings_funtype_0_hashentry_s {uint32_t keyhash; mpz_ptr_t key; uint32_t value;}; 
typedef struct gen_strings_funtype_0_hashentry_s gen_strings_funtype_0_hashentry_t;

struct gen_strings_funtype_0_htbl_s {uint32_t size; uint32_t num_entries; gen_strings_funtype_0_hashentry_t * data;}; 
typedef struct gen_strings_funtype_0_htbl_s * gen_strings_funtype_0_htbl_t;

struct gen_strings_funtype_0_s {uint32_t count;
        gen_strings_funtype_0_ftbl_t ftbl;
        gen_strings_funtype_0_htbl_t htbl;};
typedef struct gen_strings_funtype_0_s * gen_strings_funtype_0_t;

extern void release_gen_strings_funtype_0(gen_strings_funtype_0_t x);

extern gen_strings_funtype_0_t copy_gen_strings_funtype_0(gen_strings_funtype_0_t x);

extern uint32_t lookup_gen_strings_funtype_0(gen_strings_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash);

extern gen_strings_funtype_0_t dupdate_gen_strings_funtype_0(gen_strings_funtype_0_t a, mpz_ptr_t i, uint32_t v);

extern gen_strings_funtype_0_t update_gen_strings_funtype_0(gen_strings_funtype_0_t a, mpz_ptr_t i, uint32_t v);

extern bool_t equal_gen_strings_funtype_0(gen_strings_funtype_0_t x, gen_strings_funtype_0_t y);

extern char* json_gen_strings_funtype_0(gen_strings_funtype_0_t x);




struct gen_strings_closure_1_s;
        typedef struct gen_strings_closure_1_s * gen_strings_closure_1_t;

struct gen_strings_closure_1_s {uint32_t count;
         gen_strings_funtype_0_ftbl_t ftbl;
         gen_strings_funtype_0_htbl_t htbl;
        mpz_t fvar_1;};

uint32_t f_gen_strings_closure_1(struct gen_strings_closure_1_s * closure, mpz_ptr_t bvar);

uint32_t m_gen_strings_closure_1(struct gen_strings_closure_1_s * closure, mpz_ptr_t bvar);

extern uint32_t h_gen_strings_closure_1(mpz_ptr_t ivar_5, mpz_ptr_t ivar_1);

gen_strings_closure_1_t new_gen_strings_closure_1(void);

void release_gen_strings_closure_1(gen_strings_funtype_0_t closure);

gen_strings_closure_1_t copy_gen_strings_closure_1(gen_strings_closure_1_t x);


//empty

struct gen_strings_record_2_s {
        uint32_t count; 
        mpz_t length;
        gen_strings_funtype_0_t seq;};
typedef struct gen_strings_record_2_s * gen_strings_record_2_t;

extern gen_strings_record_2_t new_gen_strings_record_2(void);

extern void release_gen_strings_record_2(gen_strings_record_2_t x);

extern gen_strings_record_2_t copy_gen_strings_record_2(gen_strings_record_2_t x);

extern bool_t equal_gen_strings_record_2(gen_strings_record_2_t x, gen_strings_record_2_t y);
extern char * json_gen_strings_record_2(gen_strings_record_2_t x);

typedef struct actual_gen_strings_record_2_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_gen_strings_record_2_t;
extern void release_gen_strings_record_2_ptr(pointer_t x, type_actual_t gen_strings_record_2);

extern bool_t equal_gen_strings_record_2_ptr(pointer_t x, pointer_t y, actual_gen_strings_record_2_t T);

extern char * json_gen_strings_record_2_ptr(pointer_t x,  actual_gen_strings_record_2_t T);

actual_gen_strings_record_2_t actual_gen_strings_record_2(void);

 

extern gen_strings_record_2_t update_gen_strings_record_2_length(gen_strings_record_2_t x, mpz_ptr_t v);

extern gen_strings_record_2_t update_gen_strings_record_2_seq(gen_strings_record_2_t x, gen_strings_funtype_0_t v);




struct gen_strings_closure_3_s;
        typedef struct gen_strings_closure_3_s * gen_strings_closure_3_t;

struct gen_strings_closure_3_s {uint32_t count;
         gen_strings_funtype_0_ftbl_t ftbl;
         gen_strings_funtype_0_htbl_t htbl;
        mpz_t fvar_1;
        uint32_t fvar_2;};

uint32_t f_gen_strings_closure_3(struct gen_strings_closure_3_s * closure, mpz_ptr_t bvar);

uint32_t m_gen_strings_closure_3(struct gen_strings_closure_3_s * closure, mpz_ptr_t bvar);

extern uint32_t h_gen_strings_closure_3(mpz_ptr_t ivar_6, mpz_ptr_t ivar_2, uint32_t ivar_1);

gen_strings_closure_3_t new_gen_strings_closure_3(void);

void release_gen_strings_closure_3(gen_strings_funtype_0_t closure);

gen_strings_closure_3_t copy_gen_strings_closure_3(gen_strings_closure_3_t x);




struct gen_strings_closure_4_s;
        typedef struct gen_strings_closure_4_s * gen_strings_closure_4_t;

struct gen_strings_closure_4_s {uint32_t count;
         gen_strings_funtype_0_ftbl_t ftbl;
         gen_strings_funtype_0_htbl_t htbl;
        strings__string_t fvar_1;
        mpz_t fvar_2;};

uint32_t f_gen_strings_closure_4(struct gen_strings_closure_4_s * closure, mpz_ptr_t bvar);

uint32_t m_gen_strings_closure_4(struct gen_strings_closure_4_s * closure, mpz_ptr_t bvar);

extern uint32_t h_gen_strings_closure_4(mpz_ptr_t ivar_16, strings__string_t ivar_1, mpz_ptr_t ivar_2);

gen_strings_closure_4_t new_gen_strings_closure_4(void);

void release_gen_strings_closure_4(gen_strings_funtype_0_t closure);

gen_strings_closure_4_t copy_gen_strings_closure_4(gen_strings_closure_4_t x);




struct gen_strings_closure_5_s;
        typedef struct gen_strings_closure_5_s * gen_strings_closure_5_t;

struct gen_strings_closure_5_s {uint32_t count;
         gen_strings_funtype_0_ftbl_t ftbl;
         gen_strings_funtype_0_htbl_t htbl;
        strings__string_t fvar_1;
        mpz_t fvar_2;
        mpz_t fvar_3;};

uint32_t f_gen_strings_closure_5(struct gen_strings_closure_5_s * closure, mpz_ptr_t bvar);

uint32_t m_gen_strings_closure_5(struct gen_strings_closure_5_s * closure, mpz_ptr_t bvar);

extern uint32_t h_gen_strings_closure_5(mpz_ptr_t ivar_28, strings__string_t ivar_1, mpz_ptr_t ivar_2, mpz_ptr_t ivar_12);

gen_strings_closure_5_t new_gen_strings_closure_5(void);

void release_gen_strings_closure_5(gen_strings_funtype_0_t closure);

gen_strings_closure_5_t copy_gen_strings_closure_5(gen_strings_closure_5_t x);



extern mpz_ptr_t gen_strings__length(strings__string_t ivar_1);

extern uint32_t gen_strings__get(strings__string_t ivar_1, mpz_ptr_t ivar_2);

extern strings__string_t gen_strings__empty(void);

extern strings__string_t gen_strings__unit(uint32_t ivar_1);

extern mpz_ptr_t gen_strings__strdiff_rec(strings__string_t ivar_1, strings__string_t ivar_2, mpz_ptr_t ivar_3);

extern mpz_ptr_t gen_strings__strdiff(strings__string_t ivar_1, strings__string_t ivar_2);

extern int8_t gen_strings__strcmp(strings__string_t ivar_1, strings__string_t ivar_2);

extern strings__string_t gen_strings__prefix(strings__string_t ivar_1, mpz_ptr_t ivar_2);

extern strings__string_t gen_strings__suffix(strings__string_t ivar_1, mpz_ptr_t ivar_2);

extern strings__string_t gen_strings__substr(strings__string_t ivar_1, mpz_ptr_t ivar_2, mpz_ptr_t ivar_4);
#endif