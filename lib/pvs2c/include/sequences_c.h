//Code generated using pvs2ir
#ifndef _sequences_h 
#define _sequences_h

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

//cc -O3 -Wall -o sequences -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include sequences_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef pointer_t sequences__T_t;
//sequence

struct sequences__sequence_s;
        typedef struct sequences__sequence_s * sequences__sequence_t;

struct sequences__sequence_ftbl_s {sequences__T_t (* fptr)(struct sequences__sequence_s *, mpz_ptr_t);
        sequences__T_t (* mptr)(struct sequences__sequence_s *, mpz_ptr_t);
        void (* rptr)(struct sequences__sequence_s *);
        struct sequences__sequence_s * (* cptr)(struct sequences__sequence_s *);};
typedef struct sequences__sequence_ftbl_s * sequences__sequence_ftbl_t;

struct sequences__sequence_hashentry_s {uint32_t keyhash; mpz_ptr_t key; sequences__T_t value;}; 
typedef struct sequences__sequence_hashentry_s sequences__sequence_hashentry_t;

struct sequences__sequence_htbl_s {uint32_t size; uint32_t num_entries; sequences__sequence_hashentry_t * data;}; 
typedef struct sequences__sequence_htbl_s * sequences__sequence_htbl_t;

struct sequences__sequence_s {uint32_t count;
        sequences__sequence_ftbl_t ftbl;
        sequences__sequence_htbl_t htbl;};
typedef struct sequences__sequence_s * sequences__sequence_t;

extern void release_sequences__sequence(sequences__sequence_t x, type_actual_t sequences__T);

extern sequences__sequence_t copy_sequences__sequence(sequences__sequence_t x);

extern uint32_t lookup_sequences__sequence(sequences__sequence_htbl_t htbl, mpz_ptr_t i, uint32_t ihash);

extern sequences__sequence_t dupdate_sequences__sequence(sequences__sequence_t a, mpz_ptr_t i, sequences__T_t v, type_actual_t sequences__T);

extern sequences__sequence_t update_sequences__sequence(sequences__sequence_t a, mpz_ptr_t i, sequences__T_t v, type_actual_t sequences__T);

extern bool_t equal_sequences__sequence(sequences__sequence_t x, sequences__sequence_t y, type_actual_t sequences__T);

extern char* json_sequences__sequence(sequences__sequence_t x, type_actual_t sequences__T);




struct sequences_closure_1_s;
        typedef struct sequences_closure_1_s * sequences_closure_1_t;

struct sequences_closure_1_s {uint32_t count;
         sequences__sequence_ftbl_t ftbl;
         sequences__sequence_htbl_t htbl;
        type_actual_t fvar_1;
        sequences__sequence_t fvar_2;
        mpz_t fvar_3; type_actual_t sequences__T;};

sequences__T_t f_sequences_closure_1(struct sequences_closure_1_s * closure, mpz_ptr_t bvar);

sequences__T_t m_sequences_closure_1(struct sequences_closure_1_s * closure, mpz_ptr_t bvar);

extern sequences__T_t h_sequences_closure_1(mpz_ptr_t ivar_4, type_actual_t sequences__T, sequences__sequence_t ivar_1, mpz_ptr_t ivar_2);

sequences_closure_1_t new_sequences_closure_1(void);

void release_sequences_closure_1(sequences__sequence_t closure, type_actual_t sequences__T);

sequences_closure_1_t copy_sequences_closure_1(sequences_closure_1_t x);




struct sequences_closure_2_s;
        typedef struct sequences_closure_2_s * sequences_closure_2_t;

struct sequences_closure_2_s {uint32_t count;
         sequences__sequence_ftbl_t ftbl;
         sequences__sequence_htbl_t htbl;
        type_actual_t fvar_1;
        sequences__sequence_t fvar_2;
        mpz_t fvar_3; type_actual_t sequences__T;};

sequences__T_t f_sequences_closure_2(struct sequences_closure_2_s * closure, mpz_ptr_t bvar);

sequences__T_t m_sequences_closure_2(struct sequences_closure_2_s * closure, mpz_ptr_t bvar);

extern sequences__T_t h_sequences_closure_2(mpz_ptr_t ivar_4, type_actual_t sequences__T, sequences__sequence_t ivar_2, mpz_ptr_t ivar_1);

sequences_closure_2_t new_sequences_closure_2(void);

void release_sequences_closure_2(sequences__sequence_t closure, type_actual_t sequences__T);

sequences_closure_2_t copy_sequences_closure_2(sequences_closure_2_t x);




struct sequences_closure_3_s;
        typedef struct sequences_closure_3_s * sequences_closure_3_t;

struct sequences_closure_3_s {uint32_t count;
         sequences__sequence_ftbl_t ftbl;
         sequences__sequence_htbl_t htbl;
        type_actual_t fvar_1;
        mpz_t fvar_2;
        sequences__sequence_t fvar_3;
        sequences__T_t fvar_4; type_actual_t sequences__T;};

sequences__T_t f_sequences_closure_3(struct sequences_closure_3_s * closure, mpz_ptr_t bvar);

sequences__T_t m_sequences_closure_3(struct sequences_closure_3_s * closure, mpz_ptr_t bvar);

