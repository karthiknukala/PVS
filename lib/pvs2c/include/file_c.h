//Code generated using pvs2ir
#ifndef _file_h 
#define _file_h

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

#include "bytestrings_c.h"

#include "ordstruct_adt_c.h"

#include "ordinals_c.h"

//cc -O3 -Wall -o file -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include file_c.c <your main>.c  -lgmp -lpvs-prelude 

typedef file_t file__file_t;


//lifted_file

struct file__lifted_file_adt_s {
         uint32_t count; 
        uint8_t file__lifted_file_adt_index;};
typedef struct file__lifted_file_adt_s * file__lifted_file_adt_t;

extern file__lifted_file_adt_t new_file__lifted_file_adt(void);

extern void release_file__lifted_file_adt(file__lifted_file_adt_t x);

extern file__lifted_file_adt_t copy_file__lifted_file_adt(file__lifted_file_adt_t x);

extern bool_t equal_file__lifted_file_adt(file__lifted_file_adt_t x, file__lifted_file_adt_t y);
extern char * json_file__lifted_file_adt(file__lifted_file_adt_t x);

typedef struct actual_file__lifted_file_adt_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_file__lifted_file_adt_t;
extern void release_file__lifted_file_adt_ptr(pointer_t x, type_actual_t file__lifted_file_adt);

extern bool_t equal_file__lifted_file_adt_ptr(pointer_t x, pointer_t y, actual_file__lifted_file_adt_t T);

extern char * json_file__lifted_file_adt_ptr(pointer_t x,  actual_file__lifted_file_adt_t T);

actual_file__lifted_file_adt_t actual_file__lifted_file_adt(void);

 

extern file__lifted_file_adt_t update_file__lifted_file_adt_file__lifted_file_adt_index(file__lifted_file_adt_t x, uint8_t v);


//pass

struct file__pass_s {
        uint32_t count; 
        uint8_t file__lifted_file_adt_index;
        file__file_t contents;};
typedef struct file__pass_s * file__pass_t;

extern file__pass_t new_file__pass(void);

extern void release_file__pass(file__pass_t x);

extern file__pass_t copy_file__pass(file__pass_t x);

extern bool_t equal_file__pass(file__pass_t x, file__pass_t y);
extern char * json_file__pass(file__pass_t x);

typedef struct actual_file__pass_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_file__pass_t;
extern void release_file__pass_ptr(pointer_t x, type_actual_t file__pass);

extern bool_t equal_file__pass_ptr(pointer_t x, pointer_t y, actual_file__pass_t T);

extern char * json_file__pass_ptr(pointer_t x,  actual_file__pass_t T);

actual_file__pass_t actual_file__pass(void);

 

extern file__pass_t update_file__pass_file__lifted_file_adt_index(file__pass_t x, uint8_t v);

extern file__pass_t update_file__pass_contents(file__pass_t x, file__file_t v);


//reduce_nat

struct file_funtype_3_s;
        typedef struct file_funtype_3_s * file_funtype_3_t;

struct file_funtype_3_ftbl_s {mpz_ptr_t (* fptr)(struct file_funtype_3_s *, file__lifted_file_adt_t);
        mpz_ptr_t (* mptr)(struct file_funtype_3_s *, file__lifted_file_adt_t);
        void (* rptr)(struct file_funtype_3_s *);
        struct file_funtype_3_s * (* cptr)(struct file_funtype_3_s *);};
typedef struct file_funtype_3_ftbl_s * file_funtype_3_ftbl_t;

struct file_funtype_3_hashentry_s {uint32_t keyhash; file__lifted_file_adt_t key; mpz_t value;}; 
typedef struct file_funtype_3_hashentry_s file_funtype_3_hashentry_t;

struct file_funtype_3_htbl_s {uint32_t size; uint32_t num_entries; file_funtype_3_hashentry_t * data;}; 
typedef struct file_funtype_3_htbl_s * file_funtype_3_htbl_t;

