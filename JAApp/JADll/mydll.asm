PUBLIC alg

.DATA
; Maska 3x3 (dla czytelno�ci):
;   -1  -1   1
;   -1  -2   1
;    1   1   1

.CODE

; ---------------------------------------------------------------------------------
; void alg(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight)
;
; Rejestry 64-bit:
;   RCX = pixelData      (wej�ciowy bufor pikseli)
;   RDX = outputData     (bufor wyj�ciowy)
;   R8  = width          (szeroko��)
;   R9  = startY         (pocz�tek)
;   [rsp+104]   = endY
;   [rsp+112]   = imageHeight
; ---------------------------------------------------------------------------------

alg PROC

    ; --- Prolog ---
    push    rbp                ; Zachowuje warto�� rejestru RBP na stosie
    push    rbx                ; Zachowuje warto�� rejestru RBX na stosie
    push    rsi                ; Zachowuje warto�� rejestru RSI na stosie
    push    rdi                ; Zachowuje warto�� rejestru RDI na stosie
    push    r12                ; Zachowuje warto�� rejestru R12 na stosie
    push    r13                ; Zachowuje warto�� rejestru R13 na stosie
    push    r14                ; Zachowuje warto�� rejestru R14 na stosie
    push    r15                ; Zachowuje warto�� rejestru R15 na stosie

    ; Przepisujemy argumenty do "lokalnych" rejestr�w
    mov     rbp, rcx           ; rbp = pixelData (wej�ciowe dane pikseli)
    mov     rbx, rdx           ; rbx = outputData (bufor wyj�ciowy)
    mov     r12d, r8d          ; r12d = width (szeroko�� obrazu)
    mov     r13d, r9d          ; r13d = startY (pocz�tek przetwarzania wierszy)

    mov     eax, [rsp + 104]    ; eax = endY (ko�cowy wiersz przetwarzania)
    mov     r14d, eax          ; r14d = endY

    mov     eax, [rsp + 112]    ; eax = imageHeight (wysoko�� obrazu)
    mov     r15d, eax          ; r15d = imageHeight

    ; Je�li bufor wyj�ciowy == 0, wyjd�
    test    rbx, rbx           ; Sprawdza, czy bufor wyj�ciowy jest r�wny 0
    jz      invalid_output_buffer ; Je�li tak, przejd� do invalid_output_buffer

    ; ---------------------------------------------------------------------------------
    ; P�tla: for (y = startY; y < endY; y++)
    ; ---------------------------------------------------------------------------------
row_loop:
    cmp     r13d, r14d         ; Por�wnuje y (r13d) z endY (r14d)
    jg     end_function       ; Je�li y >= endY, zako�cz funkcj�

    ; x = 0
    xor     r9d, r9d           ; r9d = x = 0

col_loop:
    cmp     r9d, r12d          ; Por�wnuje x (r9d) z width (r12d)
    jg      next_row           ; Je�li x >= width, przejd� do nast�pnego wiersza

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
    ; Sprawd�, czy jeste�my na brzegu (x==0 || x==width-1 || y==0 || y==height-1).
    ; Je�li tak, to kopiujemy orygina�. W przeciwnym razie filtr gradientowy.
    ;------------------------------------------------------------------------------

    ; if (x == 0)
    cmp     r9d, 0             ; Por�wnuje x z 0
    je      copy_original       ; Je�li x == 0, przejd� do kopiowania orygina�u

    ; if (x == width-1)
    mov     eax, r12d          ; eax = width
    dec     eax                ; eax = width - 1
    cmp     r9d, eax           ; Por�wnuje x z width - 1
    je      copy_original       ; Je�li x == width - 1, przejd� do kopiowania orygina�u

    ; if (y == 0)
    cmp     r13d, 0            ; Por�wnuje y z 0
    je      copy_original       ; Je�li y == 0, przejd� do kopiowania orygina�u

    ; if (y == height-1)
    mov     ecx, r15d          ; ecx = imageHeight
    dec     ecx                ; ecx = imageHeight - 1
    cmp     r13d, ecx          ; Por�wnuje y z imageHeight - 1
    je      copy_original       ; Je�li y == height - 1, przejd� do kopiowania orygina�u

    ;------------------------------------------------------------------------------
    ; [1] Wykonaj filtr gradientowy 3x3 z mask�:
    ;     -1  -1   1
    ;     -1  -2   1
    ;      1   1   1
    ;
    ; Dla ka�dego z kana��w R, G, B liczymy osobno.
    ;------------------------------------------------------------------------------

    ; accR, accG, accB = 0
    xor     eax, eax           ; eax = 0
    push    rax                ; Zapisuje accR (0) na stos
    push    rax                ; Zapisuje accG (0) na stos
    push    rax                ; Zapisuje accB (0) na stos

    ;------------------------------------------------------------------------------
    ; compute_offset (funkcja inline) � obliczanie offsetu i akumulacja warto�ci RGB
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

    movzx eax, byte ptr [r10]  ; Pobiera warto�� R
    imul  eax, weight_         ; Mno�y przez wag�
    add   [rsp+16], eax        ; Dodaje do accR

    movzx eax, byte ptr [r10+1]; Pobiera warto�� G
    imul  eax, weight_         ; Mno�y przez wag�
    add   [rsp+8], eax         ; Dodaje do accG

    movzx eax, byte ptr [r10+2]; Pobiera warto�� B
    imul  eax, weight_         ; Mno�y przez wag�
    add   [rsp], eax           ; Dodaje do accB
