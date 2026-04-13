//Code generated using pvs2ir2c
#include "array_sequences_c.h"


array_sequences_array_0_t new_array_sequences_array_0(uint32_t size){
        array_sequences_array_0_t tmp = (array_sequences_array_0_t) safe_malloc(sizeof(struct array_sequences_array_0_s) + (size * sizeof(array_sequences__T_t)));
        tmp->count = 1;
        tmp->size = size;
        tmp->max = size;
        return tmp;}

void release_array_sequences_array_0(array_sequences_array_0_t x, type_actual_t array_sequences__T){
        x->count--;
        if (x->count <= 0){
                for (int i = 0; i < x->size; i++){array_sequences__T->release_ptr(x->elems[i], array_sequences__T);};
        //printf("\nFreeing\n");
        safe_free(x);}
}

void release_array_sequences_array_0_ptr(pointer_t x, type_actual_t T){
        actual_array_sequences_array_0_t actual = (actual_array_sequences_array_0_t)T;
        type_actual_t array_sequences__T = actual->array_sequences__T;
        release_array_sequences_array_0((array_sequences_array_0_t)x, array_sequences__T);
}

array_sequences_array_0_t copy_array_sequences_array_0(array_sequences_array_0_t x){
        array_sequences_array_0_t tmp = new_array_sequences_array_0(x->max);
        tmp->count = 1;
        tmp->size = x->max;
        for (uint32_t i = 0; i < x->max; i++){tmp->elems[i] = x->elems[i];
                if (i < x->size) x->elems[i]->count++;};
         return tmp;}

bool_t equal_array_sequences_array_0(array_sequences_array_0_t x, array_sequences_array_0_t y, type_actual_t array_sequences__T){
        bool_t tmp = true;
        uint32_t i = 0;
        while (i < x->size && tmp){tmp = array_sequences__T->equal_ptr(x->elems[i], y->elems[i], array_sequences__T); i++;};
        return tmp;}

char * json_array_sequences_array_0(array_sequences_array_0_t x, type_actual_t array_sequences__T){
        char ** tmp = (char **)safe_malloc(sizeof(void *) * x->size);
        for (uint32_t i = 0; i < x->size; i++){tmp[i] = array_sequences__T->json_ptr(x->elems[i], array_sequences__T);};
        char * result = json_list_with_sep(tmp, x->size, '[', ',', ']');
        for (uint32_t i = 0; i < x->size; i++) free(tmp[i]);
        free(tmp);
        return result;}

bool_t equal_array_sequences_array_0_ptr(pointer_t x, pointer_t y, type_actual_t T){
        actual_array_sequences_array_0_t actual = (actual_array_sequences_array_0_t)T;
        type_actual_t array_sequences__T = actual->array_sequences__T;
        return equal_array_sequences_array_0((array_sequences_array_0_t)x, (array_sequences_array_0_t)y, array_sequences__T);
}

char * json_array_sequences_array_0_ptr(pointer_t x, type_actual_t T){
        actual_array_sequences_array_0_t actual = (actual_array_sequences_array_0_t)T;
        type_actual_t array_sequences__T = actual->array_sequences__T;
        return json_array_sequences_array_0((array_sequences_array_0_t)x, array_sequences__T);
}

actual_array_sequences_array_0_t actual_array_sequences_array_0(type_actual_t array_sequences__T){
        actual_array_sequences_array_0_t new = (actual_array_sequences_array_0_t)safe_malloc(sizeof(struct actual_array_sequences_array_0_s));
        new->equal_ptr = (equal_ptr_t)(*equal_array_sequences_array_0_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_array_sequences_array_0_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_array_sequences_array_0_ptr);
 

        new->array_sequences__T = array_sequences__T;
 
        return new;
 };

array_sequences_array_0_t update_array_sequences_array_0(array_sequences_array_0_t x, uint32_t i, array_sequences__T_t v, type_actual_t array_sequences__T){
         array_sequences_array_0_t y;
         if (x->count == 1){y = x;}
                 else {y = copy_array_sequences_array_0(x);
                      x->count--;};
        array_sequences__T_t * yelems = y->elems;
        if (v != NULL){v->count++;}
        if (yelems[i] != NULL){array_sequences__T->release_ptr(yelems[i], array_sequences__T);};
         yelems[i] = v;
         return y;}