struct file_funtype_3_s {uint32_t count;
        file_funtype_3_ftbl_t ftbl;
        file_funtype_3_htbl_t htbl;};
typedef struct file_funtype_3_s * file_funtype_3_t;

extern void release_file_funtype_3(file_funtype_3_t x);

extern file_funtype_3_t copy_file_funtype_3(file_funtype_3_t x);

extern bool_t equal_file_funtype_3(file_funtype_3_t x, file_funtype_3_t y);

extern char* json_file_funtype_3(file_funtype_3_t x);


//reduce_nat

struct file_funtype_4_s;
        typedef struct file_funtype_4_s * file_funtype_4_t;

struct file_funtype_4_ftbl_s {mpz_ptr_t (* fptr)(struct file_funtype_4_s *, file__file_t);
        mpz_ptr_t (* mptr)(struct file_funtype_4_s *, file__file_t);
        void (* rptr)(struct file_funtype_4_s *);
        struct file_funtype_4_s * (* cptr)(struct file_funtype_4_s *);};
typedef struct file_funtype_4_ftbl_s * file_funtype_4_ftbl_t;

struct file_funtype_4_hashentry_s {uint32_t keyhash; file__file_t key; mpz_t value;}; 
typedef struct file_funtype_4_hashentry_s file_funtype_4_hashentry_t;

struct file_funtype_4_htbl_s {uint32_t size; uint32_t num_entries; file_funtype_4_hashentry_t * data;}; 
typedef struct file_funtype_4_htbl_s * file_funtype_4_htbl_t;

struct file_funtype_4_s {uint32_t count;
        file_funtype_4_ftbl_t ftbl;
        file_funtype_4_htbl_t htbl;};
typedef struct file_funtype_4_s * file_funtype_4_t;

extern void release_file_funtype_4(file_funtype_4_t x);

extern file_funtype_4_t copy_file_funtype_4(file_funtype_4_t x);

extern bool_t equal_file_funtype_4(file_funtype_4_t x, file_funtype_4_t y);

extern char* json_file_funtype_4(file_funtype_4_t x);




struct file_closure_5_s;
        typedef struct file_closure_5_s * file_closure_5_t;

struct file_closure_5_s {uint32_t count;
         file_funtype_3_ftbl_t ftbl;
         file_funtype_3_htbl_t htbl;
        file_funtype_4_t fvar_1;
        mpz_t fvar_2;};

mpz_ptr_t f_file_closure_5(struct file_closure_5_s * closure, file__lifted_file_adt_t bvar);

mpz_ptr_t m_file_closure_5(struct file_closure_5_s * closure, file__lifted_file_adt_t bvar);

extern mpz_ptr_t h_file_closure_5(file__lifted_file_adt_t ivar_6, file_funtype_4_t ivar_2, mpz_ptr_t ivar_1);

file_closure_5_t new_file_closure_5(void);

void release_file_closure_5(file_funtype_3_t closure);

file_closure_5_t copy_file_closure_5(file_closure_5_t x);


//REDUCE_nat

struct file_record_6_s {
        uint32_t count; 
        file__file_t project_1;
        file__lifted_file_adt_t project_2;};
typedef struct file_record_6_s * file_record_6_t;

extern file_record_6_t new_file_record_6(void);

extern void release_file_record_6(file_record_6_t x);

extern file_record_6_t copy_file_record_6(file_record_6_t x);

extern bool_t equal_file_record_6(file_record_6_t x, file_record_6_t y);
extern char * json_file_record_6(file_record_6_t x);

typedef struct actual_file_record_6_s {equal_ptr_t equal_ptr; release_ptr_t release_ptr; json_ptr_t json_ptr;} * actual_file_record_6_t;
extern void release_file_record_6_ptr(pointer_t x, type_actual_t file_record_6);

extern bool_t equal_file_record_6_ptr(pointer_t x, pointer_t y, actual_file_record_6_t T);

