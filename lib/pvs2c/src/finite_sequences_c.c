//Code generated using pvs2ir2c
#include "finite_sequences_c.h"

void release_finite_sequences_funtype_0(finite_sequences_funtype_0_t x, type_actual_t finite_sequences__T){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

finite_sequences_funtype_0_t copy_finite_sequences_funtype_0(finite_sequences_funtype_0_t x){return x->ftbl->cptr(x);}

uint32_t lookup_finite_sequences_funtype_0(finite_sequences_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash){
        uint32_t mask = htbl->size - 1;
        uint32_t hashindex = ihash & mask;
        finite_sequences_funtype_0_hashentry_t data = htbl->data[hashindex];
        bool_t keyzero;


        int64_t tmp3711 = mpz_cmp_ui(data.key, 0);
        keyzero = (tmp3711 == 0);
        bool_t keymatch;

        int64_t tmp3712 = mpz_cmp(data.key, i);
        keymatch = (tmp3712 == 0);
        while ((!keyzero || data.keyhash != 0) &&
                 (data.keyhash != ihash || !keymatch)){
                hashindex++;
                hashindex = hashindex & mask;
                data = htbl->data[hashindex];


                int64_t tmp3711 = mpz_cmp_ui(data.key, 0);
                keyzero = (tmp3711 == 0);


                int64_t tmp3712 = mpz_cmp(data.key, i);
                keymatch = (tmp3712 == 0);
                }
        return hashindex;
        }

finite_sequences_funtype_0_t dupdate_finite_sequences_funtype_0(finite_sequences_funtype_0_t a, mpz_ptr_t i, finite_sequences__T_t v, type_actual_t finite_sequences__T){
        finite_sequences_funtype_0_htbl_t htbl = a->htbl;
        if (htbl == NULL){//construct new htbl
                htbl = (finite_sequences_funtype_0_htbl_t)safe_malloc(sizeof(struct finite_sequences_funtype_0_htbl_s));
                htbl->size = HTBL_DEFAULT_SIZE; htbl->num_entries = 0;
                htbl->data = (finite_sequences_funtype_0_hashentry_t *)safe_malloc(HTBL_DEFAULT_SIZE * sizeof(struct finite_sequences_funtype_0_hashentry_s));
                for (uint32_t j = 0; j < HTBL_DEFAULT_SIZE; j++){mpz_init(htbl->data[j].key);mpz_set_ui(htbl->data[j].key, 0); htbl->data[j].keyhash = 0;
                }
                a->htbl = htbl;
        }
        uint32_t size = htbl->size;
        uint32_t num_entries = htbl->num_entries;
        finite_sequences_funtype_0_hashentry_t * data = htbl->data;
        if (num_entries/3 >  size/5){//resize data
                uint32_t new_size = 2*size; uint32_t new_mask = new_size - 1;
                if (size >= HTBL_MAX_SIZE) out_of_memory();
                finite_sequences_funtype_0_hashentry_t * new_data = (finite_sequences_funtype_0_hashentry_t *)safe_malloc(new_size * sizeof(struct finite_sequences_funtype_0_hashentry_s));
                for (uint32_t j = 0; j < new_size; j++){
                        new_data[j].key = 0;
                        new_data[j].keyhash = 0;}
                for (uint32_t j = 0; j < size; j++){//transfer entries
                        uint32_t keyhash = data[j].keyhash;
                        bool_t keyzero;
                        int64_t tmp3713 = mpz_cmp_ui(data[j].key, 0);
                        keyzero = (tmp3713 == 0);

                        if (!keyzero || keyhash != 0){
                                uint32_t new_loc = keyhash ^ new_mask;
                                int64_t tmp3714 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                keyzero = (tmp3714 == 0);

                                while (keyzero && new_data[new_loc].keyhash == 0){
                                        new_loc++;
                                        new_loc = new_loc ^ new_mask;

                                        int64_t tmp3715 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                        keyzero = (tmp3715 == 0);

                                }
                                mpz_set(new_data[new_loc].key, data[j].key);
                                new_data[new_loc].keyhash = keyhash;
                                new_data[new_loc].value = (finite_sequences__T_t)data[j].value;
                                }}
                htbl->size = new_size;
                htbl->num_entries = num_entries;
                htbl->data = new_data;
                safe_free(data);}
        uint32_t ihash = mpz_hash(i);
        uint32_t hashindex = lookup_finite_sequences_funtype_0(htbl, i, ihash);
        finite_sequences_funtype_0_hashentry_t hentry = htbl->data[hashindex];
        uint32_t hkeyhash = hentry.keyhash;
        bool_t hentrykeyzero;
        int64_t tmp3716 = mpz_cmp_ui(hentry.key, 0);
        hentrykeyzero = (tmp3716 == 0);

        if (hentrykeyzero && (hkeyhash == 0))
                {mpz_set(htbl->data[hashindex].key, i); htbl->data[hashindex].keyhash = ihash; htbl->data[hashindex].value = (finite_sequences__T_t)v; htbl->num_entries++;}
            else {finite_sequences__T_t tempvalue;tempvalue = (finite_sequences__T_t)htbl->data[hashindex].value;htbl->data[hashindex].value = (finite_sequences__T_t)v;if (v != NULL) v->count++;if (tempvalue != NULL)finite_sequences__T->release_ptr(tempvalue, finite_sequences__T);};
        return a;

}

finite_sequences_funtype_0_t update_finite_sequences_funtype_0(finite_sequences_funtype_0_t a, mpz_ptr_t i, finite_sequences__T_t v, type_actual_t finite_sequences__T){
        if (a->count == 1){
                return dupdate_finite_sequences_funtype_0(a, i, v, finite_sequences__T);
            } else {
                finite_sequences_funtype_0_t x = copy_finite_sequences_funtype_0(a);
                a->count--;
                return dupdate_finite_sequences_funtype_0(x, i, v, finite_sequences__T);
            }}

bool_t equal_finite_sequences_funtype_0(finite_sequences_funtype_0_t x, finite_sequences_funtype_0_t y, type_actual_t finite_sequences__T){
        return false;}

char* json_finite_sequences_funtype_0(finite_sequences_funtype_0_t x, type_actual_t finite_sequences__T){char * result = safe_malloc(36); sprintf(result, "%s", "\"finite_sequences_funtype_0\""); return result;}


finite_sequences__finite_sequence_t new_finite_sequences__finite_sequence(void){
        finite_sequences__finite_sequence_t tmp = (finite_sequences__finite_sequence_t) safe_malloc(sizeof(struct finite_sequences__finite_sequence_s));
        tmp->count = 1;
        return tmp;}

void release_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x, type_actual_t finite_sequences__T){
        x->count--;
        if (x->count <= 0){
         release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)x->seq, finite_sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_finite_sequences__finite_sequence_ptr(pointer_t x, type_actual_t T){
        actual_finite_sequences__finite_sequence_t actual = (actual_finite_sequences__finite_sequence_t)T;
        type_actual_t finite_sequences__T = actual->finite_sequences__T;
        release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)x, finite_sequences__T);
}

