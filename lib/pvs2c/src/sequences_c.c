//Code generated using pvs2ir2c
#include "sequences_c.h"

void release_sequences__sequence(sequences__sequence_t x, type_actual_t sequences__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

sequences__sequence_t copy_sequences__sequence(sequences__sequence_t x){return x->ftbl->cptr(x);}

uint32_t lookup_sequences__sequence(sequences__sequence_htbl_t htbl, mpz_ptr_t i, uint32_t ihash){
        uint32_t mask = htbl->size - 1;
        uint32_t hashindex = ihash & mask;
        sequences__sequence_hashentry_t data = htbl->data[hashindex];
        bool_t keyzero;


        int64_t tmp3682 = mpz_cmp_ui(data.key, 0);
        keyzero = (tmp3682 == 0);
        bool_t keymatch;

        int64_t tmp3683 = mpz_cmp(data.key, i);
        keymatch = (tmp3683 == 0);
        while ((!keyzero || data.keyhash != 0) &&
                 (data.keyhash != ihash || !keymatch)){
                hashindex++;
                hashindex = hashindex & mask;
                data = htbl->data[hashindex];


                int64_t tmp3682 = mpz_cmp_ui(data.key, 0);
                keyzero = (tmp3682 == 0);


                int64_t tmp3683 = mpz_cmp(data.key, i);
                keymatch = (tmp3683 == 0);
                }
        return hashindex;
        }

sequences__sequence_t dupdate_sequences__sequence(sequences__sequence_t a, mpz_ptr_t i, sequences__T_t v, type_actual_t sequences__T){
        sequences__sequence_htbl_t htbl = a->htbl;
        if (htbl == NULL){//construct new htbl
                htbl = (sequences__sequence_htbl_t)safe_malloc(sizeof(struct sequences__sequence_htbl_s));
                htbl->size = HTBL_DEFAULT_SIZE; htbl->num_entries = 0;
                htbl->data = (sequences__sequence_hashentry_t *)safe_malloc(HTBL_DEFAULT_SIZE * sizeof(struct sequences__sequence_hashentry_s));
                for (uint32_t j = 0; j < HTBL_DEFAULT_SIZE; j++){mpz_init(htbl->data[j].key);mpz_set_ui(htbl->data[j].key, 0); htbl->data[j].keyhash = 0;
                }
                a->htbl = htbl;
        }
        uint32_t size = htbl->size;
        uint32_t num_entries = htbl->num_entries;
        sequences__sequence_hashentry_t * data = htbl->data;
        if (num_entries/3 >  size/5){//resize data
                uint32_t new_size = 2*size; uint32_t new_mask = new_size - 1;
                if (size >= HTBL_MAX_SIZE) out_of_memory();
                sequences__sequence_hashentry_t * new_data = (sequences__sequence_hashentry_t *)safe_malloc(new_size * sizeof(struct sequences__sequence_hashentry_s));
                for (uint32_t j = 0; j < new_size; j++){
                        new_data[j].key = 0;
                        new_data[j].keyhash = 0;}
                for (uint32_t j = 0; j < size; j++){//transfer entries
                        uint32_t keyhash = data[j].keyhash;
                        bool_t keyzero;
                        int64_t tmp3684 = mpz_cmp_ui(data[j].key, 0);
                        keyzero = (tmp3684 == 0);

                        if (!keyzero || keyhash != 0){
                                uint32_t new_loc = keyhash ^ new_mask;
                                int64_t tmp3685 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                keyzero = (tmp3685 == 0);

                                while (keyzero && new_data[new_loc].keyhash == 0){
                                        new_loc++;
                                        new_loc = new_loc ^ new_mask;

                                        int64_t tmp3686 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                        keyzero = (tmp3686 == 0);

                                }
                                mpz_set(new_data[new_loc].key, data[j].key);
                                new_data[new_loc].keyhash = keyhash;
                                new_data[new_loc].value = (sequences__T_t)data[j].value;
                                }}
                htbl->size = new_size;
                htbl->num_entries = num_entries;
                htbl->data = new_data;
                safe_free(data);}
        uint32_t ihash = mpz_hash(i);
        uint32_t hashindex = lookup_sequences__sequence(htbl, i, ihash);
        sequences__sequence_hashentry_t hentry = htbl->data[hashindex];
        uint32_t hkeyhash = hentry.keyhash;
        bool_t hentrykeyzero;
        int64_t tmp3687 = mpz_cmp_ui(hentry.key, 0);
        hentrykeyzero = (tmp3687 == 0);

        if (hentrykeyzero && (hkeyhash == 0))
                {mpz_set(htbl->data[hashindex].key, i); htbl->data[hashindex].keyhash = ihash; htbl->data[hashindex].value = (sequences__T_t)v; htbl->num_entries++;}
            else {sequences__T_t tempvalue;tempvalue = (sequences__T_t)htbl->data[hashindex].value;htbl->data[hashindex].value = (sequences__T_t)v;if (v != NULL) v->count++;if (tempvalue != NULL)sequences__T->release_ptr(tempvalue, sequences__T);};
        return a;

}

sequences__sequence_t update_sequences__sequence(sequences__sequence_t a, mpz_ptr_t i, sequences__T_t v, type_actual_t sequences__T){
        if (a->count == 1){
                return dupdate_sequences__sequence(a, i, v, sequences__T);
            } else {
                sequences__sequence_t x = copy_sequences__sequence(a);
                a->count--;
                return dupdate_sequences__sequence(x, i, v, sequences__T);
            }}

bool_t equal_sequences__sequence(sequences__sequence_t x, sequences__sequence_t y, type_actual_t sequences__T){
        return false;}

char* json_sequences__sequence(sequences__sequence_t x, type_actual_t sequences__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"sequences__sequence\""); return result;}


