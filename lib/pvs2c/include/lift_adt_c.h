//Code generated using pvs2ir
#ifndef _lift_adt_h 
#define _lift_adt_h

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

//cc -O3 -Wall -o lift_adt -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include lift_adt_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t lift_adt__T_t;
//lift

struct lift_adt__lift_adt_s {
         uint32_t count; 
        uint8_t lift_adt__lift_adt_index;};
typedef struct lift_adt__lift_adt_s * lift_adt__lift_adt_t;

extern lift_adt__lift_adt_t new_lift_adt__lift_adt(void);

extern void release_lift_adt__lift_adt(lift_adt__lift_adt_t x, type_actual_t lift_adt__T);

extern lift_adt__lift_adt_t copy_lift_adt__lift_adt(lift_adt__lift_adt_t x);

extern bool_t equal_lift_adt__lift_adt(lift_adt__lift_adt_t x, lift_adt__lift_adt_t y, type_actual_t lift_adt__T);
extern char * json_lift_adt__lift_adt(lift_adt__lift_adt_t x, type_actual_t lift_adt__T);

typedef struct actual_lift_adt__lift_adt_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t lift_adt__T;} * actual_lift_adt__lift_adt_t;
extern void release_lift_adt__lift_adt_ptr(pointer_t x, type_actual_t lift_adt__lift_adt);

extern bool_t equal_lift_adt__lift_adt_ptr(pointer_t x, pointer_t y, actual_lift_adt__lift_adt_t T);

extern char * json_lift_adt__lift_adt_ptr(pointer_t x,  actual_lift_adt__lift_adt_t T);

actual_lift_adt__lift_adt_t actual_lift_adt__lift_adt(type_actual_t lift_adt__T);

 

extern lift_adt__lift_adt_t update_lift_adt__lift_adt_lift_adt__lift_adt_index(lift_adt__lift_adt_t x, uint8_t v);


//up

struct lift_adt__up_s {
        uint32_t count; 
        uint8_t lift_adt__lift_adt_index;
        lift_adt__T_t down;};
typedef struct lift_adt__up_s * lift_adt__up_t;

extern lift_adt__up_t new_lift_adt__up(void);

extern void release_lift_adt__up(lift_adt__up_t x, type_actual_t lift_adt__T);

extern lift_adt__up_t copy_lift_adt__up(lift_adt__up_t x);

extern bool_t equal_lift_adt__up(lift_adt__up_t x, lift_adt__up_t y, type_actual_t lift_adt__T);
extern char * json_lift_adt__up(lift_adt__up_t x, type_actual_t lift_adt__T);

typedef struct actual_lift_adt__up_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t lift_adt__T;} * actual_lift_adt__up_t;
extern void release_lift_adt__up_ptr(pointer_t x, type_actual_t lift_adt__up);

extern bool_t equal_lift_adt__up_ptr(pointer_t x, pointer_t y, actual_lift_adt__up_t T);

extern char * json_lift_adt__up_ptr(pointer_t x,  actual_lift_adt__up_t T);

actual_lift_adt__up_t actual_lift_adt__up(type_actual_t lift_adt__T);

 

extern lift_adt__up_t update_lift_adt__up_lift_adt__lift_adt_index(lift_adt__up_t x, uint8_t v);

extern lift_adt__up_t update_lift_adt__up_down(lift_adt__up_t x, lift_adt__T_t v, type_actual_t lift_adt__T);


//every

struct lift_adt_funtype_2_s;
        typedef struct lift_adt_funtype_2_s * lift_adt_funtype_2_t;

struct lift_adt_funtype_2_ftbl_s {bool_t (* fptr)(struct lift_adt_funtype_2_s *, lift_adt__lift_adt_t);
        bool_t (* mptr)(struct lift_adt_funtype_2_s *, lift_adt__lift_adt_t);
        void (* rptr)(struct lift_adt_funtype_2_s *);
        struct lift_adt_funtype_2_s * (* cptr)(struct lift_adt_funtype_2_s *);};
typedef struct lift_adt_funtype_2_ftbl_s * lift_adt_funtype_2_ftbl_t;

