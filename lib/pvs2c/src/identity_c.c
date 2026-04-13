//Code generated using pvs2ir2c
#include "identity_c.h"

identity__T_t identity__I(type_actual_t identity__T, identity__T_t ivar_1){
        identity__T_t  result;

        //copying to identity__T from identity__T;
        result = (identity__T_t)ivar_1;
        identity__T->release_ptr(ivar_1, identity__T);
        
        result->count++;
        return result;
}

identity__T_t identity__id(type_actual_t identity__T, identity__T_t ivar_1){
        identity__T_t  result;

        //copying to identity__T from identity__T;
        result = (identity__T_t)ivar_1;
        identity__T->release_ptr(ivar_1, identity__T);
        
        result->count++;
        return result;
}

identity__T_t identity__identity(type_actual_t identity__T, identity__T_t ivar_1){
        identity__T_t  result;

        //copying to identity__T from identity__T;
        result = (identity__T_t)ivar_1;
        identity__T->release_ptr(ivar_1, identity__T);
        
        result->count++;
        return result;
}