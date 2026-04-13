//Code generated using pvs2ir
#ifndef _exp2_h 
#define _exp2_h

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

#include "modulo_arithmetic_c.h"

//cc -O3 -Wall -o exp2 -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include exp2_c.c <your main>.c  -lgmp -lpvs-prelude 

extern mpz_ptr_t exp2__exp2(mpz_ptr_t ivar_1);

extern mpz_ptr_t exp2__log2(mpz_ptr_t ivar_1);
#endif