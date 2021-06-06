extern ReforzarBrillo_c
global ReforzarBrillo_asm

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
	mov r10d, 0xff000000					
	movd xmm0, r10d
	pshufd maskTrans, xmm0, 0000
	; maskTrans: ff000000ff000000ff000000ff000000

	%define umbralSup xmm14
	movd umbralSup, [rbp+16]
	pshufd umbralSup, umbralSup, 00000000b 

	%define umbralInf xmm13
	movd umbralInf, [rbp+24]
	pshufd umbralInf, umbralInf, 00000000b 

	%define addSup xmm12
	movd addSup, [rbp+32]
	pxor xmm0, xmm0
	packusdw addSup, xmm0
	packuswb addSup, xmm0 	; el incremento es a byte
	pshufb addSup, xmm0 	; broadcast incremento

	%define addInf xmm11
	movd addInf, [rbp+40]
	packusdw addInf, xmm0
	packuswb addInf, xmm0 	; el decremento es a byte
	pshufb addInf, xmm0 	; broadcast incremento

	;|argb|

	.cicloFilas:

		mov r11d, ancho
		shr r11d, 3	; r11d: ancho / 8

		.cicloColumnas:
		; leer 4 pixeles
			movdqu xmm0, [ptr_src]
		; calcular los b 
			; anular transparencia
			movdqu xmm1, maskTrans
			pandn xmm1, xmm0
			movdqu xmm0, xmm1
			; extender en dos registros de words
			pmovzxbw xmm1, xmm0	 ; xmm1: mitad baja
			movdqu xmm2, xmm0
			pxor xmm3, xmm3
			punpckhbw xmm2, xmm3 ; xmm2: mitad alta 
			; 2*g
			mov r10, 00000000ffff0000h
			movq xmm5, r10
			pinsrq xmm5, r10, 1
			; xmm5: 00000000ffff000000000000ffff0000h
			; mitad baja
			movdqu xmm3, xmm1
			pand xmm3, xmm5
			paddw xmm1, xmm3 ; sumar bytes extendidos a word no desborda
			; mitad alta
			movdqu xmm3, xmm2
			pand xmm3, xmm5
			paddw xmm2, xmm3 ; sumar bytes extendidos a word no desborda
			; (b+2*g+r)
			; juntar mitades mediante sumar horizontal
			phaddw xmm1, xmm2
			phaddw xmm1, xmm1
			movdqu xmm2, xmm1
			; /4
			psrlw xmm2, 2
			; extender los b a dw (los umbrales son int)

			pmovzxwd xmm2, xmm2
		; -> xmm2: | b3 | b2 | b1 | b0 |

		; comparar los b con  los umbrales
			; cmp umbral superior
			movdqu xmm3, xmm2
			;pmaxud xmm3, umbralSup
			pcmpgtd xmm3, umbralSup
			;pcmpeqd xmm3, xmm2 ; xmm3: mascara superior
			; cmp umbral inferior
			movdqu xmm4, umbralInf
			pcmpgtd xmm4, xmm2
			;pminud xmm4, umbralInf
			;pcmpeqd xmm4, xmm2 ; xmm4: mascara inferior
			
		; incrementar brillo (solo pixeles que superan)
			movdqu xmm1, addSup
			pand xmm1, xmm3
			paddusb xmm0, xmm1
		; decrementar brillo (solo pixeles por debajo)	
			movdqu xmm1, addInf
			pand xmm1, xmm4
			psubusb xmm0, xmm1
		; restaurar transparencia
			por xmm0, maskTrans

		; escribir dst
			movdqu [ptr_dst], xmm0

		; avanzar punteros
			add ptr_src, 16		; procesamos 4 pixeles
			add ptr_dst, 16		; procesamos 4 pixeles

		; PROXIMOS 4 PIXELES
		; leer 4 pixeles
			movdqu xmm0, [ptr_src]
		; calcular los b 
			; anular transparencia
			movdqu xmm1, maskTrans
			pandn xmm1, xmm0
			movdqu xmm0, xmm1
			; extender en dos registros de words
			pmovzxbw xmm1, xmm0	 ; xmm1: mitad baja
			movdqu xmm2, xmm0
			pxor xmm3, xmm3
			punpckhbw xmm2, xmm3 ; xmm2: mitad alta 
			; 2*g
			mov r10, 00000000ffff0000h
			movq xmm5, r10
			pinsrq xmm5, r10, 1
			; xmm5: 00000000ffff000000000000ffff0000h
			; mitad baja
			movdqu xmm3, xmm1
			pand xmm3, xmm5
			paddw xmm1, xmm3 ; sumar bytes extendidos a word no desborda
			; mitad alta
			movdqu xmm3, xmm2
			pand xmm3, xmm5
			paddw xmm2, xmm3 ; sumar bytes extendidos a word no desborda
			; (b+2*g+r)
			; juntar mitades mediante sumar horizontal
			phaddw xmm1, xmm2
			phaddw xmm1, xmm1
			movdqu xmm2, xmm1
			; /4
			psrlw xmm2, 2
			; extender los b a dw (los umbrales son int)

			pmovzxwd xmm2, xmm2
		; -> xmm2: | b3 | b2 | b1 | b0 |

		; comparar los b con  los umbrales
			; cmp umbral superior
			movdqu xmm3, xmm2
			;pmaxud xmm3, umbralSup
			pcmpgtd xmm3, umbralSup
			;pcmpeqd xmm3, xmm2 ; xmm3: mascara superior
			; cmp umbral inferior
			movdqu xmm4, umbralInf
			pcmpgtd xmm4, xmm2
			;pminud xmm4, umbralInf
			;pcmpeqd xmm4, xmm2 ; xmm4: mascara inferior
			
		; incrementar brillo (solo pixeles que superan)
			movdqu xmm1, addSup
			pand xmm1, xmm3
			paddusb xmm0, xmm1
		; decrementar brillo (solo pixeles por debajo)	
			movdqu xmm1, addInf
			pand xmm1, xmm4
			psubusb xmm0, xmm1
		; restaurar transparencia
			por xmm0, maskTrans

		; escribir dst
			movdqu [ptr_dst], xmm0

		; avanzar punteros
			add ptr_src, 16		; procesamos 4 pixeles
			add ptr_dst, 16		; procesamos 4 pixeles


		dec r11
		cmp r11, 0
		jnz .cicloColumnas

	dec alto
	cmp alto, 0
	jnz .cicloFilas ; rcx: alto

; desarmado stack frame
	pop rbp
	ret
