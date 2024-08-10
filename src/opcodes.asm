;; Extern functions
extern memset
extern cpu_display
extern cpu_ram
extern cpu_stack
extern cpu_v
extern cpu_keypad
extern cpu_i
extern cpu_dt
extern cpu_st
extern cpu_pc
extern cpu_sp
extern cpu_error
;; Errors
extern RETURN_EMPTY_STACK
extern STACK_OVERFLOW
extern ACCESS_PRIV_MEMORY
extern ACCESS_OUTB_MEMORY

section .data
  SYS_WRITE    equ 1
  SYS_EXIT     equ 60
  STD_OUT      equ 1
  EXIT_FAILURE equ 1
  PROG_BEGIN   equ 0x200
  PROG_END     equ 0xfff
  STACK_TOP    equ 32 ;; (0xf*2)+2
  STACK_BOTTOM equ 0

section .text

;; Increase pc
%macro INC_PC 0
  mov ax, word [cpu_pc]
  add ax, 2
  mov word [cpu_pc], ax
%endmacro

;; 00E0 - CLS
global _cls
_cls:
  push rbp
  mov rbp, rsp                    ;; The cls function must clear all the pixels  
  sub rsp, 16                     ;; display buffer (set a black screen).
  ;; begin                        ;; ==========================================
  mov rdi, cpu_display            ;; rdi = cpu_display
  mov esi, 0                      ;; esi = 0
  mov edx, 2048                   ;; edx = 2048 = sizeof(cpu_display)
  call memset                     ;; memset(cpu_display, 0, 2048)
  INC_PC                          ;; cpu_pc += 2
  ;; end
  leave
  ret


;; 00EE - RET
;; Return from a subroutine.
global _ret
_ret:
  push rbp                        ;; The return function recovers am address from 
  mov rbp, rsp                    ;; the stack and sets the pc to that value.
  ;; begin                        ;; ==========================================
  movzx rax, byte [cpu_sp]        ;; rax = cpu_sp
  cmp al, STACK_BOTTOM            ;; cpu_sp == 0? -> exit. Else continue.
  jne cont_00ee                   ;; If zero, exit the program.
  mov byte [cpu_error], RETURN_EMPTY_STACK ;; Save error 
  jmp end_00ee                    ;; just end the function
cont_00ee:                        ;; This will only be executed if cpu_sp != 0
  sub al, 2                       ;; cpu_sp -= 2
  mov dx, word [cpu_stack + rax]  ;; dx = cpu_stack[cpu_sp] = cpu_pc
  add dx, 2                       ;; dx += 2 = cpu_pc += 2
  mov word [cpu_pc], dx           ;; update cpu_pc
  mov byte [cpu_sp], al           ;; update cpu_sp
end_00ee:
  ;; end
  leave
  ret


;; 1nnn - JP addr
;; Jump to location addr.
;; rdi = addr
global _jp_addr
_jp_addr:
  push rbp                        ;; The jump function sets the program counter 
  mov rbp, rsp                    ;; to a specific address (0x0-0xfff)
  ;; begin                        ;; ==========================================
  cmp di, PROG_BEGIN              ;; Ilegal memory access where addr < 0x200?
  jge cont_1nnn                   ;; If not, continue. Else, exit(addr)
  mov byte [cpu_error], ACCESS_PRIV_MEMORY ;; Note a error has occurred
  jmp end_1nnn                    ;; Skip code
cont_1nnn:                        ;; Only if rdi >= 0x200
  mov word [cpu_pc], di           ;; update pc = rdi = addr 
end_1nnn:
  ;; end
  leave
  ret


;; 2nnn - CALL addr
;; Call subroutine at nnn.
;; rdi = nnn
global _call_addr
_call_addr:
  push rbp                        ;; Sets the program counter to an address,
  mov rbp, rsp                    ;; saving the current pc at the top of the stack
  ;; begin                        ;; ==========================================
  movzx rdx, byte [cpu_sp]        ;; rdx = cpu_sp
  cmp dl, STACK_TOP               ;; Is the sp pointing inside the stack?
  jl cont_2nnn                    ;; If it is, continue. Else stack overflow error 
  mov byte [cpu_error], STACK_OVERFLOW ;; Note the error
  jmp end_2nnn                    ;; end function
cont_2nnn:                        ;; Only if the sp is pointing inside the stack
  cmp di, PROG_BEGIN              ;; nnn < 0x200?
  jge just_2nnn                   ;; If greater or equal continue. Else error.
  mov byte [cpu_error], ACCESS_PRIV_MEMORY ;; Note the error
  jmp end_2nnn                    ;; end function
