PUBLIC alg

.DATA
    ; Sta³a bia³ego koloru - nie jest konieczna, ale mo¿e siê przydaæ
    const_white db 255, 255, 255

.CODE

; ---------------------------------------------------------------------------------
; void alg(IntPtr pixelData, IntPtr outputData, int width, int startY, int endY, int imageHeight)
; 
; Rejestry przy wywo³aniu (x64):
;   RCX = pixelData     (wejœciowy bufor pikseli, je¿eli potrzebny)
;   RDX = outputData    (bufor wyjœciowy)
;   R8  = width         (szerokoœæ)
;   R9  = startY        (pocz¹tek wierszy)
;   [rsp+32] = endY     (koniec wierszy)
;   [rsp+40] = imageHeight (wysokoœæ; w tym przyk³adzie mo¿e s³u¿yæ do walidacji)
; ---------------------------------------------------------------------------------

alg PROC
    ; --- Prolog (zapis rejestrów nieulotnych) ---
    push    rbp
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    ; --- Przypisz parametry do przyjaŸniejszych rejestrów/nazw ---
    ; RCX = pixelData -> w razie potrzeby, tu: rbp
    ; RDX = outputData -> rbx
    ; R8  = width      -> r12d
    ; R9  = startY     -> r13d
    ;
    ; Pi¹ty argument (endY)   -> [rsp+32]
    ; Szósty argument (height)-> [rsp+40]

    mov     rbp, rcx          ; pixelData
    mov     rbx, rdx          ; outputData
    mov     r12d, r8d         ; width
    mov     r13d, r9d         ; startY

    mov     eax, [rsp + 32]   ; endY
    mov     r14d, eax

    mov     eax, [rsp + 40]   ; imageHeight
    mov     r15d, eax         ; je¿eli potrzebne do walidacji, itp.

    ; Walidacja: jeœli outputData == 0, wyjdŸ
    test    rbx, rbx
    jz      invalid_output_buffer

    ; ---------------------------------------------------------------------------------
    ; PÊTLA PO WIERSZACH:  for (y = startY; y < endY; y++)
    ; ---------------------------------------------------------------------------------
row_loop:
    cmp     r13d, r14d
    jge     end_function  ; jeœli y >= endY -> koniec

    ; x = 0
    xor     r9d, r9d      ; r9d bêdzie licznikiem kolumn (x)

col_loop:
    cmp     r9d, r12d
    jge     next_row      ; jeœli x >= width -> kolejny wiersz

    ; offset = (y * width + x) * 3, bo RGB24 = 3 bajty na piksel
    mov     eax, r13d     ; eax = y
    imul    eax, r12d     ; eax = y * width
    add     eax, r9d      ; eax = y*width + x
    imul    eax, 3        ; eax = (y*width + x)*3 = offset w bajtach

    ; Ustawiamy bia³y kolor w buforze wyjœciowym
    ; rbx -> outputData
    lea     rsi, [rbx + rax] ; rsi = &outputData[offset]
    mov     byte ptr [rsi],   255
    mov     byte ptr [rsi+1], 255
    mov     byte ptr [rsi+2], 255

    ; x++
    inc     r9d
    jmp     col_loop

next_row:
    ; y++
    inc     r13d
    jmp     row_loop

invalid_output_buffer:
    ; Je¿eli bufor jest pusty, po prostu wyjdŸ.
    ; Mo¿esz wstawiæ tu obs³ugê b³êdu wedle uznania.
    jmp end_function

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
