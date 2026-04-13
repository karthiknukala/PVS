//Code generated using pvs2ir
#ifndef _list_adt_h 
#define _list_adt_h

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

#include "ordstruct_adt_c.h"

#include "ordinals_c.h"

//cc -O3 -Wall -o list_adt -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include list_adt_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t list_adt__T_t;
//list

struct list_adt__list_adt_s {
         uint32_t count; 
        uint8_t list_adt__list_adt_index;};
typedef struct list_adt__list_adt_s * list_adt__list_adt_t;

extern list_adt__list_adt_t new_list_adt__list_adt(void);

extern void release_list_adt__list_adt(list_adt__list_adt_t x, type_actual_t list_adt__T);

extern list_adt__list_adt_t copy_list_adt__list_adt(list_adt__list_adt_t x);

extern bool_t equal_list_adt__list_adt(list_adt__list_adt_t x, list_adt__list_adt_t y, type_actual_t list_adt__T);
extern char * json_list_adt__list_adt(list_adt__list_adt_t x, type_actual_t list_adt__T);

typedef struct actual_list_adt__list_adt_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t list_adt__T;} * actual_list_adt__list_adt_t;
extern void release_list_adt__list_adt_ptr(pointer_t x, type_actual_t list_adt__list_adt);

extern bool_t equal_list_adt__list_adt_ptr(pointer_t x, pointer_t y, actual_list_adt__list_adt_t T);

extern char * json_list_adt__list_adt_ptr(pointer_t x,  actual_list_adt__list_adt_t T);

actual_list_adt__list_adt_t actual_list_adt__list_adt(type_actual_t list_adt__T);

 

extern list_adt__list_adt_t update_list_adt__list_adt_list_adt__list_adt_index(list_adt__list_adt_t x, uint8_t v);


//cons

struct list_adt__cons_s {
        uint32_t count; 
        uint8_t list_adt__list_adt_index;
        list_adt__T_t car;
        list_adt__list_adt_t cdr;};
typedef struct list_adt__cons_s * list_adt__cons_t;

extern list_adt__cons_t new_list_adt__cons(void);

extern void release_list_adt__cons(list_adt__cons_t x, type_actual_t list_adt__T);

extern list_adt__cons_t copy_list_adt__cons(list_adt__cons_t x);

extern bool_t equal_list_adt__cons(list_adt__cons_t x, list_adt__cons_t y, type_actual_t list_adt__T);
extern char * json_list_adt__cons(list_adt__cons_t x, type_actual_t list_adt__T);

typedef struct actual_list_adt__cons_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t list_adt__T;} * actual_list_adt__cons_t;
extern void release_list_adt__cons_ptr(pointer_t x, type_actual_t list_adt__cons);

extern bool_t equal_list_adt__cons_ptr(pointer_t x, pointer_t y, actual_list_adt__cons_t T);

extern char * json_list_adt__cons_ptr(pointer_t x,  actual_list_adt__cons_t T);

actual_list_adt__cons_t actual_list_adt__cons(type_actual_t list_adt__T);

 

extern list_adt__cons_t update_list_adt__cons_list_adt__list_adt_index(list_adt__cons_t x, uint8_t v);

extern list_adt__cons_t update_list_adt__cons_car(list_adt__cons_t x, list_adt__T_t v, type_actual_t list_adt__T);

extern list_adt__cons_t update_list_adt__cons_cdr(list_adt__cons_t x, list_adt__list_adt_t v, type_actual_t list_adt__T);


//every

struct list_adt_funtype_2_s;
        typedef struct list_adt_funtype_2_s * list_adt_funtype_2_t;

struct list_adt_funtype_2_ftbl_s {bool_t (* fptr)(struct list_adt_funtype_2_s *, list_adt__list_adt_t);
        bool_t (* mptr)(struct list_adt_funtype_2_s *, list_adt__list_adt_t);
        void (* rptr)(struct list_adt_funtype_2_s *);
        struct list_adt_funtype_2_s * (* cptr)(struct list_adt_funtype_2_s *);};
typedef struct list_adt_funtype_2_ftbl_s * list_adt_funtype_2_ftbl_t;