just_2nnn:                        ;; Only if the call is legal
  mov ax, word [cpu_pc]           ;; ax = pc
  mov word [cpu_stack + rdx], ax  ;; stack[sp] = ax = pc
  add dl, 2                       ;; sp++
  mov byte [cpu_sp], dl           ;; update sp
  mov word [cpu_pc], di           ;; update pc
end_2nnn:
  ;; end
  leave
  ret


;; 3xkk - SE Vx, byte
;; Skip next instruction if Vx = kk.
;; rdi = x
;; rsi = byte
global _se_vx_byte
_se_vx_byte:
  push rbp                        ;; This function skips the next instruction
  mov rbp, rsp                    ;; (pc += 4) if v[x] == byte. Else (pc += 2)
  ;; begin                        ;; =========================================
  mov al, byte [cpu_v + rdi]      ;; al = v[x]
  mov dx, word [cpu_pc]           ;; dx = pc
  cmp al, sil                     ;; v[x] == byte?
  jne end_3xkk                    ;; if it is, do pc += 2 now.
  add dx, 2                       ;; pc += 2
end_3xkk:                         ;; Inconditional
  add dx, 2                       ;; pc += 2
  mov word [cpu_pc], dx           ;; update pc
  ;; end
  leave
  ret


;; 4xkk - SNE Vx, byte
;; Skip next instruction if Vx != kk.
;; rdi = x
;; rsi = byte
global _sne_vx_byte
_sne_vx_byte:
  push rbp                        ;; This function skips the next instruction
  mov rbp, rsp                    ;; (pc += 4) if v[x] != byte. Else (pc += 2)
  ;; begin                        ;; =========================================
  mov al, byte [cpu_v + rdi]      ;; al = v[x]
  mov dx, word [cpu_pc]           ;; dx = pc
  cmp al, sil                     ;; v[x] != byte?
  je end_4xkk                     ;; if it is, do pc += 2 now
  add dx, 2                       ;; pc += 2
end_4xkk:                         ;; Inconditional
  add dx, 2                       ;; pc += 2
  mov word [cpu_pc], dx           ;; update pc
  ;; end
  leave
  ret


;; 5xy0 - SE Vx, Vy
;; Skip next instruction if Vx = Vy.
;; rdi = x
;; rsi = y
global _se_vx_vy
_se_vx_vy:
  push rbp                        ;; This function skips the next instruction 
  mov rbp, rsp                    ;; (pc += 4) if v[x] == v[y]. Else (pc += 2)
  ;; begin                        ;; =========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  mov bx, word [cpu_pc]           ;; bx = pc
  cmp dl, al                      ;; v[x] == v[y]?
  jne end_5xy0                    ;; if it is, do pc += 2 now
  add bx, 2                       ;; pc += 2
end_5xy0:                         ;; Inconditional 
  add bx, 2                       ;; pc += 2
  mov word [cpu_pc], bx           ;; update pc
  ;; end
  leave
  ret


;; 6xkk - LD Vx, byte
;; Set Vx = kk.
;; rdi = x
;; rsi = byte
global _ld_vx_byte
_ld_vx_byte:
  push rbp                        ;; Basically this function sets a register 
  mov rbp, rsp                    ;; v[x] to a value (byte)
  ;; begin                        ;; ==========================================
  mov byte [cpu_v + rdi], sil     ;; v[x] = sil = byte
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 7xkk - ADD Vx, byte
;; Set Vx = Vx + kk.
;; rdi = x
;; rsi = byte
global _add_vx_byte;
_add_vx_byte:
  push rbp                        ;; This function sets the a register v[x] =
  mov rbp, rsp                    ;; v[x] + byte, ignoring overflow.
  ;; begin                        ;; =========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  add dl, sil                     ;; dl = v[x] += byte
  mov byte [cpu_v + rdi], dl      ;; update v[x]
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 8xy0 - LD Vx, Vy
;; Set Vx = Vy.
;; rdi = x
;; rsi = y
global _ld_vx_vy:
_ld_vx_vy:
  push rbp                        ;; This function simply sets a register v[x]
  mov rbp, rsp                    ;; the value of other register v[y]
  ;; begin                        ;; =========================================
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  mov byte [cpu_v + rdi], al      ;; update v[x] = al = v[y]
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 8xy1 - OR Vx, Vy
;; Set Vx = Vx OR Vy.
;; rdi = x
;; rsi = y
global _or_vx_vy
_or_vx_vy:
  push rbp                        ;; Just sets a register v[x] the value 
  mov rbp, rsp                    ;; v[x] | v[y]
  ;; begin                        ;; =========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  or  al, dl                      ;; al = v[x] | v[y]
  mov byte [cpu_v + rdi], al      ;; update v[x] to the new value
  mov byte [cpu_v + 0xF], 0       ;; set v[0xf] to 0
  INC_PC                          ;; pc += 2
  ;; end 
  leave
  ret