extern char * json_file_record_6_ptr(pointer_t x,  actual_file_record_6_t T);

actual_file_record_6_t actual_file_record_6(void);

 

extern file_record_6_t update_file_record_6_project_1(file_record_6_t x, file__file_t v);

extern file_record_6_t update_file_record_6_project_2(file_record_6_t x, file__lifted_file_adt_t v);


//REDUCE_nat

struct file_funtype_7_s;
        typedef struct file_funtype_7_s * file_funtype_7_t;

struct file_funtype_7_ftbl_s {mpz_ptr_t (* fptr)(struct file_funtype_7_s *, file_record_6_t);
        mpz_ptr_t (* mptr)(struct file_funtype_7_s *, file__file_t, file__lifted_file_adt_t);
        void (* rptr)(struct file_funtype_7_s *);
        struct file_funtype_7_s * (* cptr)(struct file_funtype_7_s *);};
typedef struct file_funtype_7_ftbl_s * file_funtype_7_ftbl_t;

struct file_funtype_7_hashentry_s {uint32_t keyhash; file_record_6_t key; mpz_t value;}; 
typedef struct file_funtype_7_hashentry_s file_funtype_7_hashentry_t;

struct file_funtype_7_htbl_s {uint32_t size; uint32_t num_entries; file_funtype_7_hashentry_t * data;}; 
typedef struct file_funtype_7_htbl_s * file_funtype_7_htbl_t;

struct file_funtype_7_s {uint32_t count;
        file_funtype_7_ftbl_t ftbl;
        file_funtype_7_htbl_t htbl;};
typedef struct file_funtype_7_s * file_funtype_7_t;

extern void release_file_funtype_7(file_funtype_7_t x);

extern file_funtype_7_t copy_file_funtype_7(file_funtype_7_t x);

extern bool_t equal_file_funtype_7(file_funtype_7_t x, file_funtype_7_t y);

extern char* json_file_funtype_7(file_funtype_7_t x);




struct file_closure_8_s;
        typedef struct file_closure_8_s * file_closure_8_t;

struct file_closure_8_s {uint32_t count;
         file_funtype_3_ftbl_t ftbl;
         file_funtype_3_htbl_t htbl;
        file_funtype_3_t fvar_1;
        file_funtype_7_t fvar_2;};

mpz_ptr_t f_file_closure_8(struct file_closure_8_s * closure, file__lifted_file_adt_t bvar);

mpz_ptr_t m_file_closure_8(struct file_closure_8_s * closure, file__lifted_file_adt_t bvar);

extern mpz_ptr_t h_file_closure_8(file__lifted_file_adt_t ivar_7, file_funtype_3_t ivar_1, file_funtype_7_t ivar_3);

file_closure_8_t new_file_closure_8(void);

void release_file_closure_8(file_funtype_3_t closure);

file_closure_8_t copy_file_closure_8(file_closure_8_t x);


//reduce_ordinal

struct file_funtype_9_s;
        typedef struct file_funtype_9_s * file_funtype_9_t;

struct file_funtype_9_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct file_funtype_9_s *, file__lifted_file_adt_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct file_funtype_9_s *, file__lifted_file_adt_t);
        void (* rptr)(struct file_funtype_9_s *);
        struct file_funtype_9_s * (* cptr)(struct file_funtype_9_s *);};
typedef struct file_funtype_9_ftbl_s * file_funtype_9_ftbl_t;

