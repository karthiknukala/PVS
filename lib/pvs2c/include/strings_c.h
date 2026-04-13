//Code generated using pvs2ir
#ifndef _strings_h 
#define _strings_h

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

//cc -O3 -Wall -o strings -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include strings_c.c <your main>.c  -lgmp -lpvs-prelude 
//string

struct strings_funtype_0_s;
        typedef struct strings_funtype_0_s * strings_funtype_0_t;

struct strings_funtype_0_ftbl_s {uint32_t (* fptr)(struct strings_funtype_0_s *, mpz_ptr_t);
        uint32_t (* mptr)(struct strings_funtype_0_s *, mpz_ptr_t);
        void (* rptr)(struct strings_funtype_0_s *);
        struct strings_funtype_0_s * (* cptr)(struct strings_funtype_0_s *);};
typedef struct strings_funtype_0_ftbl_s * strings_funtype_0_ftbl_t;

struct strings_funtype_0_hashentry_s {uint32_t keyhash; mpz_ptr_t key; uint32_t value;}; 
typedef struct strings_funtype_0_hashentry_s strings_funtype_0_hashentry_t;

struct strings_funtype_0_htbl_s {uint32_t size; uint32_t num_entries; strings_funtype_0_hashentry_t * data;}; 
typedef struct strings_funtype_0_htbl_s * strings_funtype_0_htbl_t;

struct strings_funtype_0_s {uint32_t count;
        strings_funtype_0_ftbl_t ftbl;
        strings_funtype_0_htbl_t htbl;};
typedef struct strings_funtype_0_s * strings_funtype_0_t;

extern void release_strings_funtype_0(strings_funtype_0_t x);

extern strings_funtype_0_t copy_strings_funtype_0(strings_funtype_0_t x);

extern uint32_t lookup_strings_funtype_0(strings_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash);

extern strings_funtype_0_t dupdate_strings_funtype_0(strings_funtype_0_t a, mpz_ptr_t i, uint32_t v);

extern strings_funtype_0_t update_strings_funtype_0(strings_funtype_0_t a, mpz_ptr_t i, uint32_t v);

extern bool_t equal_strings_funtype_0(strings_funtype_0_t x, strings_funtype_0_t y);

extern char* json_strings_funtype_0(strings_funtype_0_t x);


//string

struct strings__string_s {
        uint32_t count; 
        mpz_t length;
        strings_funtype_0_t seq;};
typedef struct strings__string_s * strings__string_t;

extern strings__string_t new_strings__string(void);

extern void release_strings__string(strings__string_t x);

extern strings__string_t copy_strings__string(strings__string_t x);

extern bool_t equal_strings__string(strings__string_t x, strings__string_t y);
extern char * json_strings__string(strings__string_t x);

typedef struct actual_strings__string_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_strings__string_t;
extern void release_strings__string_ptr(pointer_t x, type_actual_t strings__string);

extern bool_t equal_strings__string_ptr(pointer_t x, pointer_t y, actual_strings__string_t T);

extern char * json_strings__string_ptr(pointer_t x,  actual_strings__string_t T);

actual_strings__string_t actual_strings__string(void);

 

extern strings__string_t update_strings__string_length(strings__string_t x, mpz_ptr_t v);

extern strings__string_t update_strings__string_seq(strings__string_t x, strings_funtype_0_t v);


//make_string

struct strings_array_2_s { uint32_t count;
        uint32_t size;
         uint32_t max;
         uint32_t elems[]; };
typedef struct strings_array_2_s * strings_array_2_t;

extern strings_array_2_t new_strings_array_2(uint32_t size);

extern void release_strings_array_2(strings_array_2_t x);

extern strings_array_2_t copy_strings_array_2(strings_array_2_t x);

extern bool_t equal_strings_array_2(strings_array_2_t x, strings_array_2_t y);
extern char * json_strings_array_2(strings_array_2_t x);

typedef struct actual_strings_array_2_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_strings_array_2_t;
extern void release_strings_array_2_ptr(pointer_t x, type_actual_t strings_array_2);

extern bool_t equal_strings_array_2_ptr(pointer_t x, pointer_t y, type_actual_t T);

extern char * json_strings_array_2_ptr(pointer_t x, type_actual_t T);

actual_strings_array_2_t actual_strings_array_2(void);

 

extern strings_array_2_t update_strings_array_2(strings_array_2_t x, uint32_t i, uint32_t v);

extern strings_array_2_t upgrade_strings_array_2(strings_array_2_t x, uint32_t i, uint32_t v);




struct strings_closure_3_s;
        typedef struct strings_closure_3_s * strings_closure_3_t;

struct strings_closure_3_s {uint32_t count;
         strings_funtype_0_ftbl_t ftbl;
         strings_funtype_0_htbl_t htbl;
        uint32_t fvar_1;
        strings_array_2_t fvar_2;
        mpz_t fvar_3;};

uint32_t f_strings_closure_3(struct strings_closure_3_s * closure, mpz_ptr_t bvar);

uint32_t m_strings_closure_3(struct strings_closure_3_s * closure, mpz_ptr_t bvar);

extern uint32_t h_strings_closure_3(mpz_ptr_t ivar_8, uint32_t ivar_1, strings_array_2_t ivar_2, mpz_ptr_t ivar_4);

strings_closure_3_t new_strings_closure_3(void);

void release_strings_closure_3(strings_funtype_0_t closure);

strings_closure_3_t copy_strings_closure_3(strings_closure_3_t x);



extern strings__string_t strings__make_string(uint32_t ivar_1, strings_array_2_t ivar_2);
#endif