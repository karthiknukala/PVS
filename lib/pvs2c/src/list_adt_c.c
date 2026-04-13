//Code generated using pvs2ir2c
#include "list_adt_c.h"


list_adt__list_adt_t new_list_adt__list_adt(void){
        list_adt__list_adt_t tmp = (list_adt__list_adt_t) safe_malloc(sizeof(struct list_adt__list_adt_s));
        tmp->count = 1;
        return tmp;}

void release_list_adt__list_adt(list_adt__list_adt_t x, type_actual_t list_adt__T){
switch (x->list_adt__list_adt_index) {
case 1:  release_list_adt__cons((list_adt__cons_t)x, list_adt__T); break;
}}

void release_list_adt__list_adt_ptr(pointer_t x, type_actual_t T){
        actual_list_adt__list_adt_t actual = (actual_list_adt__list_adt_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        release_list_adt__list_adt((list_adt__list_adt_t)x, list_adt__T);
}

list_adt__list_adt_t copy_list_adt__list_adt(list_adt__list_adt_t x){
        list_adt__list_adt_t y = new_list_adt__list_adt();
        y->list_adt__list_adt_index = (uint8_t)x->list_adt__list_adt_index;
        y->count = 1;
        return y;}

bool_t equal_list_adt__list_adt(list_adt__list_adt_t x, list_adt__list_adt_t y, type_actual_t list_adt__T){
        bool_t tmp = x->list_adt__list_adt_index == y->list_adt__list_adt_index;
        switch  (x->list_adt__list_adt_index) {
                case 1: tmp = tmp && equal_list_adt__cons((list_adt__cons_t)x, (list_adt__cons_t)y, list_adt__T); break;
        }
        return tmp;
}

char * json_list_adt__list_adt(list_adt__list_adt_t x, type_actual_t list_adt__T){
        char * tmp = safe_malloc(24); sprintf(tmp, "{ \"constructor\": %u,", x->list_adt__list_adt_index); tmp = safe_strcat(tmp, " \"value\": ");
        switch  (x->list_adt__list_adt_index) {
                case 1: tmp = safe_strcat(tmp, json_list_adt__cons((list_adt__cons_t)x, list_adt__T)); break;
                default: tmp = safe_strcat(tmp, "null");
        };
        tmp = safe_strcat(tmp, " }");
        return tmp;
}

bool_t equal_list_adt__list_adt_ptr(pointer_t x, pointer_t y, actual_list_adt__list_adt_t T){
        actual_list_adt__list_adt_t actual = (actual_list_adt__list_adt_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return equal_list_adt__list_adt((list_adt__list_adt_t)x, (list_adt__list_adt_t)y, list_adt__T);
}

char * json_list_adt__list_adt_ptr(pointer_t x, actual_list_adt__list_adt_t T){
        actual_list_adt__list_adt_t actual = (actual_list_adt__list_adt_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return json_list_adt__list_adt((list_adt__list_adt_t)x, list_adt__T);
}

actual_list_adt__list_adt_t actual_list_adt__list_adt(type_actual_t list_adt__T){
        actual_list_adt__list_adt_t new = (actual_list_adt__list_adt_t)safe_malloc(sizeof(struct actual_list_adt__list_adt_s));
        new->equal_ptr = (equal_ptr_t)(*equal_list_adt__list_adt_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_list_adt__list_adt_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_list_adt__list_adt_ptr);
 

        new->list_adt__T = list_adt__T;
 
        return new;
 };

list_adt__list_adt_t update_list_adt__list_adt_list_adt__list_adt_index(list_adt__list_adt_t x, uint8_t v){
        list_adt__list_adt_t y;
        if (x->count == 1){y = x;}
        else {y = copy_list_adt__list_adt(x); x->count--;};
        y->list_adt__list_adt_index = (uint8_t)v;
        return y;}




list_adt__cons_t new_list_adt__cons(void){
        list_adt__cons_t tmp = (list_adt__cons_t) safe_malloc(sizeof(struct list_adt__cons_s));
        tmp->count = 1;
        return tmp;}

void release_list_adt__cons(list_adt__cons_t x, type_actual_t list_adt__T){
        x->count--;
        if (x->count <= 0){
         list_adt__T->release_ptr(x->car, list_adt__T);
         release_list_adt__list_adt((list_adt__list_adt_t)x->cdr, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_list_adt__cons_ptr(pointer_t x, type_actual_t T){
        actual_list_adt__cons_t actual = (actual_list_adt__cons_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        release_list_adt__cons((list_adt__cons_t)x, list_adt__T);
}

list_adt__cons_t copy_list_adt__cons(list_adt__cons_t x){
        list_adt__cons_t y = new_list_adt__cons();
        y->list_adt__list_adt_index = (uint8_t)x->list_adt__list_adt_index;
        y->car = x->car;
        if (y->car != NULL){y->car->count++;};
        y->cdr = x->cdr;
        if (y->cdr != NULL){y->cdr->count++;};
        y->count = 1;
        return y;}

bool_t equal_list_adt__cons(list_adt__cons_t x, list_adt__cons_t y, type_actual_t list_adt__T){
        bool_t tmp = true; tmp = tmp && x->list_adt__list_adt_index == y->list_adt__list_adt_index; tmp = tmp && list_adt__T->equal_ptr(x->car, y->car, list_adt__T); tmp = tmp && equal_list_adt__list_adt((list_adt__list_adt_t)x->cdr, (list_adt__list_adt_t)y->cdr, list_adt__T);
        return tmp;}

char * json_list_adt__cons(list_adt__cons_t x, type_actual_t list_adt__T){
        char * tmp[3]; 
        char * fld0 = safe_malloc(36);
         sprintf(fld0, "\"list_adt__list_adt_index\" : ");
        tmp[0] = safe_strcat(fld0, json_uint8(x->list_adt__list_adt_index));
        char * fld1 = safe_malloc(15);
         sprintf(fld1, "\"car\" : ");
        tmp[1] = safe_strcat(fld1, list_adt__T->json_ptr(x->car, list_adt__T));
        char * fld2 = safe_malloc(15);
         sprintf(fld2, "\"cdr\" : ");
        tmp[2] = safe_strcat(fld2, json_list_adt__list_adt((list_adt__list_adt_t)x->cdr, list_adt__T));
         char * result = json_list_with_sep(tmp, 3,  '{', ',', '}');
         for (uint32_t i = 0; i < 3; i++) free(tmp[i]);
        return result;}

bool_t equal_list_adt__cons_ptr(pointer_t x, pointer_t y, actual_list_adt__cons_t T){
        actual_list_adt__cons_t actual = (actual_list_adt__cons_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return equal_list_adt__cons((list_adt__cons_t)x, (list_adt__cons_t)y, list_adt__T);
}

char * json_list_adt__cons_ptr(pointer_t x, actual_list_adt__cons_t T){
        actual_list_adt__cons_t actual = (actual_list_adt__cons_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return json_list_adt__cons((list_adt__cons_t)x, list_adt__T);
}

actual_list_adt__cons_t actual_list_adt__cons(type_actual_t list_adt__T){
        actual_list_adt__cons_t new = (actual_list_adt__cons_t)safe_malloc(sizeof(struct actual_list_adt__cons_s));
        new->equal_ptr = (equal_ptr_t)(*equal_list_adt__cons_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_list_adt__cons_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_list_adt__cons_ptr);
 

        new->list_adt__T = list_adt__T;
 
        return new;
 };

list_adt__cons_t update_list_adt__cons_list_adt__list_adt_index(list_adt__cons_t x, uint8_t v){
        list_adt__cons_t y;
        if (x->count == 1){y = x;}
        else {y = copy_list_adt__cons(x); x->count--;};
        y->list_adt__list_adt_index = (uint8_t)v;
        return y;}

list_adt__cons_t update_list_adt__cons_car(list_adt__cons_t x, list_adt__T_t v, type_actual_t list_adt__T){
        list_adt__cons_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->car != NULL){list_adt__T->release_ptr(x->car, list_adt__T);};}
        else {y = copy_list_adt__cons(x); x->count--; y->car->count--;};
        y->car = (list_adt__T_t)v;
        return y;}

list_adt__cons_t update_list_adt__cons_cdr(list_adt__cons_t x, list_adt__list_adt_t v, type_actual_t list_adt__T){
        list_adt__cons_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->cdr != NULL){release_list_adt__list_adt((list_adt__list_adt_t)x->cdr, list_adt__T);};}
        else {y = copy_list_adt__cons(x); x->count--; y->cdr->count--;};
        y->cdr = (list_adt__list_adt_t)v;
        return y;}



void release_list_adt_funtype_2(list_adt_funtype_2_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_2_t copy_list_adt_funtype_2(list_adt_funtype_2_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_2(list_adt_funtype_2_t x, list_adt_funtype_2_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_2(list_adt_funtype_2_t x, type_actual_t list_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"list_adt_funtype_2\""); return result;}

void release_list_adt_funtype_3(list_adt_funtype_3_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_3_t copy_list_adt_funtype_3(list_adt_funtype_3_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_3(list_adt_funtype_3_t x, list_adt_funtype_3_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_3(list_adt_funtype_3_t x, type_actual_t list_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"list_adt_funtype_3\""); return result;}


bool_t f_list_adt_closure_4(struct list_adt_closure_4_s * closure, list_adt__list_adt_t bvar){
        bool_t result = h_list_adt_closure_4(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

bool_t m_list_adt_closure_4(struct list_adt_closure_4_s * closure, list_adt__list_adt_t bvar){
        return h_list_adt_closure_4(bvar, closure->fvar_1, closure->fvar_2);}

bool_t h_list_adt_closure_4(list_adt__list_adt_t ivar_5, list_adt_funtype_3_t ivar_1, type_actual_t list_adt__T){
        bool_t result;

        bool_t ivar_7;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)list_adt__T;
        ivar_5->count++;
        ivar_7 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_10, (list_adt__list_adt_t)ivar_5);
        if (ivar_7){
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_5, list_adt__T);
             result = (bool_t) true;
        } else {
             list_adt__T_t ivar_12;
             /* T */ type_actual_t ivar_16;
             ivar_16 = (type_actual_t)list_adt__T;
             ivar_5->count++;
             ivar_12 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_16, (list_adt__list_adt_t)ivar_5);
             list_adt__list_adt_t ivar_13;
             /* T */ type_actual_t ivar_20;
             ivar_20 = (type_actual_t)list_adt__T;
             ivar_13 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_20, (list_adt__list_adt_t)ivar_5);
             bool_t ivar_22;
             ivar_22 = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_12);
             if (ivar_22){
           list_adt_funtype_2_t ivar_33;
           /* T */ type_actual_t ivar_37;
           ivar_37 = (type_actual_t)list_adt__T;
           ivar_1->count++;
           ivar_33 = (list_adt_funtype_2_t)list_adt__every_1((type_actual_t)ivar_37, (list_adt_funtype_3_t)ivar_1);
           result = (bool_t)ivar_33->ftbl->fptr(ivar_33, ivar_13);
           ivar_33->ftbl->rptr(ivar_33);
             } else {
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_13, list_adt__T);
           result = (bool_t) false;};};
        return result;
}

list_adt_closure_4_t new_list_adt_closure_4(void){
        static struct list_adt_funtype_2_ftbl_s ftbl = {.fptr = (bool_t (*)(list_adt_funtype_2_t, list_adt__list_adt_t))&f_list_adt_closure_4, .mptr = (bool_t (*)(list_adt_funtype_2_t, list_adt__list_adt_t))&m_list_adt_closure_4, .rptr =  (void (*)(list_adt_funtype_2_t))&release_list_adt_closure_4, .cptr = (list_adt_funtype_2_t (*)(list_adt_funtype_2_t))&copy_list_adt_closure_4};
        list_adt_closure_4_t tmp = (list_adt_closure_4_t) safe_malloc(sizeof(struct list_adt_closure_4_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_list_adt_closure_4(list_adt_funtype_2_t closure, type_actual_t list_adt__T){
        list_adt_closure_4_t x = (list_adt_closure_4_t)closure;
        x->count--;
        if (x->count <= 0){
         release_list_adt_funtype_3((list_adt_funtype_3_t)x->fvar_1, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

list_adt_closure_4_t copy_list_adt_closure_4(list_adt_closure_4_t x){
        list_adt_closure_4_t y = new_list_adt_closure_4();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = (type_actual_t)x->fvar_2;
        if (x->htbl != NULL){
            list_adt_funtype_2_htbl_t new_htbl = (list_adt_funtype_2_htbl_t) safe_malloc(sizeof(struct list_adt_funtype_2_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            list_adt_funtype_2_hashentry_t * new_data = (list_adt_funtype_2_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct list_adt_funtype_2_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct list_adt_funtype_2_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_list_adt_closure_5(struct list_adt_closure_5_s * closure, list_adt__list_adt_t bvar){
        bool_t result = h_list_adt_closure_5(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

bool_t m_list_adt_closure_5(struct list_adt_closure_5_s * closure, list_adt__list_adt_t bvar){
        return h_list_adt_closure_5(bvar, closure->fvar_1, closure->fvar_2);}

bool_t h_list_adt_closure_5(list_adt__list_adt_t ivar_5, list_adt_funtype_3_t ivar_1, type_actual_t list_adt__T){
        bool_t result;

        bool_t ivar_7;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)list_adt__T;
        ivar_5->count++;
        ivar_7 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_10, (list_adt__list_adt_t)ivar_5);
        if (ivar_7){
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_5, list_adt__T);
             result = (bool_t) false;
        } else {
             list_adt__T_t ivar_12;
             /* T */ type_actual_t ivar_16;
             ivar_16 = (type_actual_t)list_adt__T;
             ivar_5->count++;
             ivar_12 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_16, (list_adt__list_adt_t)ivar_5);
             list_adt__list_adt_t ivar_13;
             /* T */ type_actual_t ivar_20;
             ivar_20 = (type_actual_t)list_adt__T;
             ivar_13 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_20, (list_adt__list_adt_t)ivar_5);
             bool_t ivar_22;
             ivar_22 = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_12);
             if (ivar_22){
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_13, list_adt__T);
           result = (bool_t) true;
             } else {
           list_adt_funtype_2_t ivar_33;
           /* T */ type_actual_t ivar_37;
           ivar_37 = (type_actual_t)list_adt__T;
           ivar_1->count++;
           ivar_33 = (list_adt_funtype_2_t)list_adt__some_1((type_actual_t)ivar_37, (list_adt_funtype_3_t)ivar_1);
           result = (bool_t)ivar_33->ftbl->fptr(ivar_33, ivar_13);
           ivar_33->ftbl->rptr(ivar_33);};};
        return result;
}

list_adt_closure_5_t new_list_adt_closure_5(void){
        static struct list_adt_funtype_2_ftbl_s ftbl = {.fptr = (bool_t (*)(list_adt_funtype_2_t, list_adt__list_adt_t))&f_list_adt_closure_5, .mptr = (bool_t (*)(list_adt_funtype_2_t, list_adt__list_adt_t))&m_list_adt_closure_5, .rptr =  (void (*)(list_adt_funtype_2_t))&release_list_adt_closure_5, .cptr = (list_adt_funtype_2_t (*)(list_adt_funtype_2_t))&copy_list_adt_closure_5};
        list_adt_closure_5_t tmp = (list_adt_closure_5_t) safe_malloc(sizeof(struct list_adt_closure_5_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_list_adt_closure_5(list_adt_funtype_2_t closure, type_actual_t list_adt__T){
        list_adt_closure_5_t x = (list_adt_closure_5_t)closure;
        x->count--;
        if (x->count <= 0){
         release_list_adt_funtype_3((list_adt_funtype_3_t)x->fvar_1, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

list_adt_closure_5_t copy_list_adt_closure_5(list_adt_closure_5_t x){
        list_adt_closure_5_t y = new_list_adt_closure_5();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = (type_actual_t)x->fvar_2;
        if (x->htbl != NULL){
            list_adt_funtype_2_htbl_t new_htbl = (list_adt_funtype_2_htbl_t) safe_malloc(sizeof(struct list_adt_funtype_2_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            list_adt_funtype_2_hashentry_t * new_data = (list_adt_funtype_2_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct list_adt_funtype_2_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct list_adt_funtype_2_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_list_adt_funtype_6(list_adt_funtype_6_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_6_t copy_list_adt_funtype_6(list_adt_funtype_6_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_6(list_adt_funtype_6_t x, list_adt_funtype_6_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_6(list_adt_funtype_6_t x, type_actual_t list_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"list_adt_funtype_6\""); return result;}


list_adt_record_7_t new_list_adt_record_7(void){
        list_adt_record_7_t tmp = (list_adt_record_7_t) safe_malloc(sizeof(struct list_adt_record_7_s));
        tmp->count = 1;
        return tmp;}

void release_list_adt_record_7(list_adt_record_7_t x, type_actual_t list_adt__T){
        x->count--;
        if (x->count <= 0){
         list_adt__T->release_ptr(x->project_1, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_list_adt_record_7_ptr(pointer_t x, type_actual_t T){
        actual_list_adt_record_7_t actual = (actual_list_adt_record_7_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        release_list_adt_record_7((list_adt_record_7_t)x, list_adt__T);
}

list_adt_record_7_t copy_list_adt_record_7(list_adt_record_7_t x){
        list_adt_record_7_t y = new_list_adt_record_7();
        y->project_1 = x->project_1;
        if (y->project_1 != NULL){y->project_1->count++;};
        mpz_set(y->project_2, x->project_2);
        y->count = 1;
        return y;}

bool_t equal_list_adt_record_7(list_adt_record_7_t x, list_adt_record_7_t y, type_actual_t list_adt__T){
        bool_t tmp = true; tmp = tmp && list_adt__T->equal_ptr(x->project_1, y->project_1, list_adt__T); tmp = tmp && (mpz_cmp(x->project_2, y->project_2) == 0);
        return tmp;}

char * json_list_adt_record_7(list_adt_record_7_t x, type_actual_t list_adt__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, list_adt__T->json_ptr(x->project_1, list_adt__T));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, json_mpz(x->project_2));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_list_adt_record_7_ptr(pointer_t x, pointer_t y, actual_list_adt_record_7_t T){
        actual_list_adt_record_7_t actual = (actual_list_adt_record_7_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return equal_list_adt_record_7((list_adt_record_7_t)x, (list_adt_record_7_t)y, list_adt__T);
}

char * json_list_adt_record_7_ptr(pointer_t x, actual_list_adt_record_7_t T){
        actual_list_adt_record_7_t actual = (actual_list_adt_record_7_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return json_list_adt_record_7((list_adt_record_7_t)x, list_adt__T);
}

actual_list_adt_record_7_t actual_list_adt_record_7(type_actual_t list_adt__T){
        actual_list_adt_record_7_t new = (actual_list_adt_record_7_t)safe_malloc(sizeof(struct actual_list_adt_record_7_s));
        new->equal_ptr = (equal_ptr_t)(*equal_list_adt_record_7_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_list_adt_record_7_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_list_adt_record_7_ptr);
 

        new->list_adt__T = list_adt__T;
 
        return new;
 };

list_adt_record_7_t update_list_adt_record_7_project_1(list_adt_record_7_t x, list_adt__T_t v, type_actual_t list_adt__T){
        list_adt_record_7_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_1 != NULL){list_adt__T->release_ptr(x->project_1, list_adt__T);};}
        else {y = copy_list_adt_record_7(x); x->count--; y->project_1->count--;};
        y->project_1 = (list_adt__T_t)v;
        return y;}

list_adt_record_7_t update_list_adt_record_7_project_2(list_adt_record_7_t x, mpz_ptr_t v){
        list_adt_record_7_t y;
        if (x->count == 1){y = x;}
        else {y = copy_list_adt_record_7(x); x->count--;};
        mpz_set(y->project_2, v);
        return y;}



void release_list_adt_funtype_8(list_adt_funtype_8_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_8_t copy_list_adt_funtype_8(list_adt_funtype_8_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_8(list_adt_funtype_8_t x, list_adt_funtype_8_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_8(list_adt_funtype_8_t x, type_actual_t list_adt__T){char * result = safe_malloc(28); sprintf(result, "%s", "\"list_adt_funtype_8\""); return result;}


mpz_ptr_t f_list_adt_closure_9(struct list_adt_closure_9_s * closure, list_adt__list_adt_t bvar){
        mpz_ptr_t result = h_list_adt_closure_9(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

mpz_ptr_t m_list_adt_closure_9(struct list_adt_closure_9_s * closure, list_adt__list_adt_t bvar){
        return h_list_adt_closure_9(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

mpz_ptr_t h_list_adt_closure_9(list_adt__list_adt_t ivar_6, mpz_ptr_t ivar_1, list_adt_funtype_8_t ivar_2, type_actual_t list_adt__T){
        mpz_ptr_t result;

        /* red */ list_adt_funtype_6_t ivar_7;
        /* T */ type_actual_t ivar_13;
        ivar_13 = (type_actual_t)list_adt__T;
        ivar_2->count++;
        ivar_7 = (list_adt_funtype_6_t)list_adt__reduce_nat((type_actual_t)ivar_13, ivar_1, (list_adt_funtype_8_t)ivar_2);
        bool_t ivar_18;
        /* T */ type_actual_t ivar_21;
        ivar_21 = (type_actual_t)list_adt__T;
        ivar_6->count++;
        ivar_18 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_21, (list_adt__list_adt_t)ivar_6);
        if (ivar_18){
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_6, list_adt__T);
             release_list_adt_funtype_6((list_adt_funtype_6_t)ivar_7, list_adt__T);
             //copying to mpz from mpz;
             mpz_mk_set(result, ivar_1);
        } else {
             list_adt__T_t ivar_23;
             /* T */ type_actual_t ivar_27;
             ivar_27 = (type_actual_t)list_adt__T;
             ivar_6->count++;
             ivar_23 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_27, (list_adt__list_adt_t)ivar_6);
             list_adt__list_adt_t ivar_24;
             /* T */ type_actual_t ivar_31;
             ivar_31 = (type_actual_t)list_adt__T;
             ivar_24 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_31, (list_adt__list_adt_t)ivar_6);
             mpz_ptr_t ivar_46;
             mpz_mk_set(ivar_46, ivar_7->ftbl->fptr(ivar_7, ivar_24));
             ivar_7->ftbl->rptr(ivar_7);
             mpz_mk_set(result, ivar_2->ftbl->mptr(ivar_2, ivar_23, ivar_46));};
        return result;
}

list_adt_closure_9_t new_list_adt_closure_9(void){
        static struct list_adt_funtype_6_ftbl_s ftbl = {.fptr = (mpz_ptr_t (*)(list_adt_funtype_6_t, list_adt__list_adt_t))&f_list_adt_closure_9, .mptr = (mpz_ptr_t (*)(list_adt_funtype_6_t, list_adt__list_adt_t))&m_list_adt_closure_9, .rptr =  (void (*)(list_adt_funtype_6_t))&release_list_adt_closure_9, .cptr = (list_adt_funtype_6_t (*)(list_adt_funtype_6_t))&copy_list_adt_closure_9};
        list_adt_closure_9_t tmp = (list_adt_closure_9_t) safe_malloc(sizeof(struct list_adt_closure_9_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_1);
        return tmp;}

void release_list_adt_closure_9(list_adt_funtype_6_t closure, type_actual_t list_adt__T){
        list_adt_closure_9_t x = (list_adt_closure_9_t)closure;
        x->count--;
        if (x->count <= 0){
         release_list_adt_funtype_8((list_adt_funtype_8_t)x->fvar_2, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

list_adt_closure_9_t copy_list_adt_closure_9(list_adt_closure_9_t x){
        list_adt_closure_9_t y = new_list_adt_closure_9();
        y->ftbl = x->ftbl;

        mpz_set(y->fvar_1, x->fvar_1);
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            list_adt_funtype_6_htbl_t new_htbl = (list_adt_funtype_6_htbl_t) safe_malloc(sizeof(struct list_adt_funtype_6_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            list_adt_funtype_6_hashentry_t * new_data = (list_adt_funtype_6_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct list_adt_funtype_6_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct list_adt_funtype_6_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


list_adt_record_10_t new_list_adt_record_10(void){
        list_adt_record_10_t tmp = (list_adt_record_10_t) safe_malloc(sizeof(struct list_adt_record_10_s));
        tmp->count = 1;
        return tmp;}

void release_list_adt_record_10(list_adt_record_10_t x, type_actual_t list_adt__T){
        x->count--;
        if (x->count <= 0){
         list_adt__T->release_ptr(x->project_1, list_adt__T);
         release_list_adt__list_adt((list_adt__list_adt_t)x->project_3, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_list_adt_record_10_ptr(pointer_t x, type_actual_t T){
        actual_list_adt_record_10_t actual = (actual_list_adt_record_10_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        release_list_adt_record_10((list_adt_record_10_t)x, list_adt__T);
}

list_adt_record_10_t copy_list_adt_record_10(list_adt_record_10_t x){
        list_adt_record_10_t y = new_list_adt_record_10();
        y->project_1 = x->project_1;
        if (y->project_1 != NULL){y->project_1->count++;};
        mpz_set(y->project_2, x->project_2);
        y->project_3 = x->project_3;
        if (y->project_3 != NULL){y->project_3->count++;};
        y->count = 1;
        return y;}

bool_t equal_list_adt_record_10(list_adt_record_10_t x, list_adt_record_10_t y, type_actual_t list_adt__T){
        bool_t tmp = true; tmp = tmp && list_adt__T->equal_ptr(x->project_1, y->project_1, list_adt__T); tmp = tmp && (mpz_cmp(x->project_2, y->project_2) == 0); tmp = tmp && equal_list_adt__list_adt((list_adt__list_adt_t)x->project_3, (list_adt__list_adt_t)y->project_3, list_adt__T);
        return tmp;}

char * json_list_adt_record_10(list_adt_record_10_t x, type_actual_t list_adt__T){
        char * tmp[3]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, list_adt__T->json_ptr(x->project_1, list_adt__T));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, json_mpz(x->project_2));
        char * fld2 = safe_malloc(21);
         sprintf(fld2, "\"project_3\" : ");
        tmp[2] = safe_strcat(fld2, json_list_adt__list_adt((list_adt__list_adt_t)x->project_3, list_adt__T));
         char * result = json_list_with_sep(tmp, 3,  '{', ',', '}');
         for (uint32_t i = 0; i < 3; i++) free(tmp[i]);
        return result;}

bool_t equal_list_adt_record_10_ptr(pointer_t x, pointer_t y, actual_list_adt_record_10_t T){
        actual_list_adt_record_10_t actual = (actual_list_adt_record_10_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return equal_list_adt_record_10((list_adt_record_10_t)x, (list_adt_record_10_t)y, list_adt__T);
}

char * json_list_adt_record_10_ptr(pointer_t x, actual_list_adt_record_10_t T){
        actual_list_adt_record_10_t actual = (actual_list_adt_record_10_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return json_list_adt_record_10((list_adt_record_10_t)x, list_adt__T);
}

actual_list_adt_record_10_t actual_list_adt_record_10(type_actual_t list_adt__T){
        actual_list_adt_record_10_t new = (actual_list_adt_record_10_t)safe_malloc(sizeof(struct actual_list_adt_record_10_s));
        new->equal_ptr = (equal_ptr_t)(*equal_list_adt_record_10_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_list_adt_record_10_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_list_adt_record_10_ptr);
 

        new->list_adt__T = list_adt__T;
 
        return new;
 };

list_adt_record_10_t update_list_adt_record_10_project_1(list_adt_record_10_t x, list_adt__T_t v, type_actual_t list_adt__T){
        list_adt_record_10_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_1 != NULL){list_adt__T->release_ptr(x->project_1, list_adt__T);};}
        else {y = copy_list_adt_record_10(x); x->count--; y->project_1->count--;};
        y->project_1 = (list_adt__T_t)v;
        return y;}

list_adt_record_10_t update_list_adt_record_10_project_2(list_adt_record_10_t x, mpz_ptr_t v){
        list_adt_record_10_t y;
        if (x->count == 1){y = x;}
        else {y = copy_list_adt_record_10(x); x->count--;};
        mpz_set(y->project_2, v);
        return y;}

list_adt_record_10_t update_list_adt_record_10_project_3(list_adt_record_10_t x, list_adt__list_adt_t v, type_actual_t list_adt__T){
        list_adt_record_10_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_3 != NULL){release_list_adt__list_adt((list_adt__list_adt_t)x->project_3, list_adt__T);};}
        else {y = copy_list_adt_record_10(x); x->count--; y->project_3->count--;};
        y->project_3 = (list_adt__list_adt_t)v;
        return y;}



void release_list_adt_funtype_11(list_adt_funtype_11_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_11_t copy_list_adt_funtype_11(list_adt_funtype_11_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_11(list_adt_funtype_11_t x, list_adt_funtype_11_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_11(list_adt_funtype_11_t x, type_actual_t list_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"list_adt_funtype_11\""); return result;}


mpz_ptr_t f_list_adt_closure_12(struct list_adt_closure_12_s * closure, list_adt__list_adt_t bvar){
        mpz_ptr_t result = h_list_adt_closure_12(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

mpz_ptr_t m_list_adt_closure_12(struct list_adt_closure_12_s * closure, list_adt__list_adt_t bvar){
        return h_list_adt_closure_12(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

mpz_ptr_t h_list_adt_closure_12(list_adt__list_adt_t ivar_7, list_adt_funtype_6_t ivar_1, list_adt_funtype_11_t ivar_3, type_actual_t list_adt__T){
        mpz_ptr_t result;

        /* red */ list_adt_funtype_6_t ivar_8;
        /* T */ type_actual_t ivar_14;
        ivar_14 = (type_actual_t)list_adt__T;
        ivar_1->count++;
        ivar_3->count++;
        ivar_8 = (list_adt_funtype_6_t)list_adt__REDUCE_nat((type_actual_t)ivar_14, (list_adt_funtype_6_t)ivar_1, (list_adt_funtype_11_t)ivar_3);
        bool_t ivar_26;
        /* T */ type_actual_t ivar_29;
        ivar_29 = (type_actual_t)list_adt__T;
        ivar_7->count++;
        ivar_26 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_29, (list_adt__list_adt_t)ivar_7);
        if (ivar_26){
             release_list_adt_funtype_6((list_adt_funtype_6_t)ivar_8, list_adt__T);
             mpz_mk_set(result, ivar_1->ftbl->fptr(ivar_1, ivar_7));
        } else {
             list_adt__T_t ivar_31;
             /* T */ type_actual_t ivar_35;
             ivar_35 = (type_actual_t)list_adt__T;
             ivar_7->count++;
             ivar_31 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_35, (list_adt__list_adt_t)ivar_7);
             list_adt__list_adt_t ivar_32;
             /* T */ type_actual_t ivar_39;
             ivar_39 = (type_actual_t)list_adt__T;
             ivar_7->count++;
             ivar_32 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_39, (list_adt__list_adt_t)ivar_7);
             mpz_ptr_t ivar_55;
             mpz_mk_set(ivar_55, ivar_8->ftbl->fptr(ivar_8, ivar_32));
             ivar_8->ftbl->rptr(ivar_8);
             mpz_mk_set(result, ivar_3->ftbl->mptr(ivar_3, ivar_31, ivar_55, ivar_7));};
        return result;
}

list_adt_closure_12_t new_list_adt_closure_12(void){
        static struct list_adt_funtype_6_ftbl_s ftbl = {.fptr = (mpz_ptr_t (*)(list_adt_funtype_6_t, list_adt__list_adt_t))&f_list_adt_closure_12, .mptr = (mpz_ptr_t (*)(list_adt_funtype_6_t, list_adt__list_adt_t))&m_list_adt_closure_12, .rptr =  (void (*)(list_adt_funtype_6_t))&release_list_adt_closure_12, .cptr = (list_adt_funtype_6_t (*)(list_adt_funtype_6_t))&copy_list_adt_closure_12};
        list_adt_closure_12_t tmp = (list_adt_closure_12_t) safe_malloc(sizeof(struct list_adt_closure_12_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_list_adt_closure_12(list_adt_funtype_6_t closure, type_actual_t list_adt__T){
        list_adt_closure_12_t x = (list_adt_closure_12_t)closure;
        x->count--;
        if (x->count <= 0){
         release_list_adt_funtype_6((list_adt_funtype_6_t)x->fvar_1, list_adt__T);
         release_list_adt_funtype_11((list_adt_funtype_11_t)x->fvar_2, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

list_adt_closure_12_t copy_list_adt_closure_12(list_adt_closure_12_t x){
        list_adt_closure_12_t y = new_list_adt_closure_12();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            list_adt_funtype_6_htbl_t new_htbl = (list_adt_funtype_6_htbl_t) safe_malloc(sizeof(struct list_adt_funtype_6_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            list_adt_funtype_6_hashentry_t * new_data = (list_adt_funtype_6_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct list_adt_funtype_6_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct list_adt_funtype_6_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_list_adt_funtype_13(list_adt_funtype_13_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_13_t copy_list_adt_funtype_13(list_adt_funtype_13_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_13(list_adt_funtype_13_t x, list_adt_funtype_13_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_13(list_adt_funtype_13_t x, type_actual_t list_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"list_adt_funtype_13\""); return result;}


list_adt_record_14_t new_list_adt_record_14(void){
        list_adt_record_14_t tmp = (list_adt_record_14_t) safe_malloc(sizeof(struct list_adt_record_14_s));
        tmp->count = 1;
        return tmp;}

void release_list_adt_record_14(list_adt_record_14_t x, type_actual_t list_adt__T){
        x->count--;
        if (x->count <= 0){
         list_adt__T->release_ptr(x->project_1, list_adt__T);
         release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_list_adt_record_14_ptr(pointer_t x, type_actual_t T){
        actual_list_adt_record_14_t actual = (actual_list_adt_record_14_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        release_list_adt_record_14((list_adt_record_14_t)x, list_adt__T);
}

list_adt_record_14_t copy_list_adt_record_14(list_adt_record_14_t x){
        list_adt_record_14_t y = new_list_adt_record_14();
        y->project_1 = x->project_1;
        if (y->project_1 != NULL){y->project_1->count++;};
        y->project_2 = x->project_2;
        if (y->project_2 != NULL){y->project_2->count++;};
        y->count = 1;
        return y;}

bool_t equal_list_adt_record_14(list_adt_record_14_t x, list_adt_record_14_t y, type_actual_t list_adt__T){
        bool_t tmp = true; tmp = tmp && list_adt__T->equal_ptr(x->project_1, y->project_1, list_adt__T); tmp = tmp && equal_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2, (ordstruct_adt__ordstruct_adt_t)y->project_2);
        return tmp;}

char * json_list_adt_record_14(list_adt_record_14_t x, type_actual_t list_adt__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, list_adt__T->json_ptr(x->project_1, list_adt__T));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, json_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_list_adt_record_14_ptr(pointer_t x, pointer_t y, actual_list_adt_record_14_t T){
        actual_list_adt_record_14_t actual = (actual_list_adt_record_14_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return equal_list_adt_record_14((list_adt_record_14_t)x, (list_adt_record_14_t)y, list_adt__T);
}

char * json_list_adt_record_14_ptr(pointer_t x, actual_list_adt_record_14_t T){
        actual_list_adt_record_14_t actual = (actual_list_adt_record_14_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return json_list_adt_record_14((list_adt_record_14_t)x, list_adt__T);
}

actual_list_adt_record_14_t actual_list_adt_record_14(type_actual_t list_adt__T){
        actual_list_adt_record_14_t new = (actual_list_adt_record_14_t)safe_malloc(sizeof(struct actual_list_adt_record_14_s));
        new->equal_ptr = (equal_ptr_t)(*equal_list_adt_record_14_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_list_adt_record_14_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_list_adt_record_14_ptr);
 

        new->list_adt__T = list_adt__T;
 
        return new;
 };

list_adt_record_14_t update_list_adt_record_14_project_1(list_adt_record_14_t x, list_adt__T_t v, type_actual_t list_adt__T){
        list_adt_record_14_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_1 != NULL){list_adt__T->release_ptr(x->project_1, list_adt__T);};}
        else {y = copy_list_adt_record_14(x); x->count--; y->project_1->count--;};
        y->project_1 = (list_adt__T_t)v;
        return y;}

list_adt_record_14_t update_list_adt_record_14_project_2(list_adt_record_14_t x, ordstruct_adt__ordstruct_adt_t v, type_actual_t list_adt__T){
        list_adt_record_14_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_2 != NULL){release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2);};}
        else {y = copy_list_adt_record_14(x); x->count--; y->project_2->count--;};
        y->project_2 = (ordstruct_adt__ordstruct_adt_t)v;
        return y;}



void release_list_adt_funtype_15(list_adt_funtype_15_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_15_t copy_list_adt_funtype_15(list_adt_funtype_15_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_15(list_adt_funtype_15_t x, list_adt_funtype_15_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_15(list_adt_funtype_15_t x, type_actual_t list_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"list_adt_funtype_15\""); return result;}


ordstruct_adt__ordstruct_adt_t f_list_adt_closure_16(struct list_adt_closure_16_s * closure, list_adt__list_adt_t bvar){
        ordstruct_adt__ordstruct_adt_t result = h_list_adt_closure_16(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

ordstruct_adt__ordstruct_adt_t m_list_adt_closure_16(struct list_adt_closure_16_s * closure, list_adt__list_adt_t bvar){
        return h_list_adt_closure_16(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

ordstruct_adt__ordstruct_adt_t h_list_adt_closure_16(list_adt__list_adt_t ivar_6, ordstruct_adt__ordstruct_adt_t ivar_1, list_adt_funtype_15_t ivar_2, type_actual_t list_adt__T){
        ordstruct_adt__ordstruct_adt_t result;

        /* red */ list_adt_funtype_13_t ivar_7;
        /* T */ type_actual_t ivar_13;
        ivar_13 = (type_actual_t)list_adt__T;
        ivar_1->count++;
        ivar_2->count++;
        ivar_7 = (list_adt_funtype_13_t)list_adt__reduce_ordinal((type_actual_t)ivar_13, (ordstruct_adt__ordstruct_adt_t)ivar_1, (list_adt_funtype_15_t)ivar_2);
        bool_t ivar_18;
        /* T */ type_actual_t ivar_21;
        ivar_21 = (type_actual_t)list_adt__T;
        ivar_6->count++;
        ivar_18 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_21, (list_adt__list_adt_t)ivar_6);
        if (ivar_18){
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_6, list_adt__T);
             release_list_adt_funtype_13((list_adt_funtype_13_t)ivar_7, list_adt__T);
             //copying to ordstruct_adt__ordstruct_adt from ordstruct_adt__ordstruct_adt;
             result = (ordstruct_adt__ordstruct_adt_t)ivar_1;
             if (result != NULL) result->count++;
        } else {
             list_adt__T_t ivar_23;
             /* T */ type_actual_t ivar_27;
             ivar_27 = (type_actual_t)list_adt__T;
             ivar_6->count++;
             ivar_23 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_27, (list_adt__list_adt_t)ivar_6);
             list_adt__list_adt_t ivar_24;
             /* T */ type_actual_t ivar_31;
             ivar_31 = (type_actual_t)list_adt__T;
             ivar_24 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_31, (list_adt__list_adt_t)ivar_6);
             ordstruct_adt__ordstruct_adt_t ivar_46;
             ivar_46 = (ordstruct_adt__ordstruct_adt_t)ivar_7->ftbl->fptr(ivar_7, ivar_24);
             ivar_7->ftbl->rptr(ivar_7);
             result = (ordstruct_adt__ordstruct_adt_t)ivar_2->ftbl->mptr(ivar_2, ivar_23, ivar_46);};
        return result;
}

list_adt_closure_16_t new_list_adt_closure_16(void){
        static struct list_adt_funtype_13_ftbl_s ftbl = {.fptr = (ordstruct_adt__ordstruct_adt_t (*)(list_adt_funtype_13_t, list_adt__list_adt_t))&f_list_adt_closure_16, .mptr = (ordstruct_adt__ordstruct_adt_t (*)(list_adt_funtype_13_t, list_adt__list_adt_t))&m_list_adt_closure_16, .rptr =  (void (*)(list_adt_funtype_13_t))&release_list_adt_closure_16, .cptr = (list_adt_funtype_13_t (*)(list_adt_funtype_13_t))&copy_list_adt_closure_16};
        list_adt_closure_16_t tmp = (list_adt_closure_16_t) safe_malloc(sizeof(struct list_adt_closure_16_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_list_adt_closure_16(list_adt_funtype_13_t closure, type_actual_t list_adt__T){
        list_adt_closure_16_t x = (list_adt_closure_16_t)closure;
        x->count--;
        if (x->count <= 0){
         release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->fvar_1);
         release_list_adt_funtype_15((list_adt_funtype_15_t)x->fvar_2, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

list_adt_closure_16_t copy_list_adt_closure_16(list_adt_closure_16_t x){
        list_adt_closure_16_t y = new_list_adt_closure_16();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            list_adt_funtype_13_htbl_t new_htbl = (list_adt_funtype_13_htbl_t) safe_malloc(sizeof(struct list_adt_funtype_13_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            list_adt_funtype_13_hashentry_t * new_data = (list_adt_funtype_13_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct list_adt_funtype_13_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct list_adt_funtype_13_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


list_adt_record_17_t new_list_adt_record_17(void){
        list_adt_record_17_t tmp = (list_adt_record_17_t) safe_malloc(sizeof(struct list_adt_record_17_s));
        tmp->count = 1;
        return tmp;}

void release_list_adt_record_17(list_adt_record_17_t x, type_actual_t list_adt__T){
        x->count--;
        if (x->count <= 0){
         list_adt__T->release_ptr(x->project_1, list_adt__T);
         release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2);
         release_list_adt__list_adt((list_adt__list_adt_t)x->project_3, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_list_adt_record_17_ptr(pointer_t x, type_actual_t T){
        actual_list_adt_record_17_t actual = (actual_list_adt_record_17_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        release_list_adt_record_17((list_adt_record_17_t)x, list_adt__T);
}

list_adt_record_17_t copy_list_adt_record_17(list_adt_record_17_t x){
        list_adt_record_17_t y = new_list_adt_record_17();
        y->project_1 = x->project_1;
        if (y->project_1 != NULL){y->project_1->count++;};
        y->project_2 = x->project_2;
        if (y->project_2 != NULL){y->project_2->count++;};
        y->project_3 = x->project_3;
        if (y->project_3 != NULL){y->project_3->count++;};
        y->count = 1;
        return y;}

bool_t equal_list_adt_record_17(list_adt_record_17_t x, list_adt_record_17_t y, type_actual_t list_adt__T){
        bool_t tmp = true; tmp = tmp && list_adt__T->equal_ptr(x->project_1, y->project_1, list_adt__T); tmp = tmp && equal_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2, (ordstruct_adt__ordstruct_adt_t)y->project_2); tmp = tmp && equal_list_adt__list_adt((list_adt__list_adt_t)x->project_3, (list_adt__list_adt_t)y->project_3, list_adt__T);
        return tmp;}

char * json_list_adt_record_17(list_adt_record_17_t x, type_actual_t list_adt__T){
        char * tmp[3]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, list_adt__T->json_ptr(x->project_1, list_adt__T));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, json_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2));
        char * fld2 = safe_malloc(21);
         sprintf(fld2, "\"project_3\" : ");
        tmp[2] = safe_strcat(fld2, json_list_adt__list_adt((list_adt__list_adt_t)x->project_3, list_adt__T));
         char * result = json_list_with_sep(tmp, 3,  '{', ',', '}');
         for (uint32_t i = 0; i < 3; i++) free(tmp[i]);
        return result;}

bool_t equal_list_adt_record_17_ptr(pointer_t x, pointer_t y, actual_list_adt_record_17_t T){
        actual_list_adt_record_17_t actual = (actual_list_adt_record_17_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return equal_list_adt_record_17((list_adt_record_17_t)x, (list_adt_record_17_t)y, list_adt__T);
}

char * json_list_adt_record_17_ptr(pointer_t x, actual_list_adt_record_17_t T){
        actual_list_adt_record_17_t actual = (actual_list_adt_record_17_t)T;
        type_actual_t list_adt__T = actual->list_adt__T;
        return json_list_adt_record_17((list_adt_record_17_t)x, list_adt__T);
}

actual_list_adt_record_17_t actual_list_adt_record_17(type_actual_t list_adt__T){
        actual_list_adt_record_17_t new = (actual_list_adt_record_17_t)safe_malloc(sizeof(struct actual_list_adt_record_17_s));
        new->equal_ptr = (equal_ptr_t)(*equal_list_adt_record_17_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_list_adt_record_17_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_list_adt_record_17_ptr);
 

        new->list_adt__T = list_adt__T;
 
        return new;
 };

list_adt_record_17_t update_list_adt_record_17_project_1(list_adt_record_17_t x, list_adt__T_t v, type_actual_t list_adt__T){
        list_adt_record_17_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_1 != NULL){list_adt__T->release_ptr(x->project_1, list_adt__T);};}
        else {y = copy_list_adt_record_17(x); x->count--; y->project_1->count--;};
        y->project_1 = (list_adt__T_t)v;
        return y;}

list_adt_record_17_t update_list_adt_record_17_project_2(list_adt_record_17_t x, ordstruct_adt__ordstruct_adt_t v, type_actual_t list_adt__T){
        list_adt_record_17_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_2 != NULL){release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->project_2);};}
        else {y = copy_list_adt_record_17(x); x->count--; y->project_2->count--;};
        y->project_2 = (ordstruct_adt__ordstruct_adt_t)v;
        return y;}

list_adt_record_17_t update_list_adt_record_17_project_3(list_adt_record_17_t x, list_adt__list_adt_t v, type_actual_t list_adt__T){
        list_adt_record_17_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_3 != NULL){release_list_adt__list_adt((list_adt__list_adt_t)x->project_3, list_adt__T);};}
        else {y = copy_list_adt_record_17(x); x->count--; y->project_3->count--;};
        y->project_3 = (list_adt__list_adt_t)v;
        return y;}



void release_list_adt_funtype_18(list_adt_funtype_18_t x, type_actual_t list_adt__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

list_adt_funtype_18_t copy_list_adt_funtype_18(list_adt_funtype_18_t x){return x->ftbl->cptr(x);}

bool_t equal_list_adt_funtype_18(list_adt_funtype_18_t x, list_adt_funtype_18_t y, type_actual_t list_adt__T){
        return false;}

char* json_list_adt_funtype_18(list_adt_funtype_18_t x, type_actual_t list_adt__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"list_adt_funtype_18\""); return result;}


ordstruct_adt__ordstruct_adt_t f_list_adt_closure_19(struct list_adt_closure_19_s * closure, list_adt__list_adt_t bvar){
        ordstruct_adt__ordstruct_adt_t result = h_list_adt_closure_19(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

ordstruct_adt__ordstruct_adt_t m_list_adt_closure_19(struct list_adt_closure_19_s * closure, list_adt__list_adt_t bvar){
        return h_list_adt_closure_19(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

ordstruct_adt__ordstruct_adt_t h_list_adt_closure_19(list_adt__list_adt_t ivar_7, list_adt_funtype_13_t ivar_1, list_adt_funtype_18_t ivar_3, type_actual_t list_adt__T){
        ordstruct_adt__ordstruct_adt_t result;

        /* red */ list_adt_funtype_13_t ivar_8;
        /* T */ type_actual_t ivar_14;
        ivar_14 = (type_actual_t)list_adt__T;
        ivar_1->count++;
        ivar_3->count++;
        ivar_8 = (list_adt_funtype_13_t)list_adt__REDUCE_ordinal((type_actual_t)ivar_14, (list_adt_funtype_13_t)ivar_1, (list_adt_funtype_18_t)ivar_3);
        bool_t ivar_26;
        /* T */ type_actual_t ivar_29;
        ivar_29 = (type_actual_t)list_adt__T;
        ivar_7->count++;
        ivar_26 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_29, (list_adt__list_adt_t)ivar_7);
        if (ivar_26){
             release_list_adt_funtype_13((list_adt_funtype_13_t)ivar_8, list_adt__T);
             result = (ordstruct_adt__ordstruct_adt_t)ivar_1->ftbl->fptr(ivar_1, ivar_7);
        } else {
             list_adt__T_t ivar_31;
             /* T */ type_actual_t ivar_35;
             ivar_35 = (type_actual_t)list_adt__T;
             ivar_7->count++;
             ivar_31 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_35, (list_adt__list_adt_t)ivar_7);
             list_adt__list_adt_t ivar_32;
             /* T */ type_actual_t ivar_39;
             ivar_39 = (type_actual_t)list_adt__T;
             ivar_7->count++;
             ivar_32 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_39, (list_adt__list_adt_t)ivar_7);
             ordstruct_adt__ordstruct_adt_t ivar_55;
             ivar_55 = (ordstruct_adt__ordstruct_adt_t)ivar_8->ftbl->fptr(ivar_8, ivar_32);
             ivar_8->ftbl->rptr(ivar_8);
             result = (ordstruct_adt__ordstruct_adt_t)ivar_3->ftbl->mptr(ivar_3, ivar_31, ivar_55, ivar_7);};
        return result;
}

list_adt_closure_19_t new_list_adt_closure_19(void){
        static struct list_adt_funtype_13_ftbl_s ftbl = {.fptr = (ordstruct_adt__ordstruct_adt_t (*)(list_adt_funtype_13_t, list_adt__list_adt_t))&f_list_adt_closure_19, .mptr = (ordstruct_adt__ordstruct_adt_t (*)(list_adt_funtype_13_t, list_adt__list_adt_t))&m_list_adt_closure_19, .rptr =  (void (*)(list_adt_funtype_13_t))&release_list_adt_closure_19, .cptr = (list_adt_funtype_13_t (*)(list_adt_funtype_13_t))&copy_list_adt_closure_19};
        list_adt_closure_19_t tmp = (list_adt_closure_19_t) safe_malloc(sizeof(struct list_adt_closure_19_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_list_adt_closure_19(list_adt_funtype_13_t closure, type_actual_t list_adt__T){
        list_adt_closure_19_t x = (list_adt_closure_19_t)closure;
        x->count--;
        if (x->count <= 0){
         release_list_adt_funtype_13((list_adt_funtype_13_t)x->fvar_1, list_adt__T);
         release_list_adt_funtype_18((list_adt_funtype_18_t)x->fvar_2, list_adt__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

list_adt_closure_19_t copy_list_adt_closure_19(list_adt_closure_19_t x){
        list_adt_closure_19_t y = new_list_adt_closure_19();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            list_adt_funtype_13_htbl_t new_htbl = (list_adt_funtype_13_htbl_t) safe_malloc(sizeof(struct list_adt_funtype_13_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            list_adt_funtype_13_hashentry_t * new_data = (list_adt_funtype_13_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct list_adt_funtype_13_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct list_adt_funtype_13_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

bool_t rec_list_adt__nullp(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1){
        bool_t  result;

        uint8_t ivar_3;
        ivar_3 = (uint8_t)0;
        uint8_t ivar_2;
        ivar_2 = (uint8_t)ivar_1->list_adt__list_adt_index;
        release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
        result = (ivar_2 == ivar_3);
        
        
        return result;
}

bool_t rec_list_adt__consp(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1){
        bool_t  result;

        uint8_t ivar_3;
        ivar_3 = (uint8_t)1;
        uint8_t ivar_2;
        ivar_2 = (uint8_t)ivar_1->list_adt__list_adt_index;
        release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
        result = (ivar_2 == ivar_3);
        
        
        return result;
}

list_adt__cons_t update_list_adt__list_adt_car(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__T_t ivar_3){
        list_adt__cons_t  result;

        list_adt__cons_t ivar_2;
        //copying to list_adt__cons from list_adt__list_adt;
        ivar_2 = (list_adt__cons_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
        result = (list_adt__cons_t)update_list_adt__cons_car(ivar_2, ivar_3, list_adt__T);
        
        result->count++;
        return result;
}

list_adt__T_t acc_list_adt__list_adt_car(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1){
        list_adt__T_t  result;

        list_adt__cons_t ivar_2;
        //copying to list_adt__cons from list_adt__list_adt;
        ivar_2 = (list_adt__cons_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
        result = (list_adt__T_t)ivar_2->car;
        result->count++;
        release_list_adt__cons((list_adt__cons_t)ivar_2, list_adt__T);
        
        result->count++;
        return result;
}

list_adt__cons_t update_list_adt__list_adt_cdr(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__list_adt_t ivar_3){
        list_adt__cons_t  result;

        list_adt__cons_t ivar_2;
        //copying to list_adt__cons from list_adt__list_adt;
        ivar_2 = (list_adt__cons_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
        result = (list_adt__cons_t)update_list_adt__cons_cdr(ivar_2, ivar_3, list_adt__T);
        
        result->count++;
        return result;
}

list_adt__list_adt_t acc_list_adt__list_adt_cdr(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1){
        list_adt__list_adt_t  result;

        list_adt__cons_t ivar_2;
        //copying to list_adt__cons from list_adt__list_adt;
        ivar_2 = (list_adt__cons_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
        result = (list_adt__list_adt_t)ivar_2->cdr;
        result->count++;
        release_list_adt__cons((list_adt__cons_t)ivar_2, list_adt__T);
        
        result->count++;
        return result;
}

list_adt__list_adt_t con_list_adt__null(type_actual_t list_adt__T){
        list_adt__list_adt_t  result;

        uint8_t ivar_1;
        ivar_1 = (uint8_t)0;
        list_adt__list_adt_t tmp3850 = new_list_adt__list_adt();;
        result = (list_adt__list_adt_t)tmp3850;
        tmp3850->list_adt__list_adt_index = (uint8_t)ivar_1;
        
        result->count++;
        return result;
}

list_adt__list_adt_t con_list_adt__cons(type_actual_t list_adt__T, list_adt__T_t ivar_2, list_adt__list_adt_t ivar_3){
        list_adt__list_adt_t  result;

        uint8_t ivar_1;
        ivar_1 = (uint8_t)1;
        list_adt__cons_t tmp3851 = new_list_adt__cons();;
        result = (list_adt__list_adt_t)tmp3851;
        tmp3851->list_adt__list_adt_index = (uint8_t)ivar_1;
        tmp3851->car = (list_adt__T_t)ivar_2;
        tmp3851->cdr = (list_adt__list_adt_t)ivar_3;
        
        result->count++;
        return result;
}

uint8_t list_adt__ord(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1){
        uint8_t  result;

        bool_t ivar_3;
        /* T */ type_actual_t ivar_6;
        ivar_6 = (type_actual_t)list_adt__T;
        ivar_1->count++;
        ivar_3 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_6, (list_adt__list_adt_t)ivar_1);
        if (ivar_3){
             result = (uint8_t)0;
        } else {
             result = (uint8_t)1;};
        
        
        return result;
}

list_adt_funtype_2_t list_adt__every_1(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1){
        list_adt_funtype_2_t  result;

        list_adt_closure_4_t cl3854;
        cl3854 = new_list_adt_closure_4();
        cl3854->fvar_1 = (list_adt_funtype_3_t)ivar_1;
        if (cl3854->fvar_1 != NULL) cl3854->fvar_1->count++;
        cl3854->fvar_2 = (type_actual_t)list_adt__T;
        release_list_adt_funtype_3((list_adt_funtype_3_t)ivar_1, list_adt__T);
        result = (list_adt_funtype_2_t)cl3854;
        
        result->count++;
        return result;
}

bool_t list_adt__every_2(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1, list_adt__list_adt_t ivar_3){
        bool_t  result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_8;
        ivar_8 = (type_actual_t)list_adt__T;
        ivar_3->count++;
        ivar_5 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_8, (list_adt__list_adt_t)ivar_3);
        if (ivar_5){
             release_list_adt_funtype_3((list_adt_funtype_3_t)ivar_1, list_adt__T);
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_3, list_adt__T);
             result = (bool_t) true;
        } else {
             list_adt__T_t ivar_10;
             /* T */ type_actual_t ivar_14;
             ivar_14 = (type_actual_t)list_adt__T;
             ivar_3->count++;
             ivar_10 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_14, (list_adt__list_adt_t)ivar_3);
             list_adt__list_adt_t ivar_11;
             /* T */ type_actual_t ivar_18;
             ivar_18 = (type_actual_t)list_adt__T;
             ivar_11 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_18, (list_adt__list_adt_t)ivar_3);
             bool_t ivar_20;
             ivar_20 = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_10);
             if (ivar_20){
           /* T */ type_actual_t ivar_31;
           ivar_31 = (type_actual_t)list_adt__T;
           result = (bool_t)list_adt__every_2((type_actual_t)ivar_31, (list_adt_funtype_3_t)ivar_1, (list_adt__list_adt_t)ivar_11);
             } else {
           release_list_adt_funtype_3((list_adt_funtype_3_t)ivar_1, list_adt__T);
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_11, list_adt__T);
           result = (bool_t) false;};};
        
        
        return result;
}

list_adt_funtype_2_t list_adt__some_1(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1){
        list_adt_funtype_2_t  result;

        list_adt_closure_5_t cl3857;
        cl3857 = new_list_adt_closure_5();
        cl3857->fvar_1 = (list_adt_funtype_3_t)ivar_1;
        if (cl3857->fvar_1 != NULL) cl3857->fvar_1->count++;
        cl3857->fvar_2 = (type_actual_t)list_adt__T;
        release_list_adt_funtype_3((list_adt_funtype_3_t)ivar_1, list_adt__T);
        result = (list_adt_funtype_2_t)cl3857;
        
        result->count++;
        return result;
}

bool_t list_adt__some_2(type_actual_t list_adt__T, list_adt_funtype_3_t ivar_1, list_adt__list_adt_t ivar_3){
        bool_t  result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_8;
        ivar_8 = (type_actual_t)list_adt__T;
        ivar_3->count++;
        ivar_5 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_8, (list_adt__list_adt_t)ivar_3);
        if (ivar_5){
             release_list_adt_funtype_3((list_adt_funtype_3_t)ivar_1, list_adt__T);
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_3, list_adt__T);
             result = (bool_t) false;
        } else {
             list_adt__T_t ivar_10;
             /* T */ type_actual_t ivar_14;
             ivar_14 = (type_actual_t)list_adt__T;
             ivar_3->count++;
             ivar_10 = (list_adt__T_t)acc_list_adt__list_adt_car((type_actual_t)ivar_14, (list_adt__list_adt_t)ivar_3);
             list_adt__list_adt_t ivar_11;
             /* T */ type_actual_t ivar_18;
             ivar_18 = (type_actual_t)list_adt__T;
             ivar_11 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_18, (list_adt__list_adt_t)ivar_3);
             bool_t ivar_20;
             ivar_20 = (bool_t)ivar_1->ftbl->fptr(ivar_1, ivar_10);
             if (ivar_20){
           release_list_adt_funtype_3((list_adt_funtype_3_t)ivar_1, list_adt__T);
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_11, list_adt__T);
           result = (bool_t) true;
             } else {
           /* T */ type_actual_t ivar_31;
           ivar_31 = (type_actual_t)list_adt__T;
           result = (bool_t)list_adt__some_2((type_actual_t)ivar_31, (list_adt_funtype_3_t)ivar_1, (list_adt__list_adt_t)ivar_11);};};
        
        
        return result;
}

bool_t list_adt__subterm(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__list_adt_t ivar_2){
        bool_t  result;

        bool_t ivar_3;
        ivar_1->count++;
        ivar_2->count++;
        ivar_3 = (bool_t) equal_list_adt__list_adt(ivar_1, ivar_2, list_adt__T);
        if (ivar_3){
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_2, list_adt__T);
             result = (bool_t) true;
        } else {
             bool_t ivar_9;
             /* T */ type_actual_t ivar_12;
             ivar_12 = (type_actual_t)list_adt__T;
             ivar_2->count++;
             ivar_9 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_12, (list_adt__list_adt_t)ivar_2);
             if (ivar_9){
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_2, list_adt__T);
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
           result = (bool_t) false;
             } else {
           list_adt__list_adt_t ivar_15;
           /* T */ type_actual_t ivar_22;
           ivar_22 = (type_actual_t)list_adt__T;
           ivar_15 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_22, (list_adt__list_adt_t)ivar_2);
           /* T */ type_actual_t ivar_27;
           ivar_27 = (type_actual_t)list_adt__T;
           result = (bool_t)list_adt__subterm((type_actual_t)ivar_27, (list_adt__list_adt_t)ivar_1, (list_adt__list_adt_t)ivar_15);};};
        
        
        return result;
}

bool_t list_adt__doublelessp(type_actual_t list_adt__T, list_adt__list_adt_t ivar_1, list_adt__list_adt_t ivar_2){
        bool_t  result;

        bool_t ivar_4;
        /* T */ type_actual_t ivar_7;
        ivar_7 = (type_actual_t)list_adt__T;
        ivar_2->count++;
        ivar_4 = (bool_t)rec_list_adt__nullp((type_actual_t)ivar_7, (list_adt__list_adt_t)ivar_2);
        if (ivar_4){
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_2, list_adt__T);
             release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
             result = (bool_t) false;
        } else {
             list_adt__list_adt_t ivar_10;
             /* T */ type_actual_t ivar_17;
             ivar_17 = (type_actual_t)list_adt__T;
             ivar_10 = (list_adt__list_adt_t)acc_list_adt__list_adt_cdr((type_actual_t)ivar_17, (list_adt__list_adt_t)ivar_2);
             bool_t ivar_19;
             ivar_1->count++;
             ivar_10->count++;
             ivar_19 = (bool_t) equal_list_adt__list_adt(ivar_1, ivar_10, list_adt__T);
             if (ivar_19){
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_1, list_adt__T);
           release_list_adt__list_adt((list_adt__list_adt_t)ivar_10, list_adt__T);
           result = (bool_t) true;
             } else {
           /* T */ type_actual_t ivar_27;
           ivar_27 = (type_actual_t)list_adt__T;
           result = (bool_t)list_adt__doublelessp((type_actual_t)ivar_27, (list_adt__list_adt_t)ivar_1, (list_adt__list_adt_t)ivar_10);};};
        
        
        return result;
}

list_adt_funtype_6_t list_adt__reduce_nat(type_actual_t list_adt__T, mpz_ptr_t ivar_1, list_adt_funtype_8_t ivar_2){
        list_adt_funtype_6_t  result;

        list_adt_closure_9_t cl3870;
        cl3870 = new_list_adt_closure_9();
        mpz_set(cl3870->fvar_1, ivar_1);
        cl3870->fvar_2 = (list_adt_funtype_8_t)ivar_2;
        if (cl3870->fvar_2 != NULL) cl3870->fvar_2->count++;
        cl3870->fvar_3 = (type_actual_t)list_adt__T;
        release_list_adt_funtype_8((list_adt_funtype_8_t)ivar_2, list_adt__T);
        result = (list_adt_funtype_6_t)cl3870;
        
        result->count++;
        return result;
}

list_adt_funtype_6_t list_adt__REDUCE_nat(type_actual_t list_adt__T, list_adt_funtype_6_t ivar_1, list_adt_funtype_11_t ivar_3){
        list_adt_funtype_6_t  result;

        list_adt_closure_12_t cl3884;
        cl3884 = new_list_adt_closure_12();
        cl3884->fvar_1 = (list_adt_funtype_6_t)ivar_1;
        if (cl3884->fvar_1 != NULL) cl3884->fvar_1->count++;
        cl3884->fvar_2 = (list_adt_funtype_11_t)ivar_3;
        if (cl3884->fvar_2 != NULL) cl3884->fvar_2->count++;
        cl3884->fvar_3 = (type_actual_t)list_adt__T;
        release_list_adt_funtype_11((list_adt_funtype_11_t)ivar_3, list_adt__T);
        release_list_adt_funtype_6((list_adt_funtype_6_t)ivar_1, list_adt__T);
        result = (list_adt_funtype_6_t)cl3884;
        
        result->count++;
        return result;
}

list_adt_funtype_13_t list_adt__reduce_ordinal(type_actual_t list_adt__T, ordstruct_adt__ordstruct_adt_t ivar_1, list_adt_funtype_15_t ivar_2){
        list_adt_funtype_13_t  result;

        list_adt_closure_16_t cl3894;
        cl3894 = new_list_adt_closure_16();
        cl3894->fvar_1 = (ordstruct_adt__ordstruct_adt_t)ivar_1;
        if (cl3894->fvar_1 != NULL) cl3894->fvar_1->count++;
        cl3894->fvar_2 = (list_adt_funtype_15_t)ivar_2;
        if (cl3894->fvar_2 != NULL) cl3894->fvar_2->count++;
        cl3894->fvar_3 = (type_actual_t)list_adt__T;
        release_list_adt_funtype_15((list_adt_funtype_15_t)ivar_2, list_adt__T);
        release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)ivar_1);
        result = (list_adt_funtype_13_t)cl3894;
        
        result->count++;
        return result;
}

list_adt_funtype_13_t list_adt__REDUCE_ordinal(type_actual_t list_adt__T, list_adt_funtype_13_t ivar_1, list_adt_funtype_18_t ivar_3){
        list_adt_funtype_13_t  result;

        list_adt_closure_19_t cl3908;
        cl3908 = new_list_adt_closure_19();
        cl3908->fvar_1 = (list_adt_funtype_13_t)ivar_1;
        if (cl3908->fvar_1 != NULL) cl3908->fvar_1->count++;
        cl3908->fvar_2 = (list_adt_funtype_18_t)ivar_3;
        if (cl3908->fvar_2 != NULL) cl3908->fvar_2->count++;
        cl3908->fvar_3 = (type_actual_t)list_adt__T;
        release_list_adt_funtype_18((list_adt_funtype_18_t)ivar_3, list_adt__T);
        release_list_adt_funtype_13((list_adt_funtype_13_t)ivar_1, list_adt__T);
        result = (list_adt_funtype_13_t)cl3908;
        
        result->count++;
        return result;
}