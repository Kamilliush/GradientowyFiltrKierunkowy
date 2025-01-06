PUBLIC alg

.DATA
; Maska 3x3 (dla czytelnoœci):
;   -1  -1   1
;   -1  -2   1
;    1   1   1

.CODE

; ---------------------------------------------------------------------------------
; void alg(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight)
;
; Rejestry 64-bit:
;   RCX = pixelData      (wejœciowy bufor pikseli)
;   RDX = outputData     (bufor wyjœciowy)
;   R8  = width          (szerokoœæ)
;   R9  = startY         (pocz¹tek)
;   [rsp+32]   = endY
;   [rsp+40]   = imageHeight
; ---------------------------------------------------------------------------------

alg PROC

    ; --- Prolog ---
    push    rbp
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    ; Przepisujemy argumenty do "lokalnych" rejestrów
    mov     rbp, rcx           ; rbp = pixelData (input)
    mov     rbx, rdx           ; rbx = outputData
    mov     r12d, r8d          ; r12d = width
    mov     r13d, r9d          ; r13d = startY

    mov     eax, [rsp + 32]    ; w 64-bit MASM: [rsp+32] = endY (patrz opis wy¿ej)
    mov     r14d, eax

    mov     eax, [rsp + 40]    ; [rsp+40] = imageHeight
    mov     r15d, eax

    ; Jeœli bufor wyjœciowy == 0, wyjdŸ
    test    rbx, rbx
    jz      invalid_output_buffer

    ; ---------------------------------------------------------------------------------
    ; Pêtla: for (y = startY; y < endY; y++)
    ; ---------------------------------------------------------------------------------
row_loop:
    cmp     r13d, r14d
    jge     end_function      ; jeœli y >= endY -> koniec

    ; x = 0
    xor     r9d, r9d          ; r9d = x

col_loop:
    cmp     r9d, r12d
    jge     next_row          ; jeœli x >= width -> kolejny wiersz

    ;------------------------------------------------------------------------------
    ; Obliczenie offsetu: offset = ((y * width) + x) * 3
    ;------------------------------------------------------------------------------
    mov     eax, r13d         ; eax = y
    imul    eax, r12d         ; eax = y * width
    add     eax, r9d          ; eax = (y*width + x)
    imul    eax, 3            ; eax = (y*width + x)*3

    lea     rsi, [rbx + rax]  ; rsi = &outputData[offset]
    lea     rdi, [rbp + rax]  ; rdi = &pixelData[offset]

    ;------------------------------------------------------------------------------
    ; SprawdŸ, czy jesteœmy na brzegu (x==0 || x==width-1 || y==0 || y==height-1).
    ; Jeœli tak, to kopiujemy orygina³. W przeciwnym razie filtr gradientowy.
    ;------------------------------------------------------------------------------

    ; if (x == 0)
    cmp     r9d, 0
    je      copy_original

    ; if (x == width-1)
    mov     eax, r12d
    dec     eax
    cmp     r9d, eax
    je      copy_original

    ; if (y == 0)
    cmp     r13d, 0
    je      copy_original

    ; if (y == height-1)
    mov     ecx, r15d
    dec     ecx
    cmp     r13d, ecx
    je      copy_original

    ;------------------------------------------------------------------------------
    ; [1] Wykonaj filtr gradientowy 3x3 z mask¹:
    ;     -1  -1   1
    ;     -1  -2   1
    ;      1   1   1
    ;
    ; Dla ka¿dego z kana³ów R, G, B liczymy osobno.
    ;------------------------------------------------------------------------------

    ; accR, accG, accB = 0
    xor     eax, eax
    push    rax   ; [rsp]   = accR
    push    rax   ; [rsp+8] = accG
    push    rax   ; [rsp+16]= accB

    ;------------------------------------------------------------------------------
    ; compute_offset (funkcja inline) – zamiast pseudo-funkcji z ediReg32, esiReg32
    ; u¿ywamy rejestrów edi i esi, bo w MASM to s¹ od razu 32-bit (E/DI).
    ;------------------------------------------------------------------------------

    ; Ka¿dy s¹siad:
    ;   mov edi, dx
    ;   mov esi, dy
    ;   (oblicz offset) => w EAX
    ;   pobierz R,G,B => dodaj do akumulatorów (uwzglêdniaj¹c wagê)