struct list_adt_funtype_2_hashentry_s {uint32_t keyhash; list_adt__list_adt_t key; bool_t value;}; 
typedef struct list_adt_funtype_2_hashentry_s list_adt_funtype_2_hashentry_t;

struct list_adt_funtype_2_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_2_hashentry_t * data;}; 
typedef struct list_adt_funtype_2_htbl_s * list_adt_funtype_2_htbl_t;

struct list_adt_funtype_2_s {uint32_t count;
        list_adt_funtype_2_ftbl_t ftbl;
        list_adt_funtype_2_htbl_t htbl;};
typedef struct list_adt_funtype_2_s * list_adt_funtype_2_t;

extern void release_list_adt_funtype_2(list_adt_funtype_2_t x, type_actual_t list_adt__T);

extern list_adt_funtype_2_t copy_list_adt_funtype_2(list_adt_funtype_2_t x);

extern bool_t equal_list_adt_funtype_2(list_adt_funtype_2_t x, list_adt_funtype_2_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_2(list_adt_funtype_2_t x, type_actual_t list_adt__T);


//every

struct list_adt_funtype_3_s;
        typedef struct list_adt_funtype_3_s * list_adt_funtype_3_t;

struct list_adt_funtype_3_ftbl_s {bool_t (* fptr)(struct list_adt_funtype_3_s *, list_adt__T_t);
        bool_t (* mptr)(struct list_adt_funtype_3_s *, list_adt__T_t);
        void (* rptr)(struct list_adt_funtype_3_s *);
        struct list_adt_funtype_3_s * (* cptr)(struct list_adt_funtype_3_s *);};
typedef struct list_adt_funtype_3_ftbl_s * list_adt_funtype_3_ftbl_t;

struct list_adt_funtype_3_hashentry_s {uint32_t keyhash; list_adt__T_t key; bool_t value;}; 
typedef struct list_adt_funtype_3_hashentry_s list_adt_funtype_3_hashentry_t;

struct list_adt_funtype_3_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_3_hashentry_t * data;}; 
typedef struct list_adt_funtype_3_htbl_s * list_adt_funtype_3_htbl_t;

struct list_adt_funtype_3_s {uint32_t count;
        list_adt_funtype_3_ftbl_t ftbl;
        list_adt_funtype_3_htbl_t htbl;};
typedef struct list_adt_funtype_3_s * list_adt_funtype_3_t;

extern void release_list_adt_funtype_3(list_adt_funtype_3_t x, type_actual_t list_adt__T);

extern list_adt_funtype_3_t copy_list_adt_funtype_3(list_adt_funtype_3_t x);

