;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; proof-driver.lisp -- Codex-friendly stdio proof driver for PVS
;;
;; This bridge keeps the prover interaction structured and stateful while
;; avoiding Emacs and avoiding any need to bind a local websocket port.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :pvs)

(defparameter *codex-proof-driver-version* "0.2")
(defparameter *codex-proof-driver-special-requests*
  '("driver-info"
    "interrupt-proof"
    "parse-file"
    "ping"
    "pvs2c-theory"
    "show-tccs-file"
    "shutdown"
    "typecheck-file"))

(defvar *codex-proof-driver-running* nil)
(defvar *codex-proof-driver-output-lock*
  (bt:make-lock "codex-proof-driver-output"))

(defun codex-proof-driver-write-json (payload)
  (bt:with-lock-held (*codex-proof-driver-output-lock*)
    (let ((json:*lisp-identifier-name-to-json* #'identity))
      (terpri)
      (write-line (json:encode-json-alist-to-string payload))
      (finish-output))))

(defun codex-proof-driver-notify (method &optional params)
  (codex-proof-driver-write-json
   `(("jsonrpc" . "2.0")
     ("method" . ,method)
     ,@(when params `(("params" . ,params))))))

(defun codex-proof-driver-message-hook (msg)
  (codex-proof-driver-notify "info" `(("message" . ,msg))))

(defun codex-proof-driver-warning-hook (msg)
  (codex-proof-driver-notify "warning" `(("message" . ,msg))))

(defun codex-proof-driver-buffer-hook (name contents display? read-only? append? kind)
  (declare (ignore display? read-only?))
  (codex-proof-driver-notify
   "buffer"
   `(("name" . ,name)
     ("contents" . ,contents)
     ("append" . ,append?)
     ("kind" . ,kind))))

(defun codex-proof-driver-ready ()
  (codex-proof-driver-notify
   "ready"
   `(("driver" . "pvs-codex-proof-driver")
     ("protocol" . "jsonrpc-stdio")
     ("version" . ,*codex-proof-driver-version*))))