finite_sequences__finite_sequence_t copy_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x){
        finite_sequences__finite_sequence_t y = new_finite_sequences__finite_sequence();
        mpz_set(y->length, x->length);
        y->seq = x->seq;
        if (y->seq != NULL){y->seq->count++;};
        y->count = 1;
        return y;}

bool_t equal_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x, finite_sequences__finite_sequence_t y, type_actual_t finite_sequences__T){
        bool_t tmp = true; tmp = tmp && (mpz_cmp(x->length, y->length) == 0); tmp = tmp && equal_finite_sequences_funtype_0((finite_sequences_funtype_0_t)x->seq, (finite_sequences_funtype_0_t)y->seq, finite_sequences__T);
        return tmp;}

char * json_finite_sequences__finite_sequence(finite_sequences__finite_sequence_t x, type_actual_t finite_sequences__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(18);
         sprintf(fld0, "\"length\" : ");
        tmp[0] = safe_strcat(fld0, json_mpz(x->length));
        char * fld1 = safe_malloc(15);
         sprintf(fld1, "\"seq\" : ");
        tmp[1] = safe_strcat(fld1, json_finite_sequences_funtype_0((finite_sequences_funtype_0_t)x->seq, finite_sequences__T));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_finite_sequences__finite_sequence_ptr(pointer_t x, pointer_t y, actual_finite_sequences__finite_sequence_t T){
        actual_finite_sequences__finite_sequence_t actual = (actual_finite_sequences__finite_sequence_t)T;
        type_actual_t finite_sequences__T = actual->finite_sequences__T;
        return equal_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)x, (finite_sequences__finite_sequence_t)y, finite_sequences__T);
}

char * json_finite_sequences__finite_sequence_ptr(pointer_t x, actual_finite_sequences__finite_sequence_t T){
        actual_finite_sequences__finite_sequence_t actual = (actual_finite_sequences__finite_sequence_t)T;
        type_actual_t finite_sequences__T = actual->finite_sequences__T;
        return json_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)x, finite_sequences__T);
}

actual_finite_sequences__finite_sequence_t actual_finite_sequences__finite_sequence(type_actual_t finite_sequences__T){
        actual_finite_sequences__finite_sequence_t new = (actual_finite_sequences__finite_sequence_t)safe_malloc(sizeof(struct actual_finite_sequences__finite_sequence_s));
        new->equal_ptr = (equal_ptr_t)(*equal_finite_sequences__finite_sequence_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_finite_sequences__finite_sequence_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_finite_sequences__finite_sequence_ptr);
 

        new->finite_sequences__T = finite_sequences__T;
 
        return new;
 };

finite_sequences__finite_sequence_t update_finite_sequences__finite_sequence_length(finite_sequences__finite_sequence_t x, mpz_ptr_t v){
        finite_sequences__finite_sequence_t y;
        if (x->count == 1){y = x;}
        else {y = copy_finite_sequences__finite_sequence(x); x->count--;};
        mpz_set(y->length, v);
        return y;}

