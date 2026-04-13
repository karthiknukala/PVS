//Code generated using pvs2ir
#ifndef _ordstruct_adt_h 
#define _ordstruct_adt_h

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

//cc -O3 -Wall -o ordstruct_adt -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include ordstruct_adt_c.c <your main>.c  -lgmp -lpvs-prelude 
//ordstruct

struct ordstruct_adt__ordstruct_adt_s {
         uint32_t count; 
        uint8_t ordstruct_adt__ordstruct_adt_index;};
typedef struct ordstruct_adt__ordstruct_adt_s * ordstruct_adt__ordstruct_adt_t;

extern ordstruct_adt__ordstruct_adt_t new_ordstruct_adt__ordstruct_adt(void);

extern void release_ordstruct_adt__ordstruct_adt(ordstruct_adt__ordstruct_adt_t x);

extern ordstruct_adt__ordstruct_adt_t copy_ordstruct_adt__ordstruct_adt(ordstruct_adt__ordstruct_adt_t x);

extern bool_t equal_ordstruct_adt__ordstruct_adt(ordstruct_adt__ordstruct_adt_t x, ordstruct_adt__ordstruct_adt_t y);
extern char * json_ordstruct_adt__ordstruct_adt(ordstruct_adt__ordstruct_adt_t x);

typedef struct actual_ordstruct_adt__ordstruct_adt_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_ordstruct_adt__ordstruct_adt_t;
extern void release_ordstruct_adt__ordstruct_adt_ptr(pointer_t x, type_actual_t ordstruct_adt__ordstruct_adt);

extern bool_t equal_ordstruct_adt__ordstruct_adt_ptr(pointer_t x, pointer_t y, actual_ordstruct_adt__ordstruct_adt_t T);

extern char * json_ordstruct_adt__ordstruct_adt_ptr(pointer_t x,  actual_ordstruct_adt__ordstruct_adt_t T);

actual_ordstruct_adt__ordstruct_adt_t actual_ordstruct_adt__ordstruct_adt(void);

 

extern ordstruct_adt__ordstruct_adt_t update_ordstruct_adt__ordstruct_adt_ordstruct_adt__ordstruct_adt_index(ordstruct_adt__ordstruct_adt_t x, uint8_t v);


//add

struct ordstruct_adt__add_s {
        uint32_t count; 
        uint8_t ordstruct_adt__ordstruct_adt_index;
        mpz_t coef;
        ordstruct_adt__ordstruct_adt_t exp;
        ordstruct_adt__ordstruct_adt_t rest;};
typedef struct ordstruct_adt__add_s * ordstruct_adt__add_t;

extern ordstruct_adt__add_t new_ordstruct_adt__add(void);

extern void release_ordstruct_adt__add(ordstruct_adt__add_t x);

extern ordstruct_adt__add_t copy_ordstruct_adt__add(ordstruct_adt__add_t x);

extern bool_t equal_ordstruct_adt__add(ordstruct_adt__add_t x, ordstruct_adt__add_t y);
extern char * json_ordstruct_adt__add(ordstruct_adt__add_t x);

typedef struct actual_ordstruct_adt__add_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_ordstruct_adt__add_t;
extern void release_ordstruct_adt__add_ptr(pointer_t x, type_actual_t ordstruct_adt__add);

extern bool_t equal_ordstruct_adt__add_ptr(pointer_t x, pointer_t y, actual_ordstruct_adt__add_t T);

extern char * json_ordstruct_adt__add_ptr(pointer_t x,  actual_ordstruct_adt__add_t T);

actual_ordstruct_adt__add_t actual_ordstruct_adt__add(void);

 

extern ordstruct_adt__add_t update_ordstruct_adt__add_ordstruct_adt__ordstruct_adt_index(ordstruct_adt__add_t x, uint8_t v);

extern ordstruct_adt__add_t update_ordstruct_adt__add_coef(ordstruct_adt__add_t x, mpz_ptr_t v);

extern ordstruct_adt__add_t update_ordstruct_adt__add_exp(ordstruct_adt__add_t x, ordstruct_adt__ordstruct_adt_t v);