array_sequences_array_0_t upgrade_array_sequences_array_0(array_sequences_array_0_t x, uint32_t i, array_sequences__T_t v, type_actual_t array_sequences__T){
         array_sequences_array_0_t y;
        uint32_t xmax = x->max;
        uint32_t xsize = x->size;
         if (x->count == 1 && i < xmax){y = x;}
                 else if (i >= xmax){
                            uint32_t newmax = ((xmax < UINT32_MAX/2)  ? ((i < 2 * (xmax + 1))  ? 2 * (xmax + 1) : i + 1) : UINT32_MAX);
                            y = safe_realloc(x, sizeof(struct array_sequences_array_0_s) + (newmax * sizeof(array_sequences__T_t)));
                            y->count = 1;
                            y->max = newmax;
                            for (uint32_t j = xsize; j < newmax; j++){y->elems[j] = NULL;};}
                         else {y = copy_array_sequences_array_0(x);
                            x->count--;};
        array_sequences__T_t * yelems = y->elems;
        if (v != NULL){v->count++;};
        y->size = xsize > i ? xsize : i + 1;
        if (i < xmax && yelems[i] != NULL){array_sequences__T->release_ptr(yelems[i], array_sequences__T);};
         yelems[i] = v;
         return y;}




array_sequences__arrayseq_t new_array_sequences__arrayseq(void){
        array_sequences__arrayseq_t tmp = (array_sequences__arrayseq_t) safe_malloc(sizeof(struct array_sequences__arrayseq_s));
        tmp->count = 1;
        return tmp;}

