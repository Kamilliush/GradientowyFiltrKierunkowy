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
;   [rsp+104]   = endY
;   [rsp+112]   = imageHeight
; ---------------------------------------------------------------------------------

alg PROC

    ; --- Prolog ---
    push    rbp                ; Zachowuje wartoœæ rejestru RBP na stosie
    push    rbx                ; Zachowuje wartoœæ rejestru RBX na stosie
    push    rsi                ; Zachowuje wartoœæ rejestru RSI na stosie
    push    rdi                ; Zachowuje wartoœæ rejestru RDI na stosie
    push    r12                ; Zachowuje wartoœæ rejestru R12 na stosie
    push    r13                ; Zachowuje wartoœæ rejestru R13 na stosie
    push    r14                ; Zachowuje wartoœæ rejestru R14 na stosie
    push    r15                ; Zachowuje wartoœæ rejestru R15 na stosie

    ; Przepisujemy argumenty do "lokalnych" rejestrów
    mov     rbp, rcx           ; rbp = pixelData (wejœciowe dane pikseli)
    mov     rbx, rdx           ; rbx = outputData (bufor wyjœciowy)
    mov     r12d, r8d          ; r12d = width (szerokoœæ obrazu)
    mov     r13d, r9d          ; r13d = startY (pocz¹tek przetwarzania wierszy)

    mov     eax, [rsp + 104]    ; eax = endY (koñcowy wiersz przetwarzania)
    mov     r14d, eax          ; r14d = endY

    mov     eax, [rsp + 112]    ; eax = imageHeight (wysokoœæ obrazu)
    mov     r15d, eax          ; r15d = imageHeight

    ; Jeœli bufor wyjœciowy == 0, wyjdŸ
    test    rbx, rbx           ; Sprawdza, czy bufor wyjœciowy jest równy 0
    jz      invalid_output_buffer ; Jeœli tak, przejdŸ do invalid_output_buffer

    ; ---------------------------------------------------------------------------------
    ; Pêtla: for (y = startY; y < endY; y++)
    ; ---------------------------------------------------------------------------------
row_loop:
    cmp     r13d, r14d         ; Porównuje y (r13d) z endY (r14d)
    jg     end_function       ; Jeœli y >= endY, zakoñcz funkcjê

    ; x = 0
    xor     r9d, r9d           ; r9d = x = 0

col_loop:
    cmp     r9d, r12d          ; Porównuje x (r9d) z width (r12d)
    jg      next_row           ; Jeœli x >= width, przejdŸ do nastêpnego wiersza

    ;------------------------------------------------------------------------------
    ; Obliczenie offsetu: offset = ((y * width) + x) * 3
    ;------------------------------------------------------------------------------
    mov     eax, r13d          ; eax = y
    imul    eax, r12d          ; eax = y * width
    add     eax, r9d           ; eax = (y * width + x)
    imul    eax, 3             ; eax = (y * width + x) * 3

    lea     rsi, [rbx + rax]   ; rsi = &outputData[offset]
    lea     rdi, [rbp + rax]   ; rdi = &pixelData[offset]

    ;------------------------------------------------------------------------------
    ; SprawdŸ, czy jesteœmy na brzegu (x==0 || x==width-1 || y==0 || y==height-1).
    ; Jeœli tak, to kopiujemy orygina³. W przeciwnym razie filtr gradientowy.
    ;------------------------------------------------------------------------------

    ; if (x == 0)
    cmp     r9d, 0             ; Porównuje x z 0
    je      copy_original       ; Jeœli x == 0, przejdŸ do kopiowania orygina³u

    ; if (x == width-1)
    mov     eax, r12d          ; eax = width
    dec     eax                ; eax = width - 1
    cmp     r9d, eax           ; Porównuje x z width - 1
    je      copy_original       ; Jeœli x == width - 1, przejdŸ do kopiowania orygina³u

    ; if (y == 0)
    cmp     r13d, 0            ; Porównuje y z 0
    je      copy_original       ; Jeœli y == 0, przejdŸ do kopiowania orygina³u

    ; if (y == height-1)
    mov     ecx, r15d          ; ecx = imageHeight
    dec     ecx                ; ecx = imageHeight - 1
    cmp     r13d, ecx          ; Porównuje y z imageHeight - 1
    je      copy_original       ; Jeœli y == height - 1, przejdŸ do kopiowania orygina³u

    ;------------------------------------------------------------------------------
    ; [1] Wykonaj filtr gradientowy 3x3 z mask¹:
    ;     -1  -1   1
    ;     -1  -2   1
    ;      1   1   1
    ;
    ; Dla ka¿dego z kana³ów R, G, B liczymy osobno.
    ;------------------------------------------------------------------------------

    ; accR, accG, accB = 0
    xor     eax, eax           ; eax = 0
    push    rax                ; Zapisuje accR (0) na stos
    push    rax                ; Zapisuje accG (0) na stos
    push    rax                ; Zapisuje accB (0) na stos

    ;------------------------------------------------------------------------------
    ; compute_offset (funkcja inline) – obliczanie offsetu i akumulacja wartoœci RGB
    ;------------------------------------------------------------------------------