extern ordstruct_adt__add_t update_ordstruct_adt__add_rest(ordstruct_adt__add_t x, ordstruct_adt__ordstruct_adt_t v);


//reduce_nat

struct ordstruct_adt_funtype_2_s;
        typedef struct ordstruct_adt_funtype_2_s * ordstruct_adt_funtype_2_t;

struct ordstruct_adt_funtype_2_ftbl_s {mpz_ptr_t (* fptr)(struct ordstruct_adt_funtype_2_s *, ordstruct_adt__ordstruct_adt_t);
        mpz_ptr_t (* mptr)(struct ordstruct_adt_funtype_2_s *, ordstruct_adt__ordstruct_adt_t);
        void (* rptr)(struct ordstruct_adt_funtype_2_s *);
        struct ordstruct_adt_funtype_2_s * (* cptr)(struct ordstruct_adt_funtype_2_s *);};
typedef struct ordstruct_adt_funtype_2_ftbl_s * ordstruct_adt_funtype_2_ftbl_t;

struct ordstruct_adt_funtype_2_hashentry_s {uint32_t keyhash; ordstruct_adt__ordstruct_adt_t key; mpz_t value;}; 
typedef struct ordstruct_adt_funtype_2_hashentry_s ordstruct_adt_funtype_2_hashentry_t;

struct ordstruct_adt_funtype_2_htbl_s {uint32_t size; uint32_t num_entries; ordstruct_adt_funtype_2_hashentry_t * data;}; 
typedef struct ordstruct_adt_funtype_2_htbl_s * ordstruct_adt_funtype_2_htbl_t;

struct ordstruct_adt_funtype_2_s {uint32_t count;
        ordstruct_adt_funtype_2_ftbl_t ftbl;
        ordstruct_adt_funtype_2_htbl_t htbl;};
typedef struct ordstruct_adt_funtype_2_s * ordstruct_adt_funtype_2_t;

extern void release_ordstruct_adt_funtype_2(ordstruct_adt_funtype_2_t x);

extern ordstruct_adt_funtype_2_t copy_ordstruct_adt_funtype_2(ordstruct_adt_funtype_2_t x);

extern bool_t equal_ordstruct_adt_funtype_2(ordstruct_adt_funtype_2_t x, ordstruct_adt_funtype_2_t y);

extern char* json_ordstruct_adt_funtype_2(ordstruct_adt_funtype_2_t x);


//reduce_nat

struct ordstruct_adt_record_3_s {
        uint32_t count; 
        mpz_t project_1;
        mpz_t project_2;
        mpz_t project_3;};
typedef struct ordstruct_adt_record_3_s * ordstruct_adt_record_3_t;

extern ordstruct_adt_record_3_t new_ordstruct_adt_record_3(void);

extern void release_ordstruct_adt_record_3(ordstruct_adt_record_3_t x);

extern ordstruct_adt_record_3_t copy_ordstruct_adt_record_3(ordstruct_adt_record_3_t x);

extern bool_t equal_ordstruct_adt_record_3(ordstruct_adt_record_3_t x, ordstruct_adt_record_3_t y);
extern char * json_ordstruct_adt_record_3(ordstruct_adt_record_3_t x);

typedef struct actual_ordstruct_adt_record_3_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_ordstruct_adt_record_3_t;
extern void release_ordstruct_adt_record_3_ptr(pointer_t x, type_actual_t ordstruct_adt_record_3);

extern bool_t equal_ordstruct_adt_record_3_ptr(pointer_t x, pointer_t y, actual_ordstruct_adt_record_3_t T);

extern char * json_ordstruct_adt_record_3_ptr(pointer_t x,  actual_ordstruct_adt_record_3_t T);

actual_ordstruct_adt_record_3_t actual_ordstruct_adt_record_3(void);

 

extern ordstruct_adt_record_3_t update_ordstruct_adt_record_3_project_1(ordstruct_adt_record_3_t x, mpz_ptr_t v);

