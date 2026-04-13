//Code generated using pvs2ir2c
#include "exp2_c.h"

mpz_ptr_t exp2__exp2(mpz_ptr_t ivar_1){
         mpz_ptr_t  result;

        bool_t ivar_2;
        uint8_t ivar_4;
        ivar_4 = (uint8_t)0;
        int64_t tmp3675 = mpz_cmp_ui(ivar_1, ivar_4);
        ivar_2 = (tmp3675 == 0);
        if (ivar_2){
             result = safe_malloc(sizeof(mpz_t));
             mpz_init(result);
             mpz_mk_set_ui(result, 1);
        } else {
             uint8_t ivar_6;
             ivar_6 = (uint8_t)2;
             mpz_ptr_t ivar_7;
             mpz_ptr_t ivar_13;
             uint8_t ivar_10;
             ivar_10 = (uint8_t)1;
             mpz_mk_sub_ui(ivar_13, ivar_1, (uint64_t)ivar_10);
             ivar_7 = (mpz_ptr_t)exp2__exp2(ivar_13);
             mpz_mk_mul_ui(result, ivar_7, (uint64_t)ivar_6);};
        
        
        return result;
}

mpz_ptr_t exp2__log2(mpz_ptr_t ivar_1){
         mpz_ptr_t  result;

        bool_t ivar_2;
        uint8_t ivar_4;
        ivar_4 = (uint8_t)0;
        int64_t tmp3676 = mpz_cmp_ui(ivar_1, ivar_4);
        ivar_2 = (tmp3676 == 0);
        if (ivar_2){
             result = safe_malloc(sizeof(mpz_t));
             mpz_init(result);
             mpz_mk_set_ui(result, 0);
        } else {
             mpz_ptr_t ivar_6;
             mpz_ptr_t ivar_13;
             uint8_t ivar_10;
             ivar_10 = (uint8_t)2;
             mpz_mk_fdiv_q_ui(ivar_13, ivar_1, ivar_10);
             ivar_6 = (mpz_ptr_t)exp2__log2(ivar_13);
             uint8_t ivar_7;
             ivar_7 = (uint8_t)1;
             mpz_mk_set_ui(result, (uint64_t)ivar_7);
             mpz_add(result, result, ivar_6);};
        
        
        return result;
}