finite_sequences__finite_sequence_t update_finite_sequences__finite_sequence_seq(finite_sequences__finite_sequence_t x, finite_sequences_funtype_0_t v, type_actual_t finite_sequences__T){
        finite_sequences__finite_sequence_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->seq != NULL){release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)x->seq, finite_sequences__T);};}
        else {y = copy_finite_sequences__finite_sequence(x); x->count--; y->seq->count--;};
        y->seq = (finite_sequences_funtype_0_t)v;
        return y;}




finite_sequences__T_t f_finite_sequences_closure_2(struct finite_sequences_closure_2_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        finite_sequences_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_finite_sequences_funtype_0(htbl, bvar, hash);
        finite_sequences_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3721 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3721 == 0);
        if (!keyzero || entry.keyhash != 0){
            finite_sequences__T_t result;
            result = (finite_sequences__T_t)entry.value;
            return result;}
        

        return h_finite_sequences_closure_2(bvar, closure->fvar_1, closure->fvar_2);};

return h_finite_sequences_closure_2(bvar, closure->fvar_1, closure->fvar_2);}

finite_sequences__T_t m_finite_sequences_closure_2(struct finite_sequences_closure_2_s * closure, mpz_ptr_t bvar){
        return h_finite_sequences_closure_2(bvar, closure->fvar_1, closure->fvar_2);}

finite_sequences__T_t h_finite_sequences_closure_2(mpz_ptr_t ivar_5, type_actual_t finite_sequences__T, mpz_ptr_t ivar_1){
        finite_sequences__T_t result;

        pvs2cerror("Non-executable theory: epsilons", PVS2C_EXIT_ERROR);
        return result;
}

finite_sequences_closure_2_t new_finite_sequences_closure_2(void){
        static struct finite_sequences_funtype_0_ftbl_s ftbl = {.fptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&f_finite_sequences_closure_2, .mptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&m_finite_sequences_closure_2, .rptr =  (void (*)(finite_sequences_funtype_0_t))&release_finite_sequences_closure_2, .cptr = (finite_sequences_funtype_0_t (*)(finite_sequences_funtype_0_t))&copy_finite_sequences_closure_2};
        finite_sequences_closure_2_t tmp = (finite_sequences_closure_2_t) safe_malloc(sizeof(struct finite_sequences_closure_2_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        return tmp;}

void release_finite_sequences_closure_2(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T){
        finite_sequences_closure_2_t x = (finite_sequences_closure_2_t)closure;
        x->count--;
        if (x->count <= 0){
        //printf("\nFreeing\n");
        safe_free(x);}}

finite_sequences_closure_2_t copy_finite_sequences_closure_2(finite_sequences_closure_2_t x){
        finite_sequences_closure_2_t y = new_finite_sequences_closure_2();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        mpz_set(y->fvar_2, x->fvar_2);
        if (x->htbl != NULL){
            finite_sequences_funtype_0_htbl_t new_htbl = (finite_sequences_funtype_0_htbl_t) safe_malloc(sizeof(struct finite_sequences_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            finite_sequences_funtype_0_hashentry_t * new_data = (finite_sequences_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


finite_sequences__T_t f_finite_sequences_closure_3(struct finite_sequences_closure_3_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        finite_sequences_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_finite_sequences_funtype_0(htbl, bvar, hash);
        finite_sequences_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3726 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3726 == 0);
        if (!keyzero || entry.keyhash != 0){
            finite_sequences__T_t result;
            result = (finite_sequences__T_t)entry.value;
            return result;}
        

        return h_finite_sequences_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4, closure->fvar_5);};

return h_finite_sequences_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4, closure->fvar_5);}

finite_sequences__T_t m_finite_sequences_closure_3(struct finite_sequences_closure_3_s * closure, mpz_ptr_t bvar){
        return h_finite_sequences_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4, closure->fvar_5);}

finite_sequences__T_t h_finite_sequences_closure_3(mpz_ptr_t ivar_16, type_actual_t finite_sequences__T, mpz_ptr_t ivar_7, finite_sequences__finite_sequence_t ivar_2, finite_sequences__finite_sequence_t ivar_1, mpz_ptr_t ivar_3){
        finite_sequences__T_t result;

        bool_t ivar_17;
        int64_t tmp3727 = mpz_cmp(ivar_16, ivar_3);
        ivar_17 = (tmp3727 < 0);
        if (ivar_17){
             finite_sequences_funtype_0_t ivar_24;
             finite_sequences_funtype_0_t ivar_31;
             ivar_31 = (finite_sequences_funtype_0_t)ivar_1->seq;
             ivar_31->count++;
             //copying to finite_sequences_funtype_0 from finite_sequences_funtype_0;
             ivar_24 = (finite_sequences_funtype_0_t)ivar_31;
             if (ivar_24 != NULL) ivar_24->count++;
             release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)ivar_31, finite_sequences__T);
             result = (finite_sequences__T_t)ivar_24->ftbl->fptr(ivar_24, ivar_16);
             ivar_24->ftbl->rptr(ivar_24);
        } else {
             finite_sequences_funtype_0_t ivar_39;
             finite_sequences_funtype_0_t ivar_46;
             ivar_46 = (finite_sequences_funtype_0_t)ivar_2->seq;
             ivar_46->count++;
             //copying to finite_sequences_funtype_0 from finite_sequences_funtype_0;
             ivar_39 = (finite_sequences_funtype_0_t)ivar_46;
             if (ivar_39 != NULL) ivar_39->count++;
             release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)ivar_46, finite_sequences__T);
             mpz_ptr_t ivar_47;
             mpz_mk_sub(ivar_47, ivar_16, ivar_3);
             result = (finite_sequences__T_t)ivar_39->ftbl->fptr(ivar_39, ivar_47);
             ivar_39->ftbl->rptr(ivar_39);};
        return result;
}