extern bool_t equal_list_adt_funtype_3(list_adt_funtype_3_t x, list_adt_funtype_3_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_3(list_adt_funtype_3_t x, type_actual_t list_adt__T);




struct list_adt_closure_4_s;
        typedef struct list_adt_closure_4_s * list_adt_closure_4_t;

struct list_adt_closure_4_s {uint32_t count;
         list_adt_funtype_2_ftbl_t ftbl;
         list_adt_funtype_2_htbl_t htbl;
        list_adt_funtype_3_t fvar_1;
        type_actual_t fvar_2; type_actual_t list_adt__T;};

bool_t f_list_adt_closure_4(struct list_adt_closure_4_s * closure, list_adt__list_adt_t bvar);

bool_t m_list_adt_closure_4(struct list_adt_closure_4_s * closure, list_adt__list_adt_t bvar);

extern bool_t h_list_adt_closure_4(list_adt__list_adt_t ivar_5, list_adt_funtype_3_t ivar_1, type_actual_t list_adt__T);

list_adt_closure_4_t new_list_adt_closure_4(void);

void release_list_adt_closure_4(list_adt_funtype_2_t closure, type_actual_t list_adt__T);

list_adt_closure_4_t copy_list_adt_closure_4(list_adt_closure_4_t x);




struct list_adt_closure_5_s;
        typedef struct list_adt_closure_5_s * list_adt_closure_5_t;

struct list_adt_closure_5_s {uint32_t count;
         list_adt_funtype_2_ftbl_t ftbl;
         list_adt_funtype_2_htbl_t htbl;
        list_adt_funtype_3_t fvar_1;
        type_actual_t fvar_2; type_actual_t list_adt__T;};

bool_t f_list_adt_closure_5(struct list_adt_closure_5_s * closure, list_adt__list_adt_t bvar);

bool_t m_list_adt_closure_5(struct list_adt_closure_5_s * closure, list_adt__list_adt_t bvar);

extern bool_t h_list_adt_closure_5(list_adt__list_adt_t ivar_5, list_adt_funtype_3_t ivar_1, type_actual_t list_adt__T);

list_adt_closure_5_t new_list_adt_closure_5(void);

void release_list_adt_closure_5(list_adt_funtype_2_t closure, type_actual_t list_adt__T);

list_adt_closure_5_t copy_list_adt_closure_5(list_adt_closure_5_t x);


//reduce_nat

struct list_adt_funtype_6_s;
        typedef struct list_adt_funtype_6_s * list_adt_funtype_6_t;

struct list_adt_funtype_6_ftbl_s {mpz_ptr_t (* fptr)(struct list_adt_funtype_6_s *, list_adt__list_adt_t);
        mpz_ptr_t (* mptr)(struct list_adt_funtype_6_s *, list_adt__list_adt_t);
        void (* rptr)(struct list_adt_funtype_6_s *);
        struct list_adt_funtype_6_s * (* cptr)(struct list_adt_funtype_6_s *);};
typedef struct list_adt_funtype_6_ftbl_s * list_adt_funtype_6_ftbl_t;

struct list_adt_funtype_6_hashentry_s {uint32_t keyhash; list_adt__list_adt_t key; mpz_t value;}; 
typedef struct list_adt_funtype_6_hashentry_s list_adt_funtype_6_hashentry_t;

struct list_adt_funtype_6_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_6_hashentry_t * data;}; 
typedef struct list_adt_funtype_6_htbl_s * list_adt_funtype_6_htbl_t;

struct list_adt_funtype_6_s {uint32_t count;
        list_adt_funtype_6_ftbl_t ftbl;
        list_adt_funtype_6_htbl_t htbl;};
typedef struct list_adt_funtype_6_s * list_adt_funtype_6_t;

extern void release_list_adt_funtype_6(list_adt_funtype_6_t x, type_actual_t list_adt__T);

extern list_adt_funtype_6_t copy_list_adt_funtype_6(list_adt_funtype_6_t x);

extern bool_t equal_list_adt_funtype_6(list_adt_funtype_6_t x, list_adt_funtype_6_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_6(list_adt_funtype_6_t x, type_actual_t list_adt__T);


//reduce_nat

struct list_adt_record_7_s {
        uint32_t count; 
        list_adt__T_t project_1;
        mpz_t project_2;};
typedef struct list_adt_record_7_s * list_adt_record_7_t;

extern list_adt_record_7_t new_list_adt_record_7(void);

extern void release_list_adt_record_7(list_adt_record_7_t x, type_actual_t list_adt__T);

extern list_adt_record_7_t copy_list_adt_record_7(list_adt_record_7_t x);

extern bool_t equal_list_adt_record_7(list_adt_record_7_t x, list_adt_record_7_t y, type_actual_t list_adt__T);
extern char * json_list_adt_record_7(list_adt_record_7_t x, type_actual_t list_adt__T);

typedef struct actual_list_adt_record_7_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t list_adt__T;} * actual_list_adt_record_7_t;
extern void release_list_adt_record_7_ptr(pointer_t x, type_actual_t list_adt_record_7);

extern bool_t equal_list_adt_record_7_ptr(pointer_t x, pointer_t y, actual_list_adt_record_7_t T);

extern char * json_list_adt_record_7_ptr(pointer_t x,  actual_list_adt_record_7_t T);

actual_list_adt_record_7_t actual_list_adt_record_7(type_actual_t list_adt__T);

 

extern list_adt_record_7_t update_list_adt_record_7_project_1(list_adt_record_7_t x, list_adt__T_t v, type_actual_t list_adt__T);

extern list_adt_record_7_t update_list_adt_record_7_project_2(list_adt_record_7_t x, mpz_ptr_t v);


//reduce_nat

struct list_adt_funtype_8_s;
        typedef struct list_adt_funtype_8_s * list_adt_funtype_8_t;