;; 8xy2 - AND Vx, Vy
;; Set Vx = Vx AND Vy.
;; rdi = x
;; rsi = y
global _and_vx_vy
_and_vx_vy:
  push rbp                        ;; Just sets a register v[x] the value  
  mov rbp, rsp                    ;; v[x] & v[y]
  ;; begin                        ;; =========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  and al, dl                      ;; al = v[x] & v[y]
  mov byte [cpu_v + rdi], al      ;; update v[x] to the new value
  mov byte [cpu_v + 0xF], 0       ;; set v[0xf] to 0
  INC_PC                          ;; pc += 2
  ;; end 
  leave
  ret


;; 8xy3 - XOR Vx, Vy
;; Set Vx = Vx XOR Vy.
;; rdi = x
;; rsi = y
global _xor_vx_vy
_xor_vx_vy:
  push rbp                        ;; This function sets a register v[x] the   
  mov rbp, rsp                    ;; value v[x] ^ v[y]
  ;; begin                        ;; =========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  xor al, dl                      ;; al = v[x] ^ v[y]
  mov byte [cpu_v + rdi], al      ;; update v[x] to the new value
  mov byte [cpu_v + 0xF], 0       ;; set v[0xf] to 0
  INC_PC                          ;; pc += 2
  ;; end 
  leave
  ret


;; 8xy4 - ADD Vx, Vy
;; Set Vx = Vx + Vy, set VF = carry.
;; rdi = x
;; rsi = y
global _add_vx_vy
_add_vx_vy:
  push rbp                        ;; Basically sets v[x] to v[x] + v[y], 
  mov rbp, rsp                    ;; considering carry (result >255).
  ;; begin                        ;; =========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  add dl, al                      ;; dl = v[x] + v[y]
  jnc ncarry_8xy4                 ;; If not carry, jump to v[0xf] = 0.
  mov byte [cpu_v + 0xF], 1       ;; set v[0xf] = 1
  jmp end_8xy4                    ;; jump to the update
ncarry_8xy4:                      ;; Only if there is no carry
  mov byte [cpu_v + 0xF], 0       ;; set v[0xf] = 0
end_8xy4:                         ;; Inconditional
  mov byte [cpu_v + rdi], dl      ;; set v[x] = v[x] + v[y]
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 8xy5 - SUB Vx, Vy
;; Set Vx = Vx - Vy, set VF = NOT borrow.
;; rdi = x
;; rsi = y
global _sub_vx_vy
_sub_vx_vy:
  push rbp                        ;; This instruction sets the register v[x]
  mov rbp, rsp                    ;; to the value v[x] - v[y], considering carry.
  ;; begin                        ;; ==========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  sub dl, al                      ;; dl = v[x] - v[y]
  jnc ncarry_8xy5                 ;; If not carry, jump to v[0xf] = 1
  mov byte [cpu_v + 0xF], 0       ;; set v[0xf] = 0
  jmp end_8xy5                    ;; jump to update v[x]
ncarry_8xy5:                      ;; Only if there is no carry
  mov byte [cpu_v + 0xF], 1       ;; set v[0xf] = 1
end_8xy5:                         ;; Inconditional
  mov byte [cpu_v + rdi], dl      ;; update v[x] to v[x] - v[y]
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 8xy6 - SHR Vx {, Vy}
;; Set Vx = Vy SHR 1.
;; rdi = x
;; rsi = y
global _shr_vx_vy
_shr_vx_vy:
  push rbp                        ;; This function just sets a register v[x]
  mov rbp, rsp                    ;; the value v[y] >> 1
  ;; begin                        ;; =========================================
  mov sil, byte [cpu_v + rsi]     ;; sil = v[y]
  shr sil, 1                      ;; sil = v[y] >> 1
  jnc noverflow_8xy6              ;; If no overflow, jump to v[0xf] = 0
  mov byte [cpu_v + 0xF], 1       ;; v[0xf] = 1
  jmp end_8xy6                    ;; Just skip v[0xf] = 0