ENDM

    ; (x-1, y-1) z wag� -1
    ComputeOffset -1, -1, -1

    ; (x, y-1) z wag� -1
    ComputeOffset 0, -1, -1

    ; (x+1, y-1) z wag� 1
    ComputeOffset 1, -1, 1

    ; (x-1, y) z wag� -1
    ComputeOffset -1, 0, -1

    ; (x, y) z wag� -2
    ComputeOffset 0, 0, -2

    ; (x+1, y) z wag� 1
    ComputeOffset 1, 0, 1

    ; (x-1, y+1) z wag� 1
    ComputeOffset -1, 1, 1

    ; (x, y+1) z wag� 1
    ComputeOffset 0, 1, 1

    ; (x+1, y+1) z wag� 1
    ComputeOffset 1, 1, 1

    ;------------------------------------------------------------------------------
    ; Kompresja warto�ci accR, accG, accB do zakresu [0..255] i zapis do outputData
    ;------------------------------------------------------------------------------

    mov     eax, [rsp+16]      ; Pobiera accR
    call    clamp0_255         ; Kompresuje do zakresu [0..255]
    mov     byte ptr [rsi], al ; Zapisuje warto�� R

    mov     eax, [rsp+8]       ; Pobiera accG
    call    clamp0_255         ; Kompresuje do zakresu [0..255]
    mov     byte ptr [rsi+1], al ; Zapisuje warto�� G

    mov     eax, [rsp]         ; Pobiera accB
    call    clamp0_255         ; Kompresuje do zakresu [0..255]
    mov     byte ptr [rsi+2], al ; Zapisuje warto�� B

    ; Posprz�taj 3 pushe (accR, accG, accB):
    add     rsp, 24            ; Usuwa warto�ci accR, accG, accB ze stosu

    jmp     done_pixel         ; Skok do zako�czenia przetwarzania piksela

;------------------------------------------------------------------------------
; Funkcja clamp0_255: Kompresja warto�ci do zakresu [0..255]
;------------------------------------------------------------------------------
clamp0_255:
    cmp     eax, 0             ; Sprawdza, czy warto�� jest poni�ej 0
    jl      clamp_to_zero      ; Je�li tak, ustaw na 0
    cmp     eax, 255           ; Sprawdza, czy warto�� jest powy�ej 255
    jg      clamp_to_255       ; Je�li tak, ustaw na 255
    ret                       ; W przeciwnym razie zwr�� warto��

clamp_to_zero:
    xor     eax, eax           ; Ustaw warto�� na 0
    ret

clamp_to_255:
    mov     eax, 255           ; Ustaw warto�� na 255
    ret

;------------------------------------------------------------------------------
; Kopiowanie oryginalnego piksela (je�li brzeg).
;------------------------------------------------------------------------------
copy_original:
    movzx   eax, byte ptr [rdi]     ; Pobiera warto�� R oryginalnego piksela
    mov     byte ptr [rsi], al      ; Kopiuje warto�� R
    movzx   eax, byte ptr [rdi+1]   ; Pobiera warto�� G oryginalnego piksela
    mov     byte ptr [rsi+1], al    ; Kopiuje warto�� G
    movzx   eax, byte ptr [rdi+2]   ; Pobiera warto�� B oryginalnego piksela
    mov     byte ptr [rsi+2], al    ; Kopiuje warto�� B

done_pixel:
    inc     r9d                 ; Zwi�ksza x (kolumna) o 1
    jmp     col_loop            ; Wraca do przetwarzania kolumn

next_row:
    inc     r13d                ; Zwi�ksza y (wiersz) o 1
    jmp     row_loop            ; Wraca do przetwarzania wierszy

invalid_output_buffer:
    jmp     end_function        ; Przej�cie do zako�czenia funkcji

; --- Epilog ---
end_function:
    pop     r15                 ; Przywraca warto�� rejestru R15
    pop     r14                 ; Przywraca warto�� rejestru R14
    pop     r13                 ; Przywraca warto�� rejestru R13
    pop     r12                 ; Przywraca warto�� rejestru R12
    pop     rdi                 ; Przywraca warto�� rejestru RDI
    pop     rsi                 ; Przywraca warto�� rejestru RSI
    pop     rbx                 ; Przywraca warto�� rejestru RBX
    pop     rbp                 ; Przywraca warto�� rejestru RBP
    ret                        ; Zako�czenie funkcji

alg ENDP

END
