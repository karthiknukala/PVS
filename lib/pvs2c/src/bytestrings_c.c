//Code generated using pvs2ir2c
#include "bytestrings_c.h"


bytestrings_array_1_t new_bytestrings_array_1(uint32_t size){
        bytestrings_array_1_t tmp = (bytestrings_array_1_t) safe_malloc(sizeof(struct bytestrings_array_1_s) + (size * sizeof(uint8_t)));
        tmp->count = 1;
        tmp->size = size;;
        tmp->max = size;
         return tmp;}

void release_bytestrings_array_1(bytestrings_array_1_t x){
        x->count--;
         if (x->count <= 0){safe_free(x);}
}

void release_bytestrings_array_1_ptr(pointer_t x, type_actual_t T){
        release_bytestrings_array_1((bytestrings_array_1_t)x);
}

bytestrings_array_1_t copy_bytestrings_array_1(bytestrings_array_1_t x){
        bytestrings_array_1_t tmp = new_bytestrings_array_1(x->max);
        tmp->count = 1;
        tmp->size = x->max;
        for (uint32_t i = 0; i < x->max; i++){tmp->elems[i] = (uint8_t)x->elems[i];};
         return tmp;}

bool_t equal_bytestrings_array_1(bytestrings_array_1_t x, bytestrings_array_1_t y){
        bool_t tmp = true;
        uint32_t i = 0;
        while (i < x->size && tmp){tmp = (x->elems[i] == y->elems[i]); i++;};
        return tmp;}

char * json_bytestrings_array_1(bytestrings_array_1_t x){
        char ** tmp = (char **)safe_malloc(sizeof(void *) * x->size);
        for (uint32_t i = 0; i < x->size; i++){tmp[i] = json_uint8(x->elems[i]);};
        char * result = json_list_with_sep(tmp, x->size, '[', ',', ']');
        for (uint32_t i = 0; i < x->size; i++) free(tmp[i]);
        free(tmp);
        return result;}

bool_t equal_bytestrings_array_1_ptr(pointer_t x, pointer_t y, type_actual_t T){
        return equal_bytestrings_array_1((bytestrings_array_1_t)x, (bytestrings_array_1_t)y);
}

char * json_bytestrings_array_1_ptr(pointer_t x, type_actual_t T){
        return json_bytestrings_array_1((bytestrings_array_1_t)x);
}

actual_bytestrings_array_1_t actual_bytestrings_array_1(){
        actual_bytestrings_array_1_t new = (actual_bytestrings_array_1_t)safe_malloc(sizeof(struct actual_bytestrings_array_1_s));
        new->equal_ptr = (equal_ptr_t)(*equal_bytestrings_array_1_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_bytestrings_array_1_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_bytestrings_array_1_ptr);
 

 
        return new;
 };

bytestrings_array_1_t update_bytestrings_array_1(bytestrings_array_1_t x, uint32_t i, uint8_t v){
        bytestrings_array_1_t y; 
         if (x->count == 1){y = x;}
           else {y = copy_bytestrings_array_1(x );
                x->count--;};
        y->elems[i] = (uint8_t)v;
        return y;}

bytestrings_array_1_t upgrade_bytestrings_array_1(bytestrings_array_1_t x, uint32_t i, uint8_t v){
        bytestrings_array_1_t y;
        uint32_t xmax = x->max;
         if (x->count == 1 && i < xmax){y = x;}
           else if (i >= xmax){uint32_t newmax = ((xmax < UINT32_MAX/2) ? ((i < 2 * (xmax + 1)) ? 2 * (xmax + 1) : i + 1) : UINT32_MAX);
                y = safe_realloc(x, sizeof(struct bytestrings_array_1_s) + (newmax * sizeof(uint8_t)));
                y->count = 1;
                y->size = i+1;
                y->max = newmax;}
           else {y = copy_bytestrings_array_1(x );
                x->count--;};
        ;
        return y;}




bytestrings__bytestring_t new_bytestrings__bytestring(void){
        bytestrings__bytestring_t tmp = (bytestrings__bytestring_t) safe_malloc(sizeof(struct bytestrings__bytestring_s));
        tmp->count = 1;
        return tmp;}

