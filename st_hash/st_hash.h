#ifndef _ST_HASH_H_
#define _ST_HASH_H_

typedef void * st_hash_t;

/* initialize st_hash object */
int st_hash_create (st_hash_t *h);
/* inserts st/st_size to the hash and returns a unique [1..+inf) identifier */
int st_hash_insert (st_hash_t h, void **st, int st_size);
/* returns an [1..+inf) identifier of st/st_size or -1 if absent */
int st_hash_getid (st_hash_t h, void **st, int st_size);
/* returns maximum id */
int st_hash_getmaxid (st_hash_t h);
/* destroys st_hash object */
int st_hash_destroy (st_hash_t *h);

#endif // _ST_HASH_H_
