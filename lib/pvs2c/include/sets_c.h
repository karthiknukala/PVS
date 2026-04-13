//Code generated using pvs2ir
#ifndef _sets_h 
#define _sets_h

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

//cc -O3 -Wall -o sets -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include sets_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t sets__T_t;
//set

struct sets__set_s;
        typedef struct sets__set_s * sets__set_t;

struct sets__set_ftbl_s {bool_t (* fptr)(struct sets__set_s *, sets__T_t);
        bool_t (* mptr)(struct sets__set_s *, sets__T_t);
        void (* rptr)(struct sets__set_s *);
        struct sets__set_s * (* cptr)(struct sets__set_s *);};
typedef struct sets__set_ftbl_s * sets__set_ftbl_t;

struct sets__set_hashentry_s {uint32_t keyhash; sets__T_t key; bool_t value;}; 
typedef struct sets__set_hashentry_s sets__set_hashentry_t;

struct sets__set_htbl_s {uint32_t size; uint32_t num_entries; sets__set_hashentry_t * data;}; 
typedef struct sets__set_htbl_s * sets__set_htbl_t;

struct sets__set_s {uint32_t count;
        sets__set_ftbl_t ftbl;
        sets__set_htbl_t htbl;};
typedef struct sets__set_s * sets__set_t;

extern void release_sets__set(sets__set_t x, type_actual_t sets__T);

extern sets__set_t copy_sets__set(sets__set_t x);

extern bool_t equal_sets__set(sets__set_t x, sets__set_t y, type_actual_t sets__T);

extern char* json_sets__set(sets__set_t x, type_actual_t sets__T);




struct sets_closure_1_s;
        typedef struct sets_closure_1_s * sets_closure_1_t;

struct sets_closure_1_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        type_actual_t fvar_1; type_actual_t sets__T;};

bool_t f_sets_closure_1(struct sets_closure_1_s * closure, sets__T_t bvar);

bool_t m_sets_closure_1(struct sets_closure_1_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_1(sets__T_t ivar_7, type_actual_t sets__T);

sets_closure_1_t new_sets_closure_1(void);

void release_sets_closure_1(sets__set_t closure, type_actual_t sets__T);

sets_closure_1_t copy_sets_closure_1(sets_closure_1_t x);




struct sets_closure_2_s;
        typedef struct sets_closure_2_s * sets_closure_2_t;

struct sets_closure_2_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        type_actual_t fvar_1; type_actual_t sets__T;};

bool_t f_sets_closure_2(struct sets_closure_2_s * closure, sets__T_t bvar);

bool_t m_sets_closure_2(struct sets_closure_2_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_2(sets__T_t ivar_12, type_actual_t sets__T);

sets_closure_2_t new_sets_closure_2(void);

void release_sets_closure_2(sets__set_t closure, type_actual_t sets__T);

sets_closure_2_t copy_sets_closure_2(sets_closure_2_t x);




struct sets_closure_3_s;
        typedef struct sets_closure_3_s * sets_closure_3_t;

struct sets_closure_3_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__set_t fvar_1;
        sets__set_t fvar_2;
        type_actual_t fvar_3; type_actual_t sets__T;};

bool_t f_sets_closure_3(struct sets_closure_3_s * closure, sets__T_t bvar);

bool_t m_sets_closure_3(struct sets_closure_3_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_3(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T);

sets_closure_3_t new_sets_closure_3(void);

void release_sets_closure_3(sets__set_t closure, type_actual_t sets__T);

sets_closure_3_t copy_sets_closure_3(sets_closure_3_t x);




struct sets_closure_4_s;
        typedef struct sets_closure_4_s * sets_closure_4_t;

struct sets_closure_4_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__set_t fvar_1;
        sets__set_t fvar_2;
        type_actual_t fvar_3; type_actual_t sets__T;};

bool_t f_sets_closure_4(struct sets_closure_4_s * closure, sets__T_t bvar);

