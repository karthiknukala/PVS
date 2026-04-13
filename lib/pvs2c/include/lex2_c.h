//Code generated using pvs2ir
#ifndef _lex2_h 
#define _lex2_h

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

#include "ordinals_c.h"

#include "ordstruct_adt_c.h"

//cc -O3 -Wall -o lex2 -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include lex2_c.c <your main>.c  -lgmp -lpvs-prelude 

extern ordstruct_adt__ordstruct_adt_t lex2__lex2(mpz_ptr_t ivar_1, mpz_ptr_t ivar_2);
#endif