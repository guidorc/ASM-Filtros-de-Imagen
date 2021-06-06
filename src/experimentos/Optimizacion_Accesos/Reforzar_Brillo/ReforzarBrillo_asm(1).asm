extern ReforzarBrillo_c
global ReforzarBrillo_asm

section .data

mascara: times 2 DQ 0xFFFF000000000000
mascarabytes: times 4 DD 0xFF000000

section .text
ReforzarBrillo_asm:
; armado stack frame
	push rbp
	mov rbp, rsp

; void ReforzarBrillo_asm (uint8_t *src, uint8_t *dst, int width, int height,
;                      int src_row_size, int dst_row_size, int umbralSup, int umbralInf, int brilloSup, int brilloInf);
;	rdi: 		ptr_src
;	rsi: 		ptr_dst
;	edx: 		ancho
; 	ecx: 		alto
;	r8d:	 	src_row_size
;	r9d:  		dst_row_size
;	[rbp+8]: 	umbralSup
;	[rbp+16]:	umbralInf
; 	[rbp+24]:	brilloSup
;	[rbp+32]:	brilloInf
	
	%define ptr_src rdi
	%define ptr_dst rsi
	%define ancho edx
	%define alto ecx

	%define maskTrans xmm15 
	movdqu xmm15, [mascara]
	movdqu xmm10, [mascarabytes]
	;mov qword r10, 0xFF000000
	;pxor xmm0, xmm0		
	;movq xmm0, r10					; xmm0: |...|r10|
	;movdqu xmm1, xmm0
	;pslldq xmm1, 8					; xmm1: |r10|000|
	;por xmm0, xmm1 					; xmm0: |r10|r10|
	;movdqu maskTrans, xmm0
	; maskTrans: ff000000ff000000ff000000ff000000

	%define umbralSup xmm14
	pxor xmm14, xmm14
	movd umbralSup, [rbp+16]		; xmm14: |00|00|00|US|
	pmovzxdq xmm0, umbralSup		; xmm0:  |00|US|
    movdqu umbralSup, xmm0
    pslldq xmm0, 8					; xmm0:  |US|00|
    por umbralSup, xmm0 			; xmm14: |US|US|

	%define umbralInf xmm13
	pxor xmm13, xmm13
	movd umbralInf, [rbp+24]		; xmm13: |00|00|00|UI|
	pmovzxdq xmm0, umbralInf		; xmm0:  |00|UI|
    movdqu umbralInf, xmm0
    pslldq xmm0, 8					; xmm0:  |UI|00|
    por umbralInf, xmm0 			; xmm13: |UI|UI|

	%define addSup xmm12
	movd addSup, [rbp+32]	; xmm12: |00|00|00|AD| (Dword)
	packusdw addSup, addSup ; xmm0:  |00|00|00|00|00|00|00|AD| (Words)
	movdqu xmm0, addSup	
	pslldq xmm0, 2			; xmm0:  |00|00|00|00|00|00|AD|00| (Words)
	por addSup, xmm0		; xmm12: |00|00|00|00|00|00|AD|AD|
	movdqu xmm0, addSup
	pslldq xmm0, 4			; xmm0:  |00|00|00|00|AD|AD|00|00|
	por addSup, xmm0		; xmm12: |00|00|00|00|AD|AD|AD|AD|
	movdqu xmm0, addSup
	pslldq xmm0, 8			; xmm0:  |AD|AD|AD|AD|00|00|00|00|
	por addSup, xmm0 		; xmm12: |AD|AD|AD|AD|AD|AD|AD|AD|

	%define subInf xmm11
	movd subInf, [rbp+40]	; xmm11: |00|00|00|SU| (Dword)
	packusdw subInf, subInf ; xmm0:  |00|00|00|00|00|00|00|SU| (Words)
	movdqu xmm0, subInf	
	pslldq xmm0, 2			; xmm0:  |00|00|00|00|00|00|SU|00| (Words)
	por subInf, xmm0		; xmm11: |00|00|00|00|00|00|SU|SU|
	movdqu xmm0, subInf
	pslldq xmm0, 4			; xmm0:  |00|00|00|00|SU|SU|00|00|
	por subInf, xmm0 		; xmm11: |00|00|00|00|SU|SU|SU|SU|
	movdqu xmm0, subInf
	pslldq xmm0, 8			; xmm0:  |SU|SU|SU|SU|00|00|00|00|
	por subInf, xmm0 		; xmm11: |SU|SU|SU|SU|SU|SU|SU|SU|

	;|argb|

	.cicloFilas:

		mov r11d, ancho

		.cicloColumnas:
		; leer 1 pixel
			pmovzxbw xmm0, [ptr_src]			; xmm0: |a0|r0|g0|b0| (words)
		; calcular los b 
			; anular transparencia
			movdqu xmm1, maskTrans
			pandn xmm1, xmm0
			movdqu xmm0, xmm1
			; 2*g
			mov r10, 00000000ffff0000h
			movq xmm5, r10
			pinsrq xmm5, r10, 1
			; xmm5: 00000000ffff000000000000ffff0000h
			; mitad baja
			movdqu xmm1, xmm0
			movdqu xmm3, xmm0
			pand xmm3, xmm5
			paddw xmm1, xmm3 ; sumar bytes extendidos a word no desborda
			; xmm1: |r1+2*g1+b1|r0+2*g0+b0|
			; juntar mitades mediante suma horizontal
			phaddw xmm1, xmm1
			phaddw xmm1, xmm1
			;movdqu xmm2, xmm1
			; /4
			psrlw xmm1, 2
			; extender los b a dw (los umbrales son int)

			pmovzxwd xmm1, xmm1
			pmovzxdq xmm1, xmm1
			; -> xmm1: | b1 | b0 |
		; comparar los b con  los umbrales
			; cmp umbral superior
			movdqu xmm3, xmm1
			;pmaxud xmm3, umbralSup
			pcmpgtq xmm3, umbralSup
			;pcmpeqd xmm3, xmm2 ; xmm3: mascara superior
			; cmp umbral inferior
			movdqu xmm4, umbralInf
			pcmpgtq xmm4, xmm1
			;pminud xmm4, umbralInf
			;pcmpeqd xmm4, xmm2 ; xmm4: mascara inferior
			
		; incrementar brillo (solo pixeles que superan)
			movdqu xmm2, addSup
			pand xmm2, xmm3 			; NO SUMA COMPONENTE R
			paddusw xmm0, xmm2
		; decrementar brillo (solo pixeles por debajo)
			movdqu xmm2, subInf
			pand xmm2, xmm4
			psubusw xmm0, xmm2
		; restaurar transparencia
			;por xmm0, maskTrans

		; escribir dst
			;pxor xmm1, xmm1
			packuswb xmm0, xmm0
			por xmm0, xmm10
			;por xmm0, maskTrans
			movq [ptr_dst], xmm0

		; avanzar punteros
			add ptr_src, 4		; procesamos de a 1 pixel
			add ptr_dst, 4		; procesamos de a 1 pixel

		dec r11

		; leer 1 pixel
			pmovzxbw xmm0, [ptr_src]			; xmm0: |a0|r0|g0|b0| (words)
		; calcular los b 
			; anular transparencia
			movdqu xmm1, maskTrans
			pandn xmm1, xmm0
			movdqu xmm0, xmm1
			; 2*g
			mov r10, 00000000ffff0000h
			movq xmm5, r10
			pinsrq xmm5, r10, 1
			; xmm5: 00000000ffff000000000000ffff0000h
			; mitad baja
			movdqu xmm1, xmm0
			movdqu xmm3, xmm0
			pand xmm3, xmm5
			paddw xmm1, xmm3 ; sumar bytes extendidos a word no desborda
			; xmm1: |r1+2*g1+b1|r0+2*g0+b0|
			; juntar mitades mediante suma horizontal
			phaddw xmm1, xmm1
			phaddw xmm1, xmm1
			;movdqu xmm2, xmm1
			; /4
			psrlw xmm1, 2
			; extender los b a dw (los umbrales son int)

			pmovzxwd xmm1, xmm1
			pmovzxdq xmm1, xmm1
			; -> xmm1: | b1 | b0 |
		; comparar los b con  los umbrales
			; cmp umbral superior
			movdqu xmm3, xmm1
			;pmaxud xmm3, umbralSup
			pcmpgtq xmm3, umbralSup
			;pcmpeqd xmm3, xmm2 ; xmm3: mascara superior
			; cmp umbral inferior
			movdqu xmm4, umbralInf
			pcmpgtq xmm4, xmm1
			;pminud xmm4, umbralInf
			;pcmpeqd xmm4, xmm2 ; xmm4: mascara inferior
			
		; incrementar brillo (solo pixeles que superan)
			movdqu xmm2, addSup
			pand xmm2, xmm3 			; NO SUMA COMPONENTE R
			paddusw xmm0, xmm2
		; decrementar brillo (solo pixeles por debajo)
			movdqu xmm2, subInf
			pand xmm2, xmm4
			psubusw xmm0, xmm2
		; restaurar transparencia
			;por xmm0, maskTrans

		; escribir dst
			;pxor xmm1, xmm1
			packuswb xmm0, xmm0
			por xmm0, xmm10
			;por xmm0, maskTrans
			movq [ptr_dst], xmm0

		; avanzar punteros
			add ptr_src, 4		; procesamos de a 1 pixel
			add ptr_dst, 4		; procesamos de a 1 pixel

		dec r11

		; leer 1 pixel
			pmovzxbw xmm0, [ptr_src]			; xmm0: |a0|r0|g0|b0| (words)
		; calcular los b 
			; anular transparencia
			movdqu xmm1, maskTrans
			pandn xmm1, xmm0
			movdqu xmm0, xmm1
			; 2*g
			mov r10, 00000000ffff0000h
			movq xmm5, r10
			pinsrq xmm5, r10, 1
			; xmm5: 00000000ffff000000000000ffff0000h
			; mitad baja
			movdqu xmm1, xmm0
			movdqu xmm3, xmm0
			pand xmm3, xmm5
			paddw xmm1, xmm3 ; sumar bytes extendidos a word no desborda
			; xmm1: |r1+2*g1+b1|r0+2*g0+b0|
			; juntar mitades mediante suma horizontal
			phaddw xmm1, xmm1
			phaddw xmm1, xmm1
			;movdqu xmm2, xmm1
			; /4
			psrlw xmm1, 2
			; extender los b a dw (los umbrales son int)

			pmovzxwd xmm1, xmm1
			pmovzxdq xmm1, xmm1
			; -> xmm1: | b1 | b0 |
		; comparar los b con  los umbrales
			; cmp umbral superior
			movdqu xmm3, xmm1
			;pmaxud xmm3, umbralSup
			pcmpgtq xmm3, umbralSup
			;pcmpeqd xmm3, xmm2 ; xmm3: mascara superior
			; cmp umbral inferior
			movdqu xmm4, umbralInf
			pcmpgtq xmm4, xmm1
			;pminud xmm4, umbralInf
			;pcmpeqd xmm4, xmm2 ; xmm4: mascara inferior
			
		; incrementar brillo (solo pixeles que superan)
			movdqu xmm2, addSup
			pand xmm2, xmm3 			; NO SUMA COMPONENTE R
			paddusw xmm0, xmm2
		; decrementar brillo (solo pixeles por debajo)
			movdqu xmm2, subInf
			pand xmm2, xmm4
			psubusw xmm0, xmm2
		; restaurar transparencia
			;por xmm0, maskTrans

		; escribir dst
			;pxor xmm1, xmm1
			packuswb xmm0, xmm0
			por xmm0, xmm10
			;por xmm0, maskTrans
			movq [ptr_dst], xmm0

		; avanzar punteros
			add ptr_src, 4		; procesamos de a 1 pixel
			add ptr_dst, 4		; procesamos de a 1 pixel

		dec r11

		; leer 1 pixel
			pmovzxbw xmm0, [ptr_src]			; xmm0: |a0|r0|g0|b0| (words)
		; calcular los b 
			; anular transparencia
			movdqu xmm1, maskTrans
			pandn xmm1, xmm0
			movdqu xmm0, xmm1
			; 2*g
			mov r10, 00000000ffff0000h
			movq xmm5, r10
			pinsrq xmm5, r10, 1
			; xmm5: 00000000ffff000000000000ffff0000h
			; mitad baja
			movdqu xmm1, xmm0
			movdqu xmm3, xmm0
			pand xmm3, xmm5
			paddw xmm1, xmm3 ; sumar bytes extendidos a word no desborda
			; xmm1: |r1+2*g1+b1|r0+2*g0+b0|
			; juntar mitades mediante suma horizontal
			phaddw xmm1, xmm1
			phaddw xmm1, xmm1
			;movdqu xmm2, xmm1
			; /4
			psrlw xmm1, 2
			; extender los b a dw (los umbrales son int)

			pmovzxwd xmm1, xmm1
			pmovzxdq xmm1, xmm1
			; -> xmm1: | b1 | b0 |
		; comparar los b con  los umbrales
			; cmp umbral superior
			movdqu xmm3, xmm1
			;pmaxud xmm3, umbralSup
			pcmpgtq xmm3, umbralSup
			;pcmpeqd xmm3, xmm2 ; xmm3: mascara superior
			; cmp umbral inferior
			movdqu xmm4, umbralInf
			pcmpgtq xmm4, xmm1
			;pminud xmm4, umbralInf
			;pcmpeqd xmm4, xmm2 ; xmm4: mascara inferior
			
		; incrementar brillo (solo pixeles que superan)
			movdqu xmm2, addSup
			pand xmm2, xmm3 			; NO SUMA COMPONENTE R
			paddusw xmm0, xmm2
		; decrementar brillo (solo pixeles por debajo)
			movdqu xmm2, subInf
			pand xmm2, xmm4
			psubusw xmm0, xmm2
		; restaurar transparencia
			;por xmm0, maskTrans

		; escribir dst
			;pxor xmm1, xmm1
			packuswb xmm0, xmm0
			por xmm0, xmm10
			;por xmm0, maskTrans
			movq [ptr_dst], xmm0

		; avanzar punteros
			add ptr_src, 4		; procesamos de a 1 pixel
			add ptr_dst, 4		; procesamos de a 1 pixel

		dec r11
		cmp r11, 0
		jnz .cicloColumnas

	dec alto
	cmp alto, 0
	jnz .cicloFilas ; rcx: alto

; desarmado stack frame
	pop rbp
	ret