void release_array_sequences__arrayseq(array_sequences__arrayseq_t x, type_actual_t array_sequences__T){
        x->count--;
        if (x->count <= 0){
         release_array_sequences_array_0((array_sequences_array_0_t)x->seq, array_sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_array_sequences__arrayseq_ptr(pointer_t x, type_actual_t T){
        actual_array_sequences__arrayseq_t actual = (actual_array_sequences__arrayseq_t)T;
        type_actual_t array_sequences__T = actual->array_sequences__T;
        release_array_sequences__arrayseq((array_sequences__arrayseq_t)x, array_sequences__T);
}

array_sequences__arrayseq_t copy_array_sequences__arrayseq(array_sequences__arrayseq_t x){
        array_sequences__arrayseq_t y = new_array_sequences__arrayseq();
        y->length = (uint32_t)x->length;
        y->seq = x->seq;
        if (y->seq != NULL){y->seq->count++;};
        y->count = 1;
        return y;}

bool_t equal_array_sequences__arrayseq(array_sequences__arrayseq_t x, array_sequences__arrayseq_t y, type_actual_t array_sequences__T){
        bool_t tmp = true; tmp = tmp && x->length == y->length; tmp = tmp && equal_array_sequences_array_0((array_sequences_array_0_t)x->seq, (array_sequences_array_0_t)y->seq, array_sequences__T);
        return tmp;}

char * json_array_sequences__arrayseq(array_sequences__arrayseq_t x, type_actual_t array_sequences__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(18);
         sprintf(fld0, "\"length\" : ");
        tmp[0] = safe_strcat(fld0, json_uint32(x->length));
        char * fld1 = safe_malloc(15);
         sprintf(fld1, "\"seq\" : ");
        tmp[1] = safe_strcat(fld1, json_array_sequences_array_0((array_sequences_array_0_t)x->seq, array_sequences__T));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_array_sequences__arrayseq_ptr(pointer_t x, pointer_t y, actual_array_sequences__arrayseq_t T){
        actual_array_sequences__arrayseq_t actual = (actual_array_sequences__arrayseq_t)T;
        type_actual_t array_sequences__T = actual->array_sequences__T;
        return equal_array_sequences__arrayseq((array_sequences__arrayseq_t)x, (array_sequences__arrayseq_t)y, array_sequences__T);
}

char * json_array_sequences__arrayseq_ptr(pointer_t x, actual_array_sequences__arrayseq_t T){
        actual_array_sequences__arrayseq_t actual = (actual_array_sequences__arrayseq_t)T;
        type_actual_t array_sequences__T = actual->array_sequences__T;
        return json_array_sequences__arrayseq((array_sequences__arrayseq_t)x, array_sequences__T);
}

actual_array_sequences__arrayseq_t actual_array_sequences__arrayseq(type_actual_t array_sequences__T){
        actual_array_sequences__arrayseq_t new = (actual_array_sequences__arrayseq_t)safe_malloc(sizeof(struct actual_array_sequences__arrayseq_s));
        new->equal_ptr = (equal_ptr_t)(*equal_array_sequences__arrayseq_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_array_sequences__arrayseq_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_array_sequences__arrayseq_ptr);
 

        new->array_sequences__T = array_sequences__T;
 
        return new;
 };

array_sequences__arrayseq_t update_array_sequences__arrayseq_length(array_sequences__arrayseq_t x, uint32_t v){
        array_sequences__arrayseq_t y;
        if (x->count == 1){y = x;}
        else {y = copy_array_sequences__arrayseq(x); x->count--;};
        y->length = (uint32_t)v;
        return y;}

array_sequences__arrayseq_t update_array_sequences__arrayseq_seq(array_sequences__arrayseq_t x, array_sequences_array_0_t v, type_actual_t array_sequences__T){
        array_sequences__arrayseq_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->seq != NULL){release_array_sequences_array_0((array_sequences_array_0_t)x->seq, array_sequences__T);};}
        else {y = copy_array_sequences__arrayseq(x); x->count--; y->seq->count--;};
        y->seq = (array_sequences_array_0_t)v;
        return y;}



array_sequences__arrayseq_t array_sequences__empty_aseq(type_actual_t array_sequences__T){
        array_sequences__arrayseq_t  result;

        uint32_t ivar_1;
        ivar_1 = (uint32_t)0;
        array_sequences_array_0_t ivar_11;
        uint32_t size3777;
        //copying to uint32 from uint32;
        size3777 = (uint32_t)ivar_1;
        size3777 += 0;
        ivar_11 = new_array_sequences_array_0(size3777);
        uint32_t ivar_5;
        for (uint32_t index3776 = 0; index3776 < size3777; index3776++){
             ivar_5 = (uint32_t)index3776;
             pvs2cerror("Non-executable theory: epsilons", PVS2C_EXIT_ERROR);
        };
        array_sequences__arrayseq_t tmp3778 = new_array_sequences__arrayseq();;
        result = (array_sequences__arrayseq_t)tmp3778;
        tmp3778->length = (uint32_t)ivar_1;
        tmp3778->seq = (array_sequences_array_0_t)ivar_11;
        
        result->count++;
        return result;
}

bool_t array_sequences__full_aseqp(type_actual_t array_sequences__T, array_sequences__arrayseq_t ivar_1){
        bool_t  result;

        uint32_t ivar_2;
        ivar_2 = (uint32_t)ivar_1->length;
        release_array_sequences__arrayseq((array_sequences__arrayseq_t)ivar_1, array_sequences__T);
        uint32_t ivar_3;
        uint8_t ivar_9;
        ivar_9 = (uint8_t)28;
        mpz_ptr_t ivar_7;
        //copying to mpz from uint8;
        mpz_mk_set_ui(ivar_7, ivar_9);
        ivar_3 = (uint32_t)mpz_get_ui(exp2__exp2((mpz_ptr_t)ivar_7));
        result = (ivar_2 == ivar_3);
        
        
        return result;
}

array_sequences_array_0_t array_sequences__aseq_appl(type_actual_t array_sequences__T, array_sequences__arrayseq_t ivar_1){
        array_sequences_array_0_t  result;

        array_sequences_array_0_t ivar_7;
        ivar_7 = (array_sequences_array_0_t)ivar_1->seq;
        ivar_7->count++;
        //copying to array_sequences_array_0 from array_sequences_array_0;
        result = (array_sequences_array_0_t)ivar_7;
        if (result != NULL) result->count++;
        release_array_sequences_array_0((array_sequences_array_0_t)ivar_7, array_sequences__T);
        
        result->count++;
        return result;
}

array_sequences__arrayseq_t array_sequences__aseq_add(type_actual_t array_sequences__T, array_sequences__T_t ivar_1, array_sequences__arrayseq_t ivar_2){
        array_sequences__arrayseq_t  result;

        uint32_t ivar_16;
        ivar_16 = (uint32_t)ivar_2->length;
        uint32_t ivar_3;
        uint32_t ivar_5;
        ivar_5 = (uint32_t)ivar_2->length;
        uint8_t ivar_6;
        ivar_6 = (uint8_t)1;
        ivar_3 = (uint32_t)(ivar_5 + ivar_6);
        array_sequences__arrayseq_t ivar_13;
        ivar_13 = (array_sequences__arrayseq_t)update_array_sequences__arrayseq_length(ivar_2, ivar_3);
        array_sequences_array_0_t ivar_14;
        ivar_14 = (array_sequences_array_0_t)ivar_13->seq;
        ivar_14->count++;
        array_sequences__arrayseq_t ivar_21;
        array_sequences_array_0_t ivar_23;
        ivar_23 = NULL;
        ivar_21 = (array_sequences__arrayseq_t)update_array_sequences__arrayseq_seq(ivar_13, ivar_23, array_sequences__T);
        if (ivar_23 != NULL) ivar_23->count--;
        array_sequences_array_0_t ivar_22;
        array_sequences_array_0_t ivar_18;
        array_sequences__T_t ivar_20;
        ivar_20 = NULL;
        ivar_18 = (array_sequences_array_0_t)upgrade_array_sequences_array_0(ivar_14, ivar_16, ivar_20, array_sequences__T);
        if (ivar_20 != NULL) ivar_20->count--;
        ivar_22 = (array_sequences_array_0_t)upgrade_array_sequences_array_0(ivar_18, ivar_16, ivar_1, array_sequences__T);
        if (ivar_1 != NULL) ivar_1->count--;
        result = (array_sequences__arrayseq_t)update_array_sequences__arrayseq_seq(ivar_21, ivar_22, array_sequences__T);
        if (ivar_22 != NULL) ivar_22->count--;
        
        result->count++;
        return result;
}