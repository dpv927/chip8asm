global cpu_display
global cpu_memory 
global cpu_stack
global cpu_v
global cpu_keypad 
global cpu_i
global cpu_dt
global cpu_st
global cpu_pc
global cpu_sp
global cpu_draw
global sprites
global cpu_error

section .data
  ;; Processor features
  cpu_display: times 2048 db 0x0 ;; Display Buffer
  cpu_memory:  times 4096 db 0x0 ;; Chip8 Memory
  cpu_stack:   times 16   dw 0x0 ;; Processor stack
  cpu_v:       times 16   db 0x0 ;; Vx Registers (x[0..F])
  cpu_keypad:  times 16   db 0x0 ;; Keypad keys 
  cpu_i:    dw 0x0               ;; I register
  cpu_dt:   db 0x0               ;; Delay Timer
  cpu_st:   db 0x0               ;; Sound Timer
  cpu_pc:   dw 0x200             ;; Program counter
  cpu_sp:   db 0x0               ;; Stack pointer (sp is a keyword)
  cpu_error db 0x0               ;; Runtime error code

  ;; Graphics display characters (0x0 - 0xF)
  sprites:  db 0xF0, 0x90, 0x90, 0x90, 0xF0 ;; 0
            db 0x20, 0x60, 0x20, 0x20, 0x70 ;; 1
            db 0xF0, 0x10, 0xF0, 0x80, 0xF0 ;; 2
            db 0xF0, 0x10, 0xF0, 0x10, 0xF0 ;; 3
            db 0x90, 0x90, 0xF0, 0x10, 0x10 ;; 4
            db 0xF0, 0x80, 0xF0, 0x10, 0xF0 ;; 5
            db 0xF0, 0x80, 0xF0, 0x90, 0xF0 ;; 6
            db 0xF0, 0x10, 0x20, 0x40, 0x40 ;; 7
            db 0xF0, 0x90, 0xF0, 0x90, 0xF0 ;; 8
            db 0xF0, 0x90, 0xF0, 0x10, 0xF0 ;; 9
            db 0xF0, 0x90, 0xF0, 0x90, 0x90 ;; A
            db 0xE0, 0x90, 0xE0, 0x90, 0xE0 ;; B
            db 0xF0, 0x80, 0x80, 0x80, 0xF0 ;; C
            db 0xE0, 0x90, 0x90, 0x90, 0xE0 ;; D
            db 0xF0, 0x80, 0xF0, 0x80, 0xF0 ;; E
            db 0xF0, 0x80, 0xF0, 0x80, 0x80 ;; F
