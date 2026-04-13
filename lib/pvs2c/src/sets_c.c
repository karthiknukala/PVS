//Code generated using pvs2ir2c
#include "sets_c.h"

void release_sets__set(sets__set_t x, type_actual_t sets__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

sets__set_t copy_sets__set(sets__set_t x){return x->ftbl->cptr(x);}

bool_t equal_sets__set(sets__set_t x, sets__set_t y, type_actual_t sets__T){
        return false;}

char* json_sets__set(sets__set_t x, type_actual_t sets__T){char * result = safe_malloc(19); sprintf(result, "%s", "\"sets__set\""); return result;}


bool_t f_sets_closure_1(struct sets_closure_1_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_1(bvar, closure->fvar_1); 
        return result;}

bool_t m_sets_closure_1(struct sets_closure_1_s * closure, sets__T_t bvar){
        return h_sets_closure_1(bvar, closure->fvar_1);}

bool_t h_sets_closure_1(sets__T_t ivar_7, type_actual_t sets__T){
        bool_t result;

        result = (bool_t)sets__emptyset((type_actual_t)sets__T, (sets__T_t)ivar_7);
        return result;
}

sets_closure_1_t new_sets_closure_1(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_1, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_1, .rptr =  (void (*)(sets__set_t))&release_sets_closure_1, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_1};
        sets_closure_1_t tmp = (sets_closure_1_t) safe_malloc(sizeof(struct sets_closure_1_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_1(sets__set_t closure, type_actual_t sets__T){
        sets_closure_1_t x = (sets_closure_1_t)closure;
        x->count--;
        if (x->count <= 0){
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_1_t copy_sets_closure_1(sets_closure_1_t x){
        sets_closure_1_t y = new_sets_closure_1();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_2(struct sets_closure_2_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_2(bvar, closure->fvar_1); 
        return result;}

bool_t m_sets_closure_2(struct sets_closure_2_s * closure, sets__T_t bvar){
        return h_sets_closure_2(bvar, closure->fvar_1);}

bool_t h_sets_closure_2(sets__T_t ivar_12, type_actual_t sets__T){
        bool_t result;

        result = (bool_t)sets__fullset((type_actual_t)sets__T, (sets__T_t)ivar_12);
        return result;
}

sets_closure_2_t new_sets_closure_2(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_2, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_2, .rptr =  (void (*)(sets__set_t))&release_sets_closure_2, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_2};
        sets_closure_2_t tmp = (sets_closure_2_t) safe_malloc(sizeof(struct sets_closure_2_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_2(sets__set_t closure, type_actual_t sets__T){
        sets_closure_2_t x = (sets_closure_2_t)closure;
        x->count--;
        if (x->count <= 0){
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_2_t copy_sets_closure_2(sets_closure_2_t x){
        sets_closure_2_t y = new_sets_closure_2();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_3(struct sets_closure_3_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

bool_t m_sets_closure_3(struct sets_closure_3_s * closure, sets__T_t bvar){
        return h_sets_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

bool_t h_sets_closure_3(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)sets__T;
        ivar_4->count++;
        ivar_1->count++;
        ivar_5 = (bool_t)sets__member((type_actual_t)ivar_10, (sets__T_t)ivar_4, (sets__set_t)ivar_1);
        if (ivar_5){
             sets__T->release_ptr(ivar_4, sets__T);
             result = (bool_t) true;
        } else {
             /* T */ type_actual_t ivar_16;
             ivar_16 = (type_actual_t)sets__T;
             ivar_2->count++;
             result = (bool_t)sets__member((type_actual_t)ivar_16, (sets__T_t)ivar_4, (sets__set_t)ivar_2);};
        return result;
}

sets_closure_3_t new_sets_closure_3(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_3, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_3, .rptr =  (void (*)(sets__set_t))&release_sets_closure_3, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_3};
        sets_closure_3_t tmp = (sets_closure_3_t) safe_malloc(sizeof(struct sets_closure_3_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_3(sets__set_t closure, type_actual_t sets__T){
        sets_closure_3_t x = (sets_closure_3_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_1, sets__T);
         release_sets__set((sets__set_t)x->fvar_2, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_3_t copy_sets_closure_3(sets_closure_3_t x){
        sets_closure_3_t y = new_sets_closure_3();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_4(struct sets_closure_4_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_4(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

bool_t m_sets_closure_4(struct sets_closure_4_s * closure, sets__T_t bvar){
        return h_sets_closure_4(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

bool_t h_sets_closure_4(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)sets__T;
        ivar_4->count++;
        ivar_1->count++;
        ivar_5 = (bool_t)sets__in((type_actual_t)ivar_10, (sets__T_t)ivar_4, (sets__set_t)ivar_1);
        if (ivar_5){
             sets__T->release_ptr(ivar_4, sets__T);
             result = (bool_t) true;
        } else {
             /* T */ type_actual_t ivar_16;
             ivar_16 = (type_actual_t)sets__T;
             ivar_2->count++;
             result = (bool_t)sets__in((type_actual_t)ivar_16, (sets__T_t)ivar_4, (sets__set_t)ivar_2);};
        return result;
}

sets_closure_4_t new_sets_closure_4(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_4, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_4, .rptr =  (void (*)(sets__set_t))&release_sets_closure_4, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_4};
        sets_closure_4_t tmp = (sets_closure_4_t) safe_malloc(sizeof(struct sets_closure_4_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_4(sets__set_t closure, type_actual_t sets__T){
        sets_closure_4_t x = (sets_closure_4_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_1, sets__T);
         release_sets__set((sets__set_t)x->fvar_2, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_4_t copy_sets_closure_4(sets_closure_4_t x){
        sets_closure_4_t y = new_sets_closure_4();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_5(struct sets_closure_5_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

bool_t m_sets_closure_5(struct sets_closure_5_s * closure, sets__T_t bvar){
        return h_sets_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

bool_t h_sets_closure_5(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)sets__T;
        ivar_4->count++;
        ivar_1->count++;
        ivar_5 = (bool_t)sets__member((type_actual_t)ivar_10, (sets__T_t)ivar_4, (sets__set_t)ivar_1);
        if (ivar_5){
             /* T */ type_actual_t ivar_16;
             ivar_16 = (type_actual_t)sets__T;
             ivar_2->count++;
             result = (bool_t)sets__member((type_actual_t)ivar_16, (sets__T_t)ivar_4, (sets__set_t)ivar_2);
        } else {
             sets__T->release_ptr(ivar_4, sets__T);
             result = (bool_t) false;};
        return result;
}

sets_closure_5_t new_sets_closure_5(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_5, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_5, .rptr =  (void (*)(sets__set_t))&release_sets_closure_5, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_5};
        sets_closure_5_t tmp = (sets_closure_5_t) safe_malloc(sizeof(struct sets_closure_5_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_5(sets__set_t closure, type_actual_t sets__T){
        sets_closure_5_t x = (sets_closure_5_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_1, sets__T);
         release_sets__set((sets__set_t)x->fvar_2, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_5_t copy_sets_closure_5(sets_closure_5_t x){
        sets_closure_5_t y = new_sets_closure_5();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_6(struct sets_closure_6_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_6(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

bool_t m_sets_closure_6(struct sets_closure_6_s * closure, sets__T_t bvar){
        return h_sets_closure_6(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

bool_t h_sets_closure_6(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)sets__T;
        ivar_4->count++;
        ivar_1->count++;
        ivar_5 = (bool_t)sets__in((type_actual_t)ivar_10, (sets__T_t)ivar_4, (sets__set_t)ivar_1);
        if (ivar_5){
             /* T */ type_actual_t ivar_16;
             ivar_16 = (type_actual_t)sets__T;
             ivar_2->count++;
             result = (bool_t)sets__in((type_actual_t)ivar_16, (sets__T_t)ivar_4, (sets__set_t)ivar_2);
        } else {
             sets__T->release_ptr(ivar_4, sets__T);
             result = (bool_t) false;};
        return result;
}

sets_closure_6_t new_sets_closure_6(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_6, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_6, .rptr =  (void (*)(sets__set_t))&release_sets_closure_6, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_6};
        sets_closure_6_t tmp = (sets_closure_6_t) safe_malloc(sizeof(struct sets_closure_6_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_6(sets__set_t closure, type_actual_t sets__T){
        sets_closure_6_t x = (sets_closure_6_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_1, sets__T);
         release_sets__set((sets__set_t)x->fvar_2, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_6_t copy_sets_closure_6(sets_closure_6_t x){
        sets_closure_6_t y = new_sets_closure_6();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_7(struct sets_closure_7_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_7(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

bool_t m_sets_closure_7(struct sets_closure_7_s * closure, sets__T_t bvar){
        return h_sets_closure_7(bvar, closure->fvar_1, closure->fvar_2);}

bool_t h_sets_closure_7(sets__T_t ivar_3, sets__set_t ivar_1, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_4;
        /* T */ type_actual_t ivar_8;
        ivar_8 = (type_actual_t)sets__T;
        ivar_1->count++;
        ivar_4 = (bool_t)sets__member((type_actual_t)ivar_8, (sets__T_t)ivar_3, (sets__set_t)ivar_1);
        result = !ivar_4;
        return result;
}

sets_closure_7_t new_sets_closure_7(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_7, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_7, .rptr =  (void (*)(sets__set_t))&release_sets_closure_7, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_7};
        sets_closure_7_t tmp = (sets_closure_7_t) safe_malloc(sizeof(struct sets_closure_7_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_7(sets__set_t closure, type_actual_t sets__T){
        sets_closure_7_t x = (sets_closure_7_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_1, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_7_t copy_sets_closure_7(sets_closure_7_t x){
        sets_closure_7_t y = new_sets_closure_7();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = (type_actual_t)x->fvar_2;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_8(struct sets_closure_8_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_8(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

bool_t m_sets_closure_8(struct sets_closure_8_s * closure, sets__T_t bvar){
        return h_sets_closure_8(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

bool_t h_sets_closure_8(sets__T_t ivar_4, sets__set_t ivar_2, sets__set_t ivar_1, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_5;
        /* T */ type_actual_t ivar_10;
        ivar_10 = (type_actual_t)sets__T;
        ivar_4->count++;
        ivar_1->count++;
        ivar_5 = (bool_t)sets__member((type_actual_t)ivar_10, (sets__T_t)ivar_4, (sets__set_t)ivar_1);
        if (ivar_5){
             bool_t ivar_13;
             /* T */ type_actual_t ivar_17;
             ivar_17 = (type_actual_t)sets__T;
             ivar_2->count++;
             ivar_13 = (bool_t)sets__member((type_actual_t)ivar_17, (sets__T_t)ivar_4, (sets__set_t)ivar_2);
             result = !ivar_13;
        } else {
             sets__T->release_ptr(ivar_4, sets__T);
             result = (bool_t) false;};
        return result;
}

sets_closure_8_t new_sets_closure_8(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_8, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_8, .rptr =  (void (*)(sets__set_t))&release_sets_closure_8, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_8};
        sets_closure_8_t tmp = (sets_closure_8_t) safe_malloc(sizeof(struct sets_closure_8_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_8(sets__set_t closure, type_actual_t sets__T){
        sets_closure_8_t x = (sets_closure_8_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_1, sets__T);
         release_sets__set((sets__set_t)x->fvar_2, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_8_t copy_sets_closure_8(sets_closure_8_t x){
        sets_closure_8_t y = new_sets_closure_8();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_9(struct sets_closure_9_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_9(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

bool_t m_sets_closure_9(struct sets_closure_9_s * closure, sets__T_t bvar){
        return h_sets_closure_9(bvar, closure->fvar_1, closure->fvar_2);}

bool_t h_sets_closure_9(sets__T_t ivar_3, sets__T_t ivar_1, type_actual_t sets__T){
        bool_t result;

        ivar_1->count++;
        result = (bool_t) sets__T->equal_ptr(ivar_3, ivar_1, sets__T);
        return result;
}

sets_closure_9_t new_sets_closure_9(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_9, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_9, .rptr =  (void (*)(sets__set_t))&release_sets_closure_9, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_9};
        sets_closure_9_t tmp = (sets_closure_9_t) safe_malloc(sizeof(struct sets_closure_9_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_9(sets__set_t closure, type_actual_t sets__T){
        sets_closure_9_t x = (sets_closure_9_t)closure;
        x->count--;
        if (x->count <= 0){
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_9_t copy_sets_closure_9(sets_closure_9_t x){
        sets_closure_9_t y = new_sets_closure_9();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = (type_actual_t)x->fvar_2;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_10(struct sets_closure_10_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_10(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

bool_t m_sets_closure_10(struct sets_closure_10_s * closure, sets__T_t bvar){
        return h_sets_closure_10(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

bool_t h_sets_closure_10(sets__T_t ivar_4, sets__T_t ivar_1, sets__set_t ivar_2, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_5;
        ivar_1->count++;
        ivar_4->count++;
        ivar_5 = (bool_t) sets__T->equal_ptr(ivar_1, ivar_4, sets__T);
        if (ivar_5){
             sets__T->release_ptr(ivar_4, sets__T);
             result = (bool_t) true;
        } else {
             /* T */ type_actual_t ivar_13;
             ivar_13 = (type_actual_t)sets__T;
             ivar_2->count++;
             result = (bool_t)sets__member((type_actual_t)ivar_13, (sets__T_t)ivar_4, (sets__set_t)ivar_2);};
        return result;
}

sets_closure_10_t new_sets_closure_10(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_10, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_10, .rptr =  (void (*)(sets__set_t))&release_sets_closure_10, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_10};
        sets_closure_10_t tmp = (sets_closure_10_t) safe_malloc(sizeof(struct sets_closure_10_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_10(sets__set_t closure, type_actual_t sets__T){
        sets_closure_10_t x = (sets_closure_10_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_2, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_10_t copy_sets_closure_10(sets_closure_10_t x){
        sets_closure_10_t y = new_sets_closure_10();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


bool_t f_sets_closure_11(struct sets_closure_11_s * closure, sets__T_t bvar){
        bool_t result = h_sets_closure_11(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3); 
        return result;}

bool_t m_sets_closure_11(struct sets_closure_11_s * closure, sets__T_t bvar){
        return h_sets_closure_11(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

bool_t h_sets_closure_11(sets__T_t ivar_4, sets__T_t ivar_1, sets__set_t ivar_2, type_actual_t sets__T){
        bool_t result;

        bool_t ivar_5;
        ivar_1->count++;
        ivar_4->count++;
        ivar_5 = (bool_t) !sets__T->equal_ptr(ivar_1, ivar_4, sets__T);
        if (ivar_5){
             /* T */ type_actual_t ivar_13;
             ivar_13 = (type_actual_t)sets__T;
             ivar_2->count++;
             result = (bool_t)sets__member((type_actual_t)ivar_13, (sets__T_t)ivar_4, (sets__set_t)ivar_2);
        } else {
             sets__T->release_ptr(ivar_4, sets__T);
             result = (bool_t) false;};
        return result;
}

sets_closure_11_t new_sets_closure_11(void){
        static struct sets__set_ftbl_s ftbl = {.fptr = (bool_t (*)(sets__set_t, sets__T_t))&f_sets_closure_11, .mptr = (bool_t (*)(sets__set_t, sets__T_t))&m_sets_closure_11, .rptr =  (void (*)(sets__set_t))&release_sets_closure_11, .cptr = (sets__set_t (*)(sets__set_t))&copy_sets_closure_11};
        sets_closure_11_t tmp = (sets_closure_11_t) safe_malloc(sizeof(struct sets_closure_11_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_sets_closure_11(sets__set_t closure, type_actual_t sets__T){
        sets_closure_11_t x = (sets_closure_11_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sets__set((sets__set_t)x->fvar_2, sets__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sets_closure_11_t copy_sets_closure_11(sets_closure_11_t x){
        sets_closure_11_t y = new_sets_closure_11();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        y->fvar_3 = (type_actual_t)x->fvar_3;
        if (x->htbl != NULL){
            sets__set_htbl_t new_htbl = (sets__set_htbl_t) safe_malloc(sizeof(struct sets__set_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sets__set_hashentry_t * new_data = (sets__set_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sets__set_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sets__set_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_sets__setofsets(sets__setofsets_t x, type_actual_t sets__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

sets__setofsets_t copy_sets__setofsets(sets__setofsets_t x){return x->ftbl->cptr(x);}

bool_t equal_sets__setofsets(sets__setofsets_t x, sets__setofsets_t y, type_actual_t sets__T){
        return false;}

char* json_sets__setofsets(sets__setofsets_t x, type_actual_t sets__T){char * result = safe_malloc(25); sprintf(result, "%s", "\"sets__setofsets\""); return result;}

bool_t sets__member(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2){
        bool_t  result;

        result = (bool_t)ivar_2->ftbl->fptr(ivar_2, ivar_1);
        ivar_2->ftbl->rptr(ivar_2);
        
        
        return result;
}

bool_t sets__in(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2){
        bool_t  result;

        result = (bool_t)ivar_2->ftbl->fptr(ivar_2, ivar_1);
        ivar_2->ftbl->rptr(ivar_2);
        
        
        return result;
}

bool_t sets__notin(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2){
        bool_t  result;

        bool_t ivar_3;
        ivar_3 = (bool_t)ivar_2->ftbl->fptr(ivar_2, ivar_1);
        ivar_2->ftbl->rptr(ivar_2);
        result = !ivar_3;
        
        
        return result;
}

bool_t sets__emptyset(type_actual_t sets__T, sets__T_t ivar_1){
        bool_t  result;

        result = (bool_t) false;
        
        
        return result;
}

bool_t sets___u2205_(type_actual_t sets__T, sets__T_t ivar_1){
        bool_t  result;

        result = (bool_t) false;
        
        
        return result;
}

bool_t sets__fullset(type_actual_t sets__T, sets__T_t ivar_1){
        bool_t  result;

        result = (bool_t) true;
        
        
        return result;
}

bool_t sets__nontrivialp(type_actual_t sets__T, sets__set_t ivar_1){
        bool_t  result;

        bool_t ivar_2;
        sets__set_t ivar_5;
        sets_closure_1_t cl3651;
        cl3651 = new_sets_closure_1();
        cl3651->fvar_1 = (type_actual_t)sets__T;
        ivar_5 = (sets__set_t)cl3651;
        ivar_1->count++;
        ivar_2 = (bool_t) !equal_sets__set(ivar_1, ivar_5, sets__T);
        if (ivar_2){
             sets__set_t ivar_10;
             sets_closure_2_t cl3652;
             cl3652 = new_sets_closure_2();
             cl3652->fvar_1 = (type_actual_t)sets__T;
             ivar_10 = (sets__set_t)cl3652;
             result = (bool_t) !equal_sets__set(ivar_1, ivar_10, sets__T);
        } else {
             release_sets__set((sets__set_t)ivar_1, sets__T);
             result = (bool_t) false;};
        
        
        return result;
}

sets__set_t sets__union(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        sets_closure_3_t cl3653;
        cl3653 = new_sets_closure_3();
        cl3653->fvar_1 = (sets__set_t)ivar_2;
        if (cl3653->fvar_1 != NULL) cl3653->fvar_1->count++;
        cl3653->fvar_2 = (sets__set_t)ivar_1;
        if (cl3653->fvar_2 != NULL) cl3653->fvar_2->count++;
        cl3653->fvar_3 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_2, sets__T);
        release_sets__set((sets__set_t)ivar_1, sets__T);
        result = (sets__set_t)cl3653;
        
        result->count++;
        return result;
}

sets__set_t sets__cup(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        sets_closure_4_t cl3654;
        cl3654 = new_sets_closure_4();
        cl3654->fvar_1 = (sets__set_t)ivar_2;
        if (cl3654->fvar_1 != NULL) cl3654->fvar_1->count++;
        cl3654->fvar_2 = (sets__set_t)ivar_1;
        if (cl3654->fvar_2 != NULL) cl3654->fvar_2->count++;
        cl3654->fvar_3 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_2, sets__T);
        release_sets__set((sets__set_t)ivar_1, sets__T);
        result = (sets__set_t)cl3654;
        
        result->count++;
        return result;
}

sets__set_t sets__intersection(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        sets_closure_5_t cl3655;
        cl3655 = new_sets_closure_5();
        cl3655->fvar_1 = (sets__set_t)ivar_2;
        if (cl3655->fvar_1 != NULL) cl3655->fvar_1->count++;
        cl3655->fvar_2 = (sets__set_t)ivar_1;
        if (cl3655->fvar_2 != NULL) cl3655->fvar_2->count++;
        cl3655->fvar_3 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_2, sets__T);
        release_sets__set((sets__set_t)ivar_1, sets__T);
        result = (sets__set_t)cl3655;
        
        result->count++;
        return result;
}

sets__set_t sets__cap(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        sets_closure_6_t cl3656;
        cl3656 = new_sets_closure_6();
        cl3656->fvar_1 = (sets__set_t)ivar_2;
        if (cl3656->fvar_1 != NULL) cl3656->fvar_1->count++;
        cl3656->fvar_2 = (sets__set_t)ivar_1;
        if (cl3656->fvar_2 != NULL) cl3656->fvar_2->count++;
        cl3656->fvar_3 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_2, sets__T);
        release_sets__set((sets__set_t)ivar_1, sets__T);
        result = (sets__set_t)cl3656;
        
        result->count++;
        return result;
}

sets__set_t sets__complement(type_actual_t sets__T, sets__set_t ivar_1){
        sets__set_t  result;

        sets_closure_7_t cl3657;
        cl3657 = new_sets_closure_7();
        cl3657->fvar_1 = (sets__set_t)ivar_1;
        if (cl3657->fvar_1 != NULL) cl3657->fvar_1->count++;
        cl3657->fvar_2 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_1, sets__T);
        result = (sets__set_t)cl3657;
        
        result->count++;
        return result;
}

sets__set_t sets__difference(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        sets_closure_8_t cl3658;
        cl3658 = new_sets_closure_8();
        cl3658->fvar_1 = (sets__set_t)ivar_2;
        if (cl3658->fvar_1 != NULL) cl3658->fvar_1->count++;
        cl3658->fvar_2 = (sets__set_t)ivar_1;
        if (cl3658->fvar_2 != NULL) cl3658->fvar_2->count++;
        cl3658->fvar_3 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_2, sets__T);
        release_sets__set((sets__set_t)ivar_1, sets__T);
        result = (sets__set_t)cl3658;
        
        result->count++;
        return result;
}

sets__set_t sets__symmetric_difference(type_actual_t sets__T, sets__set_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        /* T */ type_actual_t ivar_18;
        ivar_18 = (type_actual_t)sets__T;
        sets__set_t ivar_19;
        /* T */ type_actual_t ivar_8;
        ivar_8 = (type_actual_t)sets__T;
        ivar_1->count++;
        ivar_2->count++;
        ivar_19 = (sets__set_t)sets__difference((type_actual_t)ivar_8, (sets__set_t)ivar_1, (sets__set_t)ivar_2);
        sets__set_t ivar_20;
        /* T */ type_actual_t ivar_14;
        ivar_14 = (type_actual_t)sets__T;
        ivar_20 = (sets__set_t)sets__difference((type_actual_t)ivar_14, (sets__set_t)ivar_2, (sets__set_t)ivar_1);
        result = (sets__set_t)sets__union((type_actual_t)ivar_18, (sets__set_t)ivar_19, (sets__set_t)ivar_20);
        
        result->count++;
        return result;
}

sets__set_t sets__singleton(type_actual_t sets__T, sets__T_t ivar_1){
        sets__set_t  result;

        sets_closure_9_t cl3659;
        cl3659 = new_sets_closure_9();
        cl3659->fvar_1 = (sets__T_t)ivar_1;
        cl3659->fvar_2 = (type_actual_t)sets__T;
        sets__T->release_ptr(ivar_1, sets__T);
        result = (sets__set_t)cl3659;
        
        result->count++;
        return result;
}

sets__set_t sets__add(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        sets_closure_10_t cl3660;
        cl3660 = new_sets_closure_10();
        cl3660->fvar_1 = (sets__T_t)ivar_1;
        cl3660->fvar_2 = (sets__set_t)ivar_2;
        if (cl3660->fvar_2 != NULL) cl3660->fvar_2->count++;
        cl3660->fvar_3 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_2, sets__T);
        sets__T->release_ptr(ivar_1, sets__T);
        result = (sets__set_t)cl3660;
        
        result->count++;
        return result;
}

sets__set_t sets__remove(type_actual_t sets__T, sets__T_t ivar_1, sets__set_t ivar_2){
        sets__set_t  result;

        sets_closure_11_t cl3661;
        cl3661 = new_sets_closure_11();
        cl3661->fvar_1 = (sets__T_t)ivar_1;
        cl3661->fvar_2 = (sets__set_t)ivar_2;
        if (cl3661->fvar_2 != NULL) cl3661->fvar_2->count++;
        cl3661->fvar_3 = (type_actual_t)sets__T;
        release_sets__set((sets__set_t)ivar_2, sets__T);
        sets__T->release_ptr(ivar_1, sets__T);
        result = (sets__set_t)cl3661;
        
        result->count++;
        return result;
}