struct file_funtype_9_hashentry_s {uint32_t keyhash; file__lifted_file_adt_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct file_funtype_9_hashentry_s file_funtype_9_hashentry_t;

struct file_funtype_9_htbl_s {uint32_t size; uint32_t num_entries; file_funtype_9_hashentry_t * data;}; 
typedef struct file_funtype_9_htbl_s * file_funtype_9_htbl_t;

struct file_funtype_9_s {uint32_t count;
        file_funtype_9_ftbl_t ftbl;
        file_funtype_9_htbl_t htbl;};
typedef struct file_funtype_9_s * file_funtype_9_t;

extern void release_file_funtype_9(file_funtype_9_t x);

extern file_funtype_9_t copy_file_funtype_9(file_funtype_9_t x);

extern bool_t equal_file_funtype_9(file_funtype_9_t x, file_funtype_9_t y);

extern char* json_file_funtype_9(file_funtype_9_t x);


//reduce_ordinal

struct file_funtype_10_s;
        typedef struct file_funtype_10_s * file_funtype_10_t;

struct file_funtype_10_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct file_funtype_10_s *, file__file_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct file_funtype_10_s *, file__file_t);
        void (* rptr)(struct file_funtype_10_s *);
        struct file_funtype_10_s * (* cptr)(struct file_funtype_10_s *);};
typedef struct file_funtype_10_ftbl_s * file_funtype_10_ftbl_t;

