;; Native SAL inventory only: no normalization, approximation, or source writes.
;; A successful result means SAL parsed and well-formedness checked the context.

(define (corpus/node tag children attributes)
  (let ((node (make-simple-sxml-node tag children)))
    (for-each (lambda (entry) (sxml/set-attribute! node (car entry) (cdr entry)))
              attributes)
    node))

(define (corpus/formal decl)
  (corpus/node 'FORMAL '()
               (list (cons 'NAME (symbol->string (sal-decl/name decl)))
                     (cons 'KIND (if (instance-of? decl <sal-type-param-decl>)
                                      "type" "value")))))

(define (corpus/declaration decl)
  (cond
    ((instance-of? decl <sal-module-decl>)
     (corpus/node 'MODULE
                  (map corpus/formal
                       (slot-value (slot-value decl :parametric-module) :local-decls))
                  (list (cons 'NAME (symbol->string (sal-decl/name decl))))))
    ((instance-of? decl <sal-assertion-decl>)
     (corpus/node 'PROPERTY '()
                  (list (cons 'NAME (symbol->string (sal-decl/name decl))))))
    ((instance-of? decl <sal-type-decl>)
     (corpus/node 'TYPE '() (list (cons 'NAME (symbol->string (sal-decl/name decl))))))
    ((instance-of? decl <sal-context-name-decl>)
     (corpus/node 'IMPORT '() (list (cons 'NAME (symbol->string (sal-decl/name decl))))))
    (else (corpus/node 'DECLARATION '()
                       (list (cons 'NAME (symbol->string (sal-decl/name decl))))))))

(unless (= (length *arguments*) 1)
  (sign-error "Usage: run-corpus-inventory.scm SOURCE" *arguments*))
(let* ((source (car *arguments*))
       (environment (make-sal-env))
       (_ (sal-env/append-to-sal-context-path! environment (list (dirname source))))
       (context (sal-env/context-from-file environment source)))
  (sxml->xml
   (corpus/node 'SALCORPUS
                (cons (corpus/node 'FORMALS (map corpus/formal (sal-context/params context)) '())
                      (map corpus/declaration (sal-context/declarations context)))
                (list (cons 'CONTEXT (symbol->string (sal-context/name context)))
                      (cons 'SOURCE source)))))