struct list_adt_funtype_8_ftbl_s {mpz_ptr_t (* fptr)(struct list_adt_funtype_8_s *, list_adt_record_7_t);
        mpz_ptr_t (* mptr)(struct list_adt_funtype_8_s *, list_adt__T_t, mpz_ptr_t);
        void (* rptr)(struct list_adt_funtype_8_s *);
        struct list_adt_funtype_8_s * (* cptr)(struct list_adt_funtype_8_s *);};
typedef struct list_adt_funtype_8_ftbl_s * list_adt_funtype_8_ftbl_t;

struct list_adt_funtype_8_hashentry_s {uint32_t keyhash; list_adt_record_7_t key; mpz_t value;}; 
typedef struct list_adt_funtype_8_hashentry_s list_adt_funtype_8_hashentry_t;

struct list_adt_funtype_8_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_8_hashentry_t * data;}; 
typedef struct list_adt_funtype_8_htbl_s * list_adt_funtype_8_htbl_t;

struct list_adt_funtype_8_s {uint32_t count;
        list_adt_funtype_8_ftbl_t ftbl;
        list_adt_funtype_8_htbl_t htbl;};
typedef struct list_adt_funtype_8_s * list_adt_funtype_8_t;

extern void release_list_adt_funtype_8(list_adt_funtype_8_t x, type_actual_t list_adt__T);

extern list_adt_funtype_8_t copy_list_adt_funtype_8(list_adt_funtype_8_t x);

extern bool_t equal_list_adt_funtype_8(list_adt_funtype_8_t x, list_adt_funtype_8_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_8(list_adt_funtype_8_t x, type_actual_t list_adt__T);




struct list_adt_closure_9_s;
        typedef struct list_adt_closure_9_s * list_adt_closure_9_t;

struct list_adt_closure_9_s {uint32_t count;
         list_adt_funtype_6_ftbl_t ftbl;
         list_adt_funtype_6_htbl_t htbl;
        mpz_t fvar_1;
        list_adt_funtype_8_t fvar_2;
        type_actual_t fvar_3; type_actual_t list_adt__T;};

mpz_ptr_t f_list_adt_closure_9(struct list_adt_closure_9_s * closure, list_adt__list_adt_t bvar);

mpz_ptr_t m_list_adt_closure_9(struct list_adt_closure_9_s * closure, list_adt__list_adt_t bvar);

extern mpz_ptr_t h_list_adt_closure_9(list_adt__list_adt_t ivar_6, mpz_ptr_t ivar_1, list_adt_funtype_8_t ivar_2, type_actual_t list_adt__T);

list_adt_closure_9_t new_list_adt_closure_9(void);

void release_list_adt_closure_9(list_adt_funtype_6_t closure, type_actual_t list_adt__T);

list_adt_closure_9_t copy_list_adt_closure_9(list_adt_closure_9_t x);


//REDUCE_nat

struct list_adt_record_10_s {
        uint32_t count; 
        list_adt__T_t project_1;
        mpz_t project_2;
        list_adt__list_adt_t project_3;};
typedef struct list_adt_record_10_s * list_adt_record_10_t;

extern list_adt_record_10_t new_list_adt_record_10(void);

extern void release_list_adt_record_10(list_adt_record_10_t x, type_actual_t list_adt__T);

extern list_adt_record_10_t copy_list_adt_record_10(list_adt_record_10_t x);

extern bool_t equal_list_adt_record_10(list_adt_record_10_t x, list_adt_record_10_t y, type_actual_t list_adt__T);
extern char * json_list_adt_record_10(list_adt_record_10_t x, type_actual_t list_adt__T);

typedef struct actual_list_adt_record_10_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t list_adt__T;} * actual_list_adt_record_10_t;
extern void release_list_adt_record_10_ptr(pointer_t x, type_actual_t list_adt_record_10);

extern bool_t equal_list_adt_record_10_ptr(pointer_t x, pointer_t y, actual_list_adt_record_10_t T);

extern char * json_list_adt_record_10_ptr(pointer_t x,  actual_list_adt_record_10_t T);

actual_list_adt_record_10_t actual_list_adt_record_10(type_actual_t list_adt__T);

 

