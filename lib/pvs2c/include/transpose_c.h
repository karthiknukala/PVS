//Code generated using pvs2ir
#ifndef _transpose_h 
#define _transpose_h

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

//cc -O3 -Wall -o transpose -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include transpose_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t transpose__T1_t;

typedef pointer_t transpose__T2_t;

typedef pointer_t transpose__T3_t;
//transpose

struct transpose_funtype_0_s;
        typedef struct transpose_funtype_0_s * transpose_funtype_0_t;

struct transpose_funtype_0_ftbl_s {transpose__T3_t (* fptr)(struct transpose_funtype_0_s *, transpose__T1_t);
        transpose__T3_t (* mptr)(struct transpose_funtype_0_s *, transpose__T1_t);
        void (* rptr)(struct transpose_funtype_0_s *);
        struct transpose_funtype_0_s * (* cptr)(struct transpose_funtype_0_s *);};
typedef struct transpose_funtype_0_ftbl_s * transpose_funtype_0_ftbl_t;

struct transpose_funtype_0_hashentry_s {uint32_t keyhash; transpose__T1_t key; transpose__T3_t value;}; 
typedef struct transpose_funtype_0_hashentry_s transpose_funtype_0_hashentry_t;

struct transpose_funtype_0_htbl_s {uint32_t size; uint32_t num_entries; transpose_funtype_0_hashentry_t * data;}; 
typedef struct transpose_funtype_0_htbl_s * transpose_funtype_0_htbl_t;

struct transpose_funtype_0_s {uint32_t count;
        transpose_funtype_0_ftbl_t ftbl;
        transpose_funtype_0_htbl_t htbl;};
typedef struct transpose_funtype_0_s * transpose_funtype_0_t;