void release_bytestrings__bytestring(bytestrings__bytestring_t x){
        x->count--;
        if (x->count <= 0){
         release_bytestrings_array_1((bytestrings_array_1_t)x->seq);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_bytestrings__bytestring_ptr(pointer_t x, type_actual_t T){
        release_bytestrings__bytestring((bytestrings__bytestring_t)x);
}

bytestrings__bytestring_t copy_bytestrings__bytestring(bytestrings__bytestring_t x){
        bytestrings__bytestring_t y = new_bytestrings__bytestring();
        y->length = (uint32_t)x->length;
        y->seq = x->seq;
        if (y->seq != NULL){y->seq->count++;};
        y->count = 1;
        return y;}

bool_t equal_bytestrings__bytestring(bytestrings__bytestring_t x, bytestrings__bytestring_t y){
        bool_t tmp = true; tmp = tmp && x->length == y->length; tmp = tmp && equal_bytestrings_array_1((bytestrings_array_1_t)x->seq, (bytestrings_array_1_t)y->seq);
        return tmp;}

char * json_bytestrings__bytestring(bytestrings__bytestring_t x){
        char * tmp[2]; 
        char * fld0 = safe_malloc(18);
         sprintf(fld0, "\"length\" : ");
        tmp[0] = safe_strcat(fld0, json_uint32(x->length));
        char * fld1 = safe_malloc(15);
         sprintf(fld1, "\"seq\" : ");
        tmp[1] = safe_strcat(fld1, json_bytestrings_array_1((bytestrings_array_1_t)x->seq));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_bytestrings__bytestring_ptr(pointer_t x, pointer_t y, actual_bytestrings__bytestring_t T){
        return equal_bytestrings__bytestring((bytestrings__bytestring_t)x, (bytestrings__bytestring_t)y);
}

char * json_bytestrings__bytestring_ptr(pointer_t x, actual_bytestrings__bytestring_t T){
        return json_bytestrings__bytestring((bytestrings__bytestring_t)x);
}

actual_bytestrings__bytestring_t actual_bytestrings__bytestring(){
        actual_bytestrings__bytestring_t new = (actual_bytestrings__bytestring_t)safe_malloc(sizeof(struct actual_bytestrings__bytestring_s));
        new->equal_ptr = (equal_ptr_t)(*equal_bytestrings__bytestring_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_bytestrings__bytestring_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_bytestrings__bytestring_ptr);
 

 
        return new;
 };

bytestrings__bytestring_t update_bytestrings__bytestring_length(bytestrings__bytestring_t x, uint32_t v){
        bytestrings__bytestring_t y;
        if (x->count == 1){y = x;}
        else {y = copy_bytestrings__bytestring(x); x->count--;};
        y->length = (uint32_t)v;
        return y;}

bytestrings__bytestring_t update_bytestrings__bytestring_seq(bytestrings__bytestring_t x, bytestrings_array_1_t v){
        bytestrings__bytestring_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->seq != NULL){release_bytestrings_array_1((bytestrings_array_1_t)x->seq);};}
        else {y = copy_bytestrings__bytestring(x); x->count--; y->seq->count--;};
        y->seq = (bytestrings_array_1_t)v;
        return y;}



uint32_t bytestrings__bytestring_bound(void){
        uint32_t  static  result;

        static bool_t defined = false;
        if (!defined){
            
        uint8_t ivar_5;
        ivar_5 = (uint8_t)28;
        mpz_ptr_t ivar_3;
        //copying to mpz from uint8;
        mpz_mk_set_ui(ivar_3, ivar_5);
        result = (uint32_t)mpz_get_ui(exp2__exp2((mpz_ptr_t)ivar_3));
        defined = true;};
        
        
        return result;
}

uint32_t bytestrings__length(bytestrings__bytestring_t ivar_1){
        uint32_t  result;

        result = (uint32_t)ivar_1->length;
        release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
        
        
        return result;
}

uint8_t bytestrings__get(bytestrings__bytestring_t ivar_1, uint32_t ivar_2){
        uint8_t  result;

        bytestrings_array_1_t ivar_6;
        bytestrings_array_1_t ivar_11;
        ivar_11 = (bytestrings_array_1_t)ivar_1->seq;
        ivar_11->count++;
        //copying to bytestrings_array_1 from bytestrings_array_1;
        ivar_6 = (bytestrings_array_1_t)ivar_11;
        if (ivar_6 != NULL) ivar_6->count++;
        release_bytestrings_array_1((bytestrings_array_1_t)ivar_11);
        result = (uint8_t)ivar_6->elems[ivar_2];
        release_bytestrings_array_1((bytestrings_array_1_t)ivar_6);
        
        
        return result;
}

bytestrings__bytestring_t bytestrings__null(void){
        bytestrings__bytestring_t  static  result;

        static bool_t defined = false;
        if (!defined){
            
        uint32_t ivar_1;
        ivar_1 = (uint32_t)0;
        bytestrings_array_1_t ivar_6;
        uint32_t size3960;
        //copying to uint32 from uint32;
        size3960 = (uint32_t)ivar_1;
        size3960 += 0;
        ivar_6 = new_bytestrings_array_1(size3960);
        uint32_t ivar_5;
        for (uint32_t index3959 = 0; index3959 < size3960; index3959++){
             ivar_5 = (uint32_t)index3959;
             ivar_6->elems[index3959] = (uint8_t)0;
        };
        bytestrings__bytestring_t tmp3961 = new_bytestrings__bytestring();;
        result = (bytestrings__bytestring_t)tmp3961;
        tmp3961->length = (uint32_t)ivar_1;
        tmp3961->seq = (bytestrings_array_1_t)ivar_6;
        defined = true;};
        
        result->count++;
        return result;
}

bytestrings__bytestring_t bytestrings__unit(uint8_t ivar_1){
        bytestrings__bytestring_t  result;

        uint32_t ivar_2;
        ivar_2 = (uint32_t)1;
        bytestrings_array_1_t ivar_7;
        uint32_t size3965;
        //copying to uint32 from uint32;
        size3965 = (uint32_t)ivar_2;
        size3965 += 0;
        ivar_7 = new_bytestrings_array_1(size3965);
        uint32_t ivar_6;
        for (uint32_t index3964 = 0; index3964 < size3965; index3964++){
             ivar_6 = (uint32_t)index3964;
             //copying to uint8 from uint8;
             ivar_7->elems[index3964] = (uint8_t)ivar_1;
        };
        bytestrings__bytestring_t tmp3966 = new_bytestrings__bytestring();;
        result = (bytestrings__bytestring_t)tmp3966;
        tmp3966->length = (uint32_t)ivar_2;
        tmp3966->seq = (bytestrings_array_1_t)ivar_7;
        
        result->count++;
        return result;
}

bytestrings__bytestring_t bytestrings__mk_bytestring(strings__string_t ivar_1){
        bytestrings__bytestring_t  result;

        uint32_t ivar_5;
        mpz_ptr_t ivar_4;
        ivar_4 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_4);
        mpz_set(ivar_4, ivar_1->length);
        //copying to uint32 from mpz;
        ivar_5 = (uint32_t)mpz_get_ui(ivar_4);
        mpz_clear(ivar_4);
        bytestrings_array_1_t ivar_21;
        uint32_t size3970;
        //copying to uint32 from uint32;
        size3970 = (uint32_t)ivar_5;
        size3970 += 0;
        ivar_21 = new_bytestrings_array_1(size3970);
        uint32_t ivar_12;
        for (uint32_t index3969 = 0; index3969 < size3970; index3969++){
             ivar_12 = (uint32_t)index3969;
             /* i */ mpz_ptr_t ivar_10;
             //copying to mpz from uint32;
             mpz_mk_set_ui(ivar_10, ivar_12);
             uint32_t ivar_13;
             ivar_1->count++;
             ivar_13 = (uint32_t)gen_strings__get((strings__string_t)ivar_1, (mpz_ptr_t)ivar_10);
             ivar_21->elems[index3969] = (uint32_t) ivar_13;
        };
        release_strings__string((strings__string_t)ivar_1);
        bytestrings__bytestring_t tmp3971 = new_bytestrings__bytestring();;
        result = (bytestrings__bytestring_t)tmp3971;
        tmp3971->length = (uint32_t)ivar_5;
        tmp3971->seq = (bytestrings_array_1_t)ivar_21;
        
        result->count++;
        return result;
}

