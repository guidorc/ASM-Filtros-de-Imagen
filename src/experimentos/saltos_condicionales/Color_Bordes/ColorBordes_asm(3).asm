global ColorBordes_asm

;void ColorBordes_asm (uint8_t *src, uint8_t *dst, int width, int height, int src_row_size, int dst_row_size);

; rdi <- &src
; rsi <- &dst
; rdx <- ancho
; rcx <- alto
; r8  <- src_row_size
; r9  <- dst_row_size
section .data

mascara : times 4 DD 0xFF000000

section .text

ColorBordes_asm:
    push rbp
    mov rbp , rsp
    push r12
    push r13
    push r14

    ; seteamos la mascara
    movdqu xmm15, [mascara] 

    ; creamos mascara bordes superior e inferior
    mov r14, rdx
    xor r10, r10
    xor r13, r13
    not r13 
    movq xmm0, r13
    pinsrq xmm0, r13, 1
    dec rcx
    mov rax, r8
    mul rcx
    mov rdx, r14

.cicloMargenes:
	movdqu [rsi], xmm0             ; seteamos borde superior
	movdqu [rsi + rax], xmm0       ; seteamos borde inferior

	add rsi, 16
	add r10, 4
	cmp r10, rdx
	jne .cicloMargenes
	mov dword [rsi], r13d
	add rsi, 4
    lea rdi, [rdi + r8 + 4]
    mov r10, 1 
    sub rdx, 2                      ; problema: solucion procesar de a 3 u 6 pixeles

.cicloFilas:
    mov r11, 1
    .cicloColumnas: 
    	mov r12, rdi
    	sub r12, r8							; r12 <- i-1

    	; conseguimos arriba izq y arriba der
        pmovzxbw xmm0, [r12 - 4 ]           ; xmm0: |a1|r1|g1|b1|a0|r0|g0|b0| (words)
        pmovzxbw xmm1, [r12 + 4 ]
        psubw xmm0, xmm1
        pabsw xmm0, xmm0					; xmm0: |src[i-1][j-1] - src[i-1][j+1]| = A

        ; conseguimos costados
        pmovzxbw xmm1, [rdi - 4]
        pmovzxbw xmm2, [rdi + 4]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1 					; xmm1: |src[i][j-1] - src[i][j+1]| = B
        paddusw xmm0, xmm1 					; xmm0: | A + B | 

        ; conseguimos abajo izq y abajo der
        pmovzxbw xmm1, [rdi + r8 - 4 ]
        pmovzxbw xmm2, [rdi + r8 + 4 ]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1 					; xmm2: |src[i+1][j-1] - src[i+1][j+1]| = C
        paddusw xmm0, xmm1 					; xmm0: | A + B + C |

        ; conseguimos arriba izq y abajo izq
        pmovzxbw xmm1, [r12 - 4 ]
        pmovzxbw xmm2, [rdi + r8 - 4 ]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1 					; xmm1: |src[i-1][j-1] - src[i+1][j-1]| = D
        paddusw xmm0, xmm1 					; xmm0: | A + B + C + D |

        ; conseguimos arriba y abajo
        pmovzxbw xmm1, [r12]
        pmovzxbw xmm2, [rdi + r8 ]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1 					; xmm1: |src[i-1][j] - src[i+1][j]| = E
        paddusw xmm0, xmm1 					; xmm0: | A + B + C + D + E |
 
        ; conseguimos arriba der y abajo der
        pmovzxbw xmm1, [r12+ 4 ]
        pmovzxbw xmm2, [rdi + r8 + 4 ]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1 					; xmm1: |src[i-1][j+1] - src[i+1][j+1]| = F
        paddusw xmm0, xmm1 					; xmm0: | A + B + C + D + E + F|

        ; empaquetamos el resultado
        packuswb xmm0, xmm0
        ; aplicamos mascara transparencias
        por xmm0, xmm15
        ; movemos a memoria
        movq [rsi], xmm0

        add rdi, 8			; procesamos 2 pixeles
        add rsi, 8			; procesamos 2 pixeles

        ; PROXIMO PIXEL

        add qword r12, 8

        ; conseguimos arriba izq y arriba der
        pmovzxbw xmm0, [r12 - 4 ]           ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2| (words)
        pmovzxbw xmm1, [r12 + 4 ]
        psubw xmm0, xmm1
        pabsw xmm0, xmm0                    ; xmm0: |src[i-1][j-1] - src[i-1][j+1]| = A

        ; conseguimos costados
        pmovzxbw xmm1, [rdi - 4]
        pmovzxbw xmm2, [rdi + 4]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1                    ; xmm1: |src[i][j-1] - src[i][j+1]| = B
        paddusw xmm0, xmm1                  ; xmm0: | A + B | 

        ; conseguimos abajo izq y abajo der
        pmovzxbw xmm1, [rdi + r8 - 4 ]
        pmovzxbw xmm2, [rdi + r8 + 4 ] ; PROBLEMA
        psubw xmm1, xmm2
        pabsw xmm1, xmm1                    ; xmm2: |src[i+1][j-1] - src[i+1][j+1]| = C
        paddusw xmm0, xmm1                  ; xmm0: | A + B + C |

        ; conseguimos arriba izq y abajo izq
        pmovzxbw xmm1, [r12 - 4 ]
        pmovzxbw xmm2, [rdi + r8 - 4 ]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1                    ; xmm1: |src[i-1][j-1] - src[i+1][j-1]| = D
        paddusw xmm0, xmm1                  ; xmm0: | A + B + C + D |

        ; conseguimos arriba y abajo
        pmovzxbw xmm1, [r12]
        pmovzxbw xmm2, [rdi + r8 ]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1                    ; xmm1: |src[i-1][j] - src[i+1][j]| = E
        paddusw xmm0, xmm1                  ; xmm0: | A + B + C + D + E |
 
        ; conseguimos arriba der y abajo der
        pmovzxbw xmm1, [r12 + 4 ]
        pmovzxbw xmm2, [rdi + r8 + 4 ]
        psubw xmm1, xmm2
        pabsw xmm1, xmm1                    ; xmm1: |src[i-1][j+1] - src[i+1][j+1]| = F
        paddusw xmm0, xmm1                  ; xmm0: | A + B + C + D + E + F|

        ; empaquetamos el resultado
        packuswb xmm0, xmm0
        ; aplicamos mascara transparencias
        por xmm0, xmm15
        ; movemos a memoria
        movd [rsi], xmm0

        add rdi, 4          ; procesamos 1 pixel
        add rsi, 4          ; procesamos 1 pixel

    add r11, 3              ; procesamos 3 pixeles en total
    cmp r11, rdx
    jle .cicloColumnas
    add rdi, 8
    mov qword [rsi], r13 			; seteamos borde blanco
    add rsi, 8

    add r10, 1
    cmp r10, rcx
    jne .cicloFilas

    pop r14
    pop r13
    pop r12
    pop rbp
ret
