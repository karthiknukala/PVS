//Code generated using pvs2ir2c
#include "lex2_c.h"

ordstruct_adt__ordstruct_adt_t lex2__lex2(mpz_ptr_t ivar_1, mpz_ptr_t ivar_2){
        ordstruct_adt__ordstruct_adt_t  result;

        bool_t ivar_3;
        uint8_t ivar_5;
        ivar_5 = (uint8_t)0;
        int64_t tmp3842 = mpz_cmp_ui(ivar_1, ivar_5);
        ivar_3 = (tmp3842 == 0);
        if (ivar_3){
             bool_t ivar_7;
             uint8_t ivar_9;
             ivar_9 = (uint8_t)0;
             int64_t tmp3843 = mpz_cmp_ui(ivar_2, ivar_9);
             ivar_7 = (tmp3843 == 0);
             if (ivar_7){
           result = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (result != NULL) result->count++;
             } else {
           ordstruct_adt__ordstruct_adt_t ivar_16;
           ivar_16 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_16 != NULL) ivar_16->count++;
           ordstruct_adt__ordstruct_adt_t ivar_17;
           ivar_17 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_17 != NULL) ivar_17->count++;
           result = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__add((mpz_ptr_t)ivar_2, (ordstruct_adt__ordstruct_adt_t)ivar_16, (ordstruct_adt__ordstruct_adt_t)ivar_17);};
        } else {
             bool_t ivar_18;
             uint8_t ivar_20;
             ivar_20 = (uint8_t)0;
             int64_t tmp3844 = mpz_cmp_ui(ivar_2, ivar_20);
             ivar_18 = (tmp3844 == 0);
             if (ivar_18){
           ordstruct_adt__ordstruct_adt_t ivar_36;
           uint8_t ivar_33;
           ivar_33 = (uint8_t)1;
           mpz_ptr_t ivar_29;
           //copying to mpz from uint8;
           mpz_mk_set_ui(ivar_29, ivar_33);
           ordstruct_adt__ordstruct_adt_t ivar_30;
           ivar_30 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_30 != NULL) ivar_30->count++;
           ordstruct_adt__ordstruct_adt_t ivar_31;
           ivar_31 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_31 != NULL) ivar_31->count++;
           ivar_36 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__add((mpz_ptr_t)ivar_29, (ordstruct_adt__ordstruct_adt_t)ivar_30, (ordstruct_adt__ordstruct_adt_t)ivar_31);
           ordstruct_adt__ordstruct_adt_t ivar_37;
           ivar_37 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_37 != NULL) ivar_37->count++;
           result = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__add((mpz_ptr_t)ivar_1, (ordstruct_adt__ordstruct_adt_t)ivar_36, (ordstruct_adt__ordstruct_adt_t)ivar_37);
             } else {
           ordstruct_adt__ordstruct_adt_t ivar_59;
           uint8_t ivar_49;
           ivar_49 = (uint8_t)1;
           mpz_ptr_t ivar_45;
           //copying to mpz from uint8;
           mpz_mk_set_ui(ivar_45, ivar_49);
           ordstruct_adt__ordstruct_adt_t ivar_46;
           ivar_46 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_46 != NULL) ivar_46->count++;
           ordstruct_adt__ordstruct_adt_t ivar_47;
           ivar_47 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_47 != NULL) ivar_47->count++;
           ivar_59 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__add((mpz_ptr_t)ivar_45, (ordstruct_adt__ordstruct_adt_t)ivar_46, (ordstruct_adt__ordstruct_adt_t)ivar_47);
           ordstruct_adt__ordstruct_adt_t ivar_60;
           ordstruct_adt__ordstruct_adt_t ivar_55;
           ivar_55 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_55 != NULL) ivar_55->count++;
           ordstruct_adt__ordstruct_adt_t ivar_56;
           ivar_56 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__zero();
           if (ivar_56 != NULL) ivar_56->count++;
           ivar_60 = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__add((mpz_ptr_t)ivar_2, (ordstruct_adt__ordstruct_adt_t)ivar_55, (ordstruct_adt__ordstruct_adt_t)ivar_56);
           result = (ordstruct_adt__ordstruct_adt_t)con_ordstruct_adt__add((mpz_ptr_t)ivar_1, (ordstruct_adt__ordstruct_adt_t)ivar_59, (ordstruct_adt__ordstruct_adt_t)ivar_60);};};
        
        result->count++;
        return result;
}