bytestrings__bytestring_t bytestrings__doubleplus(bytestrings__bytestring_t ivar_1, bytestrings__bytestring_t ivar_2){
        bytestrings__bytestring_t  result;

        bool_t ivar_3;
        uint32_t ivar_4;
        ivar_4 = (uint32_t)ivar_1->length;
        uint8_t ivar_5;
        ivar_5 = (uint8_t)0;
        ivar_3 = (ivar_4 == ivar_5);
        if (ivar_3){
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
             //copying to bytestrings__bytestring from bytestrings__bytestring;
             result = (bytestrings__bytestring_t)ivar_2;
             if (result != NULL) result->count++;
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_2);
        } else {
             bool_t ivar_8;
             uint32_t ivar_9;
             ivar_9 = (uint32_t)ivar_2->length;
             uint8_t ivar_10;
             ivar_10 = (uint8_t)0;
             ivar_8 = (ivar_9 == ivar_10);
             if (ivar_8){
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_2);
           //copying to bytestrings__bytestring from bytestrings__bytestring;
           result = (bytestrings__bytestring_t)ivar_1;
           if (result != NULL) result->count++;
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
             } else {
           /* n */ uint32_t ivar_13;
           uint32_t ivar_14;
           ivar_14 = (uint32_t)ivar_1->length;
           uint32_t ivar_15;
           ivar_15 = (uint32_t)ivar_2->length;
           ivar_13 = (uint32_t)(ivar_14 + ivar_15);
           bytestrings_array_1_t ivar_47;
           uint32_t size3975;
           //copying to uint32 from uint32;
           size3975 = (uint32_t)ivar_13;
           size3975 += 0;
           ivar_47 = new_bytestrings_array_1(size3975);
           uint32_t ivar_23;
           for (uint32_t index3974 = 0; index3974 < size3975; index3974++){
           ivar_23 = (uint32_t)index3974;
           bool_t ivar_24;
           uint32_t ivar_26;
           ivar_26 = (uint32_t)ivar_1->length;
           ivar_24 = (ivar_23 < ivar_26);
           if (ivar_24){
            ivar_1->count++;
            ivar_47->elems[index3974] = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_1, (uint32_t)ivar_23);
           } else {
            int32_t ivar_46;
            uint32_t ivar_38;
            ivar_38 = (uint32_t)ivar_1->length;
            ivar_46 = (int32_t)((uint64_t)ivar_23 - (uint64_t)ivar_38);
            uint32_t ivar_43;
            //copying to uint32 from int32;
            ivar_43 = (uint32_t)ivar_46;
            ivar_2->count++;
            ivar_47->elems[index3974] = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_2, (uint32_t)ivar_43);};
           };
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_2);
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
           bytestrings__bytestring_t tmp3976 = new_bytestrings__bytestring();;
           result = (bytestrings__bytestring_t)tmp3976;
           tmp3976->length = (uint32_t)ivar_13;
           tmp3976->seq = (bytestrings_array_1_t)ivar_47;};};
        
        result->count++;
        return result;
}

