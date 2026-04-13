//Code generated using pvs2ir2c
#include "file_c.h"


file__lifted_file_adt_t new_file__lifted_file_adt(void){
        file__lifted_file_adt_t tmp = (file__lifted_file_adt_t) safe_malloc(sizeof(struct file__lifted_file_adt_s));
        tmp->count = 1;
        return tmp;}

void release_file__lifted_file_adt(file__lifted_file_adt_t x){
switch (x->file__lifted_file_adt_index) {
case 1:  release_file__pass((file__pass_t)x); break;
}}

void release_file__lifted_file_adt_ptr(pointer_t x, type_actual_t T){
        release_file__lifted_file_adt((file__lifted_file_adt_t)x);
}

file__lifted_file_adt_t copy_file__lifted_file_adt(file__lifted_file_adt_t x){
        file__lifted_file_adt_t y = new_file__lifted_file_adt();
        y->file__lifted_file_adt_index = (uint8_t)x->file__lifted_file_adt_index;
        y->count = 1;
        return y;}

bool_t equal_file__lifted_file_adt(file__lifted_file_adt_t x, file__lifted_file_adt_t y){
        bool_t tmp = x->file__lifted_file_adt_index == y->file__lifted_file_adt_index;
        switch  (x->file__lifted_file_adt_index) {
                case 1: tmp = tmp && equal_file__pass((file__pass_t)x, (file__pass_t)y); break;
        }
        return tmp;
}

char * json_file__lifted_file_adt(file__lifted_file_adt_t x){
        char * tmp = safe_malloc(24); sprintf(tmp, "{ \"constructor\": %u,", x->file__lifted_file_adt_index); tmp = safe_strcat(tmp, " \"value\": ");
        switch  (x->file__lifted_file_adt_index) {
                case 1: tmp = safe_strcat(tmp, json_file__pass((file__pass_t)x)); break;
                default: tmp = safe_strcat(tmp, "null");
        };
        tmp = safe_strcat(tmp, " }");
        return tmp;
}

bool_t equal_file__lifted_file_adt_ptr(pointer_t x, pointer_t y, actual_file__lifted_file_adt_t T){
        return equal_file__lifted_file_adt((file__lifted_file_adt_t)x, (file__lifted_file_adt_t)y);
}

char * json_file__lifted_file_adt_ptr(pointer_t x, actual_file__lifted_file_adt_t T){
        return json_file__lifted_file_adt((file__lifted_file_adt_t)x);
}

actual_file__lifted_file_adt_t actual_file__lifted_file_adt(){
        actual_file__lifted_file_adt_t new = (actual_file__lifted_file_adt_t)safe_malloc(sizeof(struct actual_file__lifted_file_adt_s));
        new->equal_ptr = (equal_ptr_t)(*equal_file__lifted_file_adt_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_file__lifted_file_adt_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_file__lifted_file_adt_ptr);
 

 
        return new;
 };

file__lifted_file_adt_t update_file__lifted_file_adt_file__lifted_file_adt_index(file__lifted_file_adt_t x, uint8_t v){
        file__lifted_file_adt_t y;
        if (x->count == 1){y = x;}
        else {y = copy_file__lifted_file_adt(x); x->count--;};
        y->file__lifted_file_adt_index = (uint8_t)v;
        return y;}




file__pass_t new_file__pass(void){
        file__pass_t tmp = (file__pass_t) safe_malloc(sizeof(struct file__pass_s));
        tmp->count = 1;
        return tmp;}