extern list_adt_record_10_t update_list_adt_record_10_project_1(list_adt_record_10_t x, list_adt__T_t v, type_actual_t list_adt__T);

extern list_adt_record_10_t update_list_adt_record_10_project_2(list_adt_record_10_t x, mpz_ptr_t v);

extern list_adt_record_10_t update_list_adt_record_10_project_3(list_adt_record_10_t x, list_adt__list_adt_t v, type_actual_t list_adt__T);


//REDUCE_nat

struct list_adt_funtype_11_s;
        typedef struct list_adt_funtype_11_s * list_adt_funtype_11_t;

struct list_adt_funtype_11_ftbl_s {mpz_ptr_t (* fptr)(struct list_adt_funtype_11_s *, list_adt_record_10_t);
        mpz_ptr_t (* mptr)(struct list_adt_funtype_11_s *, list_adt__T_t, mpz_ptr_t, list_adt__list_adt_t);
        void (* rptr)(struct list_adt_funtype_11_s *);
        struct list_adt_funtype_11_s * (* cptr)(struct list_adt_funtype_11_s *);};
typedef struct list_adt_funtype_11_ftbl_s * list_adt_funtype_11_ftbl_t;

struct list_adt_funtype_11_hashentry_s {uint32_t keyhash; list_adt_record_10_t key; mpz_t value;}; 
typedef struct list_adt_funtype_11_hashentry_s list_adt_funtype_11_hashentry_t;

struct list_adt_funtype_11_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_11_hashentry_t * data;}; 
typedef struct list_adt_funtype_11_htbl_s * list_adt_funtype_11_htbl_t;

struct list_adt_funtype_11_s {uint32_t count;
        list_adt_funtype_11_ftbl_t ftbl;
        list_adt_funtype_11_htbl_t htbl;};
typedef struct list_adt_funtype_11_s * list_adt_funtype_11_t;

extern void release_list_adt_funtype_11(list_adt_funtype_11_t x, type_actual_t list_adt__T);

extern list_adt_funtype_11_t copy_list_adt_funtype_11(list_adt_funtype_11_t x);

extern bool_t equal_list_adt_funtype_11(list_adt_funtype_11_t x, list_adt_funtype_11_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_11(list_adt_funtype_11_t x, type_actual_t list_adt__T);




struct list_adt_closure_12_s;
        typedef struct list_adt_closure_12_s * list_adt_closure_12_t;

struct list_adt_closure_12_s {uint32_t count;
         list_adt_funtype_6_ftbl_t ftbl;
         list_adt_funtype_6_htbl_t htbl;
        list_adt_funtype_6_t fvar_1;
        list_adt_funtype_11_t fvar_2;
        type_actual_t fvar_3; type_actual_t list_adt__T;};

mpz_ptr_t f_list_adt_closure_12(struct list_adt_closure_12_s * closure, list_adt__list_adt_t bvar);

mpz_ptr_t m_list_adt_closure_12(struct list_adt_closure_12_s * closure, list_adt__list_adt_t bvar);

extern mpz_ptr_t h_list_adt_closure_12(list_adt__list_adt_t ivar_7, list_adt_funtype_6_t ivar_1, list_adt_funtype_11_t ivar_3, type_actual_t list_adt__T);

list_adt_closure_12_t new_list_adt_closure_12(void);

void release_list_adt_closure_12(list_adt_funtype_6_t closure, type_actual_t list_adt__T);

list_adt_closure_12_t copy_list_adt_closure_12(list_adt_closure_12_t x);


//reduce_ordinal

struct list_adt_funtype_13_s;
        typedef struct list_adt_funtype_13_s * list_adt_funtype_13_t;

struct list_adt_funtype_13_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct list_adt_funtype_13_s *, list_adt__list_adt_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct list_adt_funtype_13_s *, list_adt__list_adt_t);
        void (* rptr)(struct list_adt_funtype_13_s *);
        struct list_adt_funtype_13_s * (* cptr)(struct list_adt_funtype_13_s *);};
typedef struct list_adt_funtype_13_ftbl_s * list_adt_funtype_13_ftbl_t;