bool_t m_sets_closure_4(struct sets_closure_4_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_4(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T);

sets_closure_4_t new_sets_closure_4(void);

void release_sets_closure_4(sets__set_t closure, type_actual_t sets__T);

sets_closure_4_t copy_sets_closure_4(sets_closure_4_t x);




struct sets_closure_5_s;
        typedef struct sets_closure_5_s * sets_closure_5_t;

struct sets_closure_5_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__set_t fvar_1;
        sets__set_t fvar_2;
        type_actual_t fvar_3; type_actual_t sets__T;};

bool_t f_sets_closure_5(struct sets_closure_5_s * closure, sets__T_t bvar);

bool_t m_sets_closure_5(struct sets_closure_5_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_5(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T);

sets_closure_5_t new_sets_closure_5(void);

void release_sets_closure_5(sets__set_t closure, type_actual_t sets__T);

sets_closure_5_t copy_sets_closure_5(sets_closure_5_t x);




struct sets_closure_6_s;
        typedef struct sets_closure_6_s * sets_closure_6_t;

struct sets_closure_6_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__set_t fvar_1;
        sets__set_t fvar_2;
        type_actual_t fvar_3; type_actual_t sets__T;};

bool_t f_sets_closure_6(struct sets_closure_6_s * closure, sets__T_t bvar);

bool_t m_sets_closure_6(struct sets_closure_6_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_6(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T);

sets_closure_6_t new_sets_closure_6(void);

void release_sets_closure_6(sets__set_t closure, type_actual_t sets__T);

sets_closure_6_t copy_sets_closure_6(sets_closure_6_t x);




struct sets_closure_7_s;
        typedef struct sets_closure_7_s * sets_closure_7_t;

struct sets_closure_7_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__set_t fvar_1;
        type_actual_t fvar_2; type_actual_t sets__T;};

bool_t f_sets_closure_7(struct sets_closure_7_s * closure, sets__T_t bvar);

bool_t m_sets_closure_7(struct sets_closure_7_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_7(sets__T_t ivar_3, sets__set_t ivar_1, type_actual_t sets__T);

sets_closure_7_t new_sets_closure_7(void);

void release_sets_closure_7(sets__set_t closure, type_actual_t sets__T);

sets_closure_7_t copy_sets_closure_7(sets_closure_7_t x);




struct sets_closure_8_s;
        typedef struct sets_closure_8_s * sets_closure_8_t;

struct sets_closure_8_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__set_t fvar_1;
        sets__set_t fvar_2;
        type_actual_t fvar_3; type_actual_t sets__T;};

bool_t f_sets_closure_8(struct sets_closure_8_s * closure, sets__T_t bvar);

bool_t m_sets_closure_8(struct sets_closure_8_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_8(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T);

sets_closure_8_t new_sets_closure_8(void);

void release_sets_closure_8(sets__set_t closure, type_actual_t sets__T);

sets_closure_8_t copy_sets_closure_8(sets_closure_8_t x);




struct sets_closure_9_s;
        typedef struct sets_closure_9_s * sets_closure_9_t;

struct sets_closure_9_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__T_t fvar_1;
        type_actual_t fvar_2; type_actual_t sets__T;};

bool_t f_sets_closure_9(struct sets_closure_9_s * closure, sets__T_t bvar);

bool_t m_sets_closure_9(struct sets_closure_9_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_9(sets__T_t ivar_3, sets__T_t ivar_1, type_actual_t sets__T);

sets_closure_9_t new_sets_closure_9(void);

void release_sets_closure_9(sets__set_t closure, type_actual_t sets__T);

sets_closure_9_t copy_sets_closure_9(sets_closure_9_t x);




struct sets_closure_10_s;
        typedef struct sets_closure_10_s * sets_closure_10_t;

struct sets_closure_10_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__T_t fvar_1;
        sets__set_t fvar_2;
        type_actual_t fvar_3; type_actual_t sets__T;};

bool_t f_sets_closure_10(struct sets_closure_10_s * closure, sets__T_t bvar);