finite_sequences_closure_3_t new_finite_sequences_closure_3(void){
        static struct finite_sequences_funtype_0_ftbl_s ftbl = {.fptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&f_finite_sequences_closure_3, .mptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&m_finite_sequences_closure_3, .rptr =  (void (*)(finite_sequences_funtype_0_t))&release_finite_sequences_closure_3, .cptr = (finite_sequences_funtype_0_t (*)(finite_sequences_funtype_0_t))&copy_finite_sequences_closure_3};
        finite_sequences_closure_3_t tmp = (finite_sequences_closure_3_t) safe_malloc(sizeof(struct finite_sequences_closure_3_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        mpz_init(tmp->fvar_5);
        return tmp;}

void release_finite_sequences_closure_3(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T){
        finite_sequences_closure_3_t x = (finite_sequences_closure_3_t)closure;
        x->count--;
        if (x->count <= 0){
         release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)x->fvar_3, finite_sequences__T);
         release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)x->fvar_4, finite_sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

finite_sequences_closure_3_t copy_finite_sequences_closure_3(finite_sequences_closure_3_t x){
        finite_sequences_closure_3_t y = new_finite_sequences_closure_3();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        mpz_set(y->fvar_2, x->fvar_2);
        y->fvar_3 = x->fvar_3; x->fvar_3->count++;
        y->fvar_4 = x->fvar_4; x->fvar_4->count++;
        mpz_set(y->fvar_5, x->fvar_5);
        if (x->htbl != NULL){
            finite_sequences_funtype_0_htbl_t new_htbl = (finite_sequences_funtype_0_htbl_t) safe_malloc(sizeof(struct finite_sequences_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            finite_sequences_funtype_0_hashentry_t * new_data = (finite_sequences_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


finite_sequences_record_4_t new_finite_sequences_record_4(void){
        finite_sequences_record_4_t tmp = (finite_sequences_record_4_t) safe_malloc(sizeof(struct finite_sequences_record_4_s));
        tmp->count = 1;
        return tmp;}

void release_finite_sequences_record_4(finite_sequences_record_4_t x, type_actual_t finite_sequences__T){
        x->count--;
        if (x->count <= 0){
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_finite_sequences_record_4_ptr(pointer_t x, type_actual_t T){
        actual_finite_sequences_record_4_t actual = (actual_finite_sequences_record_4_t)T;
        type_actual_t finite_sequences__T = actual->finite_sequences__T;
        release_finite_sequences_record_4((finite_sequences_record_4_t)x, finite_sequences__T);
}

finite_sequences_record_4_t copy_finite_sequences_record_4(finite_sequences_record_4_t x){
        finite_sequences_record_4_t y = new_finite_sequences_record_4();
        mpz_set(y->project_1, x->project_1);
        mpz_set(y->project_2, x->project_2);
        y->count = 1;
        return y;}

bool_t equal_finite_sequences_record_4(finite_sequences_record_4_t x, finite_sequences_record_4_t y, type_actual_t finite_sequences__T){
        bool_t tmp = true; tmp = tmp && (mpz_cmp(x->project_1, y->project_1) == 0); tmp = tmp && (mpz_cmp(x->project_2, y->project_2) == 0);
        return tmp;}

char * json_finite_sequences_record_4(finite_sequences_record_4_t x, type_actual_t finite_sequences__T){
        char * tmp[2]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, json_mpz(x->project_1));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, json_mpz(x->project_2));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_finite_sequences_record_4_ptr(pointer_t x, pointer_t y, actual_finite_sequences_record_4_t T){
        actual_finite_sequences_record_4_t actual = (actual_finite_sequences_record_4_t)T;
        type_actual_t finite_sequences__T = actual->finite_sequences__T;
        return equal_finite_sequences_record_4((finite_sequences_record_4_t)x, (finite_sequences_record_4_t)y, finite_sequences__T);
}

char * json_finite_sequences_record_4_ptr(pointer_t x, actual_finite_sequences_record_4_t T){
        actual_finite_sequences_record_4_t actual = (actual_finite_sequences_record_4_t)T;
        type_actual_t finite_sequences__T = actual->finite_sequences__T;
        return json_finite_sequences_record_4((finite_sequences_record_4_t)x, finite_sequences__T);
}

actual_finite_sequences_record_4_t actual_finite_sequences_record_4(type_actual_t finite_sequences__T){
        actual_finite_sequences_record_4_t new = (actual_finite_sequences_record_4_t)safe_malloc(sizeof(struct actual_finite_sequences_record_4_s));
        new->equal_ptr = (equal_ptr_t)(*equal_finite_sequences_record_4_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_finite_sequences_record_4_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_finite_sequences_record_4_ptr);
 

        new->finite_sequences__T = finite_sequences__T;
 
        return new;
 };

finite_sequences_record_4_t update_finite_sequences_record_4_project_1(finite_sequences_record_4_t x, mpz_ptr_t v){
        finite_sequences_record_4_t y;
        if (x->count == 1){y = x;}
        else {y = copy_finite_sequences_record_4(x); x->count--;};
        mpz_set(y->project_1, v);
        return y;}

finite_sequences_record_4_t update_finite_sequences_record_4_project_2(finite_sequences_record_4_t x, mpz_ptr_t v){
        finite_sequences_record_4_t y;
        if (x->count == 1){y = x;}
        else {y = copy_finite_sequences_record_4(x); x->count--;};
        mpz_set(y->project_2, v);
        return y;}




finite_sequences__T_t f_finite_sequences_closure_5(struct finite_sequences_closure_5_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        finite_sequences_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_finite_sequences_funtype_0(htbl, bvar, hash);
        finite_sequences_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3740 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3740 == 0);
        if (!keyzero || entry.keyhash != 0){
            finite_sequences__T_t result;
            result = (finite_sequences__T_t)entry.value;
            return result;}
        

        return h_finite_sequences_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);};

return h_finite_sequences_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);}

finite_sequences__T_t m_finite_sequences_closure_5(struct finite_sequences_closure_5_s * closure, mpz_ptr_t bvar){
        return h_finite_sequences_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);}

finite_sequences__T_t h_finite_sequences_closure_5(mpz_ptr_t ivar_47, type_actual_t finite_sequences__T, mpz_ptr_t ivar_23, mpz_ptr_t ivar_3, finite_sequences__finite_sequence_t ivar_1){
        finite_sequences__T_t result;

        finite_sequences_funtype_0_t ivar_54;
        finite_sequences_funtype_0_t ivar_61;
        ivar_61 = (finite_sequences_funtype_0_t)ivar_1->seq;
        ivar_61->count++;
        //copying to finite_sequences_funtype_0 from finite_sequences_funtype_0;
        ivar_54 = (finite_sequences_funtype_0_t)ivar_61;
        if (ivar_54 != NULL) ivar_54->count++;
        release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)ivar_61, finite_sequences__T);
        mpz_ptr_t ivar_62;
        mpz_mk_add(ivar_62, ivar_3, ivar_47);
        result = (finite_sequences__T_t)ivar_54->ftbl->fptr(ivar_54, ivar_62);
        ivar_54->ftbl->rptr(ivar_54);
        return result;
}

