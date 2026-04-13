//Code generated using pvs2ir
#ifndef _empty_bv_h 
#define _empty_bv_h

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

//cc -O3 -Wall -o empty_bv -L /Users/e35480/git/kn-pvs/lib/pvs2c/lib -I /Users/e35480/git/kn-pvs/lib/pvs2c/include empty_bv_c.c <your main>.c  -lgmp -lpvs-prelude 

extern bool_t empty_bv__empty_bv(uint8_t ivar_1);
#endif