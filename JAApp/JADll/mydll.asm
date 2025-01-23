PUBLIC alg            ; Udostêpnienie procedury 'alg' na zewn¹trz (widoczna w innych modu³ach)

.DATA
; Sta³e wykorzystywane przez maskê 3x3:
align 16
const_m1 REAL4 -1.0, -1.0, -1.0, -1.0  ; Sta³a wektorowa dla wartoœci -1 (u¿ywana przy filtrze 3x3)
const_m2 REAL4 -2.0, -2.0, -2.0, -2.0  ; Sta³a wektorowa dla wartoœci -2
const_p1 REAL4  1.0,  1.0,  1.0,  1.0  ; Sta³a wektorowa dla wartoœci  1

; Maska 3x3 (dla czytelnoœci):
;   -1  -1   1
;   -1  -2   1
;    1   1   1

.CODE

; ------------------------------------------------------------------------------
; alg(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight)
;
; Rejestry 64-bit:
;   RCX = pixelData      (wejœciowy bufor pikseli)
;   RDX = outputData     (bufor wyjœciowy)
;   R8  = width          (szerokoœæ obrazu)
;   R9  = startY         (pocz¹tek przedzia³u)
;   [rsp+104]   = endY
;   [rsp+112]   = imageHeight
; ------------------------------------------------------------------------------
alg PROC

    ; --- Prolog ---
    push    rbp             ; Zapisuje rejestr rbp na stosie (zachowanie wartoœci)
    push    rbx             ; Zapisuje rejestr rbx na stosie
    push    rsi             ; Zapisuje rejestr rsi na stosie
    push    rdi             ; Zapisuje rejestr rdi na stosie
    push    r12             ; Zapisuje rejestry ogólnego przeznaczenia (r12)
    push    r13
    push    r14
    push    r15

    ; Przepisujemy argumenty do "lokalnych" rejestrów
    mov     rbp, rcx           ; rbp = pixelData (wejœciowe dane pikseli)
    mov     rbx, rdx           ; rbx = outputData (bufor wyjœciowy)
    mov     r12d, r8d          ; r12d = width (szerokoœæ obrazu)
    mov     r13d, r9d          ; r13d = startY (pocz¹tek przedzia³u wierszy)

    mov     eax, [rsp + 104]   ; Wczytanie wartoœci endY do eax
    mov     r14d, eax          ; r14d = endY (koniec przedzia³u wierszy)

    mov     eax, [rsp + 112]   ; Wczytanie wartoœci imageHeight do eax
    mov     r15d, eax          ; r15d = imageHeight (wysokoœæ obrazu)

    ; Jeœli bufor wyjœciowy == 0, wyjdŸ z procedury
    test    rbx, rbx           ; Sprawdza, czy rbx jest zerowe
    jz      invalid_output_buffer  ; Jeœli tak, skocz do invalid_output_buffer

; ---------------------------------------------------------------------------------
; Pêtla: for (y = startY; y < endY; y++)
; ---------------------------------------------------------------------------------
row_loop:
    cmp     r13d, r14d         ; Porównanie aktualnego wiersza y z endY
    jg     end_function        ; Jeœli y > endY, wyjdŸ z procedury

    ; x = 0
    xor     r9d, r9d           ; Ustawienie x = 0 (r9d = 0)

col_loop:
    cmp     r9d, r12d          ; Porównanie x z width
    jg     next_row            ; Jeœli x >= width, przejdŸ do nastêpnego wiersza

    ;------------------------------------------------------------------------------
    ; Obliczenie offsetu: offset = ((y * width) + x) * 3
    ;------------------------------------------------------------------------------
    mov     eax, r13d          ; eax = y
    imul    eax, r12d          ; eax = y * width
    add     eax, r9d           ; eax = (y * width) + x
    imul    eax, 3             ; eax = ((y * width) + x) * 3

    lea     rsi, [rbx + rax]   ; rsi = &outputData[offset]
    lea     rdi, [rbp + rax]   ; rdi = &pixelData[offset]

    ;------------------------------------------------------------------------------
    ; SprawdŸ, czy jesteœmy na brzegu (x == 0 || x == width-1 || y == 0 || y == height-1).
    ; Jeœli tak, to kopiujemy orygina³. W przeciwnym razie stosujemy filtr gradientowy.
    ;------------------------------------------------------------------------------
    cmp     r9d, 0             ; Czy x == 0?
    je      copy_original      ; Jeœli tak, skocz do kopiowania orygina³u

    mov     eax, r12d          ; eax = width
    dec     eax                ; eax = width - 1
    cmp     r9d, eax           ; Czy x == width - 1?
    je      copy_original      ; Jeœli tak, skocz do kopiowania orygina³u

    cmp     r13d, 0            ; Czy y == 0?
    je      copy_original      ; Jeœli tak, skocz do kopiowania orygina³u

    mov     ecx, r15d          ; ecx = imageHeight
    dec     ecx                ; ecx = imageHeight - 1
    cmp     r13d, ecx          ; Czy y == imageHeight - 1?
    je      copy_original      ; Jeœli tak, skocz do kopiowania orygina³u

    ;------------------------------------------------------------------------------
    ; [1] Wykonaj filtr gradientowy 3x3 z mask¹:
    ;     -1  -1   1
    ;     -1  -2   1
    ;      1   1   1
    ;
    ; Dla ka¿dego piksela i kana³u R,G,B liczymy osobno – ale wektorowo w SSE.
    ;------------------------------------------------------------------------------

    ; W rejestrze xmm0 bêdziemy akumulowaæ sumê (w float) dla (R,G,B, X).
    ; Najpierw zerujemy akumulator.
    pxor    xmm0, xmm0         ; Ustawia xmm0 = [0, 0, 0, 0] w formacie float

    ; "Pomocniczy" rejestr do czyszczenia górnych bajtów przy rozpakowywaniu
    pxor    xmm2, xmm2         ; Ustawia xmm2 = [0, 0, 0, 0], u¿ywany w punpcklbw/punpcklwd

    ;------------------------------------------------------------------------------
    ; makro "ComputeOffsetSSE dx, dy, maskReg"
    ; Wylicza offset s¹siada i dodaje do xmm0 piksel * maska (dla filtracji 3x3).
    ;------------------------------------------------------------------------------