noverflow_8xy6:                   ;; Only if no overflow
  mov byte [cpu_v + 0xF], 0       ;; v[0xf] = 0
end_8xy6:                         ;; Inconditional
  mov [cpu_v + rdi], byte sil     ;; v[x] = (v[y] >> 1)
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 8xy7 - SUBN Vx, Vy
;; Set Vx = Vy - Vx, set VF = NOT borrow.
;; rdi = x
;; rsi = y
global _subn_vx_vy
_subn_vx_vy:
  push rbp                        ;; This operation sets v[x] to the result of
  mov rbp, rsp                    ;; v[y] - v[x], considering carry
  ;; begin                        ;; ==========================================
  mov dl, byte [cpu_v + rdi]      ;; dl = v[x]
  mov al, byte [cpu_v + rsi]      ;; al = v[y]
  sub al, dl                      ;; al = v[y] -= v[x]
  jnc ncarry_8xy7                 ;; If no carry, jump to v[0xf] = 1
  mov byte [cpu_v + 0xF], 0       ;; v[0xf] = 0
  jmp end_8xy7                    ;; Skip v[0xf] = 1
ncarry_8xy7:                      ;; Only if no carry
  mov byte [cpu_v + 0xF], 1       ;; v[0xf] = 1  
end_8xy7:                         ;; Inconditional
  mov [cpu_v + rdi], byte al      ;; update v[x] to v[y] - v[x]
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 8xyE - SHL Vx {, Vy}
;; Set Vx = Vy SHL 1.
;; rdi = x
;; rsi = y
global _shl_vx_vy
_shl_vx_vy:
  push rbp                        ;; This function sets a register v[x] to the 
  mov rbp, rsp                    ;; result of v[y] << 1
  ;; begin                        ;; ==========================================
  mov sil, byte [cpu_v + rsi]     ;; sil = v[y] 
  shl sil, 1                      ;; sil = v[y] << 1
  jnc noverflow_9xy6              ;; If no overflow, jump to v[0xf] = 0
  mov byte [cpu_v + 0xF], 1       ;; v[0xf] = 1
  jmp end_9xy6                    ;; Skip v[0xf] = 0
noverflow_9xy6:                   ;; Only if no carry
  mov byte [cpu_v + 0xF], 0       ;; v[0xf] = 0
end_9xy6:                         ;; Inconditional
  mov [cpu_v + rdi], byte sil     ;; update v[x] to v[y] << 1
  INC_PC                          ;; pc += 2
  ;; end
  leave
  ret


;; 9xy0 - SNE Vx, Vy
;; Skip next instruction if Vx != Vy.
;; rdi = x
;; rsi = y
global _sne_vx_vy
_sne_vx_vy:
  push rbp
  mov rbp, rsp
  ;; begin
  mov dl, byte [cpu_v + rdi]
  mov al, byte [cpu_v + rsi]
  mov bx, word [cpu_pc]
  cmp dl, al 
  je end_9xy0
  add bx, 2
end_9xy0:
  add bx, 2
  mov word [cpu_pc], bx
  ;; end
  leave
  ret


;; Annn - LD I, addr
;; Set I = nnn.
;; rdi = addr
global _ld_i_addr
_ld_i_addr:
  push rbp
  mov rbp, rsp
  ;; begin
  mov word [cpu_i], di
  INC_PC
  ;; end
  leave
  ret


;; Bnnn - JP V0, addr
;; Jump to location nnn + V0.
;; rdi = addr
global _jp_v0_addr
_jp_v0_addr:
  push rbp
  mov rbp, rsp
  ;; begin
  movzx si, byte [cpu_v]
  add si, di
  cmp si, PROG_BEGIN
  jge jp_v0_addr_cont
  mov byte [cpu_error], ACCESS_PRIV_MEMORY
  jmp jp_v0_addr_end
jp_v0_addr_cont:
  cmp si, PROG_END
  jle just_jp_v0_addr
  mov byte [cpu_error], ACCESS_OUTB_MEMORY
  jmp jp_v0_addr_end
just_jp_v0_addr:
  mov word [cpu_pc], si
jp_v0_addr_end:
  ;; end
  leave
  ret