extern ordstruct_adt_record_3_t update_ordstruct_adt_record_3_project_2(ordstruct_adt_record_3_t x, mpz_ptr_t v);

extern ordstruct_adt_record_3_t update_ordstruct_adt_record_3_project_3(ordstruct_adt_record_3_t x, mpz_ptr_t v);


//reduce_nat

struct ordstruct_adt_funtype_4_s;
        typedef struct ordstruct_adt_funtype_4_s * ordstruct_adt_funtype_4_t;

struct ordstruct_adt_funtype_4_ftbl_s {mpz_ptr_t (* fptr)(struct ordstruct_adt_funtype_4_s *, ordstruct_adt_record_3_t);
        mpz_ptr_t (* mptr)(struct ordstruct_adt_funtype_4_s *, mpz_ptr_t, mpz_ptr_t, mpz_ptr_t);
        void (* rptr)(struct ordstruct_adt_funtype_4_s *);
        struct ordstruct_adt_funtype_4_s * (* cptr)(struct ordstruct_adt_funtype_4_s *);};
typedef struct ordstruct_adt_funtype_4_ftbl_s * ordstruct_adt_funtype_4_ftbl_t;

struct ordstruct_adt_funtype_4_hashentry_s {uint32_t keyhash; ordstruct_adt_record_3_t key; mpz_t value;}; 
typedef struct ordstruct_adt_funtype_4_hashentry_s ordstruct_adt_funtype_4_hashentry_t;

struct ordstruct_adt_funtype_4_htbl_s {uint32_t size; uint32_t num_entries; ordstruct_adt_funtype_4_hashentry_t * data;}; 
typedef struct ordstruct_adt_funtype_4_htbl_s * ordstruct_adt_funtype_4_htbl_t;

struct ordstruct_adt_funtype_4_s {uint32_t count;
        ordstruct_adt_funtype_4_ftbl_t ftbl;
        ordstruct_adt_funtype_4_htbl_t htbl;};
typedef struct ordstruct_adt_funtype_4_s * ordstruct_adt_funtype_4_t;

extern void release_ordstruct_adt_funtype_4(ordstruct_adt_funtype_4_t x);

extern ordstruct_adt_funtype_4_t copy_ordstruct_adt_funtype_4(ordstruct_adt_funtype_4_t x);

extern bool_t equal_ordstruct_adt_funtype_4(ordstruct_adt_funtype_4_t x, ordstruct_adt_funtype_4_t y);

extern char* json_ordstruct_adt_funtype_4(ordstruct_adt_funtype_4_t x);




struct ordstruct_adt_closure_5_s;
        typedef struct ordstruct_adt_closure_5_s * ordstruct_adt_closure_5_t;

struct ordstruct_adt_closure_5_s {uint32_t count;
         ordstruct_adt_funtype_2_ftbl_t ftbl;
         ordstruct_adt_funtype_2_htbl_t htbl;
        mpz_t fvar_1;
        ordstruct_adt_funtype_4_t fvar_2;};

mpz_ptr_t f_ordstruct_adt_closure_5(struct ordstruct_adt_closure_5_s * closure, ordstruct_adt__ordstruct_adt_t bvar);

mpz_ptr_t m_ordstruct_adt_closure_5(struct ordstruct_adt_closure_5_s * closure, ordstruct_adt__ordstruct_adt_t bvar);

extern mpz_ptr_t h_ordstruct_adt_closure_5(ordstruct_adt__ordstruct_adt_t ivar_6, mpz_ptr_t ivar_1, ordstruct_adt_funtype_4_t ivar_2);

ordstruct_adt_closure_5_t new_ordstruct_adt_closure_5(void);

void release_ordstruct_adt_closure_5(ordstruct_adt_funtype_2_t closure);

ordstruct_adt_closure_5_t copy_ordstruct_adt_closure_5(ordstruct_adt_closure_5_t x);


//REDUCE_nat

struct ordstruct_adt_record_6_s {
        uint32_t count; 
        mpz_t project_1;
        mpz_t project_2;
        mpz_t project_3;
        ordstruct_adt__ordstruct_adt_t project_4;};
