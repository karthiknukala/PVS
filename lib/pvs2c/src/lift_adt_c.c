//Code generated using pvs2ir2c
#include "lift_adt_c.h"


lift_adt__lift_adt_t new_lift_adt__lift_adt(void){
        lift_adt__lift_adt_t tmp = (lift_adt__lift_adt_t) safe_malloc(sizeof(struct lift_adt__lift_adt_s));
        tmp->count = 1;
        return tmp;}

void release_lift_adt__lift_adt(lift_adt__lift_adt_t x, type_actual_t lift_adt__T){
switch (x->lift_adt__lift_adt_index) {
case 1:  release_lift_adt__up((lift_adt__up_t)x, lift_adt__T); break;
}}

void release_lift_adt__lift_adt_ptr(pointer_t x, type_actual_t T){
        actual_lift_adt__lift_adt_t actual = (actual_lift_adt__lift_adt_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        release_lift_adt__lift_adt((lift_adt__lift_adt_t)x, lift_adt__T);
}

lift_adt__lift_adt_t copy_lift_adt__lift_adt(lift_adt__lift_adt_t x){
        lift_adt__lift_adt_t y = new_lift_adt__lift_adt();
        y->lift_adt__lift_adt_index = (uint8_t)x->lift_adt__lift_adt_index;
        y->count = 1;
        return y;}

bool_t equal_lift_adt__lift_adt(lift_adt__lift_adt_t x, lift_adt__lift_adt_t y, type_actual_t lift_adt__T){
        bool_t tmp = x->lift_adt__lift_adt_index == y->lift_adt__lift_adt_index;
        switch  (x->lift_adt__lift_adt_index) {
                case 1: tmp = tmp && equal_lift_adt__up((lift_adt__up_t)x, (lift_adt__up_t)y, lift_adt__T); break;
        }
        return tmp;
}

char * json_lift_adt__lift_adt(lift_adt__lift_adt_t x, type_actual_t lift_adt__T){
        char * tmp = safe_malloc(24); sprintf(tmp, "{ \"constructor\": %u,", x->lift_adt__lift_adt_index); tmp = safe_strcat(tmp, " \"value\": ");
        switch  (x->lift_adt__lift_adt_index) {
                case 1: tmp = safe_strcat(tmp, json_lift_adt__up((lift_adt__up_t)x, lift_adt__T)); break;
                default: tmp = safe_strcat(tmp, "null");
        };
        tmp = safe_strcat(tmp, " }");
        return tmp;
}

bool_t equal_lift_adt__lift_adt_ptr(pointer_t x, pointer_t y, actual_lift_adt__lift_adt_t T){
        actual_lift_adt__lift_adt_t actual = (actual_lift_adt__lift_adt_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        return equal_lift_adt__lift_adt((lift_adt__lift_adt_t)x, (lift_adt__lift_adt_t)y, lift_adt__T);
}

char * json_lift_adt__lift_adt_ptr(pointer_t x, actual_lift_adt__lift_adt_t T){
        actual_lift_adt__lift_adt_t actual = (actual_lift_adt__lift_adt_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        return json_lift_adt__lift_adt((lift_adt__lift_adt_t)x, lift_adt__T);
}

actual_lift_adt__lift_adt_t actual_lift_adt__lift_adt(type_actual_t lift_adt__T){
        actual_lift_adt__lift_adt_t new = (actual_lift_adt__lift_adt_t)safe_malloc(sizeof(struct actual_lift_adt__lift_adt_s));
        new->equal_ptr = (equal_ptr_t)(*equal_lift_adt__lift_adt_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_lift_adt__lift_adt_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_lift_adt__lift_adt_ptr);
 

        new->lift_adt__T = lift_adt__T;
 
        return new;
 };

lift_adt__lift_adt_t update_lift_adt__lift_adt_lift_adt__lift_adt_index(lift_adt__lift_adt_t x, uint8_t v){
        lift_adt__lift_adt_t y;
        if (x->count == 1){y = x;}
        else {y = copy_lift_adt__lift_adt(x); x->count--;};
        y->lift_adt__lift_adt_index = (uint8_t)v;
        return y;}




lift_adt__up_t new_lift_adt__up(void){
        lift_adt__up_t tmp = (lift_adt__up_t) safe_malloc(sizeof(struct lift_adt__up_s));
        tmp->count = 1;
        return tmp;}

void release_lift_adt__up(lift_adt__up_t x, type_actual_t lift_adt__T){
        x->count--;
        if (x->count <= 0){
         lift_adt__T->release_ptr(x->down, lift_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_lift_adt__up_ptr(pointer_t x, type_actual_t T){
        actual_lift_adt__up_t actual = (actual_lift_adt__up_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        release_lift_adt__up((lift_adt__up_t)x, lift_adt__T);
}

lift_adt__up_t copy_lift_adt__up(lift_adt__up_t x){
        lift_adt__up_t y = new_lift_adt__up();
        y->lift_adt__lift_adt_index = (uint8_t)x->lift_adt__lift_adt_index;
        y->down = x->down;
        if (y->down != NULL){y->down->count++;};
        y->count = 1;
        return y;}

bool_t equal_lift_adt__up(lift_adt__up_t x, lift_adt__up_t y, type_actual_t lift_adt__T){
        bool_t tmp = true; tmp = tmp && x->lift_adt__lift_adt_index == y->lift_adt__lift_adt_index; tmp = tmp && lift_adt__T->equal_ptr(x->down, y->down, lift_adt__T);
        return tmp;}

char * json_lift_adt__up(lift_adt__up_t x, type_actual_t lift_adt__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(36);
         sprintf(fld0, "\"lift_adt__lift_adt_index\" : ");
        tmp[0] = safe_strcat(fld0, json_uint8(x->lift_adt__lift_adt_index));
        char * fld1 = safe_malloc(16);
         sprintf(fld1, "\"down\" : ");
        tmp[1] = safe_strcat(fld1, lift_adt__T->json_ptr(x->down, lift_adt__T));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_lift_adt__up_ptr(pointer_t x, pointer_t y, actual_lift_adt__up_t T){
        actual_lift_adt__up_t actual = (actual_lift_adt__up_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        return equal_lift_adt__up((lift_adt__up_t)x, (lift_adt__up_t)y, lift_adt__T);
}

char * json_lift_adt__up_ptr(pointer_t x, actual_lift_adt__up_t T){
        actual_lift_adt__up_t actual = (actual_lift_adt__up_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        return json_lift_adt__up((lift_adt__up_t)x, lift_adt__T);
}

actual_lift_adt__up_t actual_lift_adt__up(type_actual_t lift_adt__T){
        actual_lift_adt__up_t new = (actual_lift_adt__up_t)safe_malloc(sizeof(struct actual_lift_adt__up_s));
        new->equal_ptr = (equal_ptr_t)(*equal_lift_adt__up_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_lift_adt__up_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_lift_adt__up_ptr);
 

        new->lift_adt__T = lift_adt__T;
 
        return new;
 };

lift_adt__up_t update_lift_adt__up_lift_adt__lift_adt_index(lift_adt__up_t x, uint8_t v){
        lift_adt__up_t y;
        if (x->count == 1){y = x;}
        else {y = copy_lift_adt__up(x); x->count--;};
        y->lift_adt__lift_adt_index = (uint8_t)v;
        return y;}

lift_adt__up_t update_lift_adt__up_down(lift_adt__up_t x, lift_adt__T_t v, type_actual_t lift_adt__T){
        lift_adt__up_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->down != NULL){lift_adt__T->release_ptr(x->down, lift_adt__T);};}
        else {y = copy_lift_adt__up(x); x->count--; y->down->count--;};
        y->down = (lift_adt__T_t)v;
        return y;}



void release_lift_adt_funtype_2(lift_adt_funtype_2_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_2_t copy_lift_adt_funtype_2(lift_adt_funtype_2_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_2(lift_adt_funtype_2_t x, lift_adt_funtype_2_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_2(lift_adt_funtype_2_t x, type_actual_t lift_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"lift_adt_funtype_2\""); return result;}

void release_lift_adt_funtype_3(lift_adt_funtype_3_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_3_t copy_lift_adt_funtype_3(lift_adt_funtype_3_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_3(lift_adt_funtype_3_t x, lift_adt_funtype_3_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_3(lift_adt_funtype_3_t x, type_actual_t lift_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"lift_adt_funtype_3\""); return result;}


bool_t f_lift_adt_closure_4(struct lift_adt_closure_4_s * closure, lift_adt__lift_adt_t bvar){
        bool_t result = h_lift_adt_closure_4(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

bool_t m_lift_adt_closure_4(struct lift_adt_closure_4_s * closure, lift_adt__lift_adt_t bvar){
        return h_lift_adt_closure_4(bvar, closure->fvar_1, closure->fvar_2);}

bool_t h_lift_adt_closure_4(lift_adt__lift_adt_t ivar_5, lift_adt_funtype_3_t ivar_1, type_actual_t lift_adt__T){
        bool_t result;

        bool_t ivar_7;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)lift_adt__T;
        ivar_5->count++;
        ivar_7 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_10, (lift_adt__lift_adt_t)ivar_5);
        if (ivar_7){
             release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_5, lift_adt__T);
             result = (bool_t) true;
        } else {
             lift_adt__T_t ivar_12;
             /* T */ type_actual_t ivar_15;
             ivar_15 = (type_actual_t)lift_adt__T;
             ivar_12 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_15, (lift_adt__lift_adt_t)ivar_5);
             result = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_12);};
        return result;
}

lift_adt_closure_4_t new_lift_adt_closure_4(void){
        static struct lift_adt_funtype_2_ftbl_s ftbl = {.fptr = (bool_t (*)(lift_adt_funtype_2_t, lift_adt__lift_adt_t))&f_lift_adt_closure_4, .mptr = (bool_t (*)(lift_adt_funtype_2_t, lift_adt__lift_adt_t))&m_lift_adt_closure_4, .rptr =  (void (*)(lift_adt_funtype_2_t))&release_lift_adt_closure_4, .cptr = (lift_adt_funtype_2_t (*)(lift_adt_funtype_2_t))&copy_lift_adt_closure_4};
        lift_adt_closure_4_t tmp = (lift_adt_closure_4_t) safe_malloc(sizeof(struct lift_adt_closure_4_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_lift_adt_closure_4(lift_adt_funtype_2_t closure, type_actual_t lift_adt__T){
        lift_adt_closure_4_t x = (lift_adt_closure_4_t)closure;
        x->count--;
        if (x->count <= 0){
         release_lift_adt_funtype_3((lift_adt_funtype_3_t)x->fvar_1, lift_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

lift_adt_closure_4_t copy_lift_adt_closure_4(lift_adt_closure_4_t x){
        lift_adt_closure_4_t y = new_lift_adt_closure_4();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = (type_actual_t)x->fvar_2;
        if (x->htbl != NULL){
            lift_adt_funtype_2_htbl_t new_htbl = (lift_adt_funtype_2_htbl_t) safe_malloc(sizeof(struct lift_adt_funtype_2_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            lift_adt_funtype_2_hashentry_t * new_data = (lift_adt_funtype_2_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct lift_adt_funtype_2_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct lift_adt_funtype_2_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_lift_adt_closure_5(struct lift_adt_closure_5_s * closure, lift_adt__lift_adt_t bvar){
        bool_t result = h_lift_adt_closure_5(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

bool_t m_lift_adt_closure_5(struct lift_adt_closure_5_s * closure, lift_adt__lift_adt_t bvar){
        return h_lift_adt_closure_5(bvar, closure->fvar_1, closure->fvar_2);}

bool_t h_lift_adt_closure_5(lift_adt__lift_adt_t ivar_5, lift_adt_funtype_3_t ivar_1, type_actual_t lift_adt__T){
        bool_t result;

        bool_t ivar_7;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)lift_adt__T;
        ivar_5->count++;
        ivar_7 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_10, (lift_adt__lift_adt_t)ivar_5);
        if (ivar_7){
             release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_5, lift_adt__T);
             result = (bool_t) false;
        } else {
             lift_adt__T_t ivar_12;
             /* T */ type_actual_t ivar_15;
             ivar_15 = (type_actual_t)lift_adt__T;
             ivar_12 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_15, (lift_adt__lift_adt_t)ivar_5);
             result = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_12);};
        return result;
}

lift_adt_closure_5_t new_lift_adt_closure_5(void){
        static struct lift_adt_funtype_2_ftbl_s ftbl = {.fptr = (bool_t (*)(lift_adt_funtype_2_t, lift_adt__lift_adt_t))&f_lift_adt_closure_5, .mptr = (bool_t (*)(lift_adt_funtype_2_t, lift_adt__lift_adt_t))&m_lift_adt_closure_5, .rptr =  (void (*)(lift_adt_funtype_2_t))&release_lift_adt_closure_5, .cptr = (lift_adt_funtype_2_t (*)(lift_adt_funtype_2_t))&copy_lift_adt_closure_5};
        lift_adt_closure_5_t tmp = (lift_adt_closure_5_t) safe_malloc(sizeof(struct lift_adt_closure_5_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_lift_adt_closure_5(lift_adt_funtype_2_t closure, type_actual_t lift_adt__T){
        lift_adt_closure_5_t x = (lift_adt_closure_5_t)closure;
        x->count--;
        if (x->count <= 0){
         release_lift_adt_funtype_3((lift_adt_funtype_3_t)x->fvar_1, lift_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

lift_adt_closure_5_t copy_lift_adt_closure_5(lift_adt_closure_5_t x){
        lift_adt_closure_5_t y = new_lift_adt_closure_5();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = (type_actual_t)x->fvar_2;
        if (x->htbl != NULL){
            lift_adt_funtype_2_htbl_t new_htbl = (lift_adt_funtype_2_htbl_t) safe_malloc(sizeof(struct lift_adt_funtype_2_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            lift_adt_funtype_2_hashentry_t * new_data = (lift_adt_funtype_2_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct lift_adt_funtype_2_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct lift_adt_funtype_2_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_lift_adt_funtype_6(lift_adt_funtype_6_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_6_t copy_lift_adt_funtype_6(lift_adt_funtype_6_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_6(lift_adt_funtype_6_t x, lift_adt_funtype_6_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_6(lift_adt_funtype_6_t x, type_actual_t lift_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"lift_adt_funtype_6\""); return result;}

void release_lift_adt_funtype_7(lift_adt_funtype_7_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_7_t copy_lift_adt_funtype_7(lift_adt_funtype_7_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_7(lift_adt_funtype_7_t x, lift_adt_funtype_7_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_7(lift_adt_funtype_7_t x, type_actual_t lift_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"lift_adt_funtype_7\""); return result;}


mpz_ptr_t f_lift_adt_closure_8(struct lift_adt_closure_8_s * closure, lift_adt__lift_adt_t bvar){
        mpz_ptr_t result = h_lift_adt_closure_8(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

mpz_ptr_t m_lift_adt_closure_8(struct lift_adt_closure_8_s * closure, lift_adt__lift_adt_t bvar){
        return h_lift_adt_closure_8(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

mpz_ptr_t h_lift_adt_closure_8(lift_adt__lift_adt_t ivar_6, lift_adt_funtype_7_t ivar_2, mpz_ptr_t ivar_1, type_actual_t lift_adt__T){
        mpz_ptr_t result;

        bool_t ivar_18;
        /* T */ type_actual_t ivar_21;
        ivar_21 = (type_actual_t)lift_adt__T;
        ivar_6->count++;
        ivar_18 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_21, (lift_adt__lift_adt_t)ivar_6);
        if (ivar_18){
             release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_6, lift_adt__T);
             //copying to mpz from mpz;
             mpz_mk_set(result, ivar_1);
        } else {
             lift_adt__T_t ivar_23;
             /* T */ type_actual_t ivar_26;
             ivar_26 = (type_actual_t)lift_adt__T;
             ivar_23 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_26, (lift_adt__lift_adt_t)ivar_6);
             mpz_mk_set(result, ivar_2->ftbl->fptr(ivar_2, ivar_23));};
        return result;
}

lift_adt_closure_8_t new_lift_adt_closure_8(void){
        static struct lift_adt_funtype_6_ftbl_s ftbl = {.fptr = (mpz_ptr_t (*)(lift_adt_funtype_6_t, lift_adt__lift_adt_t))&f_lift_adt_closure_8, .mptr = (mpz_ptr_t (*)(lift_adt_funtype_6_t, lift_adt__lift_adt_t))&m_lift_adt_closure_8, .rptr =  (void (*)(lift_adt_funtype_6_t))&release_lift_adt_closure_8, .cptr = (lift_adt_funtype_6_t (*)(lift_adt_funtype_6_t))&copy_lift_adt_closure_8};
        lift_adt_closure_8_t tmp = (lift_adt_closure_8_t) safe_malloc(sizeof(struct lift_adt_closure_8_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        return tmp;}

void release_lift_adt_closure_8(lift_adt_funtype_6_t closure, type_actual_t lift_adt__T){
        lift_adt_closure_8_t x = (lift_adt_closure_8_t)closure;
        x->count--;
        if (x->count <= 0){
         release_lift_adt_funtype_7((lift_adt_funtype_7_t)x->fvar_1, lift_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

lift_adt_closure_8_t copy_lift_adt_closure_8(lift_adt_closure_8_t x){
        lift_adt_closure_8_t y = new_lift_adt_closure_8();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        mpz_set(y->fvar_2, x->fvar_2);
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            lift_adt_funtype_6_htbl_t new_htbl = (lift_adt_funtype_6_htbl_t) safe_malloc(sizeof(struct lift_adt_funtype_6_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            lift_adt_funtype_6_hashentry_t * new_data = (lift_adt_funtype_6_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct lift_adt_funtype_6_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct lift_adt_funtype_6_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


lift_adt_record_9_t new_lift_adt_record_9(void){
        lift_adt_record_9_t tmp = (lift_adt_record_9_t) safe_malloc(sizeof(struct lift_adt_record_9_s));
        tmp->count = 1;
        return tmp;}

void release_lift_adt_record_9(lift_adt_record_9_t x, type_actual_t lift_adt__T){
        x->count--;
        if (x->count <= 0){
         lift_adt__T->release_ptr(x->project_1, lift_adt__T);
         release_lift_adt__lift_adt((lift_adt__lift_adt_t)x->project_2, lift_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_lift_adt_record_9_ptr(pointer_t x, type_actual_t T){
        actual_lift_adt_record_9_t actual = (actual_lift_adt_record_9_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        release_lift_adt_record_9((lift_adt_record_9_t)x, lift_adt__T);
}

lift_adt_record_9_t copy_lift_adt_record_9(lift_adt_record_9_t x){
        lift_adt_record_9_t y = new_lift_adt_record_9();
        y->project_1 = x->project_1;
        if (y->project_1 != NULL){y->project_1->count++;};
        y->project_2 = x->project_2;
        if (y->project_2 != NULL){y->project_2->count++;};
        y->count = 1;
        return y;}

bool_t equal_lift_adt_record_9(lift_adt_record_9_t x, lift_adt_record_9_t y, type_actual_t lift_adt__T){
        bool_t tmp = true; tmp = tmp && lift_adt__T->equal_ptr(x->project_1, y->project_1, lift_adt__T); tmp = tmp && equal_lift_adt__lift_adt((lift_adt__lift_adt_t)x->project_2, (lift_adt__lift_adt_t)y->project_2, lift_adt__T);
        return tmp;}

char * json_lift_adt_record_9(lift_adt_record_9_t x, type_actual_t lift_adt__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, lift_adt__T->json_ptr(x->project_1, lift_adt__T));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, json_lift_adt__lift_adt((lift_adt__lift_adt_t)x->project_2, lift_adt__T));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_lift_adt_record_9_ptr(pointer_t x, pointer_t y, actual_lift_adt_record_9_t T){
        actual_lift_adt_record_9_t actual = (actual_lift_adt_record_9_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        return equal_lift_adt_record_9((lift_adt_record_9_t)x, (lift_adt_record_9_t)y, lift_adt__T);
}

char * json_lift_adt_record_9_ptr(pointer_t x, actual_lift_adt_record_9_t T){
        actual_lift_adt_record_9_t actual = (actual_lift_adt_record_9_t)T;
        type_actual_t lift_adt__T = actual->lift_adt__T;
        return json_lift_adt_record_9((lift_adt_record_9_t)x, lift_adt__T);
}

actual_lift_adt_record_9_t actual_lift_adt_record_9(type_actual_t lift_adt__T){
        actual_lift_adt_record_9_t new = (actual_lift_adt_record_9_t)safe_malloc(sizeof(struct actual_lift_adt_record_9_s));
        new->equal_ptr = (equal_ptr_t)(*equal_lift_adt_record_9_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_lift_adt_record_9_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_lift_adt_record_9_ptr);
 

        new->lift_adt__T = lift_adt__T;
 
        return new;
 };

lift_adt_record_9_t update_lift_adt_record_9_project_1(lift_adt_record_9_t x, lift_adt__T_t v, type_actual_t lift_adt__T){
        lift_adt_record_9_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_1 != NULL){lift_adt__T->release_ptr(x->project_1, lift_adt__T);};}
        else {y = copy_lift_adt_record_9(x); x->count--; y->project_1->count--;};
        y->project_1 = (lift_adt__T_t)v;
        return y;}

lift_adt_record_9_t update_lift_adt_record_9_project_2(lift_adt_record_9_t x, lift_adt__lift_adt_t v, type_actual_t lift_adt__T){
        lift_adt_record_9_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_2 != NULL){release_lift_adt__lift_adt((lift_adt__lift_adt_t)x->project_2, lift_adt__T);};}
        else {y = copy_lift_adt_record_9(x); x->count--; y->project_2->count--;};
        y->project_2 = (lift_adt__lift_adt_t)v;
        return y;}



void release_lift_adt_funtype_10(lift_adt_funtype_10_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_10_t copy_lift_adt_funtype_10(lift_adt_funtype_10_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_10(lift_adt_funtype_10_t x, lift_adt_funtype_10_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_10(lift_adt_funtype_10_t x, type_actual_t lift_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"lift_adt_funtype_10\""); return result;}


mpz_ptr_t f_lift_adt_closure_11(struct lift_adt_closure_11_s * closure, lift_adt__lift_adt_t bvar){
        mpz_ptr_t result = h_lift_adt_closure_11(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

mpz_ptr_t m_lift_adt_closure_11(struct lift_adt_closure_11_s * closure, lift_adt__lift_adt_t bvar){
        return h_lift_adt_closure_11(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

mpz_ptr_t h_lift_adt_closure_11(lift_adt__lift_adt_t ivar_7, lift_adt_funtype_10_t ivar_3, lift_adt_funtype_6_t ivar_1, type_actual_t lift_adt__T){
        mpz_ptr_t result;

        bool_t ivar_26;
        /* T */ type_actual_t ivar_29;
        ivar_29 = (type_actual_t)lift_adt__T;
        ivar_7->count++;
        ivar_26 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_29, (lift_adt__lift_adt_t)ivar_7);
        if (ivar_26){
             mpz_mk_set(result, ivar_1->ftbl->fptr(ivar_1, ivar_7));
        } else {
             lift_adt__T_t ivar_31;
             /* T */ type_actual_t ivar_34;
             ivar_34 = (type_actual_t)lift_adt__T;
             ivar_7->count++;
             ivar_31 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_34, (lift_adt__lift_adt_t)ivar_7);
             mpz_mk_set(result, ivar_3->ftbl->mptr(ivar_3, ivar_31, ivar_7));};
        return result;
}

lift_adt_closure_11_t new_lift_adt_closure_11(void){
        static struct lift_adt_funtype_6_ftbl_s ftbl = {.fptr = (mpz_ptr_t (*)(lift_adt_funtype_6_t, lift_adt__lift_adt_t))&f_lift_adt_closure_11, .mptr = (mpz_ptr_t (*)(lift_adt_funtype_6_t, lift_adt__lift_adt_t))&m_lift_adt_closure_11, .rptr =  (void (*)(lift_adt_funtype_6_t))&release_lift_adt_closure_11, .cptr = (lift_adt_funtype_6_t (*)(lift_adt_funtype_6_t))&copy_lift_adt_closure_11};
        lift_adt_closure_11_t tmp = (lift_adt_closure_11_t) safe_malloc(sizeof(struct lift_adt_closure_11_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_lift_adt_closure_11(lift_adt_funtype_6_t closure, type_actual_t lift_adt__T){
        lift_adt_closure_11_t x = (lift_adt_closure_11_t)closure;
        x->count--;
        if (x->count <= 0){
         release_lift_adt_funtype_10((lift_adt_funtype_10_t)x->fvar_1, lift_adt__T);
         release_lift_adt_funtype_6((lift_adt_funtype_6_t)x->fvar_2, lift_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

lift_adt_closure_11_t copy_lift_adt_closure_11(lift_adt_closure_11_t x){
        lift_adt_closure_11_t y = new_lift_adt_closure_11();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            lift_adt_funtype_6_htbl_t new_htbl = (lift_adt_funtype_6_htbl_t) safe_malloc(sizeof(struct lift_adt_funtype_6_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            lift_adt_funtype_6_hashentry_t * new_data = (lift_adt_funtype_6_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct lift_adt_funtype_6_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct lift_adt_funtype_6_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_lift_adt_funtype_12(lift_adt_funtype_12_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_12_t copy_lift_adt_funtype_12(lift_adt_funtype_12_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_12(lift_adt_funtype_12_t x, lift_adt_funtype_12_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_12(lift_adt_funtype_12_t x, type_actual_t lift_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"lift_adt_funtype_12\""); return result;}

void release_lift_adt_funtype_13(lift_adt_funtype_13_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_13_t copy_lift_adt_funtype_13(lift_adt_funtype_13_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_13(lift_adt_funtype_13_t x, lift_adt_funtype_13_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_13(lift_adt_funtype_13_t x, type_actual_t lift_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"lift_adt_funtype_13\""); return result;}


ordstruct_adt__ordstruct_adt_t f_lift_adt_closure_14(struct lift_adt_closure_14_s * closure, lift_adt__lift_adt_t bvar){
        ordstruct_adt__ordstruct_adt_t result = h_lift_adt_closure_14(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

ordstruct_adt__ordstruct_adt_t m_lift_adt_closure_14(struct lift_adt_closure_14_s * closure, lift_adt__lift_adt_t bvar){
        return h_lift_adt_closure_14(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

ordstruct_adt__ordstruct_adt_t h_lift_adt_closure_14(lift_adt__lift_adt_t ivar_6, lift_adt_funtype_13_t ivar_2, ordstruct_adt__ordstruct_adt_t ivar_1, type_actual_t lift_adt__T){
        ordstruct_adt__ordstruct_adt_t result;

        bool_t ivar_18;
        /* T */ type_actual_t ivar_21;
        ivar_21 = (type_actual_t)lift_adt__T;
        ivar_6->count++;
        ivar_18 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_21, (lift_adt__lift_adt_t)ivar_6);
        if (ivar_18){
             release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_6, lift_adt__T);
             //copying to ordstruct_adt__ordstruct_adt from ordstruct_adt__ordstruct_adt;
             result = (ordstruct_adt__ordstruct_adt_t)ivar_1;
             if (result != NULL) result->count++;
        } else {
             lift_adt__T_t ivar_23;
             /* T */ type_actual_t ivar_26;
             ivar_26 = (type_actual_t)lift_adt__T;
             ivar_23 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_26, (lift_adt__lift_adt_t)ivar_6);
             result = (ordstruct_adt__ordstruct_adt_t)ivar_2->ftbl->fptr(ivar_2, ivar_23);};
        return result;
}

lift_adt_closure_14_t new_lift_adt_closure_14(void){
        static struct lift_adt_funtype_12_ftbl_s ftbl = {.fptr = (ordstruct_adt__ordstruct_adt_t (*)(lift_adt_funtype_12_t, lift_adt__lift_adt_t))&f_lift_adt_closure_14, .mptr = (ordstruct_adt__ordstruct_adt_t (*)(lift_adt_funtype_12_t, lift_adt__lift_adt_t))&m_lift_adt_closure_14, .rptr =  (void (*)(lift_adt_funtype_12_t))&release_lift_adt_closure_14, .cptr = (lift_adt_funtype_12_t (*)(lift_adt_funtype_12_t))&copy_lift_adt_closure_14};
        lift_adt_closure_14_t tmp = (lift_adt_closure_14_t) safe_malloc(sizeof(struct lift_adt_closure_14_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_lift_adt_closure_14(lift_adt_funtype_12_t closure, type_actual_t lift_adt__T){
        lift_adt_closure_14_t x = (lift_adt_closure_14_t)closure;
        x->count--;
        if (x->count <= 0){
         release_lift_adt_funtype_13((lift_adt_funtype_13_t)x->fvar_1, lift_adt__T);
         release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->fvar_2);
        //printf("\nFreeing\n");
        safe_free(x);}}

lift_adt_closure_14_t copy_lift_adt_closure_14(lift_adt_closure_14_t x){
        lift_adt_closure_14_t y = new_lift_adt_closure_14();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            lift_adt_funtype_12_htbl_t new_htbl = (lift_adt_funtype_12_htbl_t) safe_malloc(sizeof(struct lift_adt_funtype_12_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            lift_adt_funtype_12_hashentry_t * new_data = (lift_adt_funtype_12_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct lift_adt_funtype_12_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct lift_adt_funtype_12_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_lift_adt_funtype_15(lift_adt_funtype_15_t x, type_actual_t lift_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

lift_adt_funtype_15_t copy_lift_adt_funtype_15(lift_adt_funtype_15_t x){return x->ftbl->cptr(x);}

bool_t equal_lift_adt_funtype_15(lift_adt_funtype_15_t x, lift_adt_funtype_15_t y, type_actual_t lift_adt__T){
        return false;}

char* json_lift_adt_funtype_15(lift_adt_funtype_15_t x, type_actual_t lift_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"lift_adt_funtype_15\""); return result;}


ordstruct_adt__ordstruct_adt_t f_lift_adt_closure_16(struct lift_adt_closure_16_s * closure, lift_adt__lift_adt_t bvar){
        ordstruct_adt__ordstruct_adt_t result = h_lift_adt_closure_16(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

ordstruct_adt__ordstruct_adt_t m_lift_adt_closure_16(struct lift_adt_closure_16_s * closure, lift_adt__lift_adt_t bvar){
        return h_lift_adt_closure_16(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

ordstruct_adt__ordstruct_adt_t h_lift_adt_closure_16(lift_adt__lift_adt_t ivar_7, lift_adt_funtype_15_t ivar_3, lift_adt_funtype_12_t ivar_1, type_actual_t lift_adt__T){
        ordstruct_adt__ordstruct_adt_t result;

        bool_t ivar_26;
        /* T */ type_actual_t ivar_29;
        ivar_29 = (type_actual_t)lift_adt__T;
        ivar_7->count++;
        ivar_26 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_29, (lift_adt__lift_adt_t)ivar_7);
        if (ivar_26){
             result = (ordstruct_adt__ordstruct_adt_t)ivar_1->ftbl->fptr(ivar_1, ivar_7);
        } else {
             lift_adt__T_t ivar_31;
             /* T */ type_actual_t ivar_34;
             ivar_34 = (type_actual_t)lift_adt__T;
             ivar_7->count++;
             ivar_31 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_34, (lift_adt__lift_adt_t)ivar_7);
             result = (ordstruct_adt__ordstruct_adt_t)ivar_3->ftbl->mptr(ivar_3, ivar_31, ivar_7);};
        return result;
}

lift_adt_closure_16_t new_lift_adt_closure_16(void){
        static struct lift_adt_funtype_12_ftbl_s ftbl = {.fptr = (ordstruct_adt__ordstruct_adt_t (*)(lift_adt_funtype_12_t, lift_adt__lift_adt_t))&f_lift_adt_closure_16, .mptr = (ordstruct_adt__ordstruct_adt_t (*)(lift_adt_funtype_12_t, lift_adt__lift_adt_t))&m_lift_adt_closure_16, .rptr =  (void (*)(lift_adt_funtype_12_t))&release_lift_adt_closure_16, .cptr = (lift_adt_funtype_12_t (*)(lift_adt_funtype_12_t))&copy_lift_adt_closure_16};
        lift_adt_closure_16_t tmp = (lift_adt_closure_16_t) safe_malloc(sizeof(struct lift_adt_closure_16_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_lift_adt_closure_16(lift_adt_funtype_12_t closure, type_actual_t lift_adt__T){
        lift_adt_closure_16_t x = (lift_adt_closure_16_t)closure;
        x->count--;
        if (x->count <= 0){
         release_lift_adt_funtype_15((lift_adt_funtype_15_t)x->fvar_1, lift_adt__T);
         release_lift_adt_funtype_12((lift_adt_funtype_12_t)x->fvar_2, lift_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

lift_adt_closure_16_t copy_lift_adt_closure_16(lift_adt_closure_16_t x){
        lift_adt_closure_16_t y = new_lift_adt_closure_16();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            lift_adt_funtype_12_htbl_t new_htbl = (lift_adt_funtype_12_htbl_t) safe_malloc(sizeof(struct lift_adt_funtype_12_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            lift_adt_funtype_12_hashentry_t * new_data = (lift_adt_funtype_12_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct lift_adt_funtype_12_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct lift_adt_funtype_12_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

bool_t rec_lift_adt__bottomp(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1){
        bool_t  result;

        uint8_t ivar_3;
        ivar_3 = (uint8_t)0;
        uint8_t ivar_2;
        ivar_2 = (uint8_t)ivar_1->lift_adt__lift_adt_index;
        release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_1, lift_adt__T);
        result = (ivar_2 == ivar_3);
        
        
        return result;
}

bool_t rec_lift_adt__upp(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1){
        bool_t  result;

        uint8_t ivar_3;
        ivar_3 = (uint8_t)1;
        uint8_t ivar_2;
        ivar_2 = (uint8_t)ivar_1->lift_adt__lift_adt_index;
        release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_1, lift_adt__T);
        result = (ivar_2 == ivar_3);
        
        
        return result;
}

lift_adt__up_t update_lift_adt__lift_adt_down(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1, lift_adt__T_t ivar_3){
        lift_adt__up_t  result;

        lift_adt__up_t ivar_2;
        //copying to lift_adt__up from lift_adt__lift_adt;
        ivar_2 = (lift_adt__up_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_1, lift_adt__T);
        result = (lift_adt__up_t)update_lift_adt__up_down(ivar_2, ivar_3, lift_adt__T);
        
        result->count++;
        return result;
}

lift_adt__T_t acc_lift_adt__lift_adt_down(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1){
        lift_adt__T_t  result;

        lift_adt__up_t ivar_2;
        //copying to lift_adt__up from lift_adt__lift_adt;
        ivar_2 = (lift_adt__up_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_1, lift_adt__T);
        result = (lift_adt__T_t)ivar_2->down;
        result->count++;
        release_lift_adt__up((lift_adt__up_t)ivar_2, lift_adt__T);
        
        result->count++;
        return result;
}

lift_adt__lift_adt_t con_lift_adt__bottom(type_actual_t lift_adt__T){
        lift_adt__lift_adt_t  result;

        uint8_t ivar_1;
        ivar_1 = (uint8_t)0;
        lift_adt__lift_adt_t tmp3992 = new_lift_adt__lift_adt();;
        result = (lift_adt__lift_adt_t)tmp3992;
        tmp3992->lift_adt__lift_adt_index = (uint8_t)ivar_1;
        
        result->count++;
        return result;
}

lift_adt__lift_adt_t con_lift_adt__up(type_actual_t lift_adt__T, lift_adt__T_t ivar_2){
        lift_adt__lift_adt_t  result;

        uint8_t ivar_1;
        ivar_1 = (uint8_t)1;
        lift_adt__up_t tmp3993 = new_lift_adt__up();;
        result = (lift_adt__lift_adt_t)tmp3993;
        tmp3993->lift_adt__lift_adt_index = (uint8_t)ivar_1;
        tmp3993->down = (lift_adt__T_t)ivar_2;
        
        result->count++;
        return result;
}

uint8_t lift_adt__ord(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1){
        uint8_t  result;

        bool_t ivar_3;
        /* T */ type_actual_t ivar_6;
        ivar_6 = (type_actual_t)lift_adt__T;
        ivar_1->count++;
        ivar_3 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_6, (lift_adt__lift_adt_t)ivar_1);
        if (ivar_3){
             result = (uint8_t)0;
        } else {
             result = (uint8_t)1;};
        
        
        return result;
}

lift_adt_funtype_2_t lift_adt__every_1(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1){
        lift_adt_funtype_2_t  result;

        lift_adt_closure_4_t cl3996;
        cl3996 = new_lift_adt_closure_4();
        cl3996->fvar_1 = (lift_adt_funtype_3_t)ivar_1;
        if (cl3996->fvar_1 != NULL) cl3996->fvar_1->count++;
        cl3996->fvar_2 = (type_actual_t)lift_adt__T;
        release_lift_adt_funtype_3((lift_adt_funtype_3_t)ivar_1, lift_adt__T);
        result = (lift_adt_funtype_2_t)cl3996;
        
        result->count++;
        return result;
}

bool_t lift_adt__every_2(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1, lift_adt__lift_adt_t ivar_3){
        bool_t  result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_8;
        ivar_8 = (type_actual_t)lift_adt__T;
        ivar_3->count++;
        ivar_5 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_8, (lift_adt__lift_adt_t)ivar_3);
        if (ivar_5){
             release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_3, lift_adt__T);
             release_lift_adt_funtype_3((lift_adt_funtype_3_t)ivar_1, lift_adt__T);
             result = (bool_t) true;
        } else {
             lift_adt__T_t ivar_10;
             /* T */ type_actual_t ivar_13;
             ivar_13 = (type_actual_t)lift_adt__T;
             ivar_10 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_13, (lift_adt__lift_adt_t)ivar_3);
             result = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_10);
             ivar_1->ftbl->rptr(ivar_1);};
        
        
        return result;
}

lift_adt_funtype_2_t lift_adt__some_1(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1){
        lift_adt_funtype_2_t  result;

        lift_adt_closure_5_t cl3999;
        cl3999 = new_lift_adt_closure_5();
        cl3999->fvar_1 = (lift_adt_funtype_3_t)ivar_1;
        if (cl3999->fvar_1 != NULL) cl3999->fvar_1->count++;
        cl3999->fvar_2 = (type_actual_t)lift_adt__T;
        release_lift_adt_funtype_3((lift_adt_funtype_3_t)ivar_1, lift_adt__T);
        result = (lift_adt_funtype_2_t)cl3999;
        
        result->count++;
        return result;
}

bool_t lift_adt__some_2(type_actual_t lift_adt__T, lift_adt_funtype_3_t ivar_1, lift_adt__lift_adt_t ivar_3){
        bool_t  result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_8;
        ivar_8 = (type_actual_t)lift_adt__T;
        ivar_3->count++;
        ivar_5 = (bool_t)rec_lift_adt__bottomp((type_actual_t)ivar_8, (lift_adt__lift_adt_t)ivar_3);
        if (ivar_5){
             release_lift_adt__lift_adt((lift_adt__lift_adt_t)ivar_3, lift_adt__T);
             release_lift_adt_funtype_3((lift_adt_funtype_3_t)ivar_1, lift_adt__T);
             result = (bool_t) false;
        } else {
             lift_adt__T_t ivar_10;
             /* T */ type_actual_t ivar_13;
             ivar_13 = (type_actual_t)lift_adt__T;
             ivar_10 = (lift_adt__T_t)acc_lift_adt__lift_adt_down((type_actual_t)ivar_13, (lift_adt__lift_adt_t)ivar_3);
             result = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_10);
             ivar_1->ftbl->rptr(ivar_1);};
        
        
        return result;
}

bool_t lift_adt__subterm(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1, lift_adt__lift_adt_t ivar_2){
        bool_t  result;

        result = (bool_t) equal_lift_adt__lift_adt(ivar_1, ivar_2, lift_adt__T);
        
        
        return result;
}

bool_t lift_adt__doublelessp(type_actual_t lift_adt__T, lift_adt__lift_adt_t ivar_1, lift_adt__lift_adt_t ivar_2){
        bool_t  result;

        result = (bool_t) false;
        
        
        return result;
}

lift_adt_funtype_6_t lift_adt__reduce_nat(type_actual_t lift_adt__T, mpz_ptr_t ivar_1, lift_adt_funtype_7_t ivar_2){
        lift_adt_funtype_6_t  result;

        lift_adt_closure_8_t cl4002;
        cl4002 = new_lift_adt_closure_8();
        cl4002->fvar_1 = (lift_adt_funtype_7_t)ivar_2;
        if (cl4002->fvar_1 != NULL) cl4002->fvar_1->count++;
        mpz_set(cl4002->fvar_2, ivar_1);
        cl4002->fvar_3 = (type_actual_t)lift_adt__T;
        release_lift_adt_funtype_7((lift_adt_funtype_7_t)ivar_2, lift_adt__T);
        result = (lift_adt_funtype_6_t)cl4002;
        
        result->count++;
        return result;
}

lift_adt_funtype_6_t lift_adt__REDUCE_nat(type_actual_t lift_adt__T, lift_adt_funtype_6_t ivar_1, lift_adt_funtype_10_t ivar_3){
        lift_adt_funtype_6_t  result;

        lift_adt_closure_11_t cl4012;
        cl4012 = new_lift_adt_closure_11();
        cl4012->fvar_1 = (lift_adt_funtype_10_t)ivar_3;
        if (cl4012->fvar_1 != NULL) cl4012->fvar_1->count++;
        cl4012->fvar_2 = (lift_adt_funtype_6_t)ivar_1;
        if (cl4012->fvar_2 != NULL) cl4012->fvar_2->count++;
        cl4012->fvar_3 = (type_actual_t)lift_adt__T;
        release_lift_adt_funtype_10((lift_adt_funtype_10_t)ivar_3, lift_adt__T);
        release_lift_adt_funtype_6((lift_adt_funtype_6_t)ivar_1, lift_adt__T);
        result = (lift_adt_funtype_6_t)cl4012;
        
        result->count++;
        return result;
}

lift_adt_funtype_12_t lift_adt__reduce_ordinal(type_actual_t lift_adt__T, ordstruct_adt__ordstruct_adt_t ivar_1, lift_adt_funtype_13_t ivar_2){
        lift_adt_funtype_12_t  result;

        lift_adt_closure_14_t cl4014;
        cl4014 = new_lift_adt_closure_14();
        cl4014->fvar_1 = (lift_adt_funtype_13_t)ivar_2;
        if (cl4014->fvar_1 != NULL) cl4014->fvar_1->count++;
        cl4014->fvar_2 = (ordstruct_adt__ordstruct_adt_t)ivar_1;
        if (cl4014->fvar_2 != NULL) cl4014->fvar_2->count++;
        cl4014->fvar_3 = (type_actual_t)lift_adt__T;
        release_lift_adt_funtype_13((lift_adt_funtype_13_t)ivar_2, lift_adt__T);
        release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)ivar_1);
        result = (lift_adt_funtype_12_t)cl4014;
        
        result->count++;
        return result;
}

lift_adt_funtype_12_t lift_adt__REDUCE_ordinal(type_actual_t lift_adt__T, lift_adt_funtype_12_t ivar_1, lift_adt_funtype_15_t ivar_3){
        lift_adt_funtype_12_t  result;

        lift_adt_closure_16_t cl4024;
        cl4024 = new_lift_adt_closure_16();
        cl4024->fvar_1 = (lift_adt_funtype_15_t)ivar_3;
        if (cl4024->fvar_1 != NULL) cl4024->fvar_1->count++;
        cl4024->fvar_2 = (lift_adt_funtype_12_t)ivar_1;
        if (cl4024->fvar_2 != NULL) cl4024->fvar_2->count++;
        cl4024->fvar_3 = (type_actual_t)lift_adt__T;
        release_lift_adt_funtype_15((lift_adt_funtype_15_t)ivar_3, lift_adt__T);
        release_lift_adt_funtype_12((lift_adt_funtype_12_t)ivar_1, lift_adt__T);
        result = (lift_adt_funtype_12_t)cl4024;
        
        result->count++;
        return result;
}