finite_sequences_closure_5_t new_finite_sequences_closure_5(void){
        static struct finite_sequences_funtype_0_ftbl_s ftbl = {.fptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&f_finite_sequences_closure_5, .mptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&m_finite_sequences_closure_5, .rptr =  (void (*)(finite_sequences_funtype_0_t))&release_finite_sequences_closure_5, .cptr = (finite_sequences_funtype_0_t (*)(finite_sequences_funtype_0_t))&copy_finite_sequences_closure_5};
        finite_sequences_closure_5_t tmp = (finite_sequences_closure_5_t) safe_malloc(sizeof(struct finite_sequences_closure_5_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        mpz_init(tmp->fvar_3);
        return tmp;}

void release_finite_sequences_closure_5(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T){
        finite_sequences_closure_5_t x = (finite_sequences_closure_5_t)closure;
        x->count--;
        if (x->count <= 0){
         release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)x->fvar_4, finite_sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

finite_sequences_closure_5_t copy_finite_sequences_closure_5(finite_sequences_closure_5_t x){
        finite_sequences_closure_5_t y = new_finite_sequences_closure_5();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        mpz_set(y->fvar_2, x->fvar_2);
        mpz_set(y->fvar_3, x->fvar_3);
        y->fvar_4 = x->fvar_4; x->fvar_4->count++;
        if (x->htbl != NULL){
            finite_sequences_funtype_0_htbl_t new_htbl = (finite_sequences_funtype_0_htbl_t) safe_malloc(sizeof(struct finite_sequences_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            finite_sequences_funtype_0_hashentry_t * new_data = (finite_sequences_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


finite_sequences__T_t f_finite_sequences_closure_6(struct finite_sequences_closure_6_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        finite_sequences_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_finite_sequences_funtype_0(htbl, bvar, hash);
        finite_sequences_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3753 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3753 == 0);
        if (!keyzero || entry.keyhash != 0){
            finite_sequences__T_t result;
            result = (finite_sequences__T_t)entry.value;
            return result;}
        

        return h_finite_sequences_closure_6(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);};

return h_finite_sequences_closure_6(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);}

finite_sequences__T_t m_finite_sequences_closure_6(struct finite_sequences_closure_6_s * closure, mpz_ptr_t bvar){
        return h_finite_sequences_closure_6(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3, closure->fvar_4);}

finite_sequences__T_t h_finite_sequences_closure_6(mpz_ptr_t ivar_44, type_actual_t finite_sequences__T, mpz_ptr_t ivar_23, mpz_ptr_t ivar_3, finite_sequences__finite_sequence_t ivar_1){
        finite_sequences__T_t result;

        finite_sequences_funtype_0_t ivar_51;
        finite_sequences_funtype_0_t ivar_58;
        ivar_58 = (finite_sequences_funtype_0_t)ivar_1->seq;
        ivar_58->count++;
        //copying to finite_sequences_funtype_0 from finite_sequences_funtype_0;
        ivar_51 = (finite_sequences_funtype_0_t)ivar_58;
        if (ivar_51 != NULL) ivar_51->count++;
        release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)ivar_58, finite_sequences__T);
        mpz_ptr_t ivar_59;
        mpz_mk_add(ivar_59, ivar_3, ivar_44);
        result = (finite_sequences__T_t)ivar_51->ftbl->fptr(ivar_51, ivar_59);
        ivar_51->ftbl->rptr(ivar_51);
        return result;
}

finite_sequences_closure_6_t new_finite_sequences_closure_6(void){
        static struct finite_sequences_funtype_0_ftbl_s ftbl = {.fptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&f_finite_sequences_closure_6, .mptr = (finite_sequences__T_t (*)(finite_sequences_funtype_0_t, mpz_ptr_t))&m_finite_sequences_closure_6, .rptr =  (void (*)(finite_sequences_funtype_0_t))&release_finite_sequences_closure_6, .cptr = (finite_sequences_funtype_0_t (*)(finite_sequences_funtype_0_t))&copy_finite_sequences_closure_6};
        finite_sequences_closure_6_t tmp = (finite_sequences_closure_6_t) safe_malloc(sizeof(struct finite_sequences_closure_6_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        mpz_init(tmp->fvar_3);
        return tmp;}

void release_finite_sequences_closure_6(finite_sequences_funtype_0_t closure, type_actual_t finite_sequences__T){
        finite_sequences_closure_6_t x = (finite_sequences_closure_6_t)closure;
        x->count--;
        if (x->count <= 0){
         release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)x->fvar_4, finite_sequences__T);
        //printf("\nFreeing\n");
        safe_free(x);}}

finite_sequences_closure_6_t copy_finite_sequences_closure_6(finite_sequences_closure_6_t x){
        finite_sequences_closure_6_t y = new_finite_sequences_closure_6();
        y->ftbl = x->ftbl;

        y->fvar_1 = (type_actual_t)x->fvar_1;
        mpz_set(y->fvar_2, x->fvar_2);
        mpz_set(y->fvar_3, x->fvar_3);
        y->fvar_4 = x->fvar_4; x->fvar_4->count++;
        if (x->htbl != NULL){
            finite_sequences_funtype_0_htbl_t new_htbl = (finite_sequences_funtype_0_htbl_t) safe_malloc(sizeof(struct finite_sequences_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            finite_sequences_funtype_0_hashentry_t * new_data = (finite_sequences_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct finite_sequences_funtype_0_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

finite_sequences__finite_sequence_t finite_sequences__empty_seq(type_actual_t finite_sequences__T){
        finite_sequences__finite_sequence_t  result;

        mpz_ptr_t ivar_1;
        ivar_1 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_1);
        mpz_mk_set_ui(ivar_1, 0);
        finite_sequences_funtype_0_t ivar_11;
        finite_sequences_closure_2_t cl3722;
        cl3722 = new_finite_sequences_closure_2();
        cl3722->fvar_1 = (type_actual_t)finite_sequences__T;
        mpz_set(cl3722->fvar_2, ivar_1);
        ivar_11 = (finite_sequences_funtype_0_t)cl3722;
        finite_sequences__finite_sequence_t tmp3723 = new_finite_sequences__finite_sequence();;
        result = (finite_sequences__finite_sequence_t)tmp3723;
        mpz_init(tmp3723->length);
        mpz_set(tmp3723->length, ivar_1);
        mpz_clear(ivar_1);
        tmp3723->seq = (finite_sequences_funtype_0_t)ivar_11;
        
        result->count++;
        return result;
}

finite_sequences_funtype_0_t finite_sequences__finseq_appl(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1){
        finite_sequences_funtype_0_t  result;

        finite_sequences_funtype_0_t ivar_10;
        ivar_10 = (finite_sequences_funtype_0_t)ivar_1->seq;
        ivar_10->count++;
        //copying to finite_sequences_funtype_0 from finite_sequences_funtype_0;
        result = (finite_sequences_funtype_0_t)ivar_10;
        if (result != NULL) result->count++;
        release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)ivar_10, finite_sequences__T);
        
        result->count++;
        return result;
}

finite_sequences__finite_sequence_t finite_sequences__oh(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1, finite_sequences__finite_sequence_t ivar_2){
        finite_sequences__finite_sequence_t  result;

        /* l1 */ mpz_ptr_t ivar_3;
        ivar_3 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_3);
        mpz_set(ivar_3, ivar_1->length);
        /* lsum */ mpz_ptr_t ivar_7;
        mpz_ptr_t ivar_9;
        ivar_9 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_9);
        mpz_set(ivar_9, ivar_2->length);
        mpz_mk_add(ivar_7, ivar_9, ivar_3);
        finite_sequences_funtype_0_t ivar_48;
        finite_sequences_closure_3_t cl3728;
        cl3728 = new_finite_sequences_closure_3();
        cl3728->fvar_1 = (type_actual_t)finite_sequences__T;
        mpz_set(cl3728->fvar_2, ivar_7);
        cl3728->fvar_3 = (finite_sequences__finite_sequence_t)ivar_2;
        if (cl3728->fvar_3 != NULL) cl3728->fvar_3->count++;
        cl3728->fvar_4 = (finite_sequences__finite_sequence_t)ivar_1;
        if (cl3728->fvar_4 != NULL) cl3728->fvar_4->count++;
        mpz_set(cl3728->fvar_5, ivar_3);
        release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)ivar_1, finite_sequences__T);
        release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)ivar_2, finite_sequences__T);
        ivar_48 = (finite_sequences_funtype_0_t)cl3728;
        finite_sequences__finite_sequence_t tmp3729 = new_finite_sequences__finite_sequence();;
        result = (finite_sequences__finite_sequence_t)tmp3729;
        mpz_init(tmp3729->length);
        mpz_set(tmp3729->length, ivar_7);
        mpz_clear(ivar_7);
        tmp3729->seq = (finite_sequences_funtype_0_t)ivar_48;
        
        result->count++;
        return result;
}

