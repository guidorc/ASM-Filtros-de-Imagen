;x4 bordes
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
    sub rdx, 2

.cicloFilas:
    mov r11, 1
    .cicloColumnas: 
    	mov r12, rdi
    	sub r12, r8							; r12 <- i-1

    	; conseguimos arriba izq y arriba der
        movdqu xmm0, [r12 - 4 ]             ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm1, xmm0                 ; xmm1: |a1|r1|g1|b1|a0|r0|g0|b0| (words)
        psrldq xmm0, 8
        pmovzxbw xmm2, xmm0                 ; xmm2: |a3|r3|g3|b3|a2|r2|g2|b2| (words)

        movdqu xmm0, [r12 + 4 ]             ; xmm3: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm4, xmm0                 ; xmm4: |a1|r1|g1|b1|a0|r0|g0|b0| (words)
        psrldq xmm0, 8
        pmovzxbw xmm5, xmm0                 ; xmm5: |a3|r3|g3|b3|a2|r2|g2|b2| (words)
            ; 1ros 2 pixeles
        psubw xmm1, xmm4
        pabsw xmm1, xmm1					; xmm1: |src[i-1][j-1] - src[i-1][j+1]| = A_1
            ; 2dos 2 pixeles
        psubw xmm2, xmm5
        pabsw xmm2, xmm2                    ; xmm2: |src[i-1][j-1] - src[i-1][j+1]| = A_2

        ; conseguimos costados
        movdqu xmm0, [rdi - 4]              ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm3, xmm0                 ; xmm3: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm4, xmm0                 ; xmm4: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)

        movdqu xmm0, [rdi + 4]              ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm5, xmm0                 ; xmm5: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm6, xmm0                 ; xmm6: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)
            ; 1ros 2 pixeles
        psubw xmm3, xmm5
        pabsw xmm3, xmm3                    ; xmm1: |src[i][j-1] - src[i][j+1]| = B_1
            ; 2dos 2 pixeles
        psubw xmm4, xmm6
        pabsw xmm4, xmm4                    ; xmm4: |src[i][j-1] - src[i][j+1]| = B_2
            ; Sumamos al total
        paddusw xmm1, xmm3 					; xmm1: | A_1 + B_1 | 
        paddusw xmm2, xmm4                  ; xmm2: | A_2 + B_2 | 

        ; conseguimos abajo izq y abajo der
        movdqu xmm0, [rdi + r8 - 4 ]        ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm3, xmm0                 ; xmm3: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm4, xmm0                 ; xmm4: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)

        movdqu xmm0, [rdi + r8 + 4 ]        ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm5, xmm0                 ; xmm5: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm6, xmm0                 ; xmm6: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)
            ; 1ros 2 pixeles
        psubw xmm3, xmm5
        pabsw xmm3, xmm3                    ; xmm3: |src[i+1][j-1] - src[i+1][j+1]| = C_1
            ; 2dos 2 pixeles
        psubw xmm4, xmm6
        pabsw xmm4, xmm4                    ; xmm4: |src[i+1][j-1] - src[i+1][j+1]| = C_2
            ; Sumamos al total
        paddusw xmm1, xmm3 					; xmm1: | A_1 + B_1 + C_1 |
        paddusw xmm2, xmm4                  ; xmm2: | A_2 + B_2 + C_2 |

        ; conseguimos arriba izq y abajo izq
        movdqu xmm0, [r12 - 4 ]             ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm3, xmm0                 ; xmm3: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm4, xmm0                 ; xmm4: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)

        movdqu xmm0, [rdi + r8 - 4 ]        ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm5, xmm0                 ; xmm5: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm6, xmm0                 ; xmm6: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)
            ; 1ros 2 pixeles
        psubw xmm3, xmm5
        pabsw xmm3, xmm3                    ; xmm3: |src[i-1][j-1] - src[i+1][j-1]| = D_1
            ; 2dos 2 pixeles
        psubw xmm4, xmm6
        pabsw xmm4, xmm4                    ; xmm4: |src[i-1][j-1] - src[i+1][j-1]| = D_2
            ; Sumamos al total
        paddusw xmm1, xmm3 					; xmm1: | A_1 + B_1 + C_1 + D_1 |
        paddusw xmm2, xmm4                  ; xmm2: | A_2 + B_2 + C_2 + D_2 |

        ; conseguimos arriba y abajo
        movdqu xmm0, [r12]                  ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm3, xmm0                 ; xmm3: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm4, xmm0                 ; xmm4: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)

        movdqu xmm0, [rdi + r8 ]
        pmovzxbw xmm5, xmm0
        psrldq xmm0, 8
        pmovzxbw xmm6, xmm0
            ; 1ros 2 pixeles
        psubw xmm3, xmm5
        pabsw xmm3, xmm3                    ; xmm3: |src[i-1][j] - src[i+1][j]| = E_1
            ; 2dos 2 pixeles
        psubw xmm4, xmm6
        pabsw xmm4, xmm4                    ; xmm4: |src[i-1][j] - src[i+1][j]| = E_2
            ; Sumamos al total
        paddusw xmm1, xmm3 					; xmm1: | A_1 + B_1 + C_1 + D_1 + E_1 |
        paddusw xmm2, xmm4                  ; xmm1: | A_2 + B_2 + C_2 + D_2 + E_2 |
 
        ; conseguimos arriba der y abajo der
        movdqu xmm0, [r12+ 4 ]              ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm3, xmm0                 ; xmm3: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm4, xmm0                 ; xmm4: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)

        movdqu xmm0, [rdi + r8 + 4 ]        ; xmm0: |a3|r3|g3|b3|a2|r2|g2|b2|a1|r1|g1|b1|a0|r0|g0|b0| (bytes)
        pmovzxbw xmm5, xmm0                 ; xmm5: |a1|r1|g1|b1|a0|r0|g0|b0| (Words)
        psrldq xmm0, 8
        pmovzxbw xmm6, xmm0                 ; xmm6: |a3|r3|g3|b3|a2|r2|g2|b2| (Words)
            ; 1ros 2 pixeles
        psubw xmm3, xmm5
        pabsw xmm3, xmm3                    ; xmm3: |src[i-1][j+1] - src[i+1][j+1]| = F_1
            ; 2dos 2 pixeles
        psubw xmm4, xmm6
        pabsw xmm4, xmm4                    ; xmm4: |src[i-1][j+1] - src[i+1][j+1]| = F_2
            ; Sumamos al total
        paddusw xmm1, xmm3 					; xmm1: | A_1 + B_1 + C_1 + D_1 + E_1 + F_1|
        paddusw xmm2, xmm4                  ; xmm2: | A_2 + B_2 + C_2 + D_2 + E_2 + F_2|

        ; empaquetamos el resultado
        packuswb xmm1, xmm1
        packuswb xmm2, xmm2
        ; aplicamos mascara transparencias
        por xmm1, xmm15
        por xmm2, xmm15
        ; movemos a memoria
        .gdb:
        movq [rsi], xmm1
        movq [rsi + 8], xmm2

        add rdi, 16          ; procesamos 4 pixeles
        add rsi, 16          ; procesamos 4 pixeles

 	add r11, 4           ; procesamos 4 pixeles en total
    mov rax, rdx
    sub rax, 2
    cmp r11, rax
    jle .cicloColumnas

    	; Ultimos 2 pixeles
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
        pmovzxbw xmm2, [rdi + r8 + 4 ]
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
        movq [rsi], xmm0

    add rdi, 16
    add rsi, 8
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