uint32_t bytestrings__strdiff_rec(bytestrings__bytestring_t ivar_1, bytestrings__bytestring_t ivar_2, uint32_t ivar_3){
        uint32_t  result;

        bool_t ivar_8;
        bool_t ivar_9;
        uint32_t ivar_12;
        ivar_12 = (uint32_t)ivar_1->length;
        ivar_9 = (ivar_3 == ivar_12);
        if (ivar_9){
             ivar_8 = (bool_t) true;
        } else {
             bool_t ivar_15;
             uint32_t ivar_18;
             ivar_18 = (uint32_t)ivar_2->length;
             ivar_15 = (ivar_3 == ivar_18);
             if (ivar_15){
           ivar_8 = (bool_t) true;
             } else {
           uint8_t ivar_21;
           ivar_1->count++;
           ivar_21 = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_1, (uint32_t)ivar_3);
           uint8_t ivar_22;
           ivar_2->count++;
           ivar_22 = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_2, (uint32_t)ivar_3);
           ivar_8 = (ivar_21 != ivar_22);};};
        if (ivar_8){
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_2);
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
             //copying to uint32 from uint32;
             result = (uint32_t)ivar_3;
        } else {
             uint32_t ivar_49;
             uint8_t ivar_44;
             ivar_44 = (uint8_t)1;
             ivar_49 = (uint32_t)(ivar_3 + ivar_44);
             result = (uint32_t)bytestrings__strdiff_rec((bytestrings__bytestring_t)ivar_1, (bytestrings__bytestring_t)ivar_2, (uint32_t)ivar_49);};
        
        
        return result;
}