struct lift_adt_funtype_2_hashentry_s {uint32_t keyhash; lift_adt__lift_adt_t key; bool_t value;}; 
typedef struct lift_adt_funtype_2_hashentry_s lift_adt_funtype_2_hashentry_t;

struct lift_adt_funtype_2_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_2_hashentry_t * data;}; 
typedef struct lift_adt_funtype_2_htbl_s * lift_adt_funtype_2_htbl_t;

struct lift_adt_funtype_2_s {uint32_t count;
        lift_adt_funtype_2_ftbl_t ftbl;
        lift_adt_funtype_2_htbl_t htbl;};
typedef struct lift_adt_funtype_2_s * lift_adt_funtype_2_t;

extern void release_lift_adt_funtype_2(lift_adt_funtype_2_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_2_t copy_lift_adt_funtype_2(lift_adt_funtype_2_t x);

extern bool_t equal_lift_adt_funtype_2(lift_adt_funtype_2_t x, lift_adt_funtype_2_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_2(lift_adt_funtype_2_t x, type_actual_t lift_adt__T);


//every

struct lift_adt_funtype_3_s;
        typedef struct lift_adt_funtype_3_s * lift_adt_funtype_3_t;

struct lift_adt_funtype_3_ftbl_s {bool_t (* fptr)(struct lift_adt_funtype_3_s *, lift_adt__T_t);
        bool_t (* mptr)(struct lift_adt_funtype_3_s *, lift_adt__T_t);
        void (* rptr)(struct lift_adt_funtype_3_s *);
        struct lift_adt_funtype_3_s * (* cptr)(struct lift_adt_funtype_3_s *);};
typedef struct lift_adt_funtype_3_ftbl_s * lift_adt_funtype_3_ftbl_t;

struct lift_adt_funtype_3_hashentry_s {uint32_t keyhash; lift_adt__T_t key; bool_t value;}; 
typedef struct lift_adt_funtype_3_hashentry_s lift_adt_funtype_3_hashentry_t;

struct lift_adt_funtype_3_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_3_hashentry_t * data;}; 
typedef struct lift_adt_funtype_3_htbl_s * lift_adt_funtype_3_htbl_t;

struct lift_adt_funtype_3_s {uint32_t count;
        lift_adt_funtype_3_ftbl_t ftbl;
        lift_adt_funtype_3_htbl_t htbl;};
typedef struct lift_adt_funtype_3_s * lift_adt_funtype_3_t;

extern void release_lift_adt_funtype_3(lift_adt_funtype_3_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_3_t copy_lift_adt_funtype_3(lift_adt_funtype_3_t x);

extern bool_t equal_lift_adt_funtype_3(lift_adt_funtype_3_t x, lift_adt_funtype_3_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_3(lift_adt_funtype_3_t x, type_actual_t lift_adt__T);




struct lift_adt_closure_4_s;
        typedef struct lift_adt_closure_4_s * lift_adt_closure_4_t;

struct lift_adt_closure_4_s {uint32_t count;
         lift_adt_funtype_2_ftbl_t ftbl;
         lift_adt_funtype_2_htbl_t htbl;
        lift_adt_funtype_3_t fvar_1;
        type_actual_t fvar_2; type_actual_t lift_adt__T;};

bool_t f_lift_adt_closure_4(struct lift_adt_closure_4_s * closure, lift_adt__lift_adt_t bvar);

bool_t m_lift_adt_closure_4(struct lift_adt_closure_4_s * closure, lift_adt__lift_adt_t bvar);

extern bool_t h_lift_adt_closure_4(lift_adt__lift_adt_t ivar_5, lift_adt_funtype_3_t ivar_1, type_actual_t lift_adt__T);

lift_adt_closure_4_t new_lift_adt_closure_4(void);

void release_lift_adt_closure_4(lift_adt_funtype_2_t closure, type_actual_t lift_adt__T);

lift_adt_closure_4_t copy_lift_adt_closure_4(lift_adt_closure_4_t x);




struct lift_adt_closure_5_s;
        typedef struct lift_adt_closure_5_s * lift_adt_closure_5_t;

struct lift_adt_closure_5_s {uint32_t count;
         lift_adt_funtype_2_ftbl_t ftbl;
         lift_adt_funtype_2_htbl_t htbl;
        lift_adt_funtype_3_t fvar_1;
        type_actual_t fvar_2; type_actual_t lift_adt__T;};

bool_t f_lift_adt_closure_5(struct lift_adt_closure_5_s * closure, lift_adt__lift_adt_t bvar);

bool_t m_lift_adt_closure_5(struct lift_adt_closure_5_s * closure, lift_adt__lift_adt_t bvar);

extern bool_t h_lift_adt_closure_5(lift_adt__lift_adt_t ivar_5, lift_adt_funtype_3_t ivar_1, type_actual_t lift_adt__T);

lift_adt_closure_5_t new_lift_adt_closure_5(void);

void release_lift_adt_closure_5(lift_adt_funtype_2_t closure, type_actual_t lift_adt__T);

lift_adt_closure_5_t copy_lift_adt_closure_5(lift_adt_closure_5_t x);


//reduce_nat

struct lift_adt_funtype_6_s;
        typedef struct lift_adt_funtype_6_s * lift_adt_funtype_6_t;

struct lift_adt_funtype_6_ftbl_s {mpz_ptr_t (* fptr)(struct lift_adt_funtype_6_s *, lift_adt__lift_adt_t);
        mpz_ptr_t (* mptr)(struct lift_adt_funtype_6_s *, lift_adt__lift_adt_t);
        void (* rptr)(struct lift_adt_funtype_6_s *);
        struct lift_adt_funtype_6_s * (* cptr)(struct lift_adt_funtype_6_s *);};
typedef struct lift_adt_funtype_6_ftbl_s * lift_adt_funtype_6_ftbl_t;

struct lift_adt_funtype_6_hashentry_s {uint32_t keyhash; lift_adt__lift_adt_t key; mpz_t value;}; 
typedef struct lift_adt_funtype_6_hashentry_s lift_adt_funtype_6_hashentry_t;

struct lift_adt_funtype_6_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_6_hashentry_t * data;}; 
typedef struct lift_adt_funtype_6_htbl_s * lift_adt_funtype_6_htbl_t;

struct lift_adt_funtype_6_s {uint32_t count;
        lift_adt_funtype_6_ftbl_t ftbl;
        lift_adt_funtype_6_htbl_t htbl;};
typedef struct lift_adt_funtype_6_s * lift_adt_funtype_6_t;

extern void release_lift_adt_funtype_6(lift_adt_funtype_6_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_6_t copy_lift_adt_funtype_6(lift_adt_funtype_6_t x);

extern bool_t equal_lift_adt_funtype_6(lift_adt_funtype_6_t x, lift_adt_funtype_6_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_6(lift_adt_funtype_6_t x, type_actual_t lift_adt__T);


//reduce_nat

struct lift_adt_funtype_7_s;
        typedef struct lift_adt_funtype_7_s * lift_adt_funtype_7_t;

struct lift_adt_funtype_7_ftbl_s {mpz_ptr_t (* fptr)(struct lift_adt_funtype_7_s *, lift_adt__T_t);
        mpz_ptr_t (* mptr)(struct lift_adt_funtype_7_s *, lift_adt__T_t);
        void (* rptr)(struct lift_adt_funtype_7_s *);
        struct lift_adt_funtype_7_s * (* cptr)(struct lift_adt_funtype_7_s *);};
typedef struct lift_adt_funtype_7_ftbl_s * lift_adt_funtype_7_ftbl_t;

struct lift_adt_funtype_7_hashentry_s {uint32_t keyhash; lift_adt__T_t key; mpz_t value;}; 
typedef struct lift_adt_funtype_7_hashentry_s lift_adt_funtype_7_hashentry_t;

struct lift_adt_funtype_7_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_7_hashentry_t * data;}; 
typedef struct lift_adt_funtype_7_htbl_s * lift_adt_funtype_7_htbl_t;

struct lift_adt_funtype_7_s {uint32_t count;
        lift_adt_funtype_7_ftbl_t ftbl;
        lift_adt_funtype_7_htbl_t htbl;};
typedef struct lift_adt_funtype_7_s * lift_adt_funtype_7_t;

extern void release_lift_adt_funtype_7(lift_adt_funtype_7_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_7_t copy_lift_adt_funtype_7(lift_adt_funtype_7_t x);

extern bool_t equal_lift_adt_funtype_7(lift_adt_funtype_7_t x, lift_adt_funtype_7_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_7(lift_adt_funtype_7_t x, type_actual_t lift_adt__T);




struct lift_adt_closure_8_s;
        typedef struct lift_adt_closure_8_s * lift_adt_closure_8_t;

struct lift_adt_closure_8_s {uint32_t count;
         lift_adt_funtype_6_ftbl_t ftbl;
         lift_adt_funtype_6_htbl_t htbl;
        lift_adt_funtype_7_t fvar_1;
        mpz_t fvar_2;
        type_actual_t fvar_3; type_actual_t lift_adt__T;};

mpz_ptr_t f_lift_adt_closure_8(struct lift_adt_closure_8_s * closure, lift_adt__lift_adt_t bvar);

mpz_ptr_t m_lift_adt_closure_8(struct lift_adt_closure_8_s * closure, lift_adt__lift_adt_t bvar);

extern mpz_ptr_t h_lift_adt_closure_8(lift_adt__lift_adt_t ivar_6, lift_adt_funtype_7_t ivar_2, mpz_ptr_t ivar_1, type_actual_t lift_adt__T);

lift_adt_closure_8_t new_lift_adt_closure_8(void);

void release_lift_adt_closure_8(lift_adt_funtype_6_t closure, type_actual_t lift_adt__T);

lift_adt_closure_8_t copy_lift_adt_closure_8(lift_adt_closure_8_t x);


//REDUCE_nat

struct lift_adt_record_9_s {
        uint32_t count; 
        lift_adt__T_t project_1;
        lift_adt__lift_adt_t project_2;};
typedef struct lift_adt_record_9_s * lift_adt_record_9_t;

extern lift_adt_record_9_t new_lift_adt_record_9(void);

extern void release_lift_adt_record_9(lift_adt_record_9_t x, type_actual_t lift_adt__T);

extern lift_adt_record_9_t copy_lift_adt_record_9(lift_adt_record_9_t x);

extern bool_t equal_lift_adt_record_9(lift_adt_record_9_t x, lift_adt_record_9_t y, type_actual_t lift_adt__T);
extern char * json_lift_adt_record_9(lift_adt_record_9_t x, type_actual_t lift_adt__T);

typedef struct actual_lift_adt_record_9_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t lift_adt__T;} * actual_lift_adt_record_9_t;
extern void release_lift_adt_record_9_ptr(pointer_t x, type_actual_t lift_adt_record_9);

extern bool_t equal_lift_adt_record_9_ptr(pointer_t x, pointer_t y, actual_lift_adt_record_9_t T);

extern char * json_lift_adt_record_9_ptr(pointer_t x,  actual_lift_adt_record_9_t T);

actual_lift_adt_record_9_t actual_lift_adt_record_9(type_actual_t lift_adt__T);

 

extern lift_adt_record_9_t update_lift_adt_record_9_project_1(lift_adt_record_9_t x, lift_adt__T_t v, type_actual_t lift_adt__T);

extern lift_adt_record_9_t update_lift_adt_record_9_project_2(lift_adt_record_9_t x, lift_adt__lift_adt_t v, type_actual_t lift_adt__T);


//REDUCE_nat

struct lift_adt_funtype_10_s;
        typedef struct lift_adt_funtype_10_s * lift_adt_funtype_10_t;

struct lift_adt_funtype_10_ftbl_s {mpz_ptr_t (* fptr)(struct lift_adt_funtype_10_s *, lift_adt_record_9_t);
        mpz_ptr_t (* mptr)(struct lift_adt_funtype_10_s *, lift_adt__T_t, lift_adt__lift_adt_t);
        void (* rptr)(struct lift_adt_funtype_10_s *);
        struct lift_adt_funtype_10_s * (* cptr)(struct lift_adt_funtype_10_s *);};
typedef struct lift_adt_funtype_10_ftbl_s * lift_adt_funtype_10_ftbl_t;

struct lift_adt_funtype_10_hashentry_s {uint32_t keyhash; lift_adt_record_9_t key; mpz_t value;}; 
typedef struct lift_adt_funtype_10_hashentry_s lift_adt_funtype_10_hashentry_t;

struct lift_adt_funtype_10_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_10_hashentry_t * data;}; 
typedef struct lift_adt_funtype_10_htbl_s * lift_adt_funtype_10_htbl_t;

struct lift_adt_funtype_10_s {uint32_t count;
        lift_adt_funtype_10_ftbl_t ftbl;
        lift_adt_funtype_10_htbl_t htbl;};
typedef struct lift_adt_funtype_10_s * lift_adt_funtype_10_t;

extern void release_lift_adt_funtype_10(lift_adt_funtype_10_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_10_t copy_lift_adt_funtype_10(lift_adt_funtype_10_t x);

extern bool_t equal_lift_adt_funtype_10(lift_adt_funtype_10_t x, lift_adt_funtype_10_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_10(lift_adt_funtype_10_t x, type_actual_t lift_adt__T);




struct lift_adt_closure_11_s;
        typedef struct lift_adt_closure_11_s * lift_adt_closure_11_t;

struct lift_adt_closure_11_s {uint32_t count;
         lift_adt_funtype_6_ftbl_t ftbl;
         lift_adt_funtype_6_htbl_t htbl;
        lift_adt_funtype_10_t fvar_1;
        lift_adt_funtype_6_t fvar_2;
        type_actual_t fvar_3; type_actual_t lift_adt__T;};

mpz_ptr_t f_lift_adt_closure_11(struct lift_adt_closure_11_s * closure, lift_adt__lift_adt_t bvar);

mpz_ptr_t m_lift_adt_closure_11(struct lift_adt_closure_11_s * closure, lift_adt__lift_adt_t bvar);

extern mpz_ptr_t h_lift_adt_closure_11(lift_adt__lift_adt_t ivar_7, lift_adt_funtype_10_t ivar_3, lift_adt_funtype_6_t ivar_1, type_actual_t lift_adt__T);

lift_adt_closure_11_t new_lift_adt_closure_11(void);

void release_lift_adt_closure_11(lift_adt_funtype_6_t closure, type_actual_t lift_adt__T);

lift_adt_closure_11_t copy_lift_adt_closure_11(lift_adt_closure_11_t x);


//reduce_ordinal

struct lift_adt_funtype_12_s;
        typedef struct lift_adt_funtype_12_s * lift_adt_funtype_12_t;

struct lift_adt_funtype_12_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct lift_adt_funtype_12_s *, lift_adt__lift_adt_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct lift_adt_funtype_12_s *, lift_adt__lift_adt_t);
        void (* rptr)(struct lift_adt_funtype_12_s *);
        struct lift_adt_funtype_12_s * (* cptr)(struct lift_adt_funtype_12_s *);};
typedef struct lift_adt_funtype_12_ftbl_s * lift_adt_funtype_12_ftbl_t;

struct lift_adt_funtype_12_hashentry_s {uint32_t keyhash; lift_adt__lift_adt_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct lift_adt_funtype_12_hashentry_s lift_adt_funtype_12_hashentry_t;

struct lift_adt_funtype_12_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_12_hashentry_t * data;}; 
typedef struct lift_adt_funtype_12_htbl_s * lift_adt_funtype_12_htbl_t;

struct lift_adt_funtype_12_s {uint32_t count;
        lift_adt_funtype_12_ftbl_t ftbl;
        lift_adt_funtype_12_htbl_t htbl;};
typedef struct lift_adt_funtype_12_s * lift_adt_funtype_12_t;

extern void release_lift_adt_funtype_12(lift_adt_funtype_12_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_12_t copy_lift_adt_funtype_12(lift_adt_funtype_12_t x);

extern bool_t equal_lift_adt_funtype_12(lift_adt_funtype_12_t x, lift_adt_funtype_12_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_12(lift_adt_funtype_12_t x, type_actual_t lift_adt__T);


//reduce_ordinal

struct lift_adt_funtype_13_s;
        typedef struct lift_adt_funtype_13_s * lift_adt_funtype_13_t;

struct lift_adt_funtype_13_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct lift_adt_funtype_13_s *, lift_adt__T_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct lift_adt_funtype_13_s *, lift_adt__T_t);
        void (* rptr)(struct lift_adt_funtype_13_s *);
        struct lift_adt_funtype_13_s * (* cptr)(struct lift_adt_funtype_13_s *);};
typedef struct lift_adt_funtype_13_ftbl_s * lift_adt_funtype_13_ftbl_t;

struct lift_adt_funtype_13_hashentry_s {uint32_t keyhash; lift_adt__T_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct lift_adt_funtype_13_hashentry_s lift_adt_funtype_13_hashentry_t;

struct lift_adt_funtype_13_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_13_hashentry_t * data;}; 
typedef struct lift_adt_funtype_13_htbl_s * lift_adt_funtype_13_htbl_t;

struct lift_adt_funtype_13_s {uint32_t count;
        lift_adt_funtype_13_ftbl_t ftbl;
        lift_adt_funtype_13_htbl_t htbl;};
typedef struct lift_adt_funtype_13_s * lift_adt_funtype_13_t;

extern void release_lift_adt_funtype_13(lift_adt_funtype_13_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_13_t copy_lift_adt_funtype_13(lift_adt_funtype_13_t x);

extern bool_t equal_lift_adt_funtype_13(lift_adt_funtype_13_t x, lift_adt_funtype_13_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_13(lift_adt_funtype_13_t x, type_actual_t lift_adt__T);




struct lift_adt_closure_14_s;
        typedef struct lift_adt_closure_14_s * lift_adt_closure_14_t;

struct lift_adt_closure_14_s {uint32_t count;
         lift_adt_funtype_12_ftbl_t ftbl;
         lift_adt_funtype_12_htbl_t htbl;
        lift_adt_funtype_13_t fvar_1;
        ordstruct_adt__ordstruct_adt_t fvar_2;
        type_actual_t fvar_3; type_actual_t lift_adt__T;};

ordstruct_adt__ordstruct_adt_t f_lift_adt_closure_14(struct lift_adt_closure_14_s * closure, lift_adt__lift_adt_t bvar);

ordstruct_adt__ordstruct_adt_t m_lift_adt_closure_14(struct lift_adt_closure_14_s * closure, lift_adt__lift_adt_t bvar);

extern ordstruct_adt__ordstruct_adt_t h_lift_adt_closure_14(lift_adt__lift_adt_t ivar_6, lift_adt_funtype_13_t ivar_2, ordstruct_adt__ordstruct_adt_t ivar_1, type_actual_t lift_adt__T);

lift_adt_closure_14_t new_lift_adt_closure_14(void);

void release_lift_adt_closure_14(lift_adt_funtype_12_t closure, type_actual_t lift_adt__T);

lift_adt_closure_14_t copy_lift_adt_closure_14(lift_adt_closure_14_t x);


//REDUCE_ordinal

struct lift_adt_funtype_15_s;
        typedef struct lift_adt_funtype_15_s * lift_adt_funtype_15_t;

struct lift_adt_funtype_15_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct lift_adt_funtype_15_s *, lift_adt_record_9_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct lift_adt_funtype_15_s *, lift_adt__T_t, lift_adt__lift_adt_t);
        void (* rptr)(struct lift_adt_funtype_15_s *);
        struct lift_adt_funtype_15_s * (* cptr)(struct lift_adt_funtype_15_s *);};
typedef struct lift_adt_funtype_15_ftbl_s * lift_adt_funtype_15_ftbl_t;

struct lift_adt_funtype_15_hashentry_s {uint32_t keyhash; lift_adt_record_9_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct lift_adt_funtype_15_hashentry_s lift_adt_funtype_15_hashentry_t;

struct lift_adt_funtype_15_htbl_s {uint32_t size; uint32_t num_entries; lift_adt_funtype_15_hashentry_t * data;}; 
typedef struct lift_adt_funtype_15_htbl_s * lift_adt_funtype_15_htbl_t;

struct lift_adt_funtype_15_s {uint32_t count;
        lift_adt_funtype_15_ftbl_t ftbl;
        lift_adt_funtype_15_htbl_t htbl;};
typedef struct lift_adt_funtype_15_s * lift_adt_funtype_15_t;

extern void release_lift_adt_funtype_15(lift_adt_funtype_15_t x, type_actual_t lift_adt__T);

extern lift_adt_funtype_15_t copy_lift_adt_funtype_15(lift_adt_funtype_15_t x);

extern bool_t equal_lift_adt_funtype_15(lift_adt_funtype_15_t x, lift_adt_funtype_15_t y, type_actual_t lift_adt__T);

extern char* json_lift_adt_funtype_15(lift_adt_funtype_15_t x, type_actual_t lift_adt__T);




struct lift_adt_closure_16_s;
        typedef struct lift_adt_closure_16_s * lift_adt_closure_16_t;

struct lift_adt_closure_16_s {uint32_t count;
         lift_adt_funtype_12_ftbl_t ftbl;
         lift_adt_funtype_12_htbl_t htbl;
        lift_adt_funtype_15_t fvar_1;
        lift_adt_funtype_12_t fvar_2;
        type_actual_t fvar_3; type_actual_t lift_adt__T;};

ordstruct_adt__ordstruct_adt_t f_lift_adt_closure_16(struct lift_adt_closure_16_s * closure, lift_adt__lift_adt_t bvar);

ordstruct_adt__ordstruct_adt_t m_lift_adt_closure_16(struct lift_adt_closure_16_s * closure, lift_adt__lift_adt_t bvar);

extern ordstruct_adt__ordstruct_adt_t h_lift_adt_closure_16(lift_adt__lift_adt_t ivar_7, lift_adt_funtype_15_t ivar_3, lift_adt_funtype_12_t ivar_1, type_actual_t lift_adt__T);

lift_adt_closure_16_t new_lift_adt_closure_16(void);

void release_lift_adt_closure_16(lift_adt_funtype_12_t closure, type_actual_t lift_adt__T);

lift_adt_closure_16_t copy_lift_adt_closure_16(lift_adt_closure_16_t x);



extern bool_t rec_lift_adt__bottomp(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1);

extern bool_t rec_lift_adt__upp(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1);

extern lift_adt__up_t update_lift_adt__lift_adt_down(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1, lift_adt__T_t ivar_3);

extern lift_adt__T_t acc_lift_adt__lift_adt_down(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1);

extern lift_adt__lift_adt_t con_lift_adt__bottom(type_actual_t lift_adt__T);

extern lift_adt__lift_adt_t con_lift_adt__up(type_actual_t lift_adt__T, lift_adt__T_t ivar_2);

extern uint8_t lift_adt__ord(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1);

extern lift_adt_funtype_2_t lift_adt__every_1(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1);

extern bool_t lift_adt__every_2(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1, lift_adt__lift_adt_t ivar_3);

extern lift_adt_funtype_2_t lift_adt__some_1(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1);

extern bool_t lift_adt__some_2(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1, lift_adt__lift_adt_t ivar_3);

extern bool_t lift_adt__subterm(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1, lift_adt__lift_adt_t ivar_2);

extern bool_t lift_adt__doublelessp(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1, lift_adt__lift_adt_t ivar_2);

extern lift_adt_funtype_6_t lift_adt__reduce_nat(type_actual_t lift_adt__T, mpz_ptr_t ivar_1, lift_adt_funtype_7_t ivar_2);

extern lift_adt_funtype_6_t lift_adt__REDUCE_nat(type_actual_t lift_adt__T, lift_adt_funtype_6_t ivar_1, lift_adt_funtype_10_t ivar_3);

extern lift_adt_funtype_12_t lift_adt__reduce_ordinal(type_actual_t lift_adt__T, ordstruct_adt__ordstruct_adt_t ivar_1, lift_adt_funtype_13_t ivar_2);

extern lift_adt_funtype_12_t lift_adt__REDUCE_ordinal(type_actual_t lift_adt__T, lift_adt_funtype_12_t ivar_1, lift_adt_funtype_15_t ivar_3);
#endif