typedef struct ordstruct_adt_record_6_s * ordstruct_adt_record_6_t;

extern ordstruct_adt_record_6_t new_ordstruct_adt_record_6(void);

extern void release_ordstruct_adt_record_6(ordstruct_adt_record_6_t x);

extern ordstruct_adt_record_6_t copy_ordstruct_adt_record_6(ordstruct_adt_record_6_t x);

extern bool_t equal_ordstruct_adt_record_6(ordstruct_adt_record_6_t x, ordstruct_adt_record_6_t y);
extern char * json_ordstruct_adt_record_6(ordstruct_adt_record_6_t x);

typedef struct actual_ordstruct_adt_record_6_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_ordstruct_adt_record_6_t;
extern void release_ordstruct_adt_record_6_ptr(pointer_t x, type_actual_t ordstruct_adt_record_6);

extern bool_t equal_ordstruct_adt_record_6_ptr(pointer_t x, pointer_t y, actual_ordstruct_adt_record_6_t T);

extern char * json_ordstruct_adt_record_6_ptr(pointer_t x,  actual_ordstruct_adt_record_6_t T);

actual_ordstruct_adt_record_6_t actual_ordstruct_adt_record_6(void);

 

extern ordstruct_adt_record_6_t update_ordstruct_adt_record_6_project_1(ordstruct_adt_record_6_t x, mpz_ptr_t v);

extern ordstruct_adt_record_6_t update_ordstruct_adt_record_6_project_2(ordstruct_adt_record_6_t x, mpz_ptr_t v);

extern ordstruct_adt_record_6_t update_ordstruct_adt_record_6_project_3(ordstruct_adt_record_6_t x, mpz_ptr_t v);

extern ordstruct_adt_record_6_t update_ordstruct_adt_record_6_project_4(ordstruct_adt_record_6_t x, ordstruct_adt__ordstruct_adt_t v);


//REDUCE_nat

struct ordstruct_adt_funtype_7_s;
        typedef struct ordstruct_adt_funtype_7_s * ordstruct_adt_funtype_7_t;

struct ordstruct_adt_funtype_7_ftbl_s {mpz_ptr_t (* fptr)(struct ordstruct_adt_funtype_7_s *, ordstruct_adt_record_6_t);
        mpz_ptr_t (* mptr)(struct ordstruct_adt_funtype_7_s *, mpz_ptr_t, mpz_ptr_t, mpz_ptr_t, ordstruct_adt__ordstruct_adt_t);
        void (* rptr)(struct ordstruct_adt_funtype_7_s *);
        struct ordstruct_adt_funtype_7_s * (* cptr)(struct ordstruct_adt_funtype_7_s *);};
typedef struct ordstruct_adt_funtype_7_ftbl_s * ordstruct_adt_funtype_7_ftbl_t;

struct ordstruct_adt_funtype_7_hashentry_s {uint32_t keyhash; ordstruct_adt_record_6_t key; mpz_t value;}; 
typedef struct ordstruct_adt_funtype_7_hashentry_s ordstruct_adt_funtype_7_hashentry_t;

struct ordstruct_adt_funtype_7_htbl_s {uint32_t size; uint32_t num_entries; ordstruct_adt_funtype_7_hashentry_t * data;}; 
typedef struct ordstruct_adt_funtype_7_htbl_s * ordstruct_adt_funtype_7_htbl_t;

struct ordstruct_adt_funtype_7_s {uint32_t count;
        ordstruct_adt_funtype_7_ftbl_t ftbl;
        ordstruct_adt_funtype_7_htbl_t htbl;};
typedef struct ordstruct_adt_funtype_7_s * ordstruct_adt_funtype_7_t;

extern void release_ordstruct_adt_funtype_7(ordstruct_adt_funtype_7_t x);

extern ordstruct_adt_funtype_7_t copy_ordstruct_adt_funtype_7(ordstruct_adt_funtype_7_t x);

extern bool_t equal_ordstruct_adt_funtype_7(ordstruct_adt_funtype_7_t x, ordstruct_adt_funtype_7_t y);