ComputeOffsetSSE MACRO dx_, dy_, maskLabel
    ; 1) Policz offset s¹siada:
    ; neighborX = x + dx_, neighborY = y + dy_
    mov   r10d, r9d
    add   r10d, dx_
    mov   r11d, r13d
    add   r11d, dy_

    ; offset = ((neighborY * width) + neighborX) * 3
    mov   eax, r11d
    imul  eax, r12d
    add   eax, r10d
    imul  eax, 3

    ; 2) Za³aduj 3 bajty (R,G,B) piksela do xmm1 (pobieramy 4 bajty, ostatni jest nadmiar¹)
    movd  xmm1, dword ptr [rbp + rax]

    ; 3) Rozpakuj wartoœci 8-bitowe do 16-bitowych, a potem do 32-bitowych
    punpcklbw xmm1, xmm2
    punpcklwd xmm1, xmm2

    ; 4) Konwersja int -> float (R,G,B) w dolnych trzech polach
    cvtdq2ps xmm1, xmm1

    ; 5) Mno¿enie przez sta³¹ (maskê filtra) i dodanie do akumulatora w xmm0
    mulps xmm1, xmmword ptr maskLabel
    addps xmm0, xmm1
ENDM

    ;------------------------------------------------------------------------------
    ; Dodajemy 9 s¹siadów z odpowiednimi wagami z maski 3x3.
    ;------------------------------------------------------------------------------
    ComputeOffsetSSE -1, -1, const_m1   ; (x-1, y-1) waga -1
    ComputeOffsetSSE  0, -1, const_m1   ; (x  , y-1) waga -1
    ComputeOffsetSSE  1, -1, const_p1   ; (x+1, y-1) waga  1

    ComputeOffsetSSE -1,  0, const_m1   ; (x-1, y  ) waga -1
    ComputeOffsetSSE  0,  0, const_m2   ; (x  , y  ) waga -2
    ComputeOffsetSSE  1,  0, const_p1   ; (x+1, y  ) waga  1

    ComputeOffsetSSE -1,  1, const_p1   ; (x-1, y+1) waga  1
    ComputeOffsetSSE  0,  1, const_p1   ; (x  , y+1) waga  1
    ComputeOffsetSSE  1,  1, const_p1   ; (x+1, y+1) waga  1

    ;------------------------------------------------------------------------------
    ; (2) kompresja wartoœci z xmm0 do zakresu [0..255]
    ;     - cvttps2dq => konwersja float->int z obciêciem
    ;     - packusdw  => saturacja 32->16 bit
    ;     - packuswb  => saturacja 16->8  bit
    ;------------------------------------------------------------------------------
    cvttps2dq xmm1, xmm0               ; float->int (R,G,B,X) z obciêciem
    packusdw  xmm1, xmm1               ; 32->16 bit z saturacj¹
    packuswb  xmm1, xmm1               ; 16->8  bit z saturacj¹

    ;------------------------------------------------------------------------------
    ; Zapis do bufora wyjœciowego (R, G, B w 3 najni¿szych bajtach)
    ;------------------------------------------------------------------------------
    movd    eax, xmm1                  ; W eax mamy [.. .. .. B  G  R] (LSB=R)
    mov     dword ptr [rsi], eax       ; Zapis 4 bajtów do outputData (ostatni bajt nieu¿ywany)

    jmp     done_pixel                 ; PrzejdŸ do zakoñczenia obs³ugi piksela

;------------------------------------------------------------------------------
; Kopiowanie oryginalnego piksela (jeœli brzeg).
;------------------------------------------------------------------------------
copy_original:
    movzx   eax, byte ptr [rdi]        ; Za³aduj wartoœæ R
    mov     byte ptr [rsi], al         ; Zapisz R do bufora wyjœciowego

    movzx   eax, byte ptr [rdi+1]      ; Za³aduj wartoœæ G
    mov     byte ptr [rsi+1], al       ; Zapisz G

    movzx   eax, byte ptr [rdi+2]      ; Za³aduj wartoœæ B
    mov     byte ptr [rsi+2], al       ; Zapisz B

done_pixel:
    inc     r9d                        ; Zwiêkszenie x o 1
    jmp     col_loop                   ; Powrót do pêtli kolumn

next_row:
    inc     r13d                       ; Zwiêkszenie y o 1
    jmp     row_loop                   ; Powrót do pêtli wierszy

invalid_output_buffer:
    ; nic nie robimy, po prostu koñczymy (bufor wyjœciowy niepoprawny)

; --- Epilog ---
end_function:
    pop     r15            ; Przywrócenie rejestrów w odwrotnej kolejnoœci
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    pop     rbp
    ret                    ; Zakoñczenie procedury

alg ENDP
END