ComputeOffset MACRO dx_, dy_, weight_
    mov   r10d, r9d            ; r10d = x
    add   r10d, dx_            ; r10d = x + dx_
    mov   r11d, r13d           ; r11d = y
    add   r11d, dy_            ; r11d = y + dy_

    mov   eax, r11d            ; eax = y + dy_
    imul  eax, r12d            ; eax = (y + dy_) * width
    add   eax, r10d            ; eax = (y + dy_) * width + (x + dx_)
    imul  eax, 3               ; eax = offset

    lea   r10, [rbp+rax]       ; r10 = &pixelData[offset]

    movzx eax, byte ptr [r10]  ; Pobiera wartoœæ R
    imul  eax, weight_         ; Mno¿y przez wagê
    add   [rsp+16], eax        ; Dodaje do accR

    movzx eax, byte ptr [r10+1]; Pobiera wartoœæ G
    imul  eax, weight_         ; Mno¿y przez wagê
    add   [rsp+8], eax         ; Dodaje do accG

    movzx eax, byte ptr [r10+2]; Pobiera wartoœæ B
    imul  eax, weight_         ; Mno¿y przez wagê
    add   [rsp], eax           ; Dodaje do accB
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
    ; Kompresja wartoœci accR, accG, accB do zakresu [0..255] i zapis do outputData
    ;------------------------------------------------------------------------------

    mov     eax, [rsp+16]      ; Pobiera accR
    call    clamp0_255         ; Kompresuje do zakresu [0..255]
    mov     byte ptr [rsi], al ; Zapisuje wartoœæ R

    mov     eax, [rsp+8]       ; Pobiera accG
    call    clamp0_255         ; Kompresuje do zakresu [0..255]
    mov     byte ptr [rsi+1], al ; Zapisuje wartoœæ G

    mov     eax, [rsp]         ; Pobiera accB
    call    clamp0_255         ; Kompresuje do zakresu [0..255]
    mov     byte ptr [rsi+2], al ; Zapisuje wartoœæ B

    ; Posprz¹taj 3 pushe (accR, accG, accB):
    add     rsp, 24            ; Usuwa wartoœci accR, accG, accB ze stosu

    jmp     done_pixel         ; Skok do zakoñczenia przetwarzania piksela

;------------------------------------------------------------------------------
; Funkcja clamp0_255: Kompresja wartoœci do zakresu [0..255]
;------------------------------------------------------------------------------
clamp0_255:
    cmp     eax, 0             ; Sprawdza, czy wartoœæ jest poni¿ej 0
    jl      clamp_to_zero      ; Jeœli tak, ustaw na 0
    cmp     eax, 255           ; Sprawdza, czy wartoœæ jest powy¿ej 255
    jg      clamp_to_255       ; Jeœli tak, ustaw na 255
    ret                       ; W przeciwnym razie zwróæ wartoœæ

clamp_to_zero:
    xor     eax, eax           ; Ustaw wartoœæ na 0
    ret

clamp_to_255:
    mov     eax, 255           ; Ustaw wartoœæ na 255
    ret

;------------------------------------------------------------------------------
; Kopiowanie oryginalnego piksela (jeœli brzeg).
;------------------------------------------------------------------------------
copy_original:
    movzx   eax, byte ptr [rdi]     ; Pobiera wartoœæ R oryginalnego piksela
    mov     byte ptr [rsi], al      ; Kopiuje wartoœæ R
    movzx   eax, byte ptr [rdi+1]   ; Pobiera wartoœæ G oryginalnego piksela
    mov     byte ptr [rsi+1], al    ; Kopiuje wartoœæ G
    movzx   eax, byte ptr [rdi+2]   ; Pobiera wartoœæ B oryginalnego piksela
    mov     byte ptr [rsi+2], al    ; Kopiuje wartoœæ B

done_pixel:
    inc     r9d                 ; Zwiêksza x (kolumna) o 1
    jmp     col_loop            ; Wraca do przetwarzania kolumn

next_row:
    inc     r13d                ; Zwiêksza y (wiersz) o 1
    jmp     row_loop            ; Wraca do przetwarzania wierszy

invalid_output_buffer:
    jmp     end_function        ; Przejœcie do zakoñczenia funkcji

; --- Epilog ---
end_function:
    pop     r15                 ; Przywraca wartoœæ rejestru R15
    pop     r14                 ; Przywraca wartoœæ rejestru R14
    pop     r13                 ; Przywraca wartoœæ rejestru R13
    pop     r12                 ; Przywraca wartoœæ rejestru R12
    pop     rdi                 ; Przywraca wartoœæ rejestru RDI
    pop     rsi                 ; Przywraca wartoœæ rejestru RSI
    pop     rbx                 ; Przywraca wartoœæ rejestru RBX
    pop     rbp                 ; Przywraca wartoœæ rejestru RBP
    ret                        ; Zakoñczenie funkcji

alg ENDP

END