struct list_adt_funtype_13_hashentry_s {uint32_t keyhash; list_adt__list_adt_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct list_adt_funtype_13_hashentry_s list_adt_funtype_13_hashentry_t;

struct list_adt_funtype_13_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_13_hashentry_t * data;}; 
typedef struct list_adt_funtype_13_htbl_s * list_adt_funtype_13_htbl_t;

struct list_adt_funtype_13_s {uint32_t count;
        list_adt_funtype_13_ftbl_t ftbl;
        list_adt_funtype_13_htbl_t htbl;};
typedef struct list_adt_funtype_13_s * list_adt_funtype_13_t;

extern void release_list_adt_funtype_13(list_adt_funtype_13_t x, type_actual_t list_adt__T);

extern list_adt_funtype_13_t copy_list_adt_funtype_13(list_adt_funtype_13_t x);

extern bool_t equal_list_adt_funtype_13(list_adt_funtype_13_t x, list_adt_funtype_13_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_13(list_adt_funtype_13_t x, type_actual_t list_adt__T);


//reduce_ordinal

struct list_adt_record_14_s {
        uint32_t count; 
        list_adt__T_t project_1;
        ordstruct_adt__ordstruct_adt_t project_2;};
typedef struct list_adt_record_14_s * list_adt_record_14_t;

extern list_adt_record_14_t new_list_adt_record_14(void);

extern void release_list_adt_record_14(list_adt_record_14_t x, type_actual_t list_adt__T);

extern list_adt_record_14_t copy_list_adt_record_14(list_adt_record_14_t x);

extern bool_t equal_list_adt_record_14(list_adt_record_14_t x, list_adt_record_14_t y, type_actual_t list_adt__T);
extern char * json_list_adt_record_14(list_adt_record_14_t x, type_actual_t list_adt__T);

typedef struct actual_list_adt_record_14_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t list_adt__T;} * actual_list_adt_record_14_t;
extern void release_list_adt_record_14_ptr(pointer_t x, type_actual_t list_adt_record_14);

extern bool_t equal_list_adt_record_14_ptr(pointer_t x, pointer_t y, actual_list_adt_record_14_t T);

extern char * json_list_adt_record_14_ptr(pointer_t x,  actual_list_adt_record_14_t T);

actual_list_adt_record_14_t actual_list_adt_record_14(type_actual_t list_adt__T);

 

extern list_adt_record_14_t update_list_adt_record_14_project_1(list_adt_record_14_t x, list_adt__T_t v, type_actual_t list_adt__T);

extern list_adt_record_14_t update_list_adt_record_14_project_2(list_adt_record_14_t x, ordstruct_adt__ordstruct_adt_t v, type_actual_t list_adt__T);


//reduce_ordinal

struct list_adt_funtype_15_s;
        typedef struct list_adt_funtype_15_s * list_adt_funtype_15_t;

struct list_adt_funtype_15_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct list_adt_funtype_15_s *, list_adt_record_14_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct list_adt_funtype_15_s *, list_adt__T_t, ordstruct_adt__ordstruct_adt_t);
        void (* rptr)(struct list_adt_funtype_15_s *);
        struct list_adt_funtype_15_s * (* cptr)(struct list_adt_funtype_15_s *);};
typedef struct list_adt_funtype_15_ftbl_s * list_adt_funtype_15_ftbl_t;

struct list_adt_funtype_15_hashentry_s {uint32_t keyhash; list_adt_record_14_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct list_adt_funtype_15_hashentry_s list_adt_funtype_15_hashentry_t;

struct list_adt_funtype_15_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_15_hashentry_t * data;}; 
typedef struct list_adt_funtype_15_htbl_s * list_adt_funtype_15_htbl_t;

struct list_adt_funtype_15_s {uint32_t count;
        list_adt_funtype_15_ftbl_t ftbl;
        list_adt_funtype_15_htbl_t htbl;};
typedef struct list_adt_funtype_15_s * list_adt_funtype_15_t;

extern void release_list_adt_funtype_15(list_adt_funtype_15_t x, type_actual_t list_adt__T);

extern list_adt_funtype_15_t copy_list_adt_funtype_15(list_adt_funtype_15_t x);

