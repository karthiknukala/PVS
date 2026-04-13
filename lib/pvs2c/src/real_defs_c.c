//Code generated using pvs2ir2c
#include "real_defs_c.h"

mpz_ptr_t real_defs__sgn(mpq_ptr_t ivar_1){
         mpz_ptr_t  result;

        bool_t ivar_2;
        mpq_ptr_t ivar_3;
        //copying to mpq from mpq;
        mpq_mk_set(ivar_3, ivar_1);
        uint8_t ivar_4;
        ivar_4 = (uint8_t)0;
        int64_t tmp3662 = mpq_cmp_ui(ivar_3, ivar_4, 1);
        ivar_2 = (tmp3662 >= 0);
        if (ivar_2){
             result = safe_malloc(sizeof(mpz_t));
             mpz_init(result);
             mpz_mk_set_ui(result, 1);
        } else {
             result = safe_malloc(sizeof(mpz_t));
             mpz_init(result);
             mpz_mk_set_si(result, -1);};
        
        
        return result;
}

mpq_ptr_t real_defs__abs(mpq_ptr_t ivar_1){
         mpq_ptr_t  result;

        bool_t ivar_2;
        mpq_ptr_t ivar_3;
        //copying to mpq from mpq;
        mpq_mk_set(ivar_3, ivar_1);
        uint8_t ivar_4;
        ivar_4 = (uint8_t)0;
        int64_t tmp3663 = mpq_cmp_ui(ivar_3, ivar_4, 1);
        ivar_2 = (tmp3663 < 0);
        if (ivar_2){
             mpq_ptr_t ivar_6;
             //copying to mpq from mpq;
             mpq_mk_set(ivar_6, ivar_1);
             mpq_mk_set(result, ivar_6);
             mpq_neg(result, result);
        } else {
             //copying to mpq from mpq;
             mpq_mk_set(result, ivar_1);};
        
        
        return result;
}

mpq_ptr_t real_defs__max(mpq_ptr_t ivar_1, mpq_ptr_t ivar_2){
         mpq_ptr_t  result;

        bool_t ivar_3;
        mpq_ptr_t ivar_4;
        //copying to mpq from mpq;
        mpq_mk_set(ivar_4, ivar_1);
        mpq_ptr_t ivar_5;
        //copying to mpq from mpq;
        mpq_mk_set(ivar_5, ivar_2);
        int64_t tmp3664 = mpq_cmp(ivar_4, ivar_5);
        ivar_3 = (tmp3664 < 0);
        if (ivar_3){
             //copying to mpq from mpq;
             mpq_mk_set(result, ivar_2);
        } else {
             //copying to mpq from mpq;
             mpq_mk_set(result, ivar_1);};
        
        
        return result;
}

mpq_ptr_t real_defs__min(mpq_ptr_t ivar_1, mpq_ptr_t ivar_2){
         mpq_ptr_t  result;

        bool_t ivar_3;
        mpq_ptr_t ivar_4;
        //copying to mpq from mpq;
        mpq_mk_set(ivar_4, ivar_1);
        mpq_ptr_t ivar_5;
        //copying to mpq from mpq;
        mpq_mk_set(ivar_5, ivar_2);
        int64_t tmp3665 = mpq_cmp(ivar_4, ivar_5);
        ivar_3 = (tmp3665 > 0);
        if (ivar_3){
             //copying to mpq from mpq;
             mpq_mk_set(result, ivar_2);
        } else {
             //copying to mpq from mpq;
             mpq_mk_set(result, ivar_1);};
        
        
        return result;
}