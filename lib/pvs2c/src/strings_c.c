//Code generated using pvs2ir2c
#include "strings_c.h"

void release_strings_funtype_0(strings_funtype_0_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

strings_funtype_0_t copy_strings_funtype_0(strings_funtype_0_t x){return x->ftbl->cptr(x);}

uint32_t lookup_strings_funtype_0(strings_funtype_0_htbl_t htbl, mpz_ptr_t i, uint32_t ihash){
        uint32_t mask = htbl->size - 1;
        uint32_t hashindex = ihash & mask;
        strings_funtype_0_hashentry_t data = htbl->data[hashindex];
        bool_t keyzero;


        int64_t tmp3911 = mpz_cmp_ui(data.key, 0);
        keyzero = (tmp3911 == 0);
        bool_t keymatch;

        int64_t tmp3912 = mpz_cmp(data.key, i);
        keymatch = (tmp3912 == 0);
        while ((!keyzero || data.keyhash != 0) &&
                 (data.keyhash != ihash || !keymatch)){
                hashindex++;
                hashindex = hashindex & mask;
                data = htbl->data[hashindex];


                int64_t tmp3911 = mpz_cmp_ui(data.key, 0);
                keyzero = (tmp3911 == 0);


                int64_t tmp3912 = mpz_cmp(data.key, i);
                keymatch = (tmp3912 == 0);
                }
        return hashindex;
        }

strings_funtype_0_t dupdate_strings_funtype_0(strings_funtype_0_t a, mpz_ptr_t i, uint32_t v){
        strings_funtype_0_htbl_t htbl = a->htbl;
        if (htbl == NULL){//construct new htbl
                htbl = (strings_funtype_0_htbl_t)safe_malloc(sizeof(struct strings_funtype_0_htbl_s));
                htbl->size = HTBL_DEFAULT_SIZE; htbl->num_entries = 0;
                htbl->data = (strings_funtype_0_hashentry_t *)safe_malloc(HTBL_DEFAULT_SIZE * sizeof(struct strings_funtype_0_hashentry_s));
                for (uint32_t j = 0; j < HTBL_DEFAULT_SIZE; j++){mpz_init(htbl->data[j].key);mpz_set_ui(htbl->data[j].key, 0); htbl->data[j].keyhash = 0;
                }
                a->htbl = htbl;
        }
        uint32_t size = htbl->size;
        uint32_t num_entries = htbl->num_entries;
        strings_funtype_0_hashentry_t * data = htbl->data;
        if (num_entries/3 >  size/5){//resize data
                uint32_t new_size = 2*size; uint32_t new_mask = new_size - 1;
                if (size >= HTBL_MAX_SIZE) out_of_memory();
                strings_funtype_0_hashentry_t * new_data = (strings_funtype_0_hashentry_t *)safe_malloc(new_size * sizeof(struct strings_funtype_0_hashentry_s));
                for (uint32_t j = 0; j < new_size; j++){
                        new_data[j].key = 0;
                        new_data[j].keyhash = 0;}
                for (uint32_t j = 0; j < size; j++){//transfer entries
                        uint32_t keyhash = data[j].keyhash;
                        bool_t keyzero;
                        int64_t tmp3913 = mpz_cmp_ui(data[j].key, 0);
                        keyzero = (tmp3913 == 0);

                        if (!keyzero || keyhash != 0){
                                uint32_t new_loc = keyhash ^ new_mask;
                                int64_t tmp3914 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                keyzero = (tmp3914 == 0);

                                while (keyzero && new_data[new_loc].keyhash == 0){
                                        new_loc++;
                                        new_loc = new_loc ^ new_mask;

                                        int64_t tmp3915 = mpz_cmp_ui(new_data[new_loc].key, 0);
                                        keyzero = (tmp3915 == 0);

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
        uint32_t hashindex = lookup_strings_funtype_0(htbl, i, ihash);
        strings_funtype_0_hashentry_t hentry = htbl->data[hashindex];
        uint32_t hkeyhash = hentry.keyhash;
        bool_t hentrykeyzero;
        int64_t tmp3916 = mpz_cmp_ui(hentry.key, 0);
        hentrykeyzero = (tmp3916 == 0);

        if (hentrykeyzero && (hkeyhash == 0))
                {mpz_set(htbl->data[hashindex].key, i); htbl->data[hashindex].keyhash = ihash; htbl->data[hashindex].value = (uint32_t)v; htbl->num_entries++;}
            else {htbl->data[hashindex].value = (uint32_t)v;};
        return a;

}

strings_funtype_0_t update_strings_funtype_0(strings_funtype_0_t a, mpz_ptr_t i, uint32_t v){
        if (a->count == 1){
                return dupdate_strings_funtype_0(a, i, v);
            } else {
                strings_funtype_0_t x = copy_strings_funtype_0(a);
                a->count--;
                return dupdate_strings_funtype_0(x, i, v);
            }}

bool_t equal_strings_funtype_0(strings_funtype_0_t x, strings_funtype_0_t y){
        return false;}

char* json_strings_funtype_0(strings_funtype_0_t x){char * result = safe_malloc(27); sprintf(result, "%s", "\"strings_funtype_0\""); return result;}


strings__string_t new_strings__string(void){
        strings__string_t tmp = (strings__string_t) safe_malloc(sizeof(struct strings__string_s));
        tmp->count = 1;
        return tmp;}

void release_strings__string(strings__string_t x){
        x->count--;
        if (x->count <= 0){
         release_strings_funtype_0((strings_funtype_0_t)x->seq);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_strings__string_ptr(pointer_t x, type_actual_t T){
        release_strings__string((strings__string_t)x);
}

strings__string_t copy_strings__string(strings__string_t x){
        strings__string_t y = new_strings__string();
        mpz_set(y->length, x->length);
        y->seq = x->seq;
        if (y->seq != NULL){y->seq->count++;};
        y->count = 1;
        return y;}

bool_t equal_strings__string(strings__string_t x, strings__string_t y){
        bool_t tmp = true; tmp = tmp && (mpz_cmp(x->length, y->length) == 0); tmp = tmp && equal_strings_funtype_0((strings_funtype_0_t)x->seq, (strings_funtype_0_t)y->seq);
        return tmp;}

char * json_strings__string(strings__string_t x){
        char * tmp[2]; 
        char * fld0 = safe_malloc(18);
         sprintf(fld0, "\"length\" : ");
        tmp[0] = safe_strcat(fld0, json_mpz(x->length));
        char * fld1 = safe_malloc(15);
         sprintf(fld1, "\"seq\" : ");
        tmp[1] = safe_strcat(fld1, json_strings_funtype_0((strings_funtype_0_t)x->seq));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_strings__string_ptr(pointer_t x, pointer_t y, actual_strings__string_t T){
        return equal_strings__string((strings__string_t)x, (strings__string_t)y);
}

char * json_strings__string_ptr(pointer_t x, actual_strings__string_t T){
        return json_strings__string((strings__string_t)x);
}

actual_strings__string_t actual_strings__string(){
        actual_strings__string_t new = (actual_strings__string_t)safe_malloc(sizeof(struct actual_strings__string_s));
        new->equal_ptr = (equal_ptr_t)(*equal_strings__string_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_strings__string_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_strings__string_ptr);
 

 
        return new;
 };

strings__string_t update_strings__string_length(strings__string_t x, mpz_ptr_t v){
        strings__string_t y;
        if (x->count == 1){y = x;}
        else {y = copy_strings__string(x); x->count--;};
        mpz_set(y->length, v);
        return y;}

strings__string_t update_strings__string_seq(strings__string_t x, strings_funtype_0_t v){
        strings__string_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->seq != NULL){release_strings_funtype_0((strings_funtype_0_t)x->seq);};}
        else {y = copy_strings__string(x); x->count--; y->seq->count--;};
        y->seq = (strings_funtype_0_t)v;
        return y;}




strings_array_2_t new_strings_array_2(uint32_t size){
        strings_array_2_t tmp = (strings_array_2_t) safe_malloc(sizeof(struct strings_array_2_s) + (size * sizeof(uint32_t)));
        tmp->count = 1;
        tmp->size = size;;
        tmp->max = size;
         return tmp;}

void release_strings_array_2(strings_array_2_t x){
        x->count--;
         if (x->count <= 0){safe_free(x);}
}

void release_strings_array_2_ptr(pointer_t x, type_actual_t T){
        release_strings_array_2((strings_array_2_t)x);
}

strings_array_2_t copy_strings_array_2(strings_array_2_t x){
        strings_array_2_t tmp = new_strings_array_2(x->max);
        tmp->count = 1;
        tmp->size = x->max;
        for (uint32_t i = 0; i < x->max; i++){tmp->elems[i] = (uint32_t)x->elems[i];};
         return tmp;}

bool_t equal_strings_array_2(strings_array_2_t x, strings_array_2_t y){
        bool_t tmp = true;
        uint32_t i = 0;
        while (i < x->size && tmp){tmp = (x->elems[i] == y->elems[i]); i++;};
        return tmp;}

char * json_strings_array_2(strings_array_2_t x){
        char ** tmp = (char **)safe_malloc(sizeof(void *) * x->size);
        for (uint32_t i = 0; i < x->size; i++){tmp[i] = json_uint32(x->elems[i]);};
        char * result = json_list_with_sep(tmp, x->size, '[', ',', ']');
        for (uint32_t i = 0; i < x->size; i++) free(tmp[i]);
        free(tmp);
        return result;}

bool_t equal_strings_array_2_ptr(pointer_t x, pointer_t y, type_actual_t T){
        return equal_strings_array_2((strings_array_2_t)x, (strings_array_2_t)y);
}

char * json_strings_array_2_ptr(pointer_t x, type_actual_t T){
        return json_strings_array_2((strings_array_2_t)x);
}

actual_strings_array_2_t actual_strings_array_2(){
        actual_strings_array_2_t new = (actual_strings_array_2_t)safe_malloc(sizeof(struct actual_strings_array_2_s));
        new->equal_ptr = (equal_ptr_t)(*equal_strings_array_2_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_strings_array_2_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_strings_array_2_ptr);
 

 
        return new;
 };

strings_array_2_t update_strings_array_2(strings_array_2_t x, uint32_t i, uint32_t v){
        strings_array_2_t y; 
         if (x->count == 1){y = x;}
           else {y = copy_strings_array_2(x );
                x->count--;};
        y->elems[i] = (uint32_t)v;
        return y;}

strings_array_2_t upgrade_strings_array_2(strings_array_2_t x, uint32_t i, uint32_t v){
        strings_array_2_t y;
        uint32_t xmax = x->max;
         if (x->count == 1 && i < xmax){y = x;}
           else if (i >= xmax){uint32_t newmax = ((xmax < UINT32_MAX/2) ? ((i < 2 * (xmax + 1)) ? 2 * (xmax + 1) : i + 1) : UINT32_MAX);
                y = safe_realloc(x, sizeof(struct strings_array_2_s) + (newmax * sizeof(uint32_t)));
                y->count = 1;
                y->size = i+1;
                y->max = newmax;}
           else {y = copy_strings_array_2(x );
                x->count--;};
        ;
        return y;}




uint32_t f_strings_closure_3(struct strings_closure_3_s * closure, mpz_ptr_t bvar){
if (closure->htbl != NULL){
        strings_funtype_0_htbl_t htbl = closure->htbl;
        uint32_t hash = mpz_hash(bvar);
        uint32_t hashindex = lookup_strings_funtype_0(htbl, bvar, hash);
        strings_funtype_0_hashentry_t entry = htbl->data[hashindex];
        bool_t keyzero;
         int64_t tmp3919 = mpz_cmp_ui(entry.key, 0);
         keyzero = (tmp3919 == 0);
        if (!keyzero || entry.keyhash != 0){
            uint32_t result;
            result = (uint32_t)entry.value;
            return result;}
        

        return h_strings_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);};

return h_strings_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

uint32_t m_strings_closure_3(struct strings_closure_3_s * closure, mpz_ptr_t bvar){
        return h_strings_closure_3(bvar, closure->fvar_1, closure->fvar_2, closure->fvar_3);}

uint32_t h_strings_closure_3(mpz_ptr_t ivar_8, uint32_t ivar_1, strings_array_2_t ivar_2, mpz_ptr_t ivar_4){
        uint32_t result;

        /* j */ uint32_t ivar_7;
        //copying to uint32 from mpz;
        ivar_7 = (uint32_t)mpz_get_ui(ivar_8);
        mpz_clear(ivar_8);
        result = (uint32_t)ivar_2->elems[ivar_7];
        return result;
}

strings_closure_3_t new_strings_closure_3(void){
        static struct strings_funtype_0_ftbl_s ftbl = {.fptr = (uint32_t (*)(strings_funtype_0_t, mpz_ptr_t))&f_strings_closure_3, .mptr = (uint32_t (*)(strings_funtype_0_t, mpz_ptr_t))&m_strings_closure_3, .rptr =  (void (*)(strings_funtype_0_t))&release_strings_closure_3, .cptr = (strings_funtype_0_t (*)(strings_funtype_0_t))&copy_strings_closure_3};
        strings_closure_3_t tmp = (strings_closure_3_t) safe_malloc(sizeof(struct strings_closure_3_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_3);
        return tmp;}

void release_strings_closure_3(strings_funtype_0_t closure){
        strings_closure_3_t x = (strings_closure_3_t)closure;
        x->count--;
        if (x->count <= 0){
         release_strings_array_2((strings_array_2_t)x->fvar_2);
        //printf("\nFreeing\n");
        safe_free(x);}}

strings_closure_3_t copy_strings_closure_3(strings_closure_3_t x){
        strings_closure_3_t y = new_strings_closure_3();
        y->ftbl = x->ftbl;

        y->fvar_1 = (uint32_t)x->fvar_1;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        mpz_set(y->fvar_3, x->fvar_3);
        if (x->htbl != NULL){
            strings_funtype_0_htbl_t new_htbl = (strings_funtype_0_htbl_t) safe_malloc(sizeof(struct strings_funtype_0_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            strings_funtype_0_hashentry_t * new_data = (strings_funtype_0_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct strings_funtype_0_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct strings_funtype_0_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

strings__string_t strings__make_string(uint32_t ivar_1, strings_array_2_t ivar_2){
        strings__string_t  result;

        mpz_ptr_t ivar_4;
        //copying to mpz from uint32;
        mpz_mk_set_ui(ivar_4, ivar_1);
        strings_funtype_0_t ivar_13;
        strings_closure_3_t cl3920;
        cl3920 = new_strings_closure_3();
        cl3920->fvar_1 = (uint32_t)ivar_1;
        cl3920->fvar_2 = (strings_array_2_t)ivar_2;
        if (cl3920->fvar_2 != NULL) cl3920->fvar_2->count++;
        mpz_set(cl3920->fvar_3, ivar_4);
        release_strings_array_2((strings_array_2_t)ivar_2);
        ivar_13 = (strings_funtype_0_t)cl3920;
        strings__string_t tmp3921 = new_strings__string();;
        result = (strings__string_t)tmp3921;
        mpz_init(tmp3921->length);
        mpz_set(tmp3921->length, ivar_4);
        mpz_clear(ivar_4);
        tmp3921->seq = (strings_funtype_0_t)ivar_13;
        
        result->count++;
        return result;
}