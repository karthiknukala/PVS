//Code generated using pvs2ir
#ifndef _modulo_arithmetic_h 
#define _modulo_arithmetic_h

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

//cc -O3 -Wall -o modulo_arithmetic -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include modulo_arithmetic_c.c <your main>.c  -lgmp -lpvs-prelude 
//rem

struct modulo_arithmetic_funtype_0_s;
        typedef struct modulo_arithmetic_funtype_0_s * modulo_arithmetic_funtype_0_t;

struct modulo_arithmetic_funtype_0_ftbl_s {mpz_ptr_t (* fptr)(struct modulo_arithmetic_funtype_0_s *, mpz_ptr_t);
        mpz_ptr_t (* mptr)(struct modulo_arithmetic_funtype_0_s *, mpz_ptr_t);
        void (* rptr)(struct modulo_arithmetic_funtype_0_s *);
        struct modulo_arithmetic_funtype_0_s * (* cptr)(struct modulo_arithmetic_funtype_0_s *);};
typedef struct modulo_arithmetic_funtype_0_ftbl_s * modulo_arithmetic_funtype_0_ftbl_t;

struct modulo_arithmetic_funtype_0_hashentry_s {uint32_t keyhash; mpz_ptr_t key; mpz_t value;}; 
typedef struct modulo_arithmetic_funtype_0_hashentry_s modulo_arithmetic_funtype_0_hashentry_t;

struct modulo_arithmetic_funtype_0_htbl_s {uint32_t size; uint32_t num_entries; modulo_arithmetic_funtype_0_hashentry_t * data;}; 
typedef struct modulo_arithmetic_funtype_0_htbl_s * modulo_arithmetic_funtype_0_htbl_t;

struct modulo_arithmetic_funtype_0_s {uint32_t count;
        modulo_arithmetic_funtype_0_ftbl_t ftbl;
        modulo_arithmetic_funtype_0_htbl_t htbl;};
typedef struct modulo_arithmetic_funtype_0_s * modulo_arithmetic_funtype_0_t;

extern void release_modulo_arithmetic_funtype_0(modulo_arithmetic_funtype_0_t x);

extern modulo_arithmetic_funtype_0_t copy_modulo_arithmetic_funtype_0(modulo_arithmetic_funtype_0_t x);

extern uint32_t lookup_modulo_arithmetic_funtype_0(modulo_arithmetic_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash);

extern modulo_arithmetic_funtype_0_t dupdate_modulo_arithmetic_funtype_0(modulo_arithmetic_funtype_0_t a, mpz_ptr_t i, mpz_ptr_t v);

extern modulo_arithmetic_funtype_0_t update_modulo_arithmetic_funtype_0(modulo_arithmetic_funtype_0_t a, mpz_ptr_t i, mpz_ptr_t v);

extern bool_t equal_modulo_arithmetic_funtype_0(modulo_arithmetic_funtype_0_t x, modulo_arithmetic_funtype_0_t y);

extern char* json_modulo_arithmetic_funtype_0(modulo_arithmetic_funtype_0_t x);




struct modulo_arithmetic_closure_1_s;
        typedef struct modulo_arithmetic_closure_1_s * modulo_arithmetic_closure_1_t;

struct modulo_arithmetic_closure_1_s {uint32_t count;
         modulo_arithmetic_funtype_0_ftbl_t ftbl;
         modulo_arithmetic_funtype_0_htbl_t htbl;
        mpz_t fvar_1;};

mpz_ptr_t f_modulo_arithmetic_closure_1(struct modulo_arithmetic_closure_1_s * closure, mpz_ptr_t bvar);

mpz_ptr_t m_modulo_arithmetic_closure_1(struct modulo_arithmetic_closure_1_s * closure, mpz_ptr_t bvar);

extern mpz_ptr_t h_modulo_arithmetic_closure_1(mpz_ptr_t ivar_4, mpz_ptr_t ivar_1);

modulo_arithmetic_closure_1_t new_modulo_arithmetic_closure_1(void);

void release_modulo_arithmetic_closure_1(modulo_arithmetic_funtype_0_t closure);

modulo_arithmetic_closure_1_t copy_modulo_arithmetic_closure_1(modulo_arithmetic_closure_1_t x);



extern modulo_arithmetic_funtype_0_t modulo_arithmetic__rem(mpz_ptr_t ivar_1);
#endif