extern void release_transpose_funtype_0(transpose_funtype_0_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern transpose_funtype_0_t copy_transpose_funtype_0(transpose_funtype_0_t x);

extern bool_t equal_transpose_funtype_0(transpose_funtype_0_t x, transpose_funtype_0_t y, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern char* json_transpose_funtype_0(transpose_funtype_0_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);


//transpose

struct transpose_funtype_1_s;
        typedef struct transpose_funtype_1_s * transpose_funtype_1_t;

struct transpose_funtype_1_ftbl_s {transpose_funtype_0_t (* fptr)(struct transpose_funtype_1_s *, transpose__T2_t);
        transpose_funtype_0_t (* mptr)(struct transpose_funtype_1_s *, transpose__T2_t);
        void (* rptr)(struct transpose_funtype_1_s *);
        struct transpose_funtype_1_s * (* cptr)(struct transpose_funtype_1_s *);};
typedef struct transpose_funtype_1_ftbl_s * transpose_funtype_1_ftbl_t;

struct transpose_funtype_1_hashentry_s {uint32_t keyhash; transpose__T2_t key; transpose_funtype_0_t value;}; 
typedef struct transpose_funtype_1_hashentry_s transpose_funtype_1_hashentry_t;

struct transpose_funtype_1_htbl_s {uint32_t size; uint32_t num_entries; transpose_funtype_1_hashentry_t * data;}; 
typedef struct transpose_funtype_1_htbl_s * transpose_funtype_1_htbl_t;

struct transpose_funtype_1_s {uint32_t count;
        transpose_funtype_1_ftbl_t ftbl;
        transpose_funtype_1_htbl_t htbl;};
typedef struct transpose_funtype_1_s * transpose_funtype_1_t;

extern void release_transpose_funtype_1(transpose_funtype_1_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern transpose_funtype_1_t copy_transpose_funtype_1(transpose_funtype_1_t x);

extern bool_t equal_transpose_funtype_1(transpose_funtype_1_t x, transpose_funtype_1_t y, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern char* json_transpose_funtype_1(transpose_funtype_1_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);


//transpose

struct transpose_funtype_2_s;
        typedef struct transpose_funtype_2_s * transpose_funtype_2_t;

struct transpose_funtype_2_ftbl_s {transpose__T3_t (* fptr)(struct transpose_funtype_2_s *, transpose__T2_t);
        transpose__T3_t (* mptr)(struct transpose_funtype_2_s *, transpose__T2_t);
        void (* rptr)(struct transpose_funtype_2_s *);
        struct transpose_funtype_2_s * (* cptr)(struct transpose_funtype_2_s *);};
typedef struct transpose_funtype_2_ftbl_s * transpose_funtype_2_ftbl_t;

struct transpose_funtype_2_hashentry_s {uint32_t keyhash; transpose__T2_t key; transpose__T3_t value;}; 
typedef struct transpose_funtype_2_hashentry_s transpose_funtype_2_hashentry_t;

struct transpose_funtype_2_htbl_s {uint32_t size; uint32_t num_entries; transpose_funtype_2_hashentry_t * data;}; 
typedef struct transpose_funtype_2_htbl_s * transpose_funtype_2_htbl_t;

struct transpose_funtype_2_s {uint32_t count;
        transpose_funtype_2_ftbl_t ftbl;
        transpose_funtype_2_htbl_t htbl;};
typedef struct transpose_funtype_2_s * transpose_funtype_2_t;

extern void release_transpose_funtype_2(transpose_funtype_2_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern transpose_funtype_2_t copy_transpose_funtype_2(transpose_funtype_2_t x);

extern bool_t equal_transpose_funtype_2(transpose_funtype_2_t x, transpose_funtype_2_t y, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern char* json_transpose_funtype_2(transpose_funtype_2_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);


//transpose

struct transpose_funtype_3_s;
        typedef struct transpose_funtype_3_s * transpose_funtype_3_t;

struct transpose_funtype_3_ftbl_s {transpose_funtype_2_t (* fptr)(struct transpose_funtype_3_s *, transpose__T1_t);
        transpose_funtype_2_t (* mptr)(struct transpose_funtype_3_s *, transpose__T1_t);
        void (* rptr)(struct transpose_funtype_3_s *);
        struct transpose_funtype_3_s * (* cptr)(struct transpose_funtype_3_s *);};
typedef struct transpose_funtype_3_ftbl_s * transpose_funtype_3_ftbl_t;

struct transpose_funtype_3_hashentry_s {uint32_t keyhash; transpose__T1_t key; transpose_funtype_2_t value;}; 
typedef struct transpose_funtype_3_hashentry_s transpose_funtype_3_hashentry_t;

struct transpose_funtype_3_htbl_s {uint32_t size; uint32_t num_entries; transpose_funtype_3_hashentry_t * data;}; 
typedef struct transpose_funtype_3_htbl_s * transpose_funtype_3_htbl_t;

struct transpose_funtype_3_s {uint32_t count;
        transpose_funtype_3_ftbl_t ftbl;
        transpose_funtype_3_htbl_t htbl;};
typedef struct transpose_funtype_3_s * transpose_funtype_3_t;

extern void release_transpose_funtype_3(transpose_funtype_3_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern transpose_funtype_3_t copy_transpose_funtype_3(transpose_funtype_3_t x);

extern bool_t equal_transpose_funtype_3(transpose_funtype_3_t x, transpose_funtype_3_t y, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

extern char* json_transpose_funtype_3(transpose_funtype_3_t x, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);




struct transpose_closure_4_s;
        typedef struct transpose_closure_4_s * transpose_closure_4_t;

struct transpose_closure_4_s {uint32_t count;
         transpose_funtype_1_ftbl_t ftbl;
         transpose_funtype_1_htbl_t htbl;
        type_actual_t fvar_1;
        type_actual_t fvar_2;
        type_actual_t fvar_3;
        transpose_funtype_3_t fvar_4; type_actual_t transpose__T1; type_actual_t transpose__T2; type_actual_t transpose__T3;};

transpose_funtype_0_t f_transpose_closure_4(struct transpose_closure_4_s * closure, transpose__T2_t bvar);

transpose_funtype_0_t m_transpose_closure_4(struct transpose_closure_4_s * closure, transpose__T2_t bvar);

extern transpose_funtype_0_t h_transpose_closure_4(transpose__T2_t ivar_7, type_actual_t transpose__T3, type_actual_t transpose__T1, type_actual_t transpose__T2, transpose_funtype_3_t ivar_1);

transpose_closure_4_t new_transpose_closure_4(void);

void release_transpose_closure_4(transpose_funtype_1_t closure, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

transpose_closure_4_t copy_transpose_closure_4(transpose_closure_4_t x);




struct transpose_closure_5_s;
        typedef struct transpose_closure_5_s * transpose_closure_5_t;

struct transpose_closure_5_s {uint32_t count;
         transpose_funtype_0_ftbl_t ftbl;
         transpose_funtype_0_htbl_t htbl;
        type_actual_t fvar_1;
        type_actual_t fvar_2;
        transpose__T2_t fvar_3;
        type_actual_t fvar_4;
        transpose_funtype_3_t fvar_5; type_actual_t transpose__T1; type_actual_t transpose__T2; type_actual_t transpose__T3;};

transpose__T3_t f_transpose_closure_5(struct transpose_closure_5_s * closure, transpose__T1_t bvar);

transpose__T3_t m_transpose_closure_5(struct transpose_closure_5_s * closure, transpose__T1_t bvar);

extern transpose__T3_t h_transpose_closure_5(transpose__T1_t ivar_10, type_actual_t transpose__T3, type_actual_t transpose__T1, transpose__T2_t ivar_7, type_actual_t transpose__T2, transpose_funtype_3_t ivar_1);

transpose_closure_5_t new_transpose_closure_5(void);

void release_transpose_closure_5(transpose_funtype_0_t closure, type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3);

transpose_closure_5_t copy_transpose_closure_5(transpose_closure_5_t x);



extern transpose_funtype_1_t transpose__transpose(type_actual_t transpose__T1, type_actual_t transpose__T2, type_actual_t transpose__T3, transpose_funtype_3_t ivar_1);
#endif