sequences__T_t f_sequences_closure_1(struct sequences_closure_1_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        sequences__sequence_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_sequences__sequence(htbl, bvar, hash);
        sequences__sequence_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3688 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3688 == 0);
        if (!keyzero || entry.keyhash != 0){
            sequences__T_t result;
            result = (sequences__T_t)entry.value;
            return result;}
        

        return h_sequences_closure_1(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);};

return h_sequences_closure_1(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

sequences__T_t m_sequences_closure_1(struct sequences_closure_1_s * closure, mpz_ptr_t bvar){
        return h_sequences_closure_1(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

sequences__T_t h_sequences_closure_1(mpz_ptr_t ivar_4, type_actual_t sequences__T, sequences__sequence_t ivar_1, mpz_ptr_t ivar_2){
        sequences__T_t result;

        mpz_ptr_t ivar_11;
        mpz_mk_add(ivar_11, ivar_2, ivar_4);
        result = (sequences__T_t)ivar_1->ftbl->fptr(ivar_1, ivar_11);
        return result;
}

sequences_closure_1_t new_sequences_closure_1(void){
        static struct sequences__sequence_ftbl_s ftbl = {.fptr = (sequences__T_t (*)(sequences__sequence_t, mpz_ptr_t))&f_sequences_closure_1, .mptr = (sequences__T_t (*)(sequences__sequence_t, mpz_ptr_t))&m_sequences_closure_1, .rptr =  (void (*)(sequences__sequence_t))&release_sequences_closure_1, .cptr = (sequences__sequence_t (*)(sequences__sequence_t))&copy_sequences_closure_1};
        sequences_closure_1_t tmp = (sequences_closure_1_t) safe_malloc(sizeof(struct sequences_closure_1_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_3);
        return tmp;}

void release_sequences_closure_1(sequences__sequence_t closure, type_actual_t sequences__T){
        sequences_closure_1_t x = (sequences_closure_1_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sequences__sequence((sequences__sequence_t)x->fvar_2, sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sequences_closure_1_t copy_sequences_closure_1(sequences_closure_1_t x){
        sequences_closure_1_t y = new_sequences_closure_1();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        mpz_set(y->fvar_3, x->fvar_3);
        if (x->htbl != NULL){
            sequences__sequence_htbl_t new_htbl = (sequences__sequence_htbl_t) safe_malloc(sizeof(struct sequences__sequence_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sequences__sequence_hashentry_t * new_data = (sequences__sequence_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sequences__sequence_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sequences__sequence_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


sequences__T_t f_sequences_closure_2(struct sequences_closure_2_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        sequences__sequence_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_sequences__sequence(htbl, bvar, hash);
        sequences__sequence_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3690 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3690 == 0);
        if (!keyzero || entry.keyhash != 0){
            sequences__T_t result;
            result = (sequences__T_t)entry.value;
            return result;}
        

        return h_sequences_closure_2(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);};

return h_sequences_closure_2(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

sequences__T_t m_sequences_closure_2(struct sequences_closure_2_s * closure, mpz_ptr_t bvar){
        return h_sequences_closure_2(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

sequences__T_t h_sequences_closure_2(mpz_ptr_t ivar_4, type_actual_t sequences__T, sequences__sequence_t ivar_2, mpz_ptr_t ivar_1){
        sequences__T_t result;

        bool_t ivar_5;
        int64_t tmp3691 = mpz_cmp(ivar_4, ivar_1);
        ivar_5 = (tmp3691 < 0);
        if (ivar_5){
             result = (sequences__T_t)ivar_2->ftbl->fptr(ivar_2, ivar_4);
        } else {
             mpz_ptr_t ivar_19;
             uint8_t ivar_15;
             ivar_15 = (uint8_t)1;
             mpz_mk_set_ui(ivar_19, (uint64_t)ivar_15);
             mpz_add(ivar_19, ivar_19, ivar_4);
             result = (sequences__T_t)ivar_2->ftbl->fptr(ivar_2, ivar_19);};
        return result;
}

sequences_closure_2_t new_sequences_closure_2(void){
        static struct sequences__sequence_ftbl_s ftbl = {.fptr = (sequences__T_t (*)(sequences__sequence_t, mpz_ptr_t))&f_sequences_closure_2, .mptr = (sequences__T_t (*)(sequences__sequence_t, mpz_ptr_t))&m_sequences_closure_2, .rptr =  (void (*)(sequences__sequence_t))&release_sequences_closure_2, .cptr = (sequences__sequence_t (*)(sequences__sequence_t))&copy_sequences_closure_2};
        sequences_closure_2_t tmp = (sequences_closure_2_t) safe_malloc(sizeof(struct sequences_closure_2_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_3);
        return tmp;}

void release_sequences_closure_2(sequences__sequence_t closure, type_actual_t sequences__T){
        sequences_closure_2_t x = (sequences_closure_2_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sequences__sequence((sequences__sequence_t)x->fvar_2, sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sequences_closure_2_t copy_sequences_closure_2(sequences_closure_2_t x){
        sequences_closure_2_t y = new_sequences_closure_2();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        mpz_set(y->fvar_3, x->fvar_3);
        if (x->htbl != NULL){
            sequences__sequence_htbl_t new_htbl = (sequences__sequence_htbl_t) safe_malloc(sizeof(struct sequences__sequence_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sequences__sequence_hashentry_t * new_data = (sequences__sequence_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sequences__sequence_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sequences__sequence_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


sequences__T_t f_sequences_closure_3(struct sequences_closure_3_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        sequences__sequence_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_sequences__sequence(htbl, bvar, hash);
        sequences__sequence_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3693 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3693 == 0);
        if (!keyzero || entry.keyhash != 0){
            sequences__T_t result;
            result = (sequences__T_t)entry.value;
            return result;}
        

        return h_sequences_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);};

return h_sequences_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);}

sequences__T_t m_sequences_closure_3(struct sequences_closure_3_s * closure, mpz_ptr_t bvar){
        return h_sequences_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);}

sequences__T_t h_sequences_closure_3(mpz_ptr_t ivar_5, type_actual_t sequences__T, mpz_ptr_t ivar_2, sequences__sequence_t ivar_3, sequences__T_t ivar_1){
        sequences__T_t result;

        bool_t ivar_6;
        int64_t tmp3694 = mpz_cmp(ivar_5, ivar_2);
        ivar_6 = (tmp3694 < 0);
        if (ivar_6){
             result = (sequences__T_t)ivar_3->ftbl->fptr(ivar_3, ivar_5);
        } else {
             bool_t ivar_14;
             int64_t tmp3695 = mpz_cmp(ivar_5, ivar_2);
             ivar_14 = (tmp3695 == 0);
             if (ivar_14){
           //copying to sequences__T from sequences__T;
           result = (sequences__T_t)ivar_1;
             } else {
           mpz_ptr_t ivar_24;
           uint8_t ivar_20;
           ivar_20 = (uint8_t)1;
           mpz_mk_sub_ui(ivar_24, ivar_5, (uint64_t)ivar_20);
           result = (sequences__T_t)ivar_3->ftbl->fptr(ivar_3, ivar_24);};};
        return result;
}

sequences_closure_3_t new_sequences_closure_3(void){
        static struct sequences__sequence_ftbl_s ftbl = {.fptr = (sequences__T_t (*)(sequences__sequence_t, mpz_ptr_t))&f_sequences_closure_3, .mptr = (sequences__T_t (*)(sequences__sequence_t, mpz_ptr_t))&m_sequences_closure_3, .rptr =  (void (*)(sequences__sequence_t))&release_sequences_closure_3, .cptr = (sequences__sequence_t (*)(sequences__sequence_t))&copy_sequences_closure_3};
        sequences_closure_3_t tmp = (sequences_closure_3_t) safe_malloc(sizeof(struct sequences_closure_3_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        return tmp;}

void release_sequences_closure_3(sequences__sequence_t closure, type_actual_t sequences__T){
        sequences_closure_3_t x = (sequences_closure_3_t)closure;
        x->count--;
        if (x->count <= 0){
         release_sequences__sequence((sequences__sequence_t)x->fvar_3, sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

sequences_closure_3_t copy_sequences_closure_3(sequences_closure_3_t x){
        sequences_closure_3_t y = new_sequences_closure_3();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        mpz_set(y->fvar_2, x->fvar_2);
        y->fvar_3 = x->fvar_3; x->fvar_3->count++;
        y->fvar_4 = x->fvar_4; x->fvar_4->count++;
        if (x->htbl != NULL){
            sequences__sequence_htbl_t new_htbl = (sequences__sequence_htbl_t) safe_malloc(sizeof(struct sequences__sequence_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            sequences__sequence_hashentry_t * new_data = (sequences__sequence_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct sequences__sequence_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct sequences__sequence_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


sequences_record_4_t new_sequences_record_4(void){
        sequences_record_4_t tmp = (sequences_record_4_t) safe_malloc(sizeof(struct sequences_record_4_s));
        tmp->count = 1;
        return tmp;}

void release_sequences_record_4(sequences_record_4_t x, type_actual_t sequences__T){
        x->count--;
        if (x->count <= 0){
         sequences__T->release_ptr(x->project_1, sequences__T);
         sequences__T->release_ptr(x->project_2, sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_sequences_record_4_ptr(pointer_t x, type_actual_t T){
        actual_sequences_record_4_t actual = (actual_sequences_record_4_t)T;
        type_actual_t sequences__T = actual->sequences__T;
        release_sequences_record_4((sequences_record_4_t)x, sequences__T);
}

sequences_record_4_t copy_sequences_record_4(sequences_record_4_t x){
        sequences_record_4_t y = new_sequences_record_4();
        y->project_1 = x->project_1;
        if (y->project_1 != NULL){y->project_1->count++;};
        y->project_2 = x->project_2;
        if (y->project_2 != NULL){y->project_2->count++;};
        y->count = 1;
        return y;}

bool_t equal_sequences_record_4(sequences_record_4_t x, sequences_record_4_t y, type_actual_t sequences__T){
        bool_t tmp = true; tmp = tmp && sequences__T->equal_ptr(x->project_1, y->project_1, sequences__T); tmp = tmp && sequences__T->equal_ptr(x->project_2, y->project_2, sequences__T);
        return tmp;}

char * json_sequences_record_4(sequences_record_4_t x, type_actual_t sequences__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, sequences__T->json_ptr(x->project_1, sequences__T));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, sequences__T->json_ptr(x->project_2, sequences__T));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_sequences_record_4_ptr(pointer_t x, pointer_t y, actual_sequences_record_4_t T){
        actual_sequences_record_4_t actual = (actual_sequences_record_4_t)T;
        type_actual_t sequences__T = actual->sequences__T;
        return equal_sequences_record_4((sequences_record_4_t)x, (sequences_record_4_t)y, sequences__T);
}

char * json_sequences_record_4_ptr(pointer_t x, actual_sequences_record_4_t T){
        actual_sequences_record_4_t actual = (actual_sequences_record_4_t)T;
        type_actual_t sequences__T = actual->sequences__T;
        return json_sequences_record_4((sequences_record_4_t)x, sequences__T);
}

actual_sequences_record_4_t actual_sequences_record_4(type_actual_t sequences__T){
        actual_sequences_record_4_t new = (actual_sequences_record_4_t)safe_malloc(sizeof(struct actual_sequences_record_4_s));
        new->equal_ptr = (equal_ptr_t)(*equal_sequences_record_4_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_sequences_record_4_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_sequences_record_4_ptr);
 

        new->sequences__T = sequences__T;
 
        return new;
 };

sequences_record_4_t update_sequences_record_4_project_1(sequences_record_4_t x, sequences__T_t v, type_actual_t sequences__T){
        sequences_record_4_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_1 != NULL){sequences__T->release_ptr(x->project_1, sequences__T);};}
        else {y = copy_sequences_record_4(x); x->count--; y->project_1->count--;};
        y->project_1 = (sequences__T_t)v;
        return y;}

sequences_record_4_t update_sequences_record_4_project_2(sequences_record_4_t x, sequences__T_t v, type_actual_t sequences__T){
        sequences_record_4_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_2 != NULL){sequences__T->release_ptr(x->project_2, sequences__T);};}
        else {y = copy_sequences_record_4(x); x->count--; y->project_2->count--;};
        y->project_2 = (sequences__T_t)v;
        return y;}



void release_sequences_funtype_5(sequences_funtype_5_t x, type_actual_t sequences__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

sequences_funtype_5_t copy_sequences_funtype_5(sequences_funtype_5_t x){return x->ftbl->cptr(x);}

bool_t equal_sequences_funtype_5(sequences_funtype_5_t x, sequences_funtype_5_t y, type_actual_t sequences__T){
        return false;}

char* json_sequences_funtype_5(sequences_funtype_5_t x, type_actual_t sequences__T){char * result = safe_malloc(29); sprintf(result, "%s", "\"sequences_funtype_5\""); return result;}

sequences__T_t sequences__nth(type_actual_t sequences__T, sequences__sequence_t ivar_1, mpz_ptr_t ivar_2){
        sequences__T_t  result;

        result = (sequences__T_t)ivar_1->ftbl->fptr(ivar_1, ivar_2);
        ivar_1->ftbl->rptr(ivar_1);
        
        result->count++;
        return result;
}

sequences__sequence_t sequences__suffix(type_actual_t sequences__T, sequences__sequence_t ivar_1, mpz_ptr_t ivar_2){
        sequences__sequence_t  result;

        sequences_closure_1_t cl3689;
        cl3689 = new_sequences_closure_1();
        cl3689->fvar_1 = (type_actual_t)sequences__T;
        cl3689->fvar_2 = (sequences__sequence_t)ivar_1;
        if (cl3689->fvar_2 != NULL) cl3689->fvar_2->count++;
        mpz_set(cl3689->fvar_3, ivar_2);
        release_sequences__sequence((sequences__sequence_t)ivar_1, sequences__T);
        result = (sequences__sequence_t)cl3689;
        
        result->count++;
        return result;
}

sequences__T_t sequences__first(type_actual_t sequences__T, sequences__sequence_t ivar_1){
        sequences__T_t  result;

        /* T */ type_actual_t ivar_5;
        ivar_5 = (type_actual_t)sequences__T;
        uint8_t ivar_8;
        ivar_8 = (uint8_t)0;
        mpz_ptr_t ivar_7;
        //copying to mpz from uint8;
        mpz_mk_set_ui(ivar_7, ivar_8);
        result = (sequences__T_t)sequences__nth((type_actual_t)ivar_5, (sequences__sequence_t)ivar_1, (mpz_ptr_t)ivar_7);
        
        result->count++;
        return result;
}

sequences__sequence_t sequences__rest(type_actual_t sequences__T, sequences__sequence_t ivar_1){
        sequences__sequence_t  result;

        /* T */ type_actual_t ivar_5;
        ivar_5 = (type_actual_t)sequences__T;
        uint8_t ivar_8;
        ivar_8 = (uint8_t)1;
        mpz_ptr_t ivar_7;
        //copying to mpz from uint8;
        mpz_mk_set_ui(ivar_7, ivar_8);
        result = (sequences__sequence_t)sequences__suffix((type_actual_t)ivar_5, (sequences__sequence_t)ivar_1, (mpz_ptr_t)ivar_7);
        
        result->count++;
        return result;
}

sequences__sequence_t sequences__delete(type_actual_t sequences__T, mpz_ptr_t ivar_1, sequences__sequence_t ivar_2){
        sequences__sequence_t  result;

        sequences_closure_2_t cl3692;
        cl3692 = new_sequences_closure_2();
        cl3692->fvar_1 = (type_actual_t)sequences__T;
        cl3692->fvar_2 = (sequences__sequence_t)ivar_2;
        if (cl3692->fvar_2 != NULL) cl3692->fvar_2->count++;
        mpz_set(cl3692->fvar_3, ivar_1);
        release_sequences__sequence((sequences__sequence_t)ivar_2, sequences__T);
        result = (sequences__sequence_t)cl3692;
        
        result->count++;
        return result;
}

sequences__sequence_t sequences__insert(type_actual_t sequences__T, sequences__T_t ivar_1, mpz_ptr_t ivar_2, sequences__sequence_t ivar_3){
        sequences__sequence_t  result;

        sequences_closure_3_t cl3696;
        cl3696 = new_sequences_closure_3();
        cl3696->fvar_1 = (type_actual_t)sequences__T;
        mpz_set(cl3696->fvar_2, ivar_2);
        cl3696->fvar_3 = (sequences__sequence_t)ivar_3;
        if (cl3696->fvar_3 != NULL) cl3696->fvar_3->count++;
        cl3696->fvar_4 = (sequences__T_t)ivar_1;
        sequences__T->release_ptr(ivar_1, sequences__T);
        release_sequences__sequence((sequences__sequence_t)ivar_3, sequences__T);
        result = (sequences__sequence_t)cl3696;
        
        result->count++;
        return result;
}

sequences__sequence_t sequences__add(type_actual_t sequences__T, sequences__T_t ivar_1, sequences__sequence_t ivar_2){
        sequences__sequence_t  result;

        /* T */ type_actual_t ivar_7;
        ivar_7 = (type_actual_t)sequences__T;
        uint8_t ivar_11;
        ivar_11 = (uint8_t)0;
        mpz_ptr_t ivar_9;
        //copying to mpz from uint8;
        mpz_mk_set_ui(ivar_9, ivar_11);
        result = (sequences__sequence_t)sequences__insert((type_actual_t)ivar_7, (sequences__T_t)ivar_1, (mpz_ptr_t)ivar_9, (sequences__sequence_t)ivar_2);
        
        result->count++;
        return result;
}

bool_t sequences__ascendsp(type_actual_t sequences__T, sequences__sequence_t ivar_1, sequences_funtype_5_t ivar_2){
        bool_t  result;

        pvs2cerror("Non-executable theory: functions", PVS2C_EXIT_ERROR);
        
        
        return result;
}

bool_t sequences__descendsp(type_actual_t sequences__T, sequences__sequence_t ivar_1, sequences_funtype_5_t ivar_2){
        bool_t  result;

        pvs2cerror("Non-executable theory: functions", PVS2C_EXIT_ERROR);
        
        
        return result;
}