;; Cxkk - RND Vx, byte
;; Set Vx = random byte AND kk.
;; rdi = x
;; rsi = y
global _rnd_vx_byte
_rnd_vx_byte:
  push rbp
  mov rbp, rsp
  ;; begin
  rdrand ax
  and al, sil
  mov byte [cpu_v + rdi], al
  INC_PC
  ;; end
  leave
  ret

;; Dxyn - DRW Vx, Vy, nibble
;; Display n-byte sprite
;; rdi = vx
;; rsi = vy
;; rdx = nibble
global _drw_vx_vy_nibble
_drw_vx_vy_nibble:
  push rbp
  mov rbp, rsp
  sub rsp, 16
  ;; begin
  mov byte [rbp-8], dl
  ;; [rbp-1] = x = cpu_v[vx]
  movzx rax, byte [cpu_v + rdi]
  mov byte [rbp-1], al      
  ;; [rbp-2] = y = cpu_v[vy]
  movzx rax, byte [cpu_v + rsi]
  mov byte [rbp-2], al     
  ;; [rbp-3] = it = 0
  mov byte [rbp-3], 0
  ;; cpu_v[0xf] = 0  
  mov byte [cpu_v + 0xF], 0 

drw_it_loop:
  ;; get sprite from RAM
  ;; saved at [rsp-4]
  movzx rdi, byte [rbp-3]
  movzx rsi, word [cpu_i]
  movzx rsi, byte [rsi + rdi + cpu_ram]
  mov byte [rbp-4], sil

  ;; Calculate y_wrap coordinate
  ;; = (y+it)%32 mult by 64
  ;; saved at [rbp-5]
  movzx rax, byte [rbp-2] ;; y
  movzx rdi, byte [rbp-3] ;; it
  add ax, di
  and ax, 31
  shl ax, 6
  mov word [rbp-6], ax

  ;; Set jt = 0
  ;; located at [rbp-6]
  mov byte [rbp-7], 0

drw_jt_loop:
  ;; bit = (0x80>>jt)
  mov rdi, 0x80
  movzx rcx, byte [rbp-7]
  shr di, cl
  
  ;; (bit&sprite) != 0?
  movzx rax, byte [rbp-4]
  and di, ax
  cmp di, 0
  je drw_jt_loop_end

  ;; Calculate x_wrap coordinate
  ;; = (x+jt)%64
  movzx rdi, byte [rbp-1] ; x
  movzx rsi, byte [rbp-7] ; jt
  add di, si
  and di, 63

  ;; Calculate final position (x,y)
  ;; passed to vector index
  ;; = x_wrap + (y_wrap*64)
  movzx rsi, word [rbp-6] ; y_wrap
  add di, si

  ;; Activate cpu_v[F] if overwrite
  movzx rax, byte [cpu_display + rdi]
  cmp al, 1
  jne drw_no_overwrite
  mov byte [cpu_v + 0xF], 1

drw_no_overwrite:
  xor al, 1
  mov byte [cpu_display + rdi], al

drw_jt_loop_end:
  ;; end jt loop?
  movzx rdi, byte [rbp-7]
  inc dil
  mov byte [rbp-7], dil
  cmp dil, 8
  jl drw_jt_loop

  ;; end it loop?
  movzx rdi, byte [rbp-3]
  movzx rsi, byte [rbp-8]
  inc dil
  mov byte [rbp-3], dil
  cmp dil, sil
  jl drw_it_loop 

drw_end:
  INC_PC
  ;; hell end
  leave
  ret


;; Ex9E - SKP Vx
;; Skip next instruction if key Vx is pressed.
;; rdi = x
global _skp_vx:
_skp_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  movzx rsi, byte [cpu_v + rdi]
  mov al, byte [cpu_keypad + rsi]
  mov dx, word [cpu_pc]
  cmp al, 1
  jne end_ex9e
  add dx, 2
end_ex9e:
  add dx, 2
  mov word [cpu_pc], dx
  ;; end
  leave
  ret


;; ExA1 - SKNP Vx
;; Skip next instruction if key Vx is not pressed.
;; rdi = x
global _sknp_vx:
_sknp_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  movzx rsi, byte [cpu_v + rdi]
  mov al, byte [cpu_keypad + rsi]
  mov dx, word [cpu_pc]
  cmp al, 1
  je end_exa1
  add dx, 2
end_exa1:
  add dx, 2
  mov word [cpu_pc], dx
  ;; end
  leave
  ret


;; Fx07 - LD Vx, DT
;; Set Vx = delay timer value.
;; rdi = x
global _ld_vx_dt
_ld_vx_dt:
  push rbp
  mov rbp, rsp
  ;; begin
  mov sil, byte [cpu_dt]
  mov [cpu_v + rdi], sil
  INC_PC
  ;; end
  leave
  ret


;; Fx0A - LD Vx, K
;; Wait for a key press, store key in Vx.
;; rdi = x
global _ld_vx_k
_ld_vx_k:
  push rbp
  mov rbp, rsp
  ;; begin
  xor rsi, rsi
loop_fx0a:
  mov dl, byte [cpu_keypad + rsi]
  cmp dl, 0
  jne keyp_fx0a
  inc sil
  cmp sil, 0xF
  jle loop_fx0a
  jmp end_fx0a
keyp_fx0a:
  mov byte [cpu_v + rdi], sil
  INC_PC
end_fx0a:
  ;; end
  leave
  ret


;; Fx15 - LD DT, Vx
;; Set delay timer = Vx.
;; rdi = x
global _ld_dt_vx
_ld_dt_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  mov dl, byte [cpu_v + rdi]
  mov byte [cpu_dt], dl
  INC_PC
  ;; end
  leave
  ret


;; Fx18 - LD ST, Vx
;; Set sound timer = Vx.
;; rdi = x
global _ld_st_vx
_ld_st_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  mov dl, byte [cpu_v + rdi]
  mov byte [cpu_st], dl
  INC_PC
  ;; end
  leave
  ret


;; Fx1E - ADD I, Vx
;; Set I = I + Vx.
;; rdi = x
global _add_i_vx
_add_i_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  movzx si, byte [cpu_v + rdi]
  mov dx, word [cpu_i]
  add dx, si
  cmp dx, 0xFFF
  jg  outaddr_fx1e
  mov byte [cpu_v + 0xF], 0
  jmp end_fx1e 
outaddr_fx1e:
  mov byte [cpu_v + 0xF], 1
end_fx1e:
  mov word [cpu_i], dx
  INC_PC
  ;; end
  leave
  ret


;; Fx29 - LD F, Vx
;; Set I = location of sprite for digit Vx.
;; rdi = x
global _ld_f_vx
_ld_f_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  movzx si, byte [cpu_v + rdi]
  mov ax, 5
  mul si
  mov [cpu_i], word ax
  INC_PC
  ;; end
  leave
  ret


;; Fx33 - LD B, Vx
;; Store BCD representation of Vx at I, I+1, and I+2.
;; rdi = x
global _ld_b_vx
_ld_b_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  ;; Hundreds
  movzx rsi, byte [cpu_v + rdi]
  mov rax, rsi  
  mov rcx, 100  
  div cl       
  movzx rbx, word [cpu_i]
  mov [cpu_ram + rbx], al
  ;; Tens
  mov rax, rsi
  mov rcx, 10
  div cl
  and rax, 0xFF
  div cl
  add rbx, 1
  mov [cpu_ram + rbx], ah  
  ;; Units
  mov rax, rsi
  mov rcx, 100
  div cl
  shr rax, 8
  and rax, 0xFF 
  mov rcx, 10
  div cl
  add rbx, 1
  mov [cpu_ram + rbx], ah
  INC_PC
  ;; end
  leave
  ret


;; Fx55 - LD [I], Vx
;; Store registers V0 through Vx at I.
;; rdi = x
global _ld_i_vx
_ld_i_vx:
  push rbp
  mov rbp, rsp
  ;; begin
  movzx rsi, word [cpu_i]
  xor rdx, rdx 
loop_fx55:
  mov al, byte [cpu_v + rdx]
  mov byte [cpu_ram + rsi + rdx], al
  inc dl
  cmp dl, dil
  jle loop_fx55
  add si, di
  inc si
  mov word [cpu_i], si  
  INC_PC
  ;; end
  leave
  ret


;; Fx65 - LD Vx, [I]
;; Read registers V0 through Vx from I.
;; rdi = x
global _ld_vx_i
_ld_vx_i:
  push rbp
  mov rbp, rsp
  ;; begin
  movzx rsi, word [cpu_i]
  xor rdx, rdx
loop_fx65:
  mov al, byte [cpu_ram + rsi + rdx]
  mov byte [cpu_v + rdx], al
  inc dl
  cmp dl, dil
  jle loop_fx65
  add si, di
  inc si
  mov word [cpu_i], si
  INC_PC
  ;; end
  leave
  ret