finite_sequences__finite_sequence_t finite_sequences__caret(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1, finite_sequences_record_4_t ivar_2){
        finite_sequences__finite_sequence_t  result;

        /* m */ mpz_ptr_t ivar_3;
        ivar_3 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_3);
        mpz_set(ivar_3, ivar_2->project_1);
        /* n */ mpz_ptr_t ivar_7;
        ivar_7 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_7);
        mpz_set(ivar_7, ivar_2->project_2);
        release_finite_sequences_record_4((finite_sequences_record_4_t)ivar_2, finite_sequences__T);
        bool_t ivar_11;
        bool_t ivar_12;
        int64_t tmp3738 = mpz_cmp(ivar_3, ivar_7);
        ivar_12 = (tmp3738 > 0);
        if (ivar_12){
             ivar_11 = (bool_t) true;
        } else {
             mpz_ptr_t ivar_18;
             ivar_18 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_18);
             mpz_set(ivar_18, ivar_1->length);
             int64_t tmp3739 = mpz_cmp(ivar_3, ivar_18);
             ivar_11 = (tmp3739 >= 0);};
        if (ivar_11){
             release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)ivar_1, finite_sequences__T);
             result = (finite_sequences__finite_sequence_t)finite_sequences__empty_seq((type_actual_t)finite_sequences__T);
        } else {
             /* len */ mpz_ptr_t ivar_23;
             mpz_ptr_t ivar_42;
             mpz_ptr_t ivar_26;
             mpz_mk_sub(ivar_26, ivar_7, ivar_3);
             uint8_t ivar_27;
             ivar_27 = (uint8_t)1;
             mpz_mk_set_ui(ivar_42, (uint64_t)ivar_27);
             mpz_add(ivar_42, ivar_42, ivar_26);
             mpq_ptr_t ivar_37;
             //copying to mpq from mpz;
             mpq_mk_set_z(ivar_37, ivar_42);
             mpz_clear(ivar_42);
             mpz_ptr_t ivar_41;
             mpz_ptr_t ivar_32;
             ivar_32 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_32);
             mpz_set(ivar_32, ivar_1->length);
             mpz_mk_sub(ivar_41, ivar_32, ivar_3);
             mpq_ptr_t ivar_38;
             //copying to mpq from mpz;
             mpq_mk_set_z(ivar_38, ivar_41);
             mpz_clear(ivar_41);
             mpz_mk_set_q(ivar_23, real_defs__min((mpq_ptr_t)ivar_37, (mpq_ptr_t)ivar_38));
             finite_sequences_funtype_0_t ivar_63;
             finite_sequences_closure_5_t cl3741;
             cl3741 = new_finite_sequences_closure_5();
             cl3741->fvar_1 = (type_actual_t)finite_sequences__T;
             mpz_set(cl3741->fvar_2, ivar_23);
             mpz_set(cl3741->fvar_3, ivar_3);
             cl3741->fvar_4 = (finite_sequences__finite_sequence_t)ivar_1;
             if (cl3741->fvar_4 != NULL) cl3741->fvar_4->count++;
             release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)ivar_1, finite_sequences__T);
             ivar_63 = (finite_sequences_funtype_0_t)cl3741;
             finite_sequences__finite_sequence_t tmp3742 = new_finite_sequences__finite_sequence();;
             result = (finite_sequences__finite_sequence_t)tmp3742;
             mpz_init(tmp3742->length);
             mpz_set(tmp3742->length, ivar_23);
             mpz_clear(ivar_23);
             tmp3742->seq = (finite_sequences_funtype_0_t)ivar_63;};
        
        result->count++;
        return result;
}