extern char* json_ordstruct_adt_funtype_7(ordstruct_adt_funtype_7_t x);




struct ordstruct_adt_closure_8_s;
        typedef struct ordstruct_adt_closure_8_s * ordstruct_adt_closure_8_t;

struct ordstruct_adt_closure_8_s {uint32_t count;
         ordstruct_adt_funtype_2_ftbl_t ftbl;
         ordstruct_adt_funtype_2_htbl_t htbl;
        ordstruct_adt_funtype_2_t fvar_1;
        ordstruct_adt_funtype_7_t fvar_2;};

mpz_ptr_t f_ordstruct_adt_closure_8(struct ordstruct_adt_closure_8_s * closure, ordstruct_adt__ordstruct_adt_t bvar);

mpz_ptr_t m_ordstruct_adt_closure_8(struct ordstruct_adt_closure_8_s * closure, ordstruct_adt__ordstruct_adt_t bvar);

extern mpz_ptr_t h_ordstruct_adt_closure_8(ordstruct_adt__ordstruct_adt_t ivar_7, ordstruct_adt_funtype_2_t ivar_1, ordstruct_adt_funtype_7_t ivar_3);

ordstruct_adt_closure_8_t new_ordstruct_adt_closure_8(void);

void release_ordstruct_adt_closure_8(ordstruct_adt_funtype_2_t closure);

ordstruct_adt_closure_8_t copy_ordstruct_adt_closure_8(ordstruct_adt_closure_8_t x);



extern bool_t rec_ordstruct_adt__zerop(ordstruct_adt__ordstruct_adt_t ivar_1);

extern bool_t rec_ordstruct_adt__nonzerop(ordstruct_adt__ordstruct_adt_t ivar_1);

extern ordstruct_adt__add_t update_ordstruct_adt__ordstruct_adt_coef(ordstruct_adt__ordstruct_adt_t ivar_1, mpz_ptr_t ivar_3);

extern mpz_ptr_t acc_ordstruct_adt__ordstruct_adt_coef(ordstruct_adt__ordstruct_adt_t ivar_1);

extern ordstruct_adt__add_t update_ordstruct_adt__ordstruct_adt_exp(ordstruct_adt__ordstruct_adt_t ivar_1, ordstruct_adt__ordstruct_adt_t ivar_3);

extern ordstruct_adt__ordstruct_adt_t acc_ordstruct_adt__ordstruct_adt_exp(ordstruct_adt__ordstruct_adt_t ivar_1);

extern ordstruct_adt__add_t update_ordstruct_adt__ordstruct_adt_rest(ordstruct_adt__ordstruct_adt_t ivar_1, ordstruct_adt__ordstruct_adt_t ivar_3);

extern ordstruct_adt__ordstruct_adt_t acc_ordstruct_adt__ordstruct_adt_rest(ordstruct_adt__ordstruct_adt_t ivar_1);

extern ordstruct_adt__ordstruct_adt_t con_ordstruct_adt__zero(void);

extern ordstruct_adt__ordstruct_adt_t con_ordstruct_adt__add(mpz_ptr_t ivar_2, ordstruct_adt__ordstruct_adt_t ivar_3, ordstruct_adt__ordstruct_adt_t ivar_4);

extern uint8_t ordstruct_adt__ord(ordstruct_adt__ordstruct_adt_t ivar_1);

extern bool_t ordstruct_adt__subterm(ordstruct_adt__ordstruct_adt_t ivar_1, ordstruct_adt__ordstruct_adt_t ivar_2);

extern bool_t ordstruct_adt__doublelessp(ordstruct_adt__ordstruct_adt_t ivar_1, ordstruct_adt__ordstruct_adt_t ivar_2);

extern ordstruct_adt_funtype_2_t ordstruct_adt__reduce_nat(mpz_ptr_t ivar_1, ordstruct_adt_funtype_4_t ivar_2);

extern ordstruct_adt_funtype_2_t ordstruct_adt__REDUCE_nat(ordstruct_adt_funtype_2_t ivar_1, ordstruct_adt_funtype_7_t ivar_3);
#endif