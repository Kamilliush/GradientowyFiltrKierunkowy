PUBLIC alg

.DATA
; Sta³e wykorzystywane przez maskê 3x3:
align 16
const_m1 REAL4 -1.0, -1.0, -1.0, -1.0
const_m2 REAL4 -2.0, -2.0, -2.0, -2.0
const_p1 REAL4  1.0,  1.0,  1.0,  1.0

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
;   R8  = width          (szerokoœæ)
;   R9  = startY         (pocz¹tek)
;   [rsp+104]   = endY
;   [rsp+112]   = imageHeight
; ------------------------------------------------------------------------------
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
    mov     rbp, rcx           ; rbp = pixelData (wejœciowe dane pikseli)
    mov     rbx, rdx           ; rbx = outputData (bufor wyjœciowy)
    mov     r12d, r8d          ; r12d = width (szerokoœæ obrazu)
    mov     r13d, r9d          ; r13d = startY (pocz¹tek)

    mov     eax, [rsp + 104]   ; eax = endY
    mov     r14d, eax          ; r14d = endY

    mov     eax, [rsp + 112]   ; eax = imageHeight
    mov     r15d, eax          ; r15d = imageHeight

    ; Jeœli bufor wyjœciowy == 0, wyjdŸ
    test    rbx, rbx
    jz      invalid_output_buffer

; ---------------------------------------------------------------------------------
; Pêtla: for (y = startY; y < endY; y++)
; ---------------------------------------------------------------------------------
row_loop:
    cmp     r13d, r14d
    jg     end_function       ; jeœli y >= endY, zakoñcz

    ; x = 0
    xor     r9d, r9d           ; r9d = x = 0

col_loop:
    cmp     r9d, r12d
    jg     next_row           ; jeœli x >= width => przejœcie do kolejnego wiersza

    ;------------------------------------------------------------------------------
    ; Obliczenie offsetu: offset = ((y * width) + x) * 3
    ;------------------------------------------------------------------------------
    mov     eax, r13d
    imul    eax, r12d
    add     eax, r9d
    imul    eax, 3

    lea     rsi, [rbx + rax]   ; rsi = &outputData[offset]
    lea     rdi, [rbp + rax]   ; rdi = &pixelData[offset]

    ;------------------------------------------------------------------------------
    ; SprawdŸ, czy jesteœmy na brzegu (x==0 || x==width-1 || y==0 || y==height-1).
    ; Jeœli tak, to kopiujemy orygina³. W przeciwnym razie filtr gradientowy.
    ;------------------------------------------------------------------------------
    cmp     r9d, 0
    je      copy_original

    mov     eax, r12d
    dec     eax
    cmp     r9d, eax
    je      copy_original

    cmp     r13d, 0
    je      copy_original

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
    ; Dla ka¿dego piksela i kana³u R,G,B liczymy osobno – ale wektorowo w SSE.
    ;------------------------------------------------------------------------------
    ; W rejestrze xmm0 bêdziemy akumulowaæ sumê (w float) dla (R,G,B, X)
    ; Najpierw zerujemy akumulator.
    ;------------------------------------------------------------------------------
    pxor    xmm0, xmm0         ; [0, 0, 0, 0] w formacie float

    ; "pomocniczy" rejestr do czyszczenia górnych bajtów przy rozpakowywaniu
    pxor    xmm2, xmm2         ; u¿ywany w punpcklbw/punpcklwd

    ;------------------------------------------------------------------------------
    ; makro "ComputeOffsetSSE dx, dy, maskReg"
    ; Wylicza offset s¹siada i dodaje do xmm0 piksel * maskê
    ; (podobnie jak w Darken, ale w wersji bez pêtli, bo tu maska 3×3 jest ma³a)
    ;------------------------------------------------------------------------------

ComputeOffsetSSE MACRO dx_, dy_, maskLabel
    ; 1) Policz offset s¹siada
    ; neighborX = x + dx_
    ; neighborY = y + dy_
    mov   r10d, r9d
    add   r10d, dx_
    mov   r11d, r13d
    add   r11d, dy_

    ; offset = ((neighborY * width) + neighborX) * 3
    mov   eax, r11d
    imul  eax, r12d
    add   eax, r10d
    imul  eax, 3

    ; 2) Za³aduj 3 bajty (R,G,B) piksela do xmm1
    movd  xmm1, dword ptr [rbp + rax]   ; pobieramy 4 bajty, ale 4. jest "nadmiarowy"

    ; 3) Rozpakuj 8-bit ? 16-bit ? 32-bit
    punpcklbw xmm1, xmm2               ; 8-bit  ? 16-bit
    punpcklwd xmm1, xmm2               ; 16-bit ? 32-bit

    ; 4) Konwersja int ? float (R,G,B) w dolnych 3 polach
    cvtdq2ps xmm1, xmm1

    ; 5) Mno¿enie przez sta³¹ (masê filtra) i dodanie do akumulatora
    mulps xmm1, xmmword ptr maskLabel
    addps xmm0, xmm1
ENDM

    ;------------------------------------------------------------------------------
    ; dodajemy 9 s¹siadów z wagami
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
    ;     - cvttps2dq => obciêcie do int
    ;     - packusdw  => saturacja do 16-bit
    ;     - packuswb  => saturacja do 8-bit
    ;------------------------------------------------------------------------------
    cvttps2dq xmm1, xmm0               ; float->int (R,G,B,X)
    packusdw  xmm1, xmm1               ; 32->16 bit z saturacj¹
    packuswb  xmm1, xmm1               ; 16->8  bit z saturacj¹

    ;------------------------------------------------------------------------------
    ; Zapis do bufora wyjœciowego (R, G, B w 3 najni¿szych bajtach)
    ;------------------------------------------------------------------------------
    movd    eax, xmm1                  ; w EAX mamy [.. .. .. B  G  R] (LSB=R)
    mov     dword ptr [rsi], eax       ; zapisujemy 4 bajty (ostatni jest nadmiarowy)

    jmp     done_pixel

;------------------------------------------------------------------------------
; Kopiowanie oryginalnego piksela (jeœli brzeg).
;------------------------------------------------------------------------------
copy_original:
    movzx   eax, byte ptr [rdi]        ; R
    mov     byte ptr [rsi], al

    movzx   eax, byte ptr [rdi+1]      ; G
    mov     byte ptr [rsi+1], al

    movzx   eax, byte ptr [rdi+2]      ; B
    mov     byte ptr [rsi+2], al

done_pixel:
    inc     r9d
    jmp     col_loop

next_row:
    inc     r13d
    jmp     row_loop

invalid_output_buffer:
    ; nic nie robimy, po prostu koñczymy

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