uint32_t bytestrings__strdiff(bytestrings__bytestring_t ivar_1, bytestrings__bytestring_t ivar_2){
        uint32_t  result;

        uint8_t ivar_17;
        ivar_17 = (uint8_t)0;
        uint32_t ivar_13;
        //copying to uint32 from uint8;
        ivar_13 = (uint32_t)ivar_17;
        result = (uint32_t)bytestrings__strdiff_rec((bytestrings__bytestring_t)ivar_1, (bytestrings__bytestring_t)ivar_2, (uint32_t)ivar_13);
        
        
        return result;
}

int8_t bytestrings__strcmp(bytestrings__bytestring_t ivar_1, bytestrings__bytestring_t ivar_2){
        int8_t  result;

        /* i */ uint32_t ivar_3;
        ivar_1->count++;
        ivar_2->count++;
        ivar_3 = (uint32_t)bytestrings__strdiff((bytestrings__bytestring_t)ivar_1, (bytestrings__bytestring_t)ivar_2);
        bool_t ivar_13;
        bool_t ivar_14;
        uint32_t ivar_17;
        ivar_17 = (uint32_t)ivar_1->length;
        ivar_14 = (ivar_3 == ivar_17);
        if (ivar_14){
             ivar_13 = (bool_t) true;
        } else {
             uint32_t ivar_21;
             ivar_21 = (uint32_t)ivar_2->length;
             ivar_13 = (ivar_3 == ivar_21);};
        if (ivar_13){
             bool_t ivar_25;
             uint32_t ivar_26;
             ivar_26 = (uint32_t)ivar_1->length;
             uint32_t ivar_27;
             ivar_27 = (uint32_t)ivar_2->length;
             ivar_25 = (ivar_26 < ivar_27);
             if (ivar_25){
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_2);
           result = (int8_t)-1;
             } else {
           bool_t ivar_31;
           uint32_t ivar_32;
           ivar_32 = (uint32_t)ivar_1->length;
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
           uint32_t ivar_33;
           ivar_33 = (uint32_t)ivar_2->length;
           release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_2);
           ivar_31 = (ivar_32 > ivar_33);
           if (ivar_31){
           result = (int8_t)1;
           } else {
           result = (int8_t)0;};};
        } else {
             bool_t ivar_37;
             uint8_t ivar_38;
             ivar_38 = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_1, (uint32_t)ivar_3);
             uint8_t ivar_39;
             ivar_39 = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_2, (uint32_t)ivar_3);
             ivar_37 = (ivar_38 < ivar_39);
             if (ivar_37){
           result = (int8_t)-1;
             } else {
           result = (int8_t)1;};};
        
        
        return result;
}

bytestrings__bytestring_t bytestrings__prefix(bytestrings__bytestring_t ivar_1, uint32_t ivar_2){
        bytestrings__bytestring_t  result;

        bool_t ivar_4;
        uint32_t ivar_6;
        ivar_6 = (uint32_t)ivar_1->length;
        ivar_4 = (ivar_2 == ivar_6);
        if (ivar_4){
             //copying to bytestrings__bytestring from bytestrings__bytestring;
             result = (bytestrings__bytestring_t)ivar_1;
             if (result != NULL) result->count++;
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
        } else {
             bytestrings_array_1_t ivar_23;
             uint32_t size3980;
             //copying to uint32 from uint32;
             size3980 = (uint32_t)ivar_2;
             size3980 += 0;
             ivar_23 = new_bytestrings_array_1(size3980);
             uint32_t ivar_16;
             for (uint32_t index3979 = 0; index3979 < size3980; index3979++){
           ivar_16 = (uint32_t)index3979;
           ivar_1->count++;
           ivar_23->elems[index3979] = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_1, (uint32_t)ivar_16);
             };
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
             bytestrings__bytestring_t tmp3981 = new_bytestrings__bytestring();;
             result = (bytestrings__bytestring_t)tmp3981;
             tmp3981->length = (uint32_t)ivar_2;
             tmp3981->seq = (bytestrings_array_1_t)ivar_23;};
        
        result->count++;
        return result;
}