finite_sequences__finite_sequence_t finite_sequences__doublecaret(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1, finite_sequences_record_4_t ivar_2){
        finite_sequences__finite_sequence_t  result;

        /* m */ mpz_ptr_t ivar_3;
        ivar_3 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_3);
        mpz_set(ivar_3, ivar_2->project_1);
        /* n */ mpz_ptr_t ivar_7;
        ivar_7 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_7);
        mpz_set(ivar_7, ivar_2->project_2);
        release_finite_sequences_record_4((finite_sequences_record_4_t)ivar_2, finite_sequences__T);
        bool_t ivar_11;
        bool_t ivar_12;
        int64_t tmp3751 = mpz_cmp(ivar_3, ivar_7);
        ivar_12 = (tmp3751 >= 0);
        if (ivar_12){
             ivar_11 = (bool_t) true;
        } else {
             mpz_ptr_t ivar_18;
             ivar_18 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_18);
             mpz_set(ivar_18, ivar_1->length);
             int64_t tmp3752 = mpz_cmp(ivar_3, ivar_18);
             ivar_11 = (tmp3752 >= 0);};
        if (ivar_11){
             release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)ivar_1, finite_sequences__T);
             result = (finite_sequences__finite_sequence_t)finite_sequences__empty_seq((type_actual_t)finite_sequences__T);
        } else {
             /* len */ mpz_ptr_t ivar_23;
             mpz_ptr_t ivar_39;
             mpz_mk_sub(ivar_39, ivar_7, ivar_3);
             mpq_ptr_t ivar_34;
             //copying to mpq from mpz;
             mpq_mk_set_z(ivar_34, ivar_39);
             mpz_clear(ivar_39);
             mpz_ptr_t ivar_38;
             mpz_ptr_t ivar_29;
             ivar_29 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_29);
             mpz_set(ivar_29, ivar_1->length);
             mpz_mk_sub(ivar_38, ivar_29, ivar_3);
             mpq_ptr_t ivar_35;
             //copying to mpq from mpz;
             mpq_mk_set_z(ivar_35, ivar_38);
             mpz_clear(ivar_38);
             mpz_mk_set_q(ivar_23, real_defs__min((mpq_ptr_t)ivar_34, (mpq_ptr_t)ivar_35));
             finite_sequences_funtype_0_t ivar_60;
             finite_sequences_closure_6_t cl3754;
             cl3754 = new_finite_sequences_closure_6();
             cl3754->fvar_1 = (type_actual_t)finite_sequences__T;
             mpz_set(cl3754->fvar_2, ivar_23);
             mpz_set(cl3754->fvar_3, ivar_3);
             cl3754->fvar_4 = (finite_sequences__finite_sequence_t)ivar_1;
             if (cl3754->fvar_4 != NULL) cl3754->fvar_4->count++;
             release_finite_sequences__finite_sequence((finite_sequences__finite_sequence_t)ivar_1, finite_sequences__T);
             ivar_60 = (finite_sequences_funtype_0_t)cl3754;
             finite_sequences__finite_sequence_t tmp3755 = new_finite_sequences__finite_sequence();;
             result = (finite_sequences__finite_sequence_t)tmp3755;
             mpz_init(tmp3755->length);
             mpz_set(tmp3755->length, ivar_23);
             mpz_clear(ivar_23);
             tmp3755->seq = (finite_sequences_funtype_0_t)ivar_60;};
        
        result->count++;
        return result;
}

finite_sequences__T_t finite_sequences__extract1(type_actual_t finite_sequences__T, finite_sequences__finite_sequence_t ivar_1){
        finite_sequences__T_t  result;

        finite_sequences_funtype_0_t ivar_5;
        finite_sequences_funtype_0_t ivar_12;
        ivar_12 = (finite_sequences_funtype_0_t)ivar_1->seq;
        ivar_12->count++;
        //copying to finite_sequences_funtype_0 from finite_sequences_funtype_0;
        ivar_5 = (finite_sequences_funtype_0_t)ivar_12;
        if (ivar_5 != NULL) ivar_5->count++;
        release_finite_sequences_funtype_0((finite_sequences_funtype_0_t)ivar_12, finite_sequences__T);
        uint8_t ivar_14;
        ivar_14 = (uint8_t)0;
        mpz_ptr_t ivar_13;
        //copying to mpz from uint8;
        mpz_mk_set_ui(ivar_13, ivar_14);
        result = (finite_sequences__T_t)ivar_5->ftbl->fptr(ivar_5, ivar_13);
        ivar_5->ftbl->rptr(ivar_5);
        
        result->count++;
        return result;
}