extern sequences__T_t h_sequences_closure_3(mpz_ptr_t ivar_5, type_actual_t sequences__T, mpz_ptr_t ivar_2, sequences__sequence_t ivar_3, sequences__T_t ivar_1);

sequences_closure_3_t new_sequences_closure_3(void);

void release_sequences_closure_3(sequences__sequence_t closure, type_actual_t sequences__T);

sequences_closure_3_t copy_sequences_closure_3(sequences_closure_3_t x);


//ascends?

struct sequences_record_4_s {
        uint32_t count; 
        sequences__T_t project_1;
        sequences__T_t project_2;};
typedef struct sequences_record_4_s * sequences_record_4_t;

extern sequences_record_4_t new_sequences_record_4(void);

extern void release_sequences_record_4(sequences_record_4_t x, type_actual_t sequences__T);

extern sequences_record_4_t copy_sequences_record_4(sequences_record_4_t x);

extern bool_t equal_sequences_record_4(sequences_record_4_t x, sequences_record_4_t y, type_actual_t sequences__T);
extern char * json_sequences_record_4(sequences_record_4_t x, type_actual_t sequences__T);

typedef struct actual_sequences_record_4_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr; type_actual_t sequences__T;} * actual_sequences_record_4_t;
extern void release_sequences_record_4_ptr(pointer_t x, type_actual_t sequences_record_4);

extern bool_t equal_sequences_record_4_ptr(pointer_t x, pointer_t y, actual_sequences_record_4_t T);

extern char * json_sequences_record_4_ptr(pointer_t x,  actual_sequences_record_4_t T);

actual_sequences_record_4_t actual_sequences_record_4(type_actual_t sequences__T);

 

extern sequences_record_4_t update_sequences_record_4_project_1(sequences_record_4_t x, sequences__T_t v, type_actual_t sequences__T);

extern sequences_record_4_t update_sequences_record_4_project_2(sequences_record_4_t x, sequences__T_t v, type_actual_t sequences__T);


//ascends?

struct sequences_funtype_5_s;
        typedef struct sequences_funtype_5_s * sequences_funtype_5_t;

struct sequences_funtype_5_ftbl_s {bool_t (* fptr)(struct sequences_funtype_5_s *, sequences_record_4_t);
        bool_t (* mptr)(struct sequences_funtype_5_s *, sequences__T_t, sequences__T_t);
        void (* rptr)(struct sequences_funtype_5_s *);
        struct sequences_funtype_5_s * (* cptr)(struct sequences_funtype_5_s *);};
typedef struct sequences_funtype_5_ftbl_s * sequences_funtype_5_ftbl_t;

struct sequences_funtype_5_hashentry_s {uint32_t keyhash; sequences_record_4_t key; bool_t value;}; 
typedef struct sequences_funtype_5_hashentry_s sequences_funtype_5_hashentry_t;

struct sequences_funtype_5_htbl_s {uint32_t size; uint32_t num_entries; sequences_funtype_5_hashentry_t * data;}; 
typedef struct sequences_funtype_5_htbl_s * sequences_funtype_5_htbl_t;

struct sequences_funtype_5_s {uint32_t count;
        sequences_funtype_5_ftbl_t ftbl;
        sequences_funtype_5_htbl_t htbl;};
typedef struct sequences_funtype_5_s * sequences_funtype_5_t;

extern void release_sequences_funtype_5(sequences_funtype_5_t x, type_actual_t sequences__T);

extern sequences_funtype_5_t copy_sequences_funtype_5(sequences_funtype_5_t x);

extern bool_t equal_sequences_funtype_5(sequences_funtype_5_t x, sequences_funtype_5_t y, type_actual_t sequences__T);

extern char* json_sequences_funtype_5(sequences_funtype_5_t x, type_actual_t sequences__T);



extern sequences__T_t sequences__nth(type_actual_t sequences__T, sequences__sequence_t ivar_1, mpz_ptr_t ivar_2);

extern sequences__sequence_t sequences__suffix(type_actual_t sequences__T, sequences__sequence_t ivar_1, mpz_ptr_t ivar_2);

extern sequences__T_t sequences__first(type_actual_t sequences__T, sequences__sequence_t ivar_1);

extern sequences__sequence_t sequences__rest(type_actual_t sequences__T, sequences__sequence_t ivar_1);

extern sequences__sequence_t sequences__delete(type_actual_t sequences__T, mpz_ptr_t ivar_1, sequences__sequence_t ivar_2);

extern sequences__sequence_t sequences__insert(type_actual_t sequences__T, sequences__T_t ivar_1, mpz_ptr_t ivar_2, sequences__sequence_t ivar_3);

extern sequences__sequence_t sequences__add(type_actual_t sequences__T, sequences__T_t ivar_1, sequences__sequence_t ivar_2);

extern bool_t sequences__ascendsp(type_actual_t sequences__T, sequences__sequence_t ivar_1, sequences_funtype_5_t ivar_2);

extern bool_t sequences__descendsp(type_actual_t sequences__T, sequences__sequence_t ivar_1, sequences_funtype_5_t ivar_2);
#endif