bool_t m_sets_closure_10(struct sets_closure_10_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_10(sets__T_t ivar_4, sets__T_t ivar_1, sets__set_t ivar_2, type_actual_t sets__T);

sets_closure_10_t new_sets_closure_10(void);

void release_sets_closure_10(sets__set_t closure, type_actual_t sets__T);

sets_closure_10_t copy_sets_closure_10(sets_closure_10_t x);




struct sets_closure_11_s;
        typedef struct sets_closure_11_s * sets_closure_11_t;

struct sets_closure_11_s {uint32_t count;
         sets__set_ftbl_t ftbl;
         sets__set_htbl_t htbl;
        sets__T_t fvar_1;
        sets__set_t fvar_2;
        type_actual_t fvar_3; type_actual_t sets__T;};

bool_t f_sets_closure_11(struct sets_closure_11_s * closure, sets__T_t bvar);

bool_t m_sets_closure_11(struct sets_closure_11_s * closure, sets__T_t bvar);

extern bool_t h_sets_closure_11(sets__T_t ivar_4, sets__T_t ivar_1, sets__set_t ivar_2, type_actual_t sets__T);

sets_closure_11_t new_sets_closure_11(void);

void release_sets_closure_11(sets__set_t closure, type_actual_t sets__T);

sets_closure_11_t copy_sets_closure_11(sets_closure_11_t x);


//setofsets

struct sets__setofsets_s;
        typedef struct sets__setofsets_s * sets__setofsets_t;

struct sets__setofsets_ftbl_s {bool_t (* fptr)(struct sets__setofsets_s *, sets__set_t);
        bool_t (* mptr)(struct sets__setofsets_s *, sets__set_t);
        void (* rptr)(struct sets__setofsets_s *);
        struct sets__setofsets_s * (* cptr)(struct sets__setofsets_s *);};
typedef struct sets__setofsets_ftbl_s * sets__setofsets_ftbl_t;

struct sets__setofsets_hashentry_s {uint32_t keyhash; sets__set_t key; bool_t value;}; 
typedef struct sets__setofsets_hashentry_s sets__setofsets_hashentry_t;

struct sets__setofsets_htbl_s {uint32_t size; uint32_t num_entries; sets__setofsets_hashentry_t * data;}; 
typedef struct sets__setofsets_htbl_s * sets__setofsets_htbl_t;

struct sets__setofsets_s {uint32_t count;
        sets__setofsets_ftbl_t ftbl;
        sets__setofsets_htbl_t htbl;};
typedef struct sets__setofsets_s * sets__setofsets_t;

extern void release_sets__setofsets(sets__setofsets_t x, type_actual_t sets__T);

extern sets__setofsets_t copy_sets__setofsets(sets__setofsets_t x);

extern bool_t equal_sets__setofsets(sets__setofsets_t x, sets__setofsets_t y, type_actual_t sets__T);

extern char* json_sets__setofsets(sets__setofsets_t x, type_actual_t sets__T);



extern bool_t sets__member(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2);

extern bool_t sets__in(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2);

extern bool_t sets__notin(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2);

extern bool_t sets__emptyset(type_actual_t sets__T, sets__T_t ivar_1);

extern bool_t sets___u2205_(type_actual_t sets__T, sets__T_t ivar_1);

extern bool_t sets__fullset(type_actual_t sets__T, sets__T_t ivar_1);

extern bool_t sets__nontrivialp(type_actual_t sets__T, sets__set_t ivar_1);

extern sets__set_t sets__union(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2);

extern sets__set_t sets__cup(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2);

extern sets__set_t sets__intersection(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2);

extern sets__set_t sets__cap(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2);

extern sets__set_t sets__complement(type_actual_t sets__T, sets__set_t ivar_1);

extern sets__set_t sets__difference(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2);

extern sets__set_t sets__symmetric_difference(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2);

extern sets__set_t sets__singleton(type_actual_t sets__T, sets__T_t ivar_1);

extern sets__set_t sets__add(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2);

extern sets__set_t sets__remove(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2);
#endif