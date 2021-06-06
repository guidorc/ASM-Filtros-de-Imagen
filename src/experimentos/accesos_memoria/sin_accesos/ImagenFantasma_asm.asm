; === filtro ImagenFantasma ==
; Instrumentacion: quitar instrucciones que interactuen con la memoria
; luego, 
;   costo accesos a memoria = tiempo(sin instrumentar) - tiempo(instrumentado)

section .data

extern ImagenFantasma_c
global ImagenFantasma_asm

coeficiente: DD 0.9, 0.9, 0.9, 0.9		; [coeficiente] : | 0.9 | 0.9 | 0.9 | 0.9 |
divisor: DD 8.0, 8.0, 8.0, 8.0
mascara: DD 0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000

; aridad: void ImagenFantasma_asm (uint8_t *src, uint8_t *dst, int width, int height,
;                      int src_row_size, int dst_row_size, int offsetx, int offsety);
; rdi <- &src
; rsi <- &dst
; rdx <- ancho
; rcx <- alto
; r8  <- src_tam_fila
; r9  <- dst_tam_fila
; rsp + 8 	<- offsetx
; rsp + 16  <- offsety

section .text

ImagenFantasma_asm:
	push rbp
	mov rbp, rsp
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15

		; preservamos rdx
	mov qword r11, rdx	
		; preservamos offsetx y offsety
	;mov qword r15, [rbp + 16]		; r15 <- offset x
	;mov qword r14, [rbp + 24]		; r14 <- offset y
		; seteamos indices y máscaras
	xor r12, r12					; r12 <- i (contador fila)
	xor r13, r13					; r13 <- j (contador columna)
	;movdqu xmm7, [mascara]
	;movups xmm8, [coeficiente]
	;movups xmm10, [divisor]
	
	.cicloFilas:
	cmp r12, rcx
	jae .fin
	.cicloColumnas:
		; Calculamos ii, jj
	mov qword rax, r12	; rax <- i
	shr rax, 1			; rax <- i/2
	add rax, r14		; rax <- i/2 + offsety
	mul r8				; rax <- (i/2 + offsety) * tam fila
	mov qword r10, rax	; r10 <- rax
	mov qword rax, r13	; rax <- j
	shr rax, 1			; rax <- j/2
	add rax, r15		; rax <- j/2 + offsetx
	shl rax, 2			; rax <- (j/2 + offsetx) * 4
	add r10, rax		; r11 <- ii + jj
		; conseguimos los datos para b
	;movdqu xmm0, [rdi + r10]				; xmm0: |t3|r3|g3|b3|t2|r2|g2|b2|t1|r1|g1|b1|t0|r0|g0|b0| (en Bytes)
		; reemplazamos las componentes T por G en cada Píxel
	;pinsrb xmm0, [rdi + r10 + 1], 3			; xmm0: |t3|r3|g3|b3|t2|r2|g2|b2|t1|r1|g1|b1|g0|r0|g0|b0|
	;pinsrb xmm0, [rdi + r10 + 5], 7			; xmm0: |t3|r3|g3|b3|t2|r2|g2|b2|g1|r1|g1|b1|g0|r0|g0|b0|
	;pinsrb xmm0, [rdi + r10 + 9], 11		; xmm0: |t3|r3|g3|b3|g2|r2|g2|b2|g1|r1|g1|b1|g0|r0|g0|b0|
	;pinsrb xmm0, [rdi + r10 + 13], 15		; xmm0: |g3|r3|g3|b3|g2|r2|g2|b2|g1|r1|g1|b1|g0|r0|g0|b0|
	pmovzxbw xmm1, xmm0						; xmm1: |g1|r1|g1|b1|g0|r0|g0|b0| (en Words)
	psrldq xmm0, 8							; xmm0: |  0 |  0 |pixel3|pixel2|
	pmovzxbw xmm2, xmm0						; xmm2: |g3|r3|g3|b3|g2|r2|g2|b2| (en Words)
		; calculamos b
	phaddsw xmm1, xmm2					; xmm1: |g3+r3|g3+b3| .. |g0+r0|g0+b0|
	phaddsw xmm1, xmm1					; xmm1: | .. |r3+2*g3+b3| .. |r0+2*g0+b0| (Words)
	pxor xmm6, xmm6
	punpcklwd xmm1, xmm6
	cvtdq2ps xmm1, xmm1
	divps xmm1, xmm10					; xmm1: |b3/2|b2/2|b1/2|b0/2| (singles)
		; Conseguimos los datos para la nueva matriz
	mov qword rax, r12					; rax <- i
	mul r8								; rax <- i * tam fila
	mov qword r10, rax					; r10 <- rax
	mov qword rax, r13					; rax <- j
	shl rax, 2							; rax <- j * 4
	add rax, r10						; rax <- i * tam fila + j * 4
	;movdqu xmm12, [rdi + rax]			; xmm12:|t3|r3|g3|b3|t2|r2|g2|b2|t1|r1|g1|b1|t0|r0|g0|b0| (Bytes)
		; 1er Pixel
	pmovzxbd xmm3, xmm12				; xmm3:	|T0|R0|G0|B0| (dwords)
	cvtdq2ps xmm3, xmm3					; xmm3: |T0|R0|G0|B0| (singles)
	mulps xmm3, xmm8					; xmm3: |T0*0.9|R0*0.9|G0*0.9|B0*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm11, 0x00 			; xmm11:|b0/2|b0/2|b0/2|b0/2|
	addps xmm3, xmm11					; xmm3: |T0*0.9+b0/2|R0*0.9+b0/2|G0*0.9+b0/2|B0*0.9+b0/2|
	cvtps2dq xmm3, xmm3					; xmm3 : Pixel 1
		; 2do Pixel
	psrldq xmm12, 4						; xmm12:|00|00|00|00|t3|r3|g3|b3|t2|r2|g2|b2|t1|r1|g1|b1| (Bytes)
	pmovzxbd xmm4, xmm12				; xmm4: |T1|R1|G1|B1| (dword)
	cvtdq2ps xmm4, xmm4					; xmm4: |T1|R1|G1|B1| (singles)
	mulps xmm4, xmm8					; xmm4: |T1*0.9|R1*0.9|G1*0.9|B1*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm1, 0x00 			; xmm11:|b1/2|b1/2|b1/2|b1/2|
	addps xmm4, xmm11					; sumamos b1/2
	cvtps2dq xmm4, xmm4					; xmm4: Pixel 2
	packusdw xmm3, xmm4					; xmm3: |T1*0.9|R1*0.9|G1*0.9|B1*0.9|T0*0.9|R0*0.9|G0*0.9|B0*0.9| (Words)
		; 3er Pixel
	psrldq xmm12, 4						; xmm12:|00|00|00|00|00|00|00|00|t3|r3|g3|b3|t2|r2|g2|b2| (Bytes)
	pmovzxbd xmm4, xmm12				; xmm4:	|T2|R2|G2|B2| (dwords)
	cvtdq2ps xmm4, xmm4					; xmm4: |T2|R2|G2|B2| (singles)
	mulps xmm4, xmm8					; xmm4: |T2*0.9|R2*0.9|G2*0.9|B2*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm1, 0x55 			; xmm11:|b2/2|b2/2|b2/2|b2/2|
	addps xmm4, xmm11					; sumamos b2/2
	cvtps2dq xmm4, xmm4					; xmm4: pixel 3
		; 4to Pixel
	psrldq xmm12, 4						; xmm12:|00|00|00|00|00|00|00|00|00|00|00|00|t3|r3|g3|b3| (Bytes)
	pmovzxbd xmm5, xmm12				; xmm5: |T3|R3|G3|B3| (dword)
	cvtdq2ps xmm5, xmm5					; xmm5: |T3|R3|G3|B3| (singles)
	mulps xmm5, xmm8					; xmm5: |T3*0.9|R3*0.9|G3*0.9|B3*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm1, 0x55 			; xmm11:|b3/2|b3/2|b3/2|b3/2|
	addps xmm5, xmm11					; sumamos b3/2
	cvtps2dq xmm5, xmm5					; xmm5: pixel 4
	packusdw xmm4, xmm5					; xmm4: |T3*0.9|R3*0.9|G3*0.9|B3*0.9|T2*0.9|R2*0.9|G2*0.9|B2*0.9| (Words)
		; empaquetamos
	packuswb xmm3, xmm4		; xmm3 = 4 píxeles resultado
		; seteamos transparencias en 255
	por xmm3, xmm7
		; movemos a memoria
	;movdqu [rsi + rax], xmm3

	;movdqu xmm12, [rdi + rax + 16]		; xmm12:|t7|r7|g7|b7|t6|r6|g6|b6|t5|r5|g5|b5|t4|r4|g4|b4| (Bytes)
		; 5to Pixel
	pmovzxbd xmm3, xmm12				; xmm3:	|T4|R4|G4|B4| (dwords)
	cvtdq2ps xmm3, xmm3					; xmm3: |T4|R4|G4|B4| (singles)
	mulps xmm3, xmm8					; xmm3: |T4*0.9|R4*0.9|G4*0.9|B4*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm11, 0xAA 			; xmm11:|b0/2|b0/2|b0/2|b0/2|
	addps xmm3, xmm11					; xmm3: |T4*0.9+b0/2|R4*0.9+b0/2|G4*0.9+b4/2|B4*0.9+b0/2|
	cvtps2dq xmm3, xmm3					; xmm3 : Pixel 5
		; 6to Pixel
	psrldq xmm12, 4						; xmm12:|00|00|00|00|t7|r7|g7|b7|t6|r6|g6|b6|t5|r5|g5|b5| (Bytes)
	pmovzxbd xmm4, xmm12				; xmm4: |T5|R5|G5|B5| (dword)
	cvtdq2ps xmm4, xmm4					; xmm4: |T5|R5|G5|B5| (singles)
	mulps xmm4, xmm8					; xmm4: |T5*0.9|R5*0.9|G5*0.9|B5*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm1, 0xAA 			; xmm11:|b1/2|b1/2|b1/2|b1/2|
	addps xmm4, xmm11
	cvtps2dq xmm4, xmm4					; xmm4: Pixel 6
	packusdw xmm3, xmm4					; xmm3: |T1*0.9|R1*0.9|G1*0.9|B1*0.9|T0*0.9|R0*0.9|G0*0.9|B0*0.9| (Words)
		; 7mo Pixel
	psrldq xmm12, 4						; xmm12:|00|00|00|00|00|00|00|00|t7|r7|g7|b7|t6|r6|g6|b6| (Bytes)	
	pmovzxbd xmm4, xmm12				; xmm4:	|T6|R6|G6|B6| (dwords)
	cvtdq2ps xmm4, xmm4					; xmm4: |T6|R6|G6|B6| (singles)
	mulps xmm4, xmm8					; xmm4: |T6*0.9|R6*0.9|G6*0.9|B6*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm1, 0xFF 			; xmm11:|b2/2|b2/2|b2/2|b2/2|
	addps xmm4, xmm11
	cvtps2dq xmm4, xmm4					; xmm4: pixel 7
		; 8vo Pixel
	psrldq xmm12, 4						; xmm12:|00|00|00|00|00|00|00|00|00|00|00|00|t7|r7|g7|b7| (Bytes)
	pmovzxbd xmm5, xmm12				; xmm5: |T7|R7|G7|B7| (dword)
	cvtdq2ps xmm5, xmm5					; xmm5: |T7|R7|G7|B7| (singles)
	mulps xmm5, xmm8					; xmm5: |T7*0.9|R7*0.9|G7*0.9|B7*0.9|
	movups xmm11, xmm1
	shufps xmm11, xmm1, 0xFF 			; xmm11:|b3/2|b3/2|b3/2|b3/2|
	addps xmm5, xmm11					
	cvtps2dq xmm5, xmm5					; xmm5: pixel 8
	packusdw xmm4, xmm5					; xmm4: |T3*0.9|R3*0.9|G3*0.9|B3*0.9|T2*0.9|R2*0.9|G2*0.9|B2*0.9| (Words)
		; empaquetado
	packuswb xmm3, xmm4		; xmm3 = 4 píxeles resultado
		; seteamos transparencias en 255
	por xmm3, xmm7
		; movemos a memoria
	;movdqu [rsi + rax + 16], xmm3
		; proximo ciclo
	add qword r13, 8	; levantamos de a 8 posiciones (pixeles)
	cmp r13, r11
	jnz .cicloColumnas
		; Proxima fila
	inc r12
	xor r13, r13
	jmp .cicloFilas

	.fin:

	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop rbp
	ret