extern bool_t equal_list_adt_funtype_15(list_adt_funtype_15_t x, list_adt_funtype_15_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_15(list_adt_funtype_15_t x, type_actual_t list_adt__T);




struct list_adt_closure_16_s;
        typedef struct list_adt_closure_16_s * list_adt_closure_16_t;

struct list_adt_closure_16_s {uint32_t count;
         list_adt_funtype_13_ftbl_t ftbl;
         list_adt_funtype_13_htbl_t htbl;
        ordstruct_adt__ordstruct_adt_t fvar_1;
        list_adt_funtype_15_t fvar_2;
        type_actual_t fvar_3; type_actual_t list_adt__T;};

ordstruct_adt__ordstruct_adt_t f_list_adt_closure_16(struct list_adt_closure_16_s * closure, list_adt__list_adt_t bvar);

ordstruct_adt__ordstruct_adt_t m_list_adt_closure_16(struct list_adt_closure_16_s * closure, list_adt__list_adt_t bvar);

extern ordstruct_adt__ordstruct_adt_t h_list_adt_closure_16(list_adt__list_adt_t ivar_6, ordstruct_adt__ordstruct_adt_t ivar_1, list_adt_funtype_15_t ivar_2, type_actual_t list_adt__T);

list_adt_closure_16_t new_list_adt_closure_16(void);

void release_list_adt_closure_16(list_adt_funtype_13_t closure, type_actual_t list_adt__T);

list_adt_closure_16_t copy_list_adt_closure_16(list_adt_closure_16_t x);


//REDUCE_ordinal

struct list_adt_record_17_s {
        uint32_t count; 
        list_adt__T_t project_1;
        ordstruct_adt__ordstruct_adt_t project_2;
        list_adt__list_adt_t project_3;};
typedef struct list_adt_record_17_s * list_adt_record_17_t;

extern list_adt_record_17_t new_list_adt_record_17(void);

extern void release_list_adt_record_17(list_adt_record_17_t x, type_actual_t list_adt__T);

extern list_adt_record_17_t copy_list_adt_record_17(list_adt_record_17_t x);

extern bool_t equal_list_adt_record_17(list_adt_record_17_t x, list_adt_record_17_t y, type_actual_t list_adt__T);
extern char * json_list_adt_record_17(list_adt_record_17_t x, type_actual_t list_adt__T);

typedef struct actual_list_adt_record_17_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t list_adt__T;} * actual_list_adt_record_17_t;
extern void release_list_adt_record_17_ptr(pointer_t x, type_actual_t list_adt_record_17);

extern bool_t equal_list_adt_record_17_ptr(pointer_t x, pointer_t y, actual_list_adt_record_17_t T);

extern char * json_list_adt_record_17_ptr(pointer_t x,  actual_list_adt_record_17_t T);

actual_list_adt_record_17_t actual_list_adt_record_17(type_actual_t list_adt__T);

 

extern list_adt_record_17_t update_list_adt_record_17_project_1(list_adt_record_17_t x, list_adt__T_t v, type_actual_t list_adt__T);

extern list_adt_record_17_t update_list_adt_record_17_project_2(list_adt_record_17_t x, ordstruct_adt__ordstruct_adt_t v, type_actual_t list_adt__T);

extern list_adt_record_17_t update_list_adt_record_17_project_3(list_adt_record_17_t x, list_adt__list_adt_t v, type_actual_t list_adt__T);


//REDUCE_ordinal

struct list_adt_funtype_18_s;
        typedef struct list_adt_funtype_18_s * list_adt_funtype_18_t;

struct list_adt_funtype_18_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct list_adt_funtype_18_s *, list_adt_record_17_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct list_adt_funtype_18_s *, list_adt__T_t, ordstruct_adt__ordstruct_adt_t, list_adt__list_adt_t);
        void (* rptr)(struct list_adt_funtype_18_s *);
        struct list_adt_funtype_18_s * (* cptr)(struct list_adt_funtype_18_s *);};
typedef struct list_adt_funtype_18_ftbl_s * list_adt_funtype_18_ftbl_t;