bytestrings__bytestring_t bytestrings__suffix(bytestrings__bytestring_t ivar_1, uint32_t ivar_2){
        bytestrings__bytestring_t  result;

        bool_t ivar_4;
        uint8_t ivar_6;
        ivar_6 = (uint8_t)0;
        ivar_4 = (ivar_2 == ivar_6);
        if (ivar_4){
             //copying to bytestrings__bytestring from bytestrings__bytestring;
             result = (bytestrings__bytestring_t)ivar_1;
             if (result != NULL) result->count++;
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
        } else {
             uint32_t ivar_12;
             uint32_t ivar_8;
             ivar_8 = (uint32_t)ivar_1->length;
             ivar_12 = (uint32_t)(ivar_8 - ivar_2);
             bytestrings_array_1_t ivar_40;
             uint32_t size3985;
             //copying to uint32 from uint32;
             size3985 = (uint32_t)ivar_12;
             size3985 += 0;
             ivar_40 = new_bytestrings_array_1(size3985);
             uint32_t ivar_28;
             for (uint32_t index3984 = 0; index3984 < size3985; index3984++){
           ivar_28 = (uint32_t)index3984;
           /* j */ mpz_ptr_t ivar_23;
           //copying to mpz from uint32;
           mpz_mk_set_ui(ivar_23, ivar_28);
           mpz_ptr_t ivar_39;
           mpz_mk_add_ui(ivar_39, ivar_23, (uint64_t)ivar_2);
           uint32_t ivar_36;
           //copying to uint32 from mpz;
           ivar_36 = (uint32_t)mpz_get_ui(ivar_39);
           mpz_clear(ivar_39);
           ivar_1->count++;
           ivar_40->elems[index3984] = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_1, (uint32_t)ivar_36);
             };
             release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
             bytestrings__bytestring_t tmp3986 = new_bytestrings__bytestring();;
             result = (bytestrings__bytestring_t)tmp3986;
             tmp3986->length = (uint32_t)ivar_12;
             tmp3986->seq = (bytestrings_array_1_t)ivar_40;};
        
        result->count++;
        return result;
}

bytestrings__bytestring_t bytestrings__substr(bytestrings__bytestring_t ivar_1, uint32_t ivar_2, uint32_t ivar_4){
        bytestrings__bytestring_t  result;

        bytestrings__bytestring_t ivar_18;
        ivar_1->count++;
        ivar_18 = (bytestrings__bytestring_t)bytestrings__suffix((bytestrings__bytestring_t)ivar_1, (uint32_t)ivar_2);
        int32_t ivar_22;
        ivar_22 = (int32_t)((uint64_t)ivar_4 - (uint64_t)ivar_2);
        uint32_t ivar_19;
        //copying to uint32 from int32;
        ivar_19 = (uint32_t)ivar_22;
        result = (bytestrings__bytestring_t)bytestrings__prefix((bytestrings__bytestring_t)ivar_18, (uint32_t)ivar_19);
        
        result->count++;
        return result;
}

bool_t bytestrings__ascii_bytestringp(bytestrings__bytestring_t ivar_1){
        bool_t  result;

        uint32_t low3987;
        uint32_t highvar3988;
        result = true;
        low3987 = (uint32_t) 0;
        highvar3988 = (uint32_t)ivar_1->length;
        release_bytestrings__bytestring((bytestrings__bytestring_t)ivar_1);
        highvar3988 += 0;
        for (uint32_t ivar_2 = low3987; ivar_2 < highvar3988; ivar_2++){
             uint8_t ivar_4;
             ivar_4 = (uint8_t)bytestrings__get((bytestrings__bytestring_t)ivar_1, (uint32_t)ivar_2);
             uint8_t ivar_5;
             ivar_5 = (uint8_t)128;
             result = (ivar_4 < ivar_5);
             if (!result) break;
        };
        
        
        return result;
}