void release_file__pass(file__pass_t x){
        x->count--;
        if (x->count <= 0){
         release_file__file((file__file_t)x->contents);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_file__pass_ptr(pointer_t x, type_actual_t T){
        release_file__pass((file__pass_t)x);
}

file__pass_t copy_file__pass(file__pass_t x){
        file__pass_t y = new_file__pass();
        y->file__lifted_file_adt_index = (uint8_t)x->file__lifted_file_adt_index;
        y->contents = x->contents;
        if (y->contents != NULL){y->contents->count++;};
        y->count = 1;
        return y;}

bool_t equal_file__pass(file__pass_t x, file__pass_t y){
        bool_t tmp = true; tmp = tmp && x->file__lifted_file_adt_index == y->file__lifted_file_adt_index; tmp = tmp && equal_file__file((file__file_t)x->contents, (file__file_t)y->contents);
        return tmp;}

char * json_file__pass(file__pass_t x){
        char * tmp[2]; 
        char * fld0 = safe_malloc(39);
         sprintf(fld0, "\"file__lifted_file_adt_index\" : ");
        tmp[0] = safe_strcat(fld0, json_uint8(x->file__lifted_file_adt_index));
        char * fld1 = safe_malloc(20);
         sprintf(fld1, "\"contents\" : ");
        tmp[1] = safe_strcat(fld1, json_file__file((file__file_t)x->contents));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_file__pass_ptr(pointer_t x, pointer_t y, actual_file__pass_t T){
        return equal_file__pass((file__pass_t)x, (file__pass_t)y);
}

char * json_file__pass_ptr(pointer_t x, actual_file__pass_t T){
        return json_file__pass((file__pass_t)x);
}

actual_file__pass_t actual_file__pass(){
        actual_file__pass_t new = (actual_file__pass_t)safe_malloc(sizeof(struct actual_file__pass_s));
        new->equal_ptr = (equal_ptr_t)(*equal_file__pass_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_file__pass_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_file__pass_ptr);
 

 
        return new;
 };

file__pass_t update_file__pass_file__lifted_file_adt_index(file__pass_t x, uint8_t v){
        file__pass_t y;
        if (x->count == 1){y = x;}
        else {y = copy_file__pass(x); x->count--;};
        y->file__lifted_file_adt_index = (uint8_t)v;
        return y;}

file__pass_t update_file__pass_contents(file__pass_t x, file__file_t v){
        file__pass_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->contents != NULL){release_file__file((file__file_t)x->contents);};}
        else {y = copy_file__pass(x); x->count--; y->contents->count--;};
        y->contents = (file__file_t)v;
        return y;}



void release_file_funtype_3(file_funtype_3_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

file_funtype_3_t copy_file_funtype_3(file_funtype_3_t x){return x->ftbl->cptr(x);}

bool_t equal_file_funtype_3(file_funtype_3_t x, file_funtype_3_t y){
        return false;}

char* json_file_funtype_3(file_funtype_3_t x){char * result = safe_malloc(24); sprintf(result, "%s", "\"file_funtype_3\""); return result;}

void release_file_funtype_4(file_funtype_4_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

file_funtype_4_t copy_file_funtype_4(file_funtype_4_t x){return x->ftbl->cptr(x);}

bool_t equal_file_funtype_4(file_funtype_4_t x, file_funtype_4_t y){
        return false;}

char* json_file_funtype_4(file_funtype_4_t x){char * result = safe_malloc(24); sprintf(result, "%s", "\"file_funtype_4\""); return result;}


mpz_ptr_t f_file_closure_5(struct file_closure_5_s * closure, file__lifted_file_adt_t bvar){
        mpz_ptr_t result = h_file_closure_5(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

mpz_ptr_t m_file_closure_5(struct file_closure_5_s * closure, file__lifted_file_adt_t bvar){
        return h_file_closure_5(bvar, closure->fvar_1, closure->fvar_2);}

mpz_ptr_t h_file_closure_5(file__lifted_file_adt_t ivar_6, file_funtype_4_t ivar_2, mpz_ptr_t ivar_1){
        mpz_ptr_t result;

        bool_t ivar_17;
        ivar_6->count++;
        ivar_17 = (bool_t)rec_file__failp((file__lifted_file_adt_t)ivar_6);
        if (ivar_17){
             release_file__lifted_file_adt((file__lifted_file_adt_t)ivar_6);
             //copying to mpz from mpz;
             mpz_mk_set(result, ivar_1);
        } else {
             file__file_t ivar_21;
             ivar_21 = (file__file_t)acc_file__lifted_file_adt_contents((file__lifted_file_adt_t)ivar_6);
             mpz_mk_set(result, ivar_2->ftbl->fptr(ivar_2, ivar_21));};
        return result;
}

file_closure_5_t new_file_closure_5(void){
        static struct file_funtype_3_ftbl_s ftbl = {.fptr = (mpz_ptr_t (*)(file_funtype_3_t, file__lifted_file_adt_t))&f_file_closure_5, .mptr = (mpz_ptr_t (*)(file_funtype_3_t, file__lifted_file_adt_t))&m_file_closure_5, .rptr =  (void (*)(file_funtype_3_t))&release_file_closure_5, .cptr = (file_funtype_3_t (*)(file_funtype_3_t))&copy_file_closure_5};
        file_closure_5_t tmp = (file_closure_5_t) safe_malloc(sizeof(struct file_closure_5_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        mpz_init(tmp->fvar_2);
        return tmp;}

void release_file_closure_5(file_funtype_3_t closure){
        file_closure_5_t x = (file_closure_5_t)closure;
        x->count--;
        if (x->count <= 0){
         release_file_funtype_4((file_funtype_4_t)x->fvar_1);
        //printf("\nFreeing\n");
        safe_free(x);}}

file_closure_5_t copy_file_closure_5(file_closure_5_t x){
        file_closure_5_t y = new_file_closure_5();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        mpz_set(y->fvar_2, x->fvar_2);
        if (x->htbl != NULL){
            file_funtype_3_htbl_t new_htbl = (file_funtype_3_htbl_t) safe_malloc(sizeof(struct file_funtype_3_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            file_funtype_3_hashentry_t * new_data = (file_funtype_3_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct file_funtype_3_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct file_funtype_3_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}


file_record_6_t new_file_record_6(void){
        file_record_6_t tmp = (file_record_6_t) safe_malloc(sizeof(struct file_record_6_s));
        tmp->count = 1;
        return tmp;}

void release_file_record_6(file_record_6_t x){
        x->count--;
        if (x->count <= 0){
         release_file__file((file__file_t)x->project_1);
         release_file__lifted_file_adt((file__lifted_file_adt_t)x->project_2);
        //printf("\nFreeing\n");
        safe_free(x);}}

void release_file_record_6_ptr(pointer_t x, type_actual_t T){
        release_file_record_6((file_record_6_t)x);
}

file_record_6_t copy_file_record_6(file_record_6_t x){
        file_record_6_t y = new_file_record_6();
        y->project_1 = x->project_1;
        if (y->project_1 != NULL){y->project_1->count++;};
        y->project_2 = x->project_2;
        if (y->project_2 != NULL){y->project_2->count++;};
        y->count = 1;
        return y;}

bool_t equal_file_record_6(file_record_6_t x, file_record_6_t y){
        bool_t tmp = true; tmp = tmp && equal_file__file((file__file_t)x->project_1, (file__file_t)y->project_1); tmp = tmp && equal_file__lifted_file_adt((file__lifted_file_adt_t)x->project_2, (file__lifted_file_adt_t)y->project_2);
        return tmp;}

char * json_file_record_6(file_record_6_t x){
        char * tmp[2]; 
        char * fld0 = safe_malloc(21);
         sprintf(fld0, "\"project_1\" : ");
        tmp[0] = safe_strcat(fld0, json_file__file((file__file_t)x->project_1));
        char * fld1 = safe_malloc(21);
         sprintf(fld1, "\"project_2\" : ");
        tmp[1] = safe_strcat(fld1, json_file__lifted_file_adt((file__lifted_file_adt_t)x->project_2));
         char * result = json_list_with_sep(tmp, 2,  '{', ',', '}');
         for (uint32_t i = 0; i < 2; i++) free(tmp[i]);
        return result;}

bool_t equal_file_record_6_ptr(pointer_t x, pointer_t y, actual_file_record_6_t T){
        return equal_file_record_6((file_record_6_t)x, (file_record_6_t)y);
}

char * json_file_record_6_ptr(pointer_t x, actual_file_record_6_t T){
        return json_file_record_6((file_record_6_t)x);
}

actual_file_record_6_t actual_file_record_6(){
        actual_file_record_6_t new = (actual_file_record_6_t)safe_malloc(sizeof(struct actual_file_record_6_s));
        new->equal_ptr = (equal_ptr_t)(*equal_file_record_6_ptr);
 
        new->release_ptr = (release_ptr_t)(*release_file_record_6_ptr);
 
        new->json_ptr = (json_ptr_t)(*json_file_record_6_ptr);
 

 
        return new;
 };

file_record_6_t update_file_record_6_project_1(file_record_6_t x, file__file_t v){
        file_record_6_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_1 != NULL){release_file__file((file__file_t)x->project_1);};}
        else {y = copy_file_record_6(x); x->count--; y->project_1->count--;};
        y->project_1 = (file__file_t)v;
        return y;}

file_record_6_t update_file_record_6_project_2(file_record_6_t x, file__lifted_file_adt_t v){
        file_record_6_t y;
        if (v != NULL){v->count++;};
        if (x->count == 1){y = x; if (x->project_2 != NULL){release_file__lifted_file_adt((file__lifted_file_adt_t)x->project_2);};}
        else {y = copy_file_record_6(x); x->count--; y->project_2->count--;};
        y->project_2 = (file__lifted_file_adt_t)v;
        return y;}



void release_file_funtype_7(file_funtype_7_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

file_funtype_7_t copy_file_funtype_7(file_funtype_7_t x){return x->ftbl->cptr(x);}

bool_t equal_file_funtype_7(file_funtype_7_t x, file_funtype_7_t y){
        return false;}

char* json_file_funtype_7(file_funtype_7_t x){char * result = safe_malloc(24); sprintf(result, "%s", "\"file_funtype_7\""); return result;}


mpz_ptr_t f_file_closure_8(struct file_closure_8_s * closure, file__lifted_file_adt_t bvar){
        mpz_ptr_t result = h_file_closure_8(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

mpz_ptr_t m_file_closure_8(struct file_closure_8_s * closure, file__lifted_file_adt_t bvar){
        return h_file_closure_8(bvar, closure->fvar_1, closure->fvar_2);}

mpz_ptr_t h_file_closure_8(file__lifted_file_adt_t ivar_7, file_funtype_3_t ivar_1, file_funtype_7_t ivar_3){
        mpz_ptr_t result;

        bool_t ivar_25;
        ivar_7->count++;
        ivar_25 = (bool_t)rec_file__failp((file__lifted_file_adt_t)ivar_7);
        if (ivar_25){
             mpz_mk_set(result, ivar_1->ftbl->fptr(ivar_1, ivar_7));
        } else {
             file__file_t ivar_29;
             ivar_7->count++;
             ivar_29 = (file__file_t)acc_file__lifted_file_adt_contents((file__lifted_file_adt_t)ivar_7);
             mpz_mk_set(result, ivar_3->ftbl->mptr(ivar_3, ivar_29, ivar_7));};
        return result;
}

file_closure_8_t new_file_closure_8(void){
        static struct file_funtype_3_ftbl_s ftbl = {.fptr = (mpz_ptr_t (*)(file_funtype_3_t, file__lifted_file_adt_t))&f_file_closure_8, .mptr = (mpz_ptr_t (*)(file_funtype_3_t, file__lifted_file_adt_t))&m_file_closure_8, .rptr =  (void (*)(file_funtype_3_t))&release_file_closure_8, .cptr = (file_funtype_3_t (*)(file_funtype_3_t))&copy_file_closure_8};
        file_closure_8_t tmp = (file_closure_8_t) safe_malloc(sizeof(struct file_closure_8_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_file_closure_8(file_funtype_3_t closure){
        file_closure_8_t x = (file_closure_8_t)closure;
        x->count--;
        if (x->count <= 0){
         release_file_funtype_3((file_funtype_3_t)x->fvar_1);
         release_file_funtype_7((file_funtype_7_t)x->fvar_2);
        //printf("\nFreeing\n");
        safe_free(x);}}

file_closure_8_t copy_file_closure_8(file_closure_8_t x){
        file_closure_8_t y = new_file_closure_8();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        if (x->htbl != NULL){
            file_funtype_3_htbl_t new_htbl = (file_funtype_3_htbl_t) safe_malloc(sizeof(struct file_funtype_3_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            file_funtype_3_hashentry_t * new_data = (file_funtype_3_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct file_funtype_3_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct file_funtype_3_hashentry_s)));
            new_htbl->data = new_data;;
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_file_funtype_9(file_funtype_9_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

file_funtype_9_t copy_file_funtype_9(file_funtype_9_t x){return x->ftbl->cptr(x);}

bool_t equal_file_funtype_9(file_funtype_9_t x, file_funtype_9_t y){
        return false;}

char* json_file_funtype_9(file_funtype_9_t x){char * result = safe_malloc(24); sprintf(result, "%s", "\"file_funtype_9\""); return result;}

void release_file_funtype_10(file_funtype_10_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

file_funtype_10_t copy_file_funtype_10(file_funtype_10_t x){return x->ftbl->cptr(x);}

bool_t equal_file_funtype_10(file_funtype_10_t x, file_funtype_10_t y){
        return false;}

char* json_file_funtype_10(file_funtype_10_t x){char * result = safe_malloc(25); sprintf(result, "%s", "\"file_funtype_10\""); return result;}


ordstruct_adt__ordstruct_adt_t f_file_closure_11(struct file_closure_11_s * closure, file__lifted_file_adt_t bvar){
        ordstruct_adt__ordstruct_adt_t result = h_file_closure_11(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

ordstruct_adt__ordstruct_adt_t m_file_closure_11(struct file_closure_11_s * closure, file__lifted_file_adt_t bvar){
        return h_file_closure_11(bvar, closure->fvar_1, closure->fvar_2);}

ordstruct_adt__ordstruct_adt_t h_file_closure_11(file__lifted_file_adt_t ivar_6, file_funtype_10_t ivar_2, ordstruct_adt__ordstruct_adt_t ivar_1){
        ordstruct_adt__ordstruct_adt_t result;

        bool_t ivar_17;
        ivar_6->count++;
        ivar_17 = (bool_t)rec_file__failp((file__lifted_file_adt_t)ivar_6);
        if (ivar_17){
             release_file__lifted_file_adt((file__lifted_file_adt_t)ivar_6);
             //copying to ordstruct_adt__ordstruct_adt from ordstruct_adt__ordstruct_adt;
             result = (ordstruct_adt__ordstruct_adt_t)ivar_1;
             if (result != NULL) result->count++;
        } else {
             file__file_t ivar_21;
             ivar_21 = (file__file_t)acc_file__lifted_file_adt_contents((file__lifted_file_adt_t)ivar_6);
             result = (ordstruct_adt__ordstruct_adt_t)ivar_2->ftbl->fptr(ivar_2, ivar_21);};
        return result;
}

file_closure_11_t new_file_closure_11(void){
        static struct file_funtype_9_ftbl_s ftbl = {.fptr = (ordstruct_adt__ordstruct_adt_t (*)(file_funtype_9_t, file__lifted_file_adt_t))&f_file_closure_11, .mptr = (ordstruct_adt__ordstruct_adt_t (*)(file_funtype_9_t, file__lifted_file_adt_t))&m_file_closure_11, .rptr =  (void (*)(file_funtype_9_t))&release_file_closure_11, .cptr = (file_funtype_9_t (*)(file_funtype_9_t))&copy_file_closure_11};
        file_closure_11_t tmp = (file_closure_11_t) safe_malloc(sizeof(struct file_closure_11_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_file_closure_11(file_funtype_9_t closure){
        file_closure_11_t x = (file_closure_11_t)closure;
        x->count--;
        if (x->count <= 0){
         release_file_funtype_10((file_funtype_10_t)x->fvar_1);
         release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)x->fvar_2);
        //printf("\nFreeing\n");
        safe_free(x);}}

file_closure_11_t copy_file_closure_11(file_closure_11_t x){
        file_closure_11_t y = new_file_closure_11();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        if (x->htbl != NULL){
            file_funtype_9_htbl_t new_htbl = (file_funtype_9_htbl_t) safe_malloc(sizeof(struct file_funtype_9_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            file_funtype_9_hashentry_t * new_data = (file_funtype_9_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct file_funtype_9_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct file_funtype_9_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

void release_file_funtype_12(file_funtype_12_t x){
        x->count--;
            if (x->count <= 0)

                x->ftbl->rptr(x);}

file_funtype_12_t copy_file_funtype_12(file_funtype_12_t x){return x->ftbl->cptr(x);}

bool_t equal_file_funtype_12(file_funtype_12_t x, file_funtype_12_t y){
        return false;}

char* json_file_funtype_12(file_funtype_12_t x){char * result = safe_malloc(25); sprintf(result, "%s", "\"file_funtype_12\""); return result;}


ordstruct_adt__ordstruct_adt_t f_file_closure_13(struct file_closure_13_s * closure, file__lifted_file_adt_t bvar){
        ordstruct_adt__ordstruct_adt_t result = h_file_closure_13(bvar, closure->fvar_1, closure->fvar_2); 
        return result;}

ordstruct_adt__ordstruct_adt_t m_file_closure_13(struct file_closure_13_s * closure, file__lifted_file_adt_t bvar){
        return h_file_closure_13(bvar, closure->fvar_1, closure->fvar_2);}

ordstruct_adt__ordstruct_adt_t h_file_closure_13(file__lifted_file_adt_t ivar_7, file_funtype_9_t ivar_1, file_funtype_12_t ivar_3){
        ordstruct_adt__ordstruct_adt_t result;

        bool_t ivar_25;
        ivar_7->count++;
        ivar_25 = (bool_t)rec_file__failp((file__lifted_file_adt_t)ivar_7);
        if (ivar_25){
             result = (ordstruct_adt__ordstruct_adt_t)ivar_1->ftbl->fptr(ivar_1, ivar_7);
        } else {
             file__file_t ivar_29;
             ivar_7->count++;
             ivar_29 = (file__file_t)acc_file__lifted_file_adt_contents((file__lifted_file_adt_t)ivar_7);
             result = (ordstruct_adt__ordstruct_adt_t)ivar_3->ftbl->mptr(ivar_3, ivar_29, ivar_7);};
        return result;
}

file_closure_13_t new_file_closure_13(void){
        static struct file_funtype_9_ftbl_s ftbl = {.fptr = (ordstruct_adt__ordstruct_adt_t (*)(file_funtype_9_t, file__lifted_file_adt_t))&f_file_closure_13, .mptr = (ordstruct_adt__ordstruct_adt_t (*)(file_funtype_9_t, file__lifted_file_adt_t))&m_file_closure_13, .rptr =  (void (*)(file_funtype_9_t))&release_file_closure_13, .cptr = (file_funtype_9_t (*)(file_funtype_9_t))&copy_file_closure_13};
        file_closure_13_t tmp = (file_closure_13_t) safe_malloc(sizeof(struct file_closure_13_s));
        tmp->count = 1;
        tmp->ftbl = &ftbl;
        tmp->htbl = NULL;
        return tmp;}

void release_file_closure_13(file_funtype_9_t closure){
        file_closure_13_t x = (file_closure_13_t)closure;
        x->count--;
        if (x->count <= 0){
         release_file_funtype_9((file_funtype_9_t)x->fvar_1);
         release_file_funtype_12((file_funtype_12_t)x->fvar_2);
        //printf("\nFreeing\n");
        safe_free(x);}}

file_closure_13_t copy_file_closure_13(file_closure_13_t x){
        file_closure_13_t y = new_file_closure_13();
        y->ftbl = x->ftbl;

        y->fvar_1 = x->fvar_1; x->fvar_1->count++;
        y->fvar_2 = x->fvar_2; x->fvar_2->count++;
        if (x->htbl != NULL){
            file_funtype_9_htbl_t new_htbl = (file_funtype_9_htbl_t) safe_malloc(sizeof(struct file_funtype_9_htbl_s));
            new_htbl->size = x->htbl->size;
            new_htbl->num_entries = x->htbl->num_entries;
            file_funtype_9_hashentry_t * new_data = (file_funtype_9_hashentry_t *) safe_malloc(new_htbl->size * sizeof(struct file_funtype_9_hashentry_s));
            memcpy(new_data, x->htbl->data, (new_htbl->size * sizeof(struct file_funtype_9_hashentry_s)));
            new_htbl->data = new_data;
            for (uint32_t j = 0; j < new_htbl->size; j++){
                        if ((new_htbl->data[j].key != 0) || new_htbl->data[j].keyhash != 0) new_htbl->data[j].value->count++;};
            y->htbl = new_htbl;
        } else
            {y->htbl = NULL;};
        return y;
}

bool_t rec_file__failp(file__lifted_file_adt_t ivar_1){
        bool_t  result;

        uint8_t ivar_3;
        ivar_3 = (uint8_t)0;
        uint8_t ivar_2;
        ivar_2 = (uint8_t)ivar_1->file__lifted_file_adt_index;
        release_file__lifted_file_adt((file__lifted_file_adt_t)ivar_1);
        result = (ivar_2 == ivar_3);
        
        
        return result;
}

bool_t rec_file__passp(file__lifted_file_adt_t ivar_1){
        bool_t  result;

        uint8_t ivar_3;
        ivar_3 = (uint8_t)1;
        uint8_t ivar_2;
        ivar_2 = (uint8_t)ivar_1->file__lifted_file_adt_index;
        release_file__lifted_file_adt((file__lifted_file_adt_t)ivar_1);
        result = (ivar_2 == ivar_3);
        
        
        return result;
}

file__pass_t update_file__lifted_file_adt_contents(file__lifted_file_adt_t ivar_1, file__file_t ivar_3){
        file__pass_t  result;

        file__pass_t ivar_2;
        //copying to file__pass from file__lifted_file_adt;
        ivar_2 = (file__pass_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_file__lifted_file_adt((file__lifted_file_adt_t)ivar_1);
        result = (file__pass_t)update_file__pass_contents(ivar_2, ivar_3);
        
        result->count++;
        return result;
}

file__file_t acc_file__lifted_file_adt_contents(file__lifted_file_adt_t ivar_1){
        file__file_t  result;

        file__pass_t ivar_2;
        //copying to file__pass from file__lifted_file_adt;
        ivar_2 = (file__pass_t)ivar_1;
        if (ivar_2 != NULL) ivar_2->count++;
        release_file__lifted_file_adt((file__lifted_file_adt_t)ivar_1);
        result = (file__file_t)ivar_2->contents;
        result->count++;
        release_file__pass((file__pass_t)ivar_2);
        
        result->count++;
        return result;
}

file__lifted_file_adt_t con_file__fail(void){
        file__lifted_file_adt_t  static  result;

        static bool_t defined = false;
        if (!defined){
            
        uint8_t ivar_1;
        ivar_1 = (uint8_t)0;
        file__lifted_file_adt_t tmp4028 = new_file__lifted_file_adt();;
        result = (file__lifted_file_adt_t)tmp4028;
        tmp4028->file__lifted_file_adt_index = (uint8_t)ivar_1;
        defined = true;};
        
        result->count++;
        return result;
}

file__lifted_file_adt_t con_file__pass(file__file_t ivar_2){
        file__lifted_file_adt_t  result;

        uint8_t ivar_1;
        ivar_1 = (uint8_t)1;
        file__pass_t tmp4029 = new_file__pass();;
        result = (file__lifted_file_adt_t)tmp4029;
        tmp4029->file__lifted_file_adt_index = (uint8_t)ivar_1;
        tmp4029->contents = (file__file_t)ivar_2;
        
        result->count++;
        return result;
}

uint8_t file__ord(file__lifted_file_adt_t ivar_1){
        uint8_t  result;

        bool_t ivar_3;
        ivar_1->count++;
        ivar_3 = (bool_t)rec_file__failp((file__lifted_file_adt_t)ivar_1);
        if (ivar_3){
             result = (uint8_t)0;
        } else {
             result = (uint8_t)1;};
        
        
        return result;
}

bool_t file__subterm(file__lifted_file_adt_t ivar_1, file__lifted_file_adt_t ivar_2){
        bool_t  result;

        result = (bool_t) equal_file__lifted_file_adt(ivar_1, ivar_2);
        
        
        return result;
}

bool_t file__doublelessp(file__lifted_file_adt_t ivar_1, file__lifted_file_adt_t ivar_2){
        bool_t  result;

        result = (bool_t) false;
        
        
        return result;
}

file_funtype_3_t file__reduce_nat(mpz_ptr_t ivar_1, file_funtype_4_t ivar_2){
        file_funtype_3_t  result;

        file_closure_5_t cl4032;
        cl4032 = new_file_closure_5();
        cl4032->fvar_1 = (file_funtype_4_t)ivar_2;
        if (cl4032->fvar_1 != NULL) cl4032->fvar_1->count++;
        mpz_set(cl4032->fvar_2, ivar_1);
        release_file_funtype_4((file_funtype_4_t)ivar_2);
        result = (file_funtype_3_t)cl4032;
        
        result->count++;
        return result;
}

file_funtype_3_t file__REDUCE_nat(file_funtype_3_t ivar_1, file_funtype_7_t ivar_3){
        file_funtype_3_t  result;

        file_closure_8_t cl4042;
        cl4042 = new_file_closure_8();
        cl4042->fvar_1 = (file_funtype_3_t)ivar_1;
        if (cl4042->fvar_1 != NULL) cl4042->fvar_1->count++;
        cl4042->fvar_2 = (file_funtype_7_t)ivar_3;
        if (cl4042->fvar_2 != NULL) cl4042->fvar_2->count++;
        release_file_funtype_7((file_funtype_7_t)ivar_3);
        release_file_funtype_3((file_funtype_3_t)ivar_1);
        result = (file_funtype_3_t)cl4042;
        
        result->count++;
        return result;
}

file_funtype_9_t file__reduce_ordinal(ordstruct_adt__ordstruct_adt_t ivar_1, file_funtype_10_t ivar_2){
        file_funtype_9_t  result;

        file_closure_11_t cl4044;
        cl4044 = new_file_closure_11();
        cl4044->fvar_1 = (file_funtype_10_t)ivar_2;
        if (cl4044->fvar_1 != NULL) cl4044->fvar_1->count++;
        cl4044->fvar_2 = (ordstruct_adt__ordstruct_adt_t)ivar_1;
        if (cl4044->fvar_2 != NULL) cl4044->fvar_2->count++;
        release_file_funtype_10((file_funtype_10_t)ivar_2);
        release_ordstruct_adt__ordstruct_adt((ordstruct_adt__ordstruct_adt_t)ivar_1);
        result = (file_funtype_9_t)cl4044;
        
        result->count++;
        return result;
}

file_funtype_9_t file__REDUCE_ordinal(file_funtype_9_t ivar_1, file_funtype_12_t ivar_3){
        file_funtype_9_t  result;

        file_closure_13_t cl4054;
        cl4054 = new_file_closure_13();
        cl4054->fvar_1 = (file_funtype_9_t)ivar_1;
        if (cl4054->fvar_1 != NULL) cl4054->fvar_1->count++;
        cl4054->fvar_2 = (file_funtype_12_t)ivar_3;
        if (cl4054->fvar_2 != NULL) cl4054->fvar_2->count++;
        release_file_funtype_12((file_funtype_12_t)ivar_3);
        release_file_funtype_9((file_funtype_9_t)ivar_1);
        result = (file_funtype_9_t)cl4054;
        
        result->count++;
        return result;
}

bool_t file__openp(file__file_t f){struct stat s;
    return (fstat(f->fd, &s) != -1);
   }

bytestrings__bytestring_t file__name(file__file_t f){
   char * name = f->name;
   uint32_t size = strlen(name);
    bytestrings_array_1_t newarray = new_bytestrings_array_1(size);
    memcpy(newarray, (char *) name, size);
    bytestrings__bytestring_t newstring = new_bytestrings__bytestring();
    newstring->length = size;
    newstring->seq = newarray;
    return newstring;
   }

uint32_t file__file_size(file__file_t f){uint32_t result = f->size;
    release_file__file(f);
    return result;}

file__lifted_file_adt_t file__open(bytestrings__bytestring_t name){
    char * filenamestring = byte2cstring(name->length, name->seq->elems);
    uint64_t fd = open(filenamestring, O_RDWR, S_IRUSR | S_IWUSR);
    release_bytestrings__bytestring(name); 
    safe_free(filenamestring);
    struct stat s;
    if (fstat(fd, &s) == -1){
       return con_file__fail(); //pvs2cerror("File size extraction failed.n")
       }
    uint32_t size = s.st_size;
    uint32_t capacity = 4096 * (size/4096 + 1);
    char * contents = (char *) mmap(NULL, capacity, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    file_t ff = (file_t) safe_malloc(sizeof(file_s));
    ff->count = 1;
    ff->fd = fd;
    ff->size = size;
    ff->capacity = capacity;
    ff->contents = contents;
    ff->name = filenamestring;
    return con_file__pass(ff);
   }

file__lifted_file_adt_t file__create(bytestrings__bytestring_t name){
    char * filenamestring = byte2cstring(name->length, name->seq->elems);
    uint64_t fd = open(filenamestring, O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
    release_bytestrings__bytestring(name); 
    safe_free(filenamestring);
    struct stat s;
    if (fstat(fd, &s) == -1){
       return con_file__fail(); //pvs2cerror("File size extraction failed.n")
       }
    uint32_t size = s.st_size;
    uint32_t capacity = 4096 * (size/4096 + 1);
    char * contents = (char *) mmap(NULL, capacity, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    file_t ff = (file_t) safe_malloc(sizeof(file_s));
    ff->count = 1;
    ff->fd = fd;
    ff->size = size;
    ff->capacity = capacity;
    ff->contents = contents;
    ff->name = filenamestring;
    return con_file__pass(ff);
   }

file__lifted_file_adt_t file__setbyte(file__file_t f, uint32_t i, uint8_t b){if (f->count == 1){
     f->contents[i] = b;
     return con_file__pass(f);
     };
    return con_file__fail();
}

file__lifted_file_adt_t file__append(file__file_t f, bytestrings__bytestring_t b){if (f->count > 1) return con_file__fail();
    uint64_t fd = f->fd;
    uint32_t size = f->size;
    uint32_t capacity = f->capacity;
    char * contents = f->contents;
    uint32_t len = b->length;
    char * data = (char *)b->seq->elems;
    ftruncate(fd, size + len);
    if (size + len < capacity){
    for (size_t i = 0; i < len; i++)
      contents[i + size] = data[i];
  } else {
    munmap(contents, capacity);
    uint32_t new_capacity = capacity + (10 * 4096);
    char * new_contents = mmap(NULL, new_capacity, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0); 
    for (size_t i = 0; i < len; i++)
      new_contents[i + size] = data[i];
    f->contents = new_contents;
 };
   f->size = size + len;
   return con_file__pass(f);
}

uint8_t file__getbyte(file__file_t f, uint32_t i){uint8_t result = f->contents[i];
    release_file__file(f);
    return result;
}

bytestrings__bytestring_t file__getbytestring(file__file_t f, uint32_t i, uint32_t size){bytestrings_array_1_t newarray = new_bytestrings_array_1(size);
    memcpy(newarray->elems, (char *) f->contents + i, size);
    bytestrings__bytestring_t newstring = new_bytestrings__bytestring();
    newstring->length = size;
    newstring->seq = newarray;
    release_file__file(f);
    return newstring;
    }

bytestrings__bytestring_t file__printc(bytestrings__bytestring_t b){printf("\n");
    for (uint32_t i = 0; i < b->length; i++) printf("%c", b->seq->elems[i]);
    return b;
   }


bytestrings__bytestring_t file__printh(bytestrings__bytestring_t b){printf("\n");
    for (uint32_t i = 0; i < b->length; i++) printf("%02X", b->seq->elems[i]);
    return b;
   }