struct list_adt_funtype_18_hashentry_s {uint32_t keyhash; list_adt_record_17_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct list_adt_funtype_18_hashentry_s list_adt_funtype_18_hashentry_t;

struct list_adt_funtype_18_htbl_s {uint32_t size; uint32_t num_entries; list_adt_funtype_18_hashentry_t * data;}; 
typedef struct list_adt_funtype_18_htbl_s * list_adt_funtype_18_htbl_t;

struct list_adt_funtype_18_s {uint32_t count;
        list_adt_funtype_18_ftbl_t ftbl;
        list_adt_funtype_18_htbl_t htbl;};
typedef struct list_adt_funtype_18_s * list_adt_funtype_18_t;

extern void release_list_adt_funtype_18(list_adt_funtype_18_t x, type_actual_t list_adt__T);

extern list_adt_funtype_18_t copy_list_adt_funtype_18(list_adt_funtype_18_t x);

extern bool_t equal_list_adt_funtype_18(list_adt_funtype_18_t x, list_adt_funtype_18_t y, type_actual_t list_adt__T);

extern char* json_list_adt_funtype_18(list_adt_funtype_18_t x, type_actual_t list_adt__T);




struct list_adt_closure_19_s;
        typedef struct list_adt_closure_19_s * list_adt_closure_19_t;

struct list_adt_closure_19_s {uint32_t count;
         list_adt_funtype_13_ftbl_t ftbl;
         list_adt_funtype_13_htbl_t htbl;
        list_adt_funtype_13_t fvar_1;
        list_adt_funtype_18_t fvar_2;
        type_actual_t fvar_3; type_actual_t list_adt__T;};

ordstruct_adt__ordstruct_adt_t f_list_adt_closure_19(struct list_adt_closure_19_s * closure, list_adt__list_adt_t bvar);

ordstruct_adt__ordstruct_adt_t m_list_adt_closure_19(struct list_adt_closure_19_s * closure, list_adt__list_adt_t bvar);

extern ordstruct_adt__ordstruct_adt_t h_list_adt_closure_19(list_adt__list_adt_t ivar_7, list_adt_funtype_13_t ivar_1, list_adt_funtype_18_t ivar_3, type_actual_t list_adt__T);

list_adt_closure_19_t new_list_adt_closure_19(void);

void release_list_adt_closure_19(list_adt_funtype_13_t closure, type_actual_t list_adt__T);

list_adt_closure_19_t copy_list_adt_closure_19(list_adt_closure_19_t x);



extern bool_t rec_list_adt__nullp(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1);

extern bool_t rec_list_adt__consp(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1);

extern list_adt__cons_t update_list_adt__list_adt_car(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__T_t ivar_3);

extern list_adt__T_t acc_list_adt__list_adt_car(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1);

extern list_adt__cons_t update_list_adt__list_adt_cdr(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__list_adt_t ivar_3);

extern list_adt__list_adt_t acc_list_adt__list_adt_cdr(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1);

extern list_adt__list_adt_t con_list_adt__null(type_actual_t list_adt__T);

extern list_adt__list_adt_t con_list_adt__cons(type_actual_t list_adt__T, list_adt__T_t ivar_2, list_adt__list_adt_t ivar_3);

extern uint8_t list_adt__ord(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1);

extern list_adt_funtype_2_t list_adt__every_1(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1);

extern bool_t list_adt__every_2(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1, list_adt__list_adt_t ivar_3);

extern list_adt_funtype_2_t list_adt__some_1(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1);

extern bool_t list_adt__some_2(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1, list_adt__list_adt_t ivar_3);

extern bool_t list_adt__subterm(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__list_adt_t ivar_2);

extern bool_t list_adt__doublelessp(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__list_adt_t ivar_2);

extern list_adt_funtype_6_t list_adt__reduce_nat(type_actual_t list_adt__T, mpz_ptr_t ivar_1, list_adt_funtype_8_t ivar_2);

extern list_adt_funtype_6_t list_adt__REDUCE_nat(type_actual_t list_adt__T, list_adt_funtype_6_t ivar_1, list_adt_funtype_11_t ivar_3);

extern list_adt_funtype_13_t list_adt__reduce_ordinal(type_actual_t list_adt__T, ordstruct_adt__ordstruct_adt_t ivar_1, list_adt_funtype_15_t ivar_2);

extern list_adt_funtype_13_t list_adt__REDUCE_ordinal(type_actual_t list_adt__T, list_adt_funtype_13_t ivar_1, list_adt_funtype_18_t ivar_3);
#endif