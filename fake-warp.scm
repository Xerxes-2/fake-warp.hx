;; fake-warp.scm
;; Trigger terminal cursor animation by briefly flashing an intermediate cursor
;; shape whenever block is involved (mode switch or cursor movement).
;;
;; Helix's block cursor is not the native terminal cursor, so the terminal's
;; blink/animation won't reset naturally. This plugin forces a shape transition
;; to make the terminal redraw its cursor animation.

(require "helix/misc.scm")
(require "helix/configuration.scm")
(require "helix/editor.scm")

(provide install-fake-warp!)

;; ─── State ───────────────────────────────────────────────────────────────────

(define *fake-warp-installed* #f)
(define *animating* #f)

;; How long (ms) the intermediate shape is shown before restoring.
(define *flash-ms* 40)

;; ─── Shape state (lazily loaded from config on first use) ────────────────────

(define *shape-normal* 'block)
(define *shape-insert* 'block)
(define *shape-select* 'block)
(define *shapes-loaded* #f)

(define (reload-shapes!)
  (set! *shape-normal* (string->symbol (get-config-option-value "cursor-shape.normal")))
  (set! *shape-insert* (string->symbol (get-config-option-value "cursor-shape.insert")))
  (set! *shape-select* (string->symbol (get-config-option-value "cursor-shape.select")))
  (set! *shapes-loaded* #t))

(define (ensure-shapes-loaded!)
  (unless *shapes-loaded* (reload-shapes!)))

;; ─── Helpers ─────────────────────────────────────────────────────────────────

(define (shape-for-mode mode)
  (cond
    [(equal? mode 'normal) *shape-normal*]
    [(equal? mode 'insert) *shape-insert*]
    [(equal? mode 'select) *shape-select*]
    [else 'block]))

(define (mode->sym mode)
  (cond
    [(equal? mode 'normal) 'normal]
    [(equal? mode 'insert) 'insert]
    [(equal? mode 'select) 'select]
    [else 'normal]))

(define (intermediate-shape a b)
  (cond
    [(and (not (equal? a 'bar)) (not (equal? b 'bar))) 'bar]
    [(and (not (equal? a 'underline)) (not (equal? b 'underline))) 'underline]
    [else 'bar]))

(define (apply-canonical-shapes!)
  (cursor-shape #:normal *shape-normal* #:insert *shape-insert* #:select *shape-select*))

(define (apply-shapes-with-override! mode-sym override)
  (cursor-shape
    #:normal (if (equal? mode-sym 'normal) override *shape-normal*)
    #:insert (if (equal? mode-sym 'insert) override *shape-insert*)
    #:select (if (equal? mode-sym 'select) override *shape-select*)))

;; ─── Hooks ───────────────────────────────────────────────────────────────────

(define (register-fake-warp-hooks!)
  ;; On mode switch: if either side is block, flash an intermediate shape.
  (register-hook! "on-mode-switch"
    (lambda (event)
      (ensure-shapes-loaded!)
      (when (not *animating*)
        (let* ([old-mode  (mode->sym (mode-switch-old event))]
               [new-mode  (mode->sym (mode-switch-new event))]
               [old-shape (shape-for-mode old-mode)]
               [new-shape (shape-for-mode new-mode)])
          (when (or (equal? old-shape 'block) (equal? new-shape 'block))
            (let ([mid (intermediate-shape old-shape new-shape)])
              (set! *animating* #t)
              (apply-shapes-with-override! new-mode mid)
              (enqueue-thread-local-callback-with-delay *flash-ms*
                (lambda ()
                  (apply-canonical-shapes!)
                  (set! *animating* #f)))))))))

  ;; On cursor move: if current shape is block, briefly flash a non-block shape.
  (register-hook! "selection-did-change"
    (lambda (_view-id)
      (ensure-shapes-loaded!)
      (when (not *animating*)
        (let* ([mode  (mode->sym (editor-mode))]
               [shape (shape-for-mode mode)])
          (when (equal? shape 'block)
            (set! *animating* #t)
            (apply-shapes-with-override! mode (intermediate-shape shape shape))
            (enqueue-thread-local-callback-with-delay *flash-ms*
              (lambda ()
                (apply-canonical-shapes!)
                (set! *animating* #f)))))))))

;; ─── Entry point ─────────────────────────────────────────────────────────────

(define (install-fake-warp!)
  (if *fake-warp-installed*
      #f
      (begin
        (set! *fake-warp-installed* #t)
        (register-fake-warp-hooks!)
        (set-status! "fake-warp loaded"))))

(install-fake-warp!)
