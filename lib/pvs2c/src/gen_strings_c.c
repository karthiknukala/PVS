//Code generated using pvs2ir2c
#include "gen_strings_c.h"

void release_gen_strings_funtype_0(gen_strings_funtype_0_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

gen_strings_funtype_0_t copy_gen_strings_funtype_0(gen_strings_funtype_0_t x){return x->ftbl->cptr(x);}

uint32_t lookup_gen_strings_funtype_0(gen_strings_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash){
        uint32_t mask = htbl->size - 1;
        uint32_t hashindex = ihash & mask;
        gen_strings_funtype_0_hashentry_t data = htbl->data[hashindex];
        bool_t keyzero;


        int64_t tmp3922 = mpz_cmp_ui(data.key, 0);
        keyzero = (tmp3922 == 0);
        bool_t keymatch;

        int64_t tmp3923 = mpz_cmp(data.key, i);
        keymatch = (tmp3923 == 0);
        while ((!keyzero || data.keyhash != 0) &&
                 (data.keyhash != ihash || !keymatch)){
                hashindex++;
                hashindex = hashindex & mask;
                data = htbl->data[hashindex];


                int64_t tmp3922 = mpz_cmp_ui(data.key, 0);
                keyzero = (tmp3922 == 0);


                int64_t tmp3923 = mpz_cmp(data.key, i);
                keymatch = (tmp3923 == 0);
                }
        return hashindex;
        }

gen_strings_funtype_0_t dupdate_gen_strings_funtype_0(gen_strings_funtype_0_t a, mpz_ptr_t i, uint32_t v){
        gen_strings_funtype_0_htbl_t htbl = a->htbl;
        if (htbl == NULL){//construct new htbl
                htbl = (gen_strings_funtype_0_htbl_t)safe_malloc(sizeof(struct gen_strings_funtype_0_htbl_s));
                htbl->size = HTBL_DEFAULT_SIZE; htbl->num_entries = 0;
                htbl->data = (gen_strings_funtype_0_hashentry_t *)safe_malloc(HTBL_DEFAULT_SIZE * sizeof(struct gen_strings_funtype_0_hashentry_s));
                for (uint32_t j = 0; j < HTBL_DEFAULT_SIZE; j++){mpz_init(htbl->data[j].key);mpz_set_ui(htbl->data[j].key, 0); htbl->data[j].keyhash = 0;
                }
                a->htbl = htbl;
        }
        uint32_t size = htbl->size;
        uint32_t num_entries = htbl->num_entries;
        gen_strings_funtype_0_hashentry_t * data = htbl->data;
        if (num_entries/3 >  size/5){//resize data
                uint32_t new_size = 2*size; uint32_t new_mask = new_size - 1;
                if (size >= HTBL_MAX_SIZE) out_of_memory();
                gen_strings_funtype_0_hashentry_t * new_data = (gen_strings_funtype_0_hashentry_t *)safe_malloc(new_size * sizeof(struct gen_strings_funtype_0_hashentry_s));
                for (uint32_t j = 0; j < new_size; j++){
                        new_data[j].key = 0;
                        new_data[j].keyhash = 0;}
                for (uint32_t j = 0; j < size; j++){//transfer entries
                        uint32_t keyhash = data[j].keyhash;
                        bool_t keyzero;
                        int64_t tmp3924 = mpz_cmp_ui(data[j].key, 0);
                        keyzero = (tmp3924 == 0);

                        if (!keyzero || keyhash != 0){
                                uint32_t new_loc = keyhash ^ new_mask;
                                int64_t tmp3925 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                keyzero = (tmp3925 == 0);

                                while (keyzero && new_data[new_loc].keyhash == 0){
                                        new_loc++;
                                        new_loc = new_loc ^ new_mask;

                                        int64_t tmp3926 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                        keyzero = (tmp3926 == 0);

                                }
                                mpz_set(new_data[new_loc].key, data[j].key);
                                new_data[new_loc].keyhash = keyhash;
                                new_data[new_loc].value = (uint32_t)data[j].value;
                                }}
                htbl->size = new_size;
                htbl->num_entries = num_entries;
                htbl->data = new_data;
                safe_free(data);}
        uint32_t ihash = mpz_hash(i);
        uint32_t hashindex = lookup_gen_strings_funtype_0(htbl, i, ihash);
        gen_strings_funtype_0_hashentry_t hentry = htbl->data[hashindex];
        uint32_t hkeyhash = hentry.keyhash;
        bool_t hentrykeyzero;
        int64_t tmp3927 = mpz_cmp_ui(hentry.key, 0);
        hentrykeyzero = (tmp3927 == 0);

        if (hentrykeyzero && (hkeyhash == 0))
                {mpz_set(htbl->data[hashindex].key, i); htbl->data[hashindex].keyhash = ihash; htbl->data[hashindex].value = (uint32_t)v; htbl->num_entries++;}
            else {htbl->data[hashindex].value = (uint32_t)v;};
        return a;

}

gen_strings_funtype_0_t update_gen_strings_funtype_0(gen_strings_funtype_0_t a, mpz_ptr_t i, uint32_t v){
        if (a->count == 1){
                return dupdate_gen_strings_funtype_0(a, i, v);
            } else {
                gen_strings_funtype_0_t x = copy_gen_strings_funtype_0(a);
                a->count--;
                return dupdate_gen_strings_funtype_0(x, i, v);
            }}

bool_t equal_gen_strings_funtype_0(gen_strings_funtype_0_t x, gen_strings_funtype_0_t y){
        return false;}

char* json_gen_strings_funtype_0(gen_strings_funtype_0_t x){char * result = safe_malloc(31); sprintf(result, "%s", "\"gen_strings_funtype_0\""); return result;}


uint32_t f_gen_strings_closure_1(struct gen_strings_closure_1_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        gen_strings_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_gen_strings_funtype_0(htbl, bvar, hash);
        gen_strings_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3930 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3930 == 0);
        if (!keyzero || entry.keyhash != 0){
            uint32_t result;
            result = (uint32_t)entry.value;
            return result;}
        

        return h_gen_strings_closure_1(bvar, closure->fvar_1);};