(defun codex-proof-driver-response (id result)
  `(("jsonrpc" . "2.0")
    ("id" . ,id)
    ("result" . ,result)))

(defun codex-proof-driver-error (id code message &optional data)
  `(("jsonrpc" . "2.0")
    ("id" . ,id)
    ("error" . (("code" . ,code)
                ("message" . ,message)
                ,@(when data `(("data" . ,data)))))))

(defun codex-proof-driver-pvs-error-data (condition)
  (let ((fname (when (file-name condition)
                 `(("file_name" . ,(namestring (file-name condition))))))
        (place (when (place condition)
                 `(("place" . ,(place condition))))))
    `(,@fname
      ,@place
      ("error_string" . ,(error-string condition)))))

(defun codex-proof-driver-path-string (path)
  (when path
    (let ((pathname (pathname path)))
      (namestring (or (ignore-errors (truename pathname))
                      pathname)))))

(defun codex-proof-driver-resolve-pvs-file (filename)
  (when filename
    (let ((specpath (ignore-errors (make-specpath filename))))
      (when specpath
        (codex-proof-driver-path-string specpath)))))

(defun codex-proof-driver-nonempty-lines (string)
  (when (and string (< 0 (length string)))
    (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) string)))
      (when (< 0 (length trimmed))
        (remove-if #'(lambda (line)
                       (zerop (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                                   line))))
                   (uiop:split-string trimmed :separator '(#\Newline #\Return)))))))

(defun codex-proof-driver-call-capturing-output (thunk)
  (let (result)
    (let ((output (with-output-to-string (stream)
                    (let ((*standard-output* stream)
                          (*error-output* stream)
                          (*trace-output* stream))
                      (setq result (funcall thunk))))))
      (values result output))))

(defun codex-proof-driver-theory-id-from-json (theory)
  (cdr (assoc "id" theory :test #'string=)))

(defun codex-proof-driver-theory-file-from-json (theory)
  (cdr (assoc "fileName" theory :test #'string=)))

(defun codex-proof-driver-theory-decls-from-json (theory)
  (cdr (assoc "decls" theory :test #'string=)))

(defun codex-proof-driver-theory-summaries (theories)
  (mapcar #'(lambda (theory)
              `(("id" . ,(codex-proof-driver-theory-id-from-json theory))
                ("fileName" . ,(codex-proof-driver-theory-file-from-json theory))
                ("declCount" . ,(length (codex-proof-driver-theory-decls-from-json theory)))))
          theories))

(defun codex-proof-driver-theory-ids (theories)
  (mapcar #'codex-proof-driver-theory-id-from-json theories))

(defun codex-proof-driver-parse-file-result (filename)
  (let ((resolved-file (codex-proof-driver-resolve-pvs-file filename)))
    (let ((theories (let ((parsed-theories (parse-file filename)))
                      (save-context)
                      (pvs-jsonrpc::json-theories parsed-theories))))
      `(("operation" . "parse")
        ("input" . ,filename)
        ,@(when resolved-file `(("file" . ,resolved-file)))
        ("theoryCount" . ,(length theories))
        ("theoryIds" . ,(codex-proof-driver-theory-ids theories))
        ("theorySummaries" . ,(codex-proof-driver-theory-summaries theories))
        ("theories" . ,theories)))))

(defun codex-proof-driver-typecheck-file-result (filename &optional content force?)
  (let ((resolved-file (codex-proof-driver-resolve-pvs-file filename)))
    (let ((theories (progn
                      (when (and content (< 0 (length content)))
                        (with-open-file (out filename :direction :output :if-exists :supersede)
                          (write content :stream out :escape nil)))
                      (pvs-jsonrpc::json-theories (typecheck-file filename force?)))))
      `(("operation" . "typecheck")
        ("input" . ,filename)
        ,@(when resolved-file `(("file" . ,resolved-file)))
        ("force" . ,(if force? t nil))
        ("contentSupplied" . ,(and content (< 0 (length content))))
        ("theoryCount" . ,(length theories))
        ("theoryIds" . ,(codex-proof-driver-theory-ids theories))
        ("theorySummaries" . ,(codex-proof-driver-theory-summaries theories))
        ("theories" . ,theories)))))

(defun codex-proof-driver-show-tccs-result (theoryref)
  (let* ((theory (get-typechecked-theory theoryref nil t))
         (tccs (get-tccs theoryref))
         (resolved-file (when theory (codex-proof-driver-path-string (make-specpath theory))))
         (proved-count (count-if #'(lambda (tcc)
                                     (string= (cdr (assoc "proved" tcc :test #'string=))
                                              "true"))
                                 tccs)))
    `(("operation" . "show-tccs")
      ("input" . ,theoryref)
      ,@(when theory `(("theoryId" . ,(string (id theory)))))
      ,@(when resolved-file `(("file" . ,resolved-file)))
      ("tccCount" . ,(length tccs))
      ("provedCount" . ,proved-count)
      ("unprovedCount" . ,(- (length tccs) proved-count))
      ("tccs" . ,tccs))))

(defun codex-proof-driver-pvs2c-related-theories (theory)
  (let ((imported-theories (all-imported-theories theory)))
    (append (if (listp imported-theories) imported-theories nil)
            (list theory))))

(defun codex-proof-driver-pvs2c-warning-json (theory warning)
  (let ((decl (car warning))
        (message (cdr warning)))
    `(("theoryId" . ,(string (id theory)))
      ,@(when decl `(("declId" . ,(string (id decl)))))
      ("message" . ,(string-trim '(#\Space #\Tab #\Newline #\Return) message)))))

(defun codex-proof-driver-pvs2c-theory-warnings (theory)
  (mapcar #'(lambda (warning)
              (codex-proof-driver-pvs2c-warning-json theory warning))
          (reverse (copy-list (pvs2c-warnings theory)))))

(defun codex-proof-driver-pvs2c-generated-file (path)
  (when (and path (uiop:file-exists-p path))
    (codex-proof-driver-path-string path)))

(defun codex-proof-driver-pvs2c-artifact-paths (theory &optional library-path)
  (let* ((theory-id (format nil "~a" (simple-id (id theory))))
         (context-path (codex-proof-driver-path-string (context-path theory)))
         (library-root (when library-path
                         (codex-proof-driver-path-string library-path)))
         (header-file (if library-root
                          (format nil "~a/include/~a_c.h" library-root theory-id)
                          (format nil "~apvs2c/include/~a_c.h" context-path theory-id)))
         (deps-file (if library-root
                        (format nil "~a/include/~a.pvs2c" library-root theory-id)
                        (format nil "~apvs2c/src/~a.deps" context-path theory-id)))
         (c-file (if library-root
                     (format nil "~a/src/~a_c.c" library-root theory-id)
                     (format nil "~apvs2c/src/~a_c.c" context-path theory-id)))
         (test-main-file (format nil "~apvs2c/src/~a.c" context-path theory-id))
         (warnings (codex-proof-driver-pvs2c-theory-warnings theory)))
    `(("theoryId" . ,(string (id theory)))
      ("file" . ,(codex-proof-driver-path-string (make-specpath theory)))
      ,@(let ((generated-header (codex-proof-driver-pvs2c-generated-file header-file)))
          (when generated-header
            `(("headerFile" . ,generated-header))))
      ,@(let ((generated-c-file (codex-proof-driver-pvs2c-generated-file c-file)))
          (when generated-c-file
            `(("cFile" . ,generated-c-file))))
      ,@(let ((generated-deps-file (codex-proof-driver-pvs2c-generated-file deps-file)))
          (when generated-deps-file
            `(("depsFile" . ,generated-deps-file))))
      ,@(let ((generated-test-main-file (codex-proof-driver-pvs2c-generated-file
                                         test-main-file)))
          (when generated-test-main-file
            `(("testMainFile" . ,generated-test-main-file))))
      ("warningCount" . ,(length warnings))
      ,@(when warnings `(("warnings" . ,warnings))))))

(defun codex-proof-driver-pvs2c-result (theoryref &optional force? library-path)
  (let* ((resolved-library-path (when (and library-path (< 0 (length library-path)))
                                  (codex-proof-driver-path-string library-path)))
         (theory (get-typechecked-theory theoryref nil t)))
    (unless theory
      (error "Could not locate typechecked theory ~a" theoryref))
    (multiple-value-bind (result raw-output)
        (codex-proof-driver-call-capturing-output
         #'(lambda ()
             (let ((*pvs2c-library-path* resolved-library-path))
               (pvs2c-theory theoryref force?))))
      (let* ((related-theories (codex-proof-driver-pvs2c-related-theories theory))
             (artifacts (mapcar #'(lambda (related-theory)
                                    (codex-proof-driver-pvs2c-artifact-paths
                                     related-theory resolved-library-path))
                                related-theories))
             (messages (codex-proof-driver-nonempty-lines raw-output))
             (all-warnings (mapcan #'codex-proof-driver-pvs2c-theory-warnings
                                   related-theories)))
        `(("operation" . "pvs2c-theory")
          ("input" . ,theoryref)
          ("force" . ,(if force? t nil))
          ("theoryId" . ,(string (id theory)))
          ("file" . ,(codex-proof-driver-path-string (make-specpath theory)))
          ,@(when resolved-library-path `(("libraryPath" . ,resolved-library-path)))
          ,@(when result `(("result" . ,result)))
          ("artifactCount" . ,(length artifacts))
          ("artifacts" . ,artifacts)
          ("warningCount" . ,(length all-warnings))
          ,@(when all-warnings `(("warnings" . ,all-warnings)))
          ,@(when messages `(("messages" . ,messages))))))))

(defun codex-proof-driver-request-docs ()
  (list
   `(("name" . "change-context")
     ("params" . ("workspace"))
     ("summary" . "Switch the current PVS workspace before parsing, typechecking, proving, or running pvs2c."))
   `(("name" . "parse-file")
     ("params" . ("filename"))
     ("summary" . "Parse a file and return structured theories plus a compact summary."))
   `(("name" . "typecheck-file")
     ("params" . ("filename" "content?" "force?"))
     ("summary" . "Typecheck a file, optionally replacing its contents first, and return structured theories plus a summary."))
   `(("name" . "show-tccs-file")
     ("params" . ("theoryref"))
     ("summary" . "Return the theory's TCCs with proved/unproved counts in one response."))
   `(("name" . "prove-formula")
     ("params" . ("formref"))
     ("summary" . "Start an interactive proof session and return the current proof state."))
   `(("name" . "proof-command")
     ("params" . ("proof-id" "command"))
     ("summary" . "Run one prover command against an open proof session."))
   `(("name" . "interrupt-proof")
     ("params" . ("proof-id"))
     ("summary" . "Interrupt a long-running proof command and restore the proof session."))
   `(("name" . "pvs2c-theory")
     ("params" . ("theoryref" "force?" "library-path?"))
     ("summary" . "Run pvs2c on a theory and return generated artifact paths plus collected warnings."))
   `(("name" . "shutdown")
     ("params" . ())
     ("summary" . "Terminate the Codex proxy and the underlying headless PVS process."))))

(defun codex-proof-driver-special-request (method params)
  (cond ((string-equal method "ping")
         (values t "pong" nil))
        ((string-equal method "driver-info")
         (values
          t
          `(("driver" . "pvs-codex-proof-driver")
            ("protocol" . "jsonrpc-stdio")
            ("version" . ,*codex-proof-driver-version*)
            ("workspace" . ,(namestring *default-pathname-defaults*))
            ("recommendedRequests" . ,(codex-proof-driver-request-docs))
            ("requests" . ,(sort
                            (append *codex-proof-driver-special-requests*
                                    (mapcar #'(lambda (entry)
                                                (string-downcase (string (car entry))))
                                      pvs-jsonrpc::*pvs-request-methods*))
                            #'string-lessp)))
          nil))
        ((string-equal method "parse-file")
         (let ((filename (car params)))
           (unless filename
             (error "parse-file requires a filename"))
           (values t (codex-proof-driver-parse-file-result filename) nil)))
        ((string-equal method "typecheck-file")
         (let ((filename (car params))
               (content (cadr params))
               (force? (caddr params)))
           (unless filename
             (error "typecheck-file requires a filename"))
           (values t (codex-proof-driver-typecheck-file-result filename content force?) nil)))
        ((string-equal method "show-tccs-file")
         (let ((theoryref (car params)))
           (unless theoryref
             (error "show-tccs-file requires a theory reference"))
           (values t (codex-proof-driver-show-tccs-result theoryref) nil)))
        ((string-equal method "pvs2c-theory")
         (let ((theoryref (car params))
               (force? (cadr params))
               (library-path (caddr params)))
           (unless theoryref
             (error "pvs2c-theory requires a theory reference"))
           (values t (codex-proof-driver-pvs2c-result theoryref force? library-path) nil)))
        ((string-equal method "shutdown")
         (setq *codex-proof-driver-running* nil)
         (ignore-errors (quit-all-proof-sessions))
         (values t `(("shutdown" . t)) nil))
        ((string-equal method "interrupt-proof")
         (let ((proof-id (car params)))
           (unless proof-id
             (error "interrupt-proof requires a proof id"))
           ;; The stock implementation prints debugging text directly to
           ;; *standard-output*, which breaks a JSONL transport.
           (let ((*standard-output* (make-broadcast-stream))
                 (*error-output* (make-broadcast-stream))
                 (*trace-output* (make-broadcast-stream)))
             (values t (interrupt-session proof-id) nil))))
        (t
         (values nil nil nil))))

(defun codex-proof-driver-dispatch (request)
  (typecase request
    (pvs-jsonrpc::jsonrpc-request
     (let* ((id (pvs-jsonrpc::jreq-id request))
            (method (pvs-jsonrpc::jreq-method request))
            (params (pvs-jsonrpc::jreq-params request)))
       (multiple-value-bind (special? result ignore)
           (codex-proof-driver-special-request method params)
         (declare (ignore ignore))
         (if special?
             (codex-proof-driver-response id result)
           (multiple-value-bind (reqfun reqsig)
               (pvs-jsonrpc::get-json-request-function method)
             (pvs-jsonrpc::check-params params reqsig)
             (let ((pvs-jsonrpc::*current-jsonrpc-request* request))
               (codex-proof-driver-response id (apply reqfun params))))))))
    (pvs-jsonrpc::jsonrpc-notification
     (let* ((method (pvs-jsonrpc::jnot-method request))
            (params (pvs-jsonrpc::jnot-params request)))
       (multiple-value-bind (special? result ignore)
           (codex-proof-driver-special-request method params)
         (declare (ignore result ignore))
         (unless special?
           (multiple-value-bind (reqfun reqsig)
               (pvs-jsonrpc::get-json-request-function method)
             (pvs-jsonrpc::check-params params reqsig)
             (apply reqfun params)))))
     nil)
    (t
     (error "Unsupported request object: ~a" (type-of request)))))

(defun codex-proof-driver-process-line (line)
  (handler-case
      (let* ((cl-json:*identifier-name-to-key* #'string-downcase)
             (message (json:decode-json-from-string line))
             (request (pvs-jsonrpc::jsonrpc-object message)))
        (handler-case
            (codex-proof-driver-dispatch request)
          (pvs-error (condition)
            (typecase request
              (pvs-jsonrpc::jsonrpc-request
               (codex-proof-driver-error
                (pvs-jsonrpc::jreq-id request)
                1
                (message condition)
                (codex-proof-driver-pvs-error-data condition)))
              (t
               (codex-proof-driver-notify
                "warning"
                `(("message" . ,(message condition))
                  ("data" . ,(codex-proof-driver-pvs-error-data condition))))
               nil)))
          (error (condition)
            (typecase request
              (pvs-jsonrpc::jsonrpc-request
               (codex-proof-driver-error
                (pvs-jsonrpc::jreq-id request)
                -32700
                "PVS Error"
                (format nil "~a" condition)))
              (t
               (codex-proof-driver-notify
                "warning"
                `(("message" . "PVS Error")
                  ("data" . ,(format nil "~a" condition))))
               nil)))))
    (error (condition)
      (codex-proof-driver-error nil -32700 "Json-RPC Error" (format nil "~a" condition)))))

(defun codex-proof-driver-handle-line (line)
  (let ((response (codex-proof-driver-process-line line)))
    (when response
      (codex-proof-driver-write-json response))))

(defun codex-proof-driver-install-hooks ()
  (clear-pvs-hooks)
  (setq *pvs-message-hook* (list #'codex-proof-driver-message-hook)
        *pvs-warning-hook* #'codex-proof-driver-warning-hook
        *pvs-buffer-hook* #'codex-proof-driver-buffer-hook
        *suppress-msg* t
        *proceed-without-asking* t)
  ;; Keep the session-based prover input hook active.
  (pushnew #'session-read *prover-input-hooks*))

(defun codex-proof-driver-main ()
  "Run a line-oriented JSON-RPC driver on standard input/output."
  (let ((*package* (find-package :pvs)))
    (codex-proof-driver-install-hooks)
    (setq *codex-proof-driver-running* t)
    (codex-proof-driver-ready)
    (loop while *codex-proof-driver-running*
          for line = (read-line *standard-input* nil nil)
          do (cond
               ((null line)
                (setq *codex-proof-driver-running* nil))
               ((string= (string-trim '(#\Space #\Tab #\Newline #\Return) line) "")
                nil)
               (t
                ;; Handle each request on its own thread so that
                ;; interrupt-proof can be issued while a long-running
                ;; proof-command is still waiting on a session result.
                (bt:make-thread
                 (lambda ()
                   (codex-proof-driver-handle-line line))
                 :name "codex-proof-driver-request")))))
  (ignore-errors (quit-all-proof-sessions))
  (uiop:quit 0))