struct file_funtype_10_hashentry_s {uint32_t keyhash; file__file_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct file_funtype_10_hashentry_s file_funtype_10_hashentry_t;

struct file_funtype_10_htbl_s {uint32_t size; uint32_t num_entries; file_funtype_10_hashentry_t * data;}; 
typedef struct file_funtype_10_htbl_s * file_funtype_10_htbl_t;

struct file_funtype_10_s {uint32_t count;
        file_funtype_10_ftbl_t ftbl;
        file_funtype_10_htbl_t htbl;};
typedef struct file_funtype_10_s * file_funtype_10_t;

extern void release_file_funtype_10(file_funtype_10_t x);

extern file_funtype_10_t copy_file_funtype_10(file_funtype_10_t x);

extern bool_t equal_file_funtype_10(file_funtype_10_t x, file_funtype_10_t y);

extern char* json_file_funtype_10(file_funtype_10_t x);




struct file_closure_11_s;
        typedef struct file_closure_11_s * file_closure_11_t;

struct file_closure_11_s {uint32_t count;
         file_funtype_9_ftbl_t ftbl;
         file_funtype_9_htbl_t htbl;
        file_funtype_10_t fvar_1;
        ordstruct_adt__ordstruct_adt_t fvar_2;};

ordstruct_adt__ordstruct_adt_t f_file_closure_11(struct file_closure_11_s * closure, file__lifted_file_adt_t bvar);

ordstruct_adt__ordstruct_adt_t m_file_closure_11(struct file_closure_11_s * closure, file__lifted_file_adt_t bvar);

extern ordstruct_adt__ordstruct_adt_t h_file_closure_11(file__lifted_file_adt_t ivar_6, file_funtype_10_t ivar_2, ordstruct_adt__ordstruct_adt_t ivar_1);

file_closure_11_t new_file_closure_11(void);

void release_file_closure_11(file_funtype_9_t closure);

file_closure_11_t copy_file_closure_11(file_closure_11_t x);


//REDUCE_ordinal

struct file_funtype_12_s;
        typedef struct file_funtype_12_s * file_funtype_12_t;

struct file_funtype_12_ftbl_s {ordstruct_adt__ordstruct_adt_t (* fptr)(struct file_funtype_12_s *, file_record_6_t);
        ordstruct_adt__ordstruct_adt_t (* mptr)(struct file_funtype_12_s *, file__file_t, file__lifted_file_adt_t);
        void (* rptr)(struct file_funtype_12_s *);
        struct file_funtype_12_s * (* cptr)(struct file_funtype_12_s *);};
typedef struct file_funtype_12_ftbl_s * file_funtype_12_ftbl_t;

struct file_funtype_12_hashentry_s {uint32_t keyhash; file_record_6_t key; ordstruct_adt__ordstruct_adt_t value;}; 
typedef struct file_funtype_12_hashentry_s file_funtype_12_hashentry_t;

struct file_funtype_12_htbl_s {uint32_t size; uint32_t num_entries; file_funtype_12_hashentry_t * data;}; 
typedef struct file_funtype_12_htbl_s * file_funtype_12_htbl_t;

struct file_funtype_12_s {uint32_t count;
        file_funtype_12_ftbl_t ftbl;
        file_funtype_12_htbl_t htbl;};
typedef struct file_funtype_12_s * file_funtype_12_t;

extern void release_file_funtype_12(file_funtype_12_t x);

extern file_funtype_12_t copy_file_funtype_12(file_funtype_12_t x);

extern bool_t equal_file_funtype_12(file_funtype_12_t x, file_funtype_12_t y);

extern char* json_file_funtype_12(file_funtype_12_t x);




struct file_closure_13_s;
        typedef struct file_closure_13_s * file_closure_13_t;

struct file_closure_13_s {uint32_t count;
         file_funtype_9_ftbl_t ftbl;
         file_funtype_9_htbl_t htbl;
        file_funtype_9_t fvar_1;
        file_funtype_12_t fvar_2;};

ordstruct_adt__ordstruct_adt_t f_file_closure_13(struct file_closure_13_s * closure, file__lifted_file_adt_t bvar);

ordstruct_adt__ordstruct_adt_t m_file_closure_13(struct file_closure_13_s * closure, file__lifted_file_adt_t bvar);

extern ordstruct_adt__ordstruct_adt_t h_file_closure_13(file__lifted_file_adt_t ivar_7, file_funtype_9_t ivar_1, file_funtype_12_t ivar_3);

file_closure_13_t new_file_closure_13(void);

void release_file_closure_13(file_funtype_9_t closure);

file_closure_13_t copy_file_closure_13(file_closure_13_t x);



extern bool_t rec_file__failp(file__lifted_file_adt_t ivar_1);

extern bool_t rec_file__passp(file__lifted_file_adt_t ivar_1);

extern file__pass_t update_file__lifted_file_adt_contents(file__lifted_file_adt_t ivar_1, file__file_t ivar_3);

extern file__file_t acc_file__lifted_file_adt_contents(file__lifted_file_adt_t ivar_1);

extern file__lifted_file_adt_t con_file__fail(void);

extern file__lifted_file_adt_t con_file__pass(file__file_t ivar_2);

extern uint8_t file__ord(file__lifted_file_adt_t ivar_1);

extern bool_t file__subterm(file__lifted_file_adt_t ivar_1, file__lifted_file_adt_t ivar_2);

extern bool_t file__doublelessp(file__lifted_file_adt_t ivar_1, file__lifted_file_adt_t ivar_2);

extern file_funtype_3_t file__reduce_nat(mpz_ptr_t ivar_1, file_funtype_4_t ivar_2);

extern file_funtype_3_t file__REDUCE_nat(file_funtype_3_t ivar_1, file_funtype_7_t ivar_3);

extern file_funtype_9_t file__reduce_ordinal(ordstruct_adt__ordstruct_adt_t ivar_1, file_funtype_10_t ivar_2);

extern file_funtype_9_t file__REDUCE_ordinal(file_funtype_9_t ivar_1, file_funtype_12_t ivar_3);

bool_t file__openp(file__file_t f);

bytestrings__bytestring_t file__name(file__file_t f);

uint32_t file__file_size(file__file_t f);

file__lifted_file_adt_t file__open(bytestrings__bytestring_t name);

file__lifted_file_adt_t file__create(bytestrings__bytestring_t name);

file__lifted_file_adt_t file__setbyte(file__file_t f, uint32_t i, uint8_t b);

file__lifted_file_adt_t file__append(file__file_t f, bytestrings__bytestring_t b);

uint8_t file__getbyte(file__file_t f, uint32_t i);

bytestrings__bytestring_t file__getbytestring(file__file_t f, uint32_t i, uint32_t size);

bytestrings__bytestring_t file__printc(bytestrings__bytestring_t b);

bytestrings__bytestring_t file__printh(bytestrings__bytestring_t b);
#endif