;=== Definicja ma³ej „pomocniczej” procedury inline do obliczenia offsetu ===
; Zamiast definicji label "compute_offset:" z 'push r10/push r11', robimy to inline
; aby unikn¹æ problemów z ML64. Mo¿esz oczywiœcie wydzieliæ w PROC, ale bêdzie to
; wymaga³o konwencji wywo³añ. Najprostsze jest zrobienie inline.

ComputeOffset MACRO dx_, dy_, weight_
    ;   r10d = x + dx_
    ;   r11d = y + dy_
    mov   r10d, r9d
    add   r10d, dx_
    mov   r11d, r13d
    add   r11d, dy_

    ; offset = ((r11d) * width + (r10d))*3
    mov   eax, r11d
    imul  eax, r12d
    add   eax, r10d
    imul  eax, 3
    ; => offset w EAX

    ; r10 = &pixelData[offset]
    lea   r10, [rbp+rax]

    ; R
    movzx eax, byte ptr [r10]
    imul  eax, weight_
    add   [rsp+16], eax  ; accR => [rsp+16]

    ; G
    movzx eax, byte ptr [r10+1]
    imul  eax, weight_
    add   [rsp+8], eax   ; accG => [rsp+8]

    ; B
    movzx eax, byte ptr [r10+2]
    imul  eax, weight_
    add   [rsp], eax     ; accB => [rsp]
ENDM

    ; (x-1, y-1) z wag¹ -1
    ComputeOffset -1, -1, -1

    ; (x, y-1) z wag¹ -1
    ComputeOffset 0, -1, -1

    ; (x+1, y-1) z wag¹ 1
    ComputeOffset 1, -1, 1

    ; (x-1, y) z wag¹ -1
    ComputeOffset -1, 0, -1

    ; (x, y) z wag¹ -2
    ComputeOffset 0, 0, -2

    ; (x+1, y) z wag¹ 1
    ComputeOffset 1, 0, 1

    ; (x-1, y+1) z wag¹ 1
    ComputeOffset -1, 1, 1

    ; (x, y+1) z wag¹ 1
    ComputeOffset 0, 1, 1

    ; (x+1, y+1) z wag¹ 1
    ComputeOffset 1, 1, 1

    ;------------------------------------------------------------------------------
    ; Teraz w [rsp+16] jest accR, w [rsp+8] accG, w [rsp] accB.
    ; Nale¿y je skompresowaæ do [0..255], zapisaæ do outputData (rsi).
    ;------------------------------------------------------------------------------

    mov     eax, [rsp+16]  ; accR
    call    clamp0_255
    mov     byte ptr [rsi], al    ; output R

    mov     eax, [rsp+8]   ; accG
    call    clamp0_255
    mov     byte ptr [rsi+1], al  ; output G

    mov     eax, [rsp]     ; accB
    call    clamp0_255
    mov     byte ptr [rsi+2], al  ; output B

    ; Posprz¹taj 3 pushe (accR, accG, accB):
    add     rsp, 24

    jmp     done_pixel

;------------------------------------------------------------------------------
; Funkcja clamp0_255: w rejestrze EAX mamy wartoœæ, zwracamy w AL obciêt¹ do [0..255].
;------------------------------------------------------------------------------
clamp0_255:
    cmp     eax, 0
    jl      clamp_to_zero
    cmp     eax, 255
    jg      clamp_to_255
    ret

clamp_to_zero:
    xor     eax, eax
    ret

clamp_to_255:
    mov     eax, 255
    ret

;------------------------------------------------------------------------------
; Kopiowanie oryginalnego piksela (jeœli brzeg).
;------------------------------------------------------------------------------
copy_original:
    movzx   eax, byte ptr [rdi]     ; R
    mov     byte ptr [rsi], al
    movzx   eax, byte ptr [rdi+1]   ; G
    mov     byte ptr [rsi+1], al
    movzx   eax, byte ptr [rdi+2]   ; B
    mov     byte ptr [rsi+2], al

done_pixel:
    inc     r9d
    jmp     col_loop

next_row:
    inc     r13d
    jmp     row_loop

invalid_output_buffer:
    jmp     end_function

; --- Epilog ---
end_function:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    pop     rbp
    ret

alg ENDP

END
