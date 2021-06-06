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
	push r12
	push r13
	push r14
	push r15

		; preservamos rdx
	mov qword r11, rdx	
		; preservamos offsetx y offsety
	mov qword r15, [rbp + 16]		; r15 <- offset x
	mov qword r14, [rbp + 24]		; r14 <- offset y
		; seteamos indices y máscaras
	xor r12, r12					; r12 <- i (contador fila)
	xor r13, r13					; r13 <- j (contador columna)
	movdqu xmm7, [mascara]
	movups xmm8, [coeficiente]
	movups xmm10, [divisor]
	
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
	pmovzxbd xmm0, [rdi + r10]			; xmm0: |t0|r0|g0|b0| (Dwords)
	movdqu xmm1, xmm0
	pslldq xmm1, 8						; xmm1: |g0|b0|00|00|
	pblendw xmm0, xmm1, 0xC0			; xmm0: |g0|r0|g0|b0| (Dwords)
		; calculamos b
	phaddd xmm0, xmm0					; xmm0: |	....	|g0+r0|g0+b0| (dwords)
	phaddd xmm0, xmm0					; xmm0: |	....	| r0+2*g0+b0| (dwords)
	cvtdq2ps xmm0, xmm0
	divps xmm0, xmm10					; xmm0: |	....	       |b0/2| (single)
		; Conseguimos los datos para la nueva matriz
	mov qword rax, r12					; rax <- i
	mul r8								; rax <- i * tam fila
	mov qword r10, rax					; r10 <- rax
	mov qword rax, r13					; rax <- j
	shl rax, 2							; rax <- j * 4
	add rax, r10						; rax <- i * tam fila + j * 4
	pmovzxbw xmm12, [rdi + rax]			; xmm12:|t1|r1|g1|b1|t0|r0|g0|b0| (Words)
		; 1er Pixel
	pmovzxwd xmm3, xmm12				; xmm3:	|T0|R0|G0|B0| (dwords)
	cvtdq2ps xmm3, xmm3					; xmm3: |T0|R0|G0|B0| (singles)
	mulps xmm3, xmm8					; xmm3: |T0*0.9|R0*0.9|G0*0.9|B0*0.9|
	movups xmm11, xmm0
	shufps xmm11, xmm11, 0x00 			; xmm11:|b0/2|b0/2|b0/2|b0/2|
	addps xmm3, xmm11					; xmm3: |T0*0.9+b0/2|R0*0.9+b0/2|G0*0.9+b0/2|B0*0.9+b0/2|
	cvtps2dq xmm3, xmm3					; xmm3 : Pixel 1
		; 2do Pixel
	psrldq xmm12, 8						; xmm12:|00|00|00|00|t1|r1|g1|b1| (Words)
	pmovzxwd xmm4, xmm12				; xmm4: |T1|R1|G1|B1| (dword)
	cvtdq2ps xmm4, xmm4					; xmm4: |T1|R1|G1|B1| (singles)
	mulps xmm4, xmm8					; xmm4: |T1*0.9|R1*0.9|G1*0.9|B1*0.9|
	;movups xmm11, xmm0
	;shufps xmm11, xmm1, 0x00 			; xmm11:|b0/2|b0/2|b0/2|b0/2|
	addps xmm4, xmm11					; sumamos b0/2
	cvtps2dq xmm4, xmm4					; xmm4: Pixel 2
	packusdw xmm3, xmm4					; xmm3: |T1*0.9|R1*0.9|G1*0.9|B1*0.9|T0*0.9|R0*0.9|G0*0.9|B0*0.9| (Words)
		; empaquetamos
	packuswb xmm3, xmm3					; xmm3 = 2 píxeles resultado
		; seteamos transparencias en 255
	por xmm3, xmm7
		; movemos a memoria
	movq [rsi + rax], xmm3

		; proximo ciclo
	add qword r13, 2					; levantamos de a 2 posiciones (pixeles)
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
	pop rbp
	ret