return h_gen_strings_closure_1(bvar, closure->fvar_1);}

uint32_t m_gen_strings_closure_1(struct gen_strings_closure_1_s * closure, mpz_ptr_t bvar){
        return h_gen_strings_closure_1(bvar, closure->fvar_1);}

uint32_t h_gen_strings_closure_1(mpz_ptr_t ivar_5, mpz_ptr_t ivar_1){
        uint32_t result;

        uint8_t ivar_6;
        ivar_6 = (uint8_t)0;
        result = (uint32_t) ivar_6;
        return result;
}

gen_strings_closure_1_t new_gen_strings_closure_1(void){
        static struct gen_strings_funtype_0_ftbl_s ftbl = {.fptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&f_gen_strings_closure_1, .mptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&m_gen_strings_closure_1, .rptr =  (void (*)(gen_strings_funtype_0_t))&release_gen_strings_closure_1, .cptr = (gen_strings_funtype_0_t (*)(gen_strings_funtype_0_t))&copy_gen_strings_closure_1};
        gen_strings_closure_1_t tmp = (gen_strings_closure_1_t) safe_malloc(sizeof(struct gen_strings_closure_1_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_1);
        return tmp;}

void release_gen_strings_closure_1(gen_strings_funtype_0_t closure){
        gen_strings_closure_1_t x = (gen_strings_closure_1_t)closure;
        x->count--;
        if (x->count <= 0){
        //printf("\nFreeing\n");
        safe_free(x);}}

gen_strings_closure_1_t copy_gen_strings_closure_1(gen_strings_closure_1_t x){
        gen_strings_closure_1_t y = new_gen_strings_closure_1();
        y->ftbl = x->ftbl;

        mpz_set(y->fvar_1, x->fvar_1);
        if (x->htbl != NULL){
            gen_strings_funtype_0_htbl_t new_htbl = (gen_strings_funtype_0_htbl_t) safe_malloc(sizeof(struct gen_strings_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            gen_strings_funtype_0_hashentry_t * new_data = (gen_strings_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


gen_strings_record_2_t new_gen_strings_record_2(void){
        gen_strings_record_2_t tmp = (gen_strings_record_2_t) safe_malloc(sizeof(struct gen_strings_record_2_s));
        tmp->count = 1;
        return tmp;}

void release_gen_strings_record_2(gen_strings_record_2_t x){
        x->count--;
        if (x->count <= 0){
         release_gen_strings_funtype_0((gen_strings_funtype_0_t)x->seq);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_gen_strings_record_2_ptr(pointer_t x, type_actual_t T){
        release_gen_strings_record_2((gen_strings_record_2_t)x);
}

gen_strings_record_2_t copy_gen_strings_record_2(gen_strings_record_2_t x){
        gen_strings_record_2_t y = new_gen_strings_record_2();
        mpz_set(y->length, x->length);
        y->seq = x->seq;
        if (y->seq != NULL){y->seq->count++;};
        y->count = 1;
        return y;}

bool_t equal_gen_strings_record_2(gen_strings_record_2_t x, gen_strings_record_2_t y){
        bool_t tmp = true; tmp = tmp && (mpz_cmp(x->length, y->length) == 0); tmp = tmp && equal_gen_strings_funtype_0((gen_strings_funtype_0_t)x->seq, (gen_strings_funtype_0_t)y->seq);
        return tmp;}

char * json_gen_strings_record_2(gen_strings_record_2_t x){
        char * tmp[2]; 
        char * fld0 = safe_malloc(18);
         sprintf(fld0, "\"length\" : ");
        tmp[0] = safe_strcat(fld0, json_mpz(x->length));
        char * fld1 = safe_malloc(15);
         sprintf(fld1, "\"seq\" : ");
        tmp[1] = safe_strcat(fld1, json_gen_strings_funtype_0((gen_strings_funtype_0_t)x->seq));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_gen_strings_record_2_ptr(pointer_t x, pointer_t y, actual_gen_strings_record_2_t T){
        return equal_gen_strings_record_2((gen_strings_record_2_t)x, (gen_strings_record_2_t)y);
}

char * json_gen_strings_record_2_ptr(pointer_t x, actual_gen_strings_record_2_t T){
        return json_gen_strings_record_2((gen_strings_record_2_t)x);
}

actual_gen_strings_record_2_t actual_gen_strings_record_2(){
        actual_gen_strings_record_2_t new = (actual_gen_strings_record_2_t)safe_malloc(sizeof(struct actual_gen_strings_record_2_s));
        new->equal_ptr = (equal_ptr_t)(*equal_gen_strings_record_2_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_gen_strings_record_2_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_gen_strings_record_2_ptr);
 

 
        return new;
 };

gen_strings_record_2_t update_gen_strings_record_2_length(gen_strings_record_2_t x, mpz_ptr_t v){
        gen_strings_record_2_t y;
        if (x->count == 1){y = x;}
        else {y = copy_gen_strings_record_2(x); x->count--;};
        mpz_set(y->length, v);
        return y;}

gen_strings_record_2_t update_gen_strings_record_2_seq(gen_strings_record_2_t x, gen_strings_funtype_0_t v){
        gen_strings_record_2_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->seq != NULL){release_gen_strings_funtype_0((gen_strings_funtype_0_t)x->seq);};}
        else {y = copy_gen_strings_record_2(x); x->count--; y->seq->count--;};
        y->seq = (gen_strings_funtype_0_t)v;
        return y;}




uint32_t f_gen_strings_closure_3(struct gen_strings_closure_3_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        gen_strings_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_gen_strings_funtype_0(htbl, bvar, hash);
        gen_strings_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3935 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3935 == 0);
        if (!keyzero || entry.keyhash != 0){
            uint32_t result;
            result = (uint32_t)entry.value;
            return result;}
        

        return h_gen_strings_closure_3(bvar, closure->fvar_1, closure->fvar_2);};

return h_gen_strings_closure_3(bvar, closure->fvar_1, closure->fvar_2);}

uint32_t m_gen_strings_closure_3(struct gen_strings_closure_3_s * closure, mpz_ptr_t bvar){
        return h_gen_strings_closure_3(bvar, closure->fvar_1, closure->fvar_2);}

uint32_t h_gen_strings_closure_3(mpz_ptr_t ivar_6, mpz_ptr_t ivar_2, uint32_t ivar_1){
        uint32_t result;

        //copying to uint32 from uint32;
        result = (uint32_t)ivar_1;
        return result;
}

gen_strings_closure_3_t new_gen_strings_closure_3(void){
        static struct gen_strings_funtype_0_ftbl_s ftbl = {.fptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&f_gen_strings_closure_3, .mptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&m_gen_strings_closure_3, .rptr =  (void (*)(gen_strings_funtype_0_t))&release_gen_strings_closure_3, .cptr = (gen_strings_funtype_0_t (*)(gen_strings_funtype_0_t))&copy_gen_strings_closure_3};
        gen_strings_closure_3_t tmp = (gen_strings_closure_3_t) safe_malloc(sizeof(struct gen_strings_closure_3_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_1);
        return tmp;}

void release_gen_strings_closure_3(gen_strings_funtype_0_t closure){
        gen_strings_closure_3_t x = (gen_strings_closure_3_t)closure;
        x->count--;
        if (x->count <= 0){
        //printf("\nFreeing\n");
        safe_free(x);}}

gen_strings_closure_3_t copy_gen_strings_closure_3(gen_strings_closure_3_t x){
        gen_strings_closure_3_t y = new_gen_strings_closure_3();
        y->ftbl = x->ftbl;

        mpz_set(y->fvar_1, x->fvar_1);
        y->fvar_2 = (uint32_t)x->fvar_2;
        if (x->htbl != NULL){
            gen_strings_funtype_0_htbl_t new_htbl = (gen_strings_funtype_0_htbl_t) safe_malloc(sizeof(struct gen_strings_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            gen_strings_funtype_0_hashentry_t * new_data = (gen_strings_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


uint32_t f_gen_strings_closure_4(struct gen_strings_closure_4_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        gen_strings_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_gen_strings_funtype_0(htbl, bvar, hash);
        gen_strings_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3946 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3946 == 0);
        if (!keyzero || entry.keyhash != 0){
            uint32_t result;
            result = (uint32_t)entry.value;
            return result;}
        

        return h_gen_strings_closure_4(bvar, closure->fvar_1, closure->fvar_2);};

return h_gen_strings_closure_4(bvar, closure->fvar_1, closure->fvar_2);}

uint32_t m_gen_strings_closure_4(struct gen_strings_closure_4_s * closure, mpz_ptr_t bvar){
        return h_gen_strings_closure_4(bvar, closure->fvar_1, closure->fvar_2);}

uint32_t h_gen_strings_closure_4(mpz_ptr_t ivar_16, strings__string_t ivar_1, mpz_ptr_t ivar_2){
        uint32_t result;

        ivar_1->count++;
        result = (uint32_t)gen_strings__get((strings__string_t)ivar_1, (mpz_ptr_t)ivar_16);
        return result;
}

gen_strings_closure_4_t new_gen_strings_closure_4(void){
        static struct gen_strings_funtype_0_ftbl_s ftbl = {.fptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&f_gen_strings_closure_4, .mptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&m_gen_strings_closure_4, .rptr =  (void (*)(gen_strings_funtype_0_t))&release_gen_strings_closure_4, .cptr = (gen_strings_funtype_0_t (*)(gen_strings_funtype_0_t))&copy_gen_strings_closure_4};
        gen_strings_closure_4_t tmp = (gen_strings_closure_4_t) safe_malloc(sizeof(struct gen_strings_closure_4_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        return tmp;}

void release_gen_strings_closure_4(gen_strings_funtype_0_t closure){
        gen_strings_closure_4_t x = (gen_strings_closure_4_t)closure;
        x->count--;
        if (x->count <= 0){
         release_strings__string((strings__string_t)x->fvar_1);
        //printf("\nFreeing\n");
        safe_free(x);}}

gen_strings_closure_4_t copy_gen_strings_closure_4(gen_strings_closure_4_t x){
        gen_strings_closure_4_t y = new_gen_strings_closure_4();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        mpz_set(y->fvar_2, x->fvar_2);
        if (x->htbl != NULL){
            gen_strings_funtype_0_htbl_t new_htbl = (gen_strings_funtype_0_htbl_t) safe_malloc(sizeof(struct gen_strings_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            gen_strings_funtype_0_hashentry_t * new_data = (gen_strings_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


uint32_t f_gen_strings_closure_5(struct gen_strings_closure_5_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        gen_strings_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_gen_strings_funtype_0(htbl, bvar, hash);
        gen_strings_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3952 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3952 == 0);
        if (!keyzero || entry.keyhash != 0){
            uint32_t result;
            result = (uint32_t)entry.value;
            return result;}
        

        return h_gen_strings_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);};

return h_gen_strings_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

uint32_t m_gen_strings_closure_5(struct gen_strings_closure_5_s * closure, mpz_ptr_t bvar){
        return h_gen_strings_closure_5(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

uint32_t h_gen_strings_closure_5(mpz_ptr_t ivar_28, strings__string_t ivar_1, mpz_ptr_t ivar_2, mpz_ptr_t ivar_12){
        uint32_t result;

        mpz_ptr_t ivar_36;
        mpz_mk_add(ivar_36, ivar_28, ivar_2);
        ivar_1->count++;
        result = (uint32_t)gen_strings__get((strings__string_t)ivar_1, (mpz_ptr_t)ivar_36);
        return result;
}

gen_strings_closure_5_t new_gen_strings_closure_5(void){
        static struct gen_strings_funtype_0_ftbl_s ftbl = {.fptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&f_gen_strings_closure_5, .mptr = (uint32_t (*)(gen_strings_funtype_0_t, mpz_ptr_t))&m_gen_strings_closure_5, .rptr =  (void (*)(gen_strings_funtype_0_t))&release_gen_strings_closure_5, .cptr = (gen_strings_funtype_0_t (*)(gen_strings_funtype_0_t))&copy_gen_strings_closure_5};
        gen_strings_closure_5_t tmp = (gen_strings_closure_5_t) safe_malloc(sizeof(struct gen_strings_closure_5_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        mpz_init(tmp->fvar_3);
        return tmp;}

void release_gen_strings_closure_5(gen_strings_funtype_0_t closure){
        gen_strings_closure_5_t x = (gen_strings_closure_5_t)closure;
        x->count--;
        if (x->count <= 0){
         release_strings__string((strings__string_t)x->fvar_1);
        //printf("\nFreeing\n");
        safe_free(x);}}

gen_strings_closure_5_t copy_gen_strings_closure_5(gen_strings_closure_5_t x){
        gen_strings_closure_5_t y = new_gen_strings_closure_5();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        mpz_set(y->fvar_2, x->fvar_2);
        mpz_set(y->fvar_3, x->fvar_3);
        if (x->htbl != NULL){
            gen_strings_funtype_0_htbl_t new_htbl = (gen_strings_funtype_0_htbl_t) safe_malloc(sizeof(struct gen_strings_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            gen_strings_funtype_0_hashentry_t * new_data = (gen_strings_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct gen_strings_funtype_0_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

mpz_ptr_t gen_strings__length(strings__string_t ivar_1){
         mpz_ptr_t  result;

        result = safe_malloc(sizeof(mpz_t));
        mpz_init(result);
        mpz_set(result, ivar_1->length);
        release_strings__string((strings__string_t)ivar_1);
        
        
        return result;
}

uint32_t gen_strings__get(strings__string_t ivar_1, mpz_ptr_t ivar_2){
        uint32_t  result;

        gen_strings_funtype_0_t ivar_7;
        gen_strings_funtype_0_t ivar_14;
        ivar_14 = (gen_strings_funtype_0_t)ivar_1->seq;
        ivar_14->count++;
        //copying to gen_strings_funtype_0 from gen_strings_funtype_0;
        ivar_7 = (gen_strings_funtype_0_t)ivar_14;
        if (ivar_7 != NULL) ivar_7->count++;
        release_gen_strings_funtype_0((gen_strings_funtype_0_t)ivar_14);
        result = (uint32_t)ivar_7->ftbl->fptr(ivar_7, ivar_2);
        ivar_7->ftbl->rptr(ivar_7);
        
        
        return result;
}

strings__string_t gen_strings__empty(void){
        strings__string_t  static  result;

        static bool_t defined = false;
        if (!defined){
            
        mpz_ptr_t ivar_1;
        ivar_1 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_1);
        mpz_mk_set_ui(ivar_1, 0);
        gen_strings_funtype_0_t ivar_8;
        gen_strings_closure_1_t cl3931;
        cl3931 = new_gen_strings_closure_1();
        mpz_set(cl3931->fvar_1, ivar_1);
        ivar_8 = (gen_strings_funtype_0_t)cl3931;
        gen_strings_record_2_t tmp3932 = new_gen_strings_record_2();;
        result = (strings__string_t)tmp3932;
        mpz_init(tmp3932->length);
        mpz_set(tmp3932->length, ivar_1);
        mpz_clear(ivar_1);
        tmp3932->seq = (gen_strings_funtype_0_t)ivar_8;
        defined = true;};
        
        result->count++;
        return result;
}

strings__string_t gen_strings__unit(uint32_t ivar_1){
        strings__string_t  result;

        mpz_ptr_t ivar_2;
        ivar_2 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_2);
        mpz_mk_set_ui(ivar_2, 1);
        gen_strings_funtype_0_t ivar_7;
        gen_strings_closure_3_t cl3936;
        cl3936 = new_gen_strings_closure_3();
        mpz_set(cl3936->fvar_1, ivar_2);
        cl3936->fvar_2 = (uint32_t)ivar_1;
        ivar_7 = (gen_strings_funtype_0_t)cl3936;
        gen_strings_record_2_t tmp3937 = new_gen_strings_record_2();;
        result = (strings__string_t)tmp3937;
        mpz_init(tmp3937->length);
        mpz_set(tmp3937->length, ivar_2);
        mpz_clear(ivar_2);
        tmp3937->seq = (gen_strings_funtype_0_t)ivar_7;
        
        result->count++;
        return result;
}

mpz_ptr_t gen_strings__strdiff_rec(strings__string_t ivar_1, strings__string_t ivar_2, mpz_ptr_t ivar_3){
         mpz_ptr_t  result;

        bool_t ivar_26;
        bool_t ivar_27;
        mpz_ptr_t ivar_30;
        ivar_30 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_30);
        mpz_set(ivar_30, ivar_1->length);
        int64_t tmp3938 = mpz_cmp(ivar_3, ivar_30);
        ivar_27 = (tmp3938 == 0);
        if (ivar_27){
             ivar_26 = (bool_t) true;
        } else {
             bool_t ivar_33;
             mpz_ptr_t ivar_36;
             ivar_36 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_36);
             mpz_set(ivar_36, ivar_2->length);
             int64_t tmp3939 = mpz_cmp(ivar_3, ivar_36);
             ivar_33 = (tmp3939 == 0);
             if (ivar_33){
           ivar_26 = (bool_t) true;
             } else {
           uint32_t ivar_39;
           ivar_1->count++;
           ivar_39 = (uint32_t)gen_strings__get((strings__string_t)ivar_1, (mpz_ptr_t)ivar_3);
           uint32_t ivar_40;
           ivar_2->count++;
           ivar_40 = (uint32_t)gen_strings__get((strings__string_t)ivar_2, (mpz_ptr_t)ivar_3);
           ivar_26 = (ivar_39 != ivar_40);};};
        if (ivar_26){
             release_strings__string((strings__string_t)ivar_2);
             release_strings__string((strings__string_t)ivar_1);
             //copying to mpz from mpz;
             mpz_mk_set(result, ivar_3);
             mpz_clear(ivar_3);
        } else {
             mpz_ptr_t ivar_76;
             uint8_t ivar_71;
             ivar_71 = (uint8_t)1;
             mpz_mk_set_ui(ivar_76, (uint64_t)ivar_71);
             mpz_add(ivar_76, ivar_76, ivar_3);
             result = (mpz_ptr_t)gen_strings__strdiff_rec((strings__string_t)ivar_1, (strings__string_t)ivar_2, ivar_76);};
        
        
        return result;
}

mpz_ptr_t gen_strings__strdiff(strings__string_t ivar_1, strings__string_t ivar_2){
         mpz_ptr_t  result;

        uint8_t ivar_44;
        ivar_44 = (uint8_t)0;
        mpz_ptr_t ivar_31;
        //copying to mpz from uint8;
        mpz_mk_set_ui(ivar_31, ivar_44);
        result = (mpz_ptr_t)gen_strings__strdiff_rec((strings__string_t)ivar_1, (strings__string_t)ivar_2, (mpz_ptr_t)ivar_31);
        
        
        return result;
}

int8_t gen_strings__strcmp(strings__string_t ivar_1, strings__string_t ivar_2){
        int8_t  result;

        /* i */ mpz_ptr_t ivar_3;
        ivar_1->count++;
        ivar_2->count++;
        ivar_3 = (mpz_ptr_t)gen_strings__strdiff((strings__string_t)ivar_1, (strings__string_t)ivar_2);
        bool_t ivar_31;
        mpq_ptr_t ivar_33;
        mpz_ptr_t ivar_44;
        ivar_44 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_44);
        mpz_set(ivar_44, ivar_1->length);
        mpq_ptr_t ivar_39;
        //copying to mpq from mpz;
        mpq_mk_set_z(ivar_39, ivar_44);
        mpz_clear(ivar_44);
        mpz_ptr_t ivar_43;
        ivar_43 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_43);
        mpz_set(ivar_43, ivar_2->length);
        mpq_ptr_t ivar_40;
        //copying to mpq from mpz;
        mpq_mk_set_z(ivar_40, ivar_43);
        mpz_clear(ivar_43);
        ivar_33 = (mpq_ptr_t)real_defs__min((mpq_ptr_t)ivar_39, (mpq_ptr_t)ivar_40);
        int64_t tmp3940 = mpq_cmp_z(ivar_33, ivar_3);
        ivar_31 = (tmp3940 == 0);
        if (ivar_31){
             bool_t ivar_46;
             mpz_ptr_t ivar_47;
             ivar_47 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_47);
             mpz_set(ivar_47, ivar_1->length);
             mpz_ptr_t ivar_48;
             ivar_48 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_48);
             mpz_set(ivar_48, ivar_2->length);
             int64_t tmp3941 = mpz_cmp(ivar_47, ivar_48);
             ivar_46 = (tmp3941 < 0);
             if (ivar_46){
           release_strings__string((strings__string_t)ivar_1);
           release_strings__string((strings__string_t)ivar_2);
           result = (int8_t)-1;
             } else {
           bool_t ivar_52;
           mpz_ptr_t ivar_53;
           ivar_53 = safe_malloc(sizeof(mpz_t));
           mpz_init(ivar_53);
           mpz_set(ivar_53, ivar_1->length);
           release_strings__string((strings__string_t)ivar_1);
           mpz_ptr_t ivar_54;
           ivar_54 = safe_malloc(sizeof(mpz_t));
           mpz_init(ivar_54);
           mpz_set(ivar_54, ivar_2->length);
           release_strings__string((strings__string_t)ivar_2);
           int64_t tmp3942 = mpz_cmp(ivar_53, ivar_54);
           ivar_52 = (tmp3942 > 0);
           if (ivar_52){
           result = (int8_t)1;
           } else {
           result = (int8_t)0;};};
        } else {
             bool_t ivar_58;
             uint32_t ivar_59;
             uint32_t ivar_61;
             ivar_61 = (uint32_t)gen_strings__get((strings__string_t)ivar_1, (mpz_ptr_t)ivar_3);
             ivar_59 = (uint32_t) ivar_61;
             uint32_t ivar_60;
             uint32_t ivar_69;
             ivar_69 = (uint32_t)gen_strings__get((strings__string_t)ivar_2, (mpz_ptr_t)ivar_3);
             ivar_60 = (uint32_t) ivar_69;
             ivar_58 = (ivar_59 < ivar_60);
             if (ivar_58){
           result = (int8_t)-1;
             } else {
           result = (int8_t)1;};};
        
        
        return result;
}

strings__string_t gen_strings__prefix(strings__string_t ivar_1, mpz_ptr_t ivar_2){
        strings__string_t  result;

        bool_t ivar_4;
        mpz_ptr_t ivar_6;
        ivar_6 = safe_malloc(sizeof(mpz_t));
        mpz_init(ivar_6);
        mpz_set(ivar_6, ivar_1->length);
        int64_t tmp3945 = mpz_cmp(ivar_2, ivar_6);
        ivar_4 = (tmp3945 == 0);
        if (ivar_4){
             //copying to strings__string from strings__string;
             result = (strings__string_t)ivar_1;
             if (result != NULL) result->count++;
             release_strings__string((strings__string_t)ivar_1);
        } else {
             gen_strings_funtype_0_t ivar_23;
             gen_strings_closure_4_t cl3947;
             cl3947 = new_gen_strings_closure_4();
             cl3947->fvar_1 = (strings__string_t)ivar_1;
             if (cl3947->fvar_1 != NULL) cl3947->fvar_1->count++;
             mpz_set(cl3947->fvar_2, ivar_2);
             release_strings__string((strings__string_t)ivar_1);
             ivar_23 = (gen_strings_funtype_0_t)cl3947;
             gen_strings_record_2_t tmp3948 = new_gen_strings_record_2();;
             result = (strings__string_t)tmp3948;
             mpz_init(tmp3948->length);
             mpz_set(tmp3948->length, ivar_2);
             mpz_clear(ivar_2);
             tmp3948->seq = (gen_strings_funtype_0_t)ivar_23;};
        
        result->count++;
        return result;
}

strings__string_t gen_strings__suffix(strings__string_t ivar_1, mpz_ptr_t ivar_2){
        strings__string_t  result;

        bool_t ivar_4;
        uint8_t ivar_6;
        ivar_6 = (uint8_t)0;
        int64_t tmp3951 = mpz_cmp_ui(ivar_2, ivar_6);
        ivar_4 = (tmp3951 == 0);
        if (ivar_4){
             //copying to strings__string from strings__string;
             result = (strings__string_t)ivar_1;
             if (result != NULL) result->count++;
             release_strings__string((strings__string_t)ivar_1);
        } else {
             mpz_ptr_t ivar_12;
             mpz_ptr_t ivar_8;
             ivar_8 = safe_malloc(sizeof(mpz_t));
             mpz_init(ivar_8);
             mpz_set(ivar_8, ivar_1->length);
             mpz_mk_sub(ivar_12, ivar_8, ivar_2);
             gen_strings_funtype_0_t ivar_38;
             gen_strings_closure_5_t cl3953;
             cl3953 = new_gen_strings_closure_5();
             cl3953->fvar_1 = (strings__string_t)ivar_1;
             if (cl3953->fvar_1 != NULL) cl3953->fvar_1->count++;
             mpz_set(cl3953->fvar_2, ivar_2);
             mpz_set(cl3953->fvar_3, ivar_12);
             release_strings__string((strings__string_t)ivar_1);
             ivar_38 = (gen_strings_funtype_0_t)cl3953;
             gen_strings_record_2_t tmp3954 = new_gen_strings_record_2();;
             result = (strings__string_t)tmp3954;
             mpz_init(tmp3954->length);
             mpz_set(tmp3954->length, ivar_12);
             mpz_clear(ivar_12);
             tmp3954->seq = (gen_strings_funtype_0_t)ivar_38;};
        
        result->count++;
        return result;
}

strings__string_t gen_strings__substr(strings__string_t ivar_1, mpz_ptr_t ivar_2, mpz_ptr_t ivar_4){
        strings__string_t  result;

        strings__string_t ivar_18;
        ivar_1->count++;
        ivar_18 = (strings__string_t)gen_strings__suffix((strings__string_t)ivar_1, (mpz_ptr_t)ivar_2);
        mpz_ptr_t ivar_19;
        mpz_mk_sub(ivar_19, ivar_4, ivar_2);
        result = (strings__string_t)gen_strings__prefix((strings__string_t)ivar_18, (mpz_ptr_t)ivar_19);
        
        result->count++;
        return result;
}