/************************************************************************************
 * arch/arm/src/arm/arm_vectors.S
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.  The
 * ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 ************************************************************************************/

/************************************************************************************
 * Included Files
 ************************************************************************************/

#include <nuttx/config.h>
#include <nuttx/irq.h>

#include "arm.h"
#include "arm_arch.h"

/************************************************************************************
 * Pre-processor Definitions
 ************************************************************************************/

/************************************************************************************
 * Public Data
 ************************************************************************************/

	.data
g_irqtmp:
	.word	0		/* Saved lr */
	.word	0		/* Saved spsr */
g_undeftmp:
	.word	0		/* Saved lr */
	.word	0		/* Saved spsr */
g_aborttmp:
	.word	0		/* Saved lr */
	.word	0		/* Saved spsr */

/************************************************************************************
 * Assembly Macros
 ************************************************************************************/

/************************************************************************************
 * Private Functions
 ************************************************************************************/

	.text

/************************************************************************************
 * Public Functions
 ************************************************************************************/

	.text

/************************************************************************************
 * Name: arm_vectorirq
 *
 * Description:
 *   Interrupt exception. Entered in IRQ mode with spsr = SVC CPSR, lr = SVC PC
 *
 ************************************************************************************/

	.globl	arm_vectorirq
	.type	arm_vectorirq, %function
arm_vectorirq:
	/* On entry, we are in IRQ mode.  We are free to use
	 * the IRQ mode r13 and r14.
	 */

	ldr	r13, .Lirqtmp
	sub	lr, lr, #4
	str	lr, [r13]			@ save lr_IRQ
	mrs	lr, spsr
	str	lr, [r13, #4]			@ save spsr_IRQ

	/* Then switch back to SVC mode */

	bic	lr, lr, #MODE_MASK	/* Keep F and T bits */
	orr	lr, lr, #(SVC_MODE | PSR_I_BIT)
	msr	cpsr_c, lr		/* Switch to SVC mode */

	/* Create a context structure.  First set aside a stack frame
	 * and store r0-r12 into the frame.
	 */

	sub	sp, sp, #XCPTCONTEXT_SIZE
	stmia	sp, {r0-r12}		/* Save the SVC mode regs */

	/* Get the correct values of r13(sp) and r14(lr) in r1 and r2 */

	add	r1, sp, #XCPTCONTEXT_SIZE
	mov	r2, r14

	/* Get the values for r15(pc) and CPSR in r3 and r4 */

	ldr	r0, .Lirqtmp		/* Points to temp storage */
	ldmia	r0, {r3, r4}		/* Recover r1=lr_IRQ, r2=spsr_IRQ */

	add	r0, sp, #(4*REG_SP)	/* Offset to pc, cpsr storage */
	stmia	r0, {r1-r4}

	/* Then call the IRQ handler with interrupts disabled. */

	mov	fp, #0			/* Init frame pointer */
	mov	r0, sp			/* Get r0=xcp */

#if CONFIG_ARCH_INTERRUPTSTACK > 3
	ldr	sp, .Lirqstackbase	/* SP = interrupt stack base */
	str	r0, [sp, #-4]!		/* Save the xcp address at SP-4 then update SP */
	bl	arm_decodeirq		/* Call the handler */
	ldr	sp, [sp]		/* Restore the user stack pointer */
#else
	bl	arm_decodeirq		/* Call the handler */
#endif

	/* Restore the CPSR, SVC mode registers and return */
.Lnoirqset:
	ldr	r0, [sp, #(4*REG_CPSR)]	/* Setup the SVC mode SPSR */
	msr	spsr, r0
	ldmia	sp, {r0-r15}^		/* Return */

.Lirqtmp:
	.word	g_irqtmp
#if CONFIG_ARCH_INTERRUPTSTACK > 3
.Lirqstackbase:
	.word	g_intstackbase
#endif
	.size	arm_vectorirq, . - arm_vectorirq
	.align	5

/************************************************************************************
 * Function: arm_vectorswi
 *
 * Description:
 *   SWI interrupt. We enter the SWI in SVC mode.
 *
 ************************************************************************************/

	.globl	arm_vectorswi
	.type	arm_vectorswi, %function
arm_vectorswi:

	/* Create a context structure.  First set aside a stack frame
	 * and store r0-r12 into the frame.
	 */

	sub	sp, sp, #XCPTCONTEXT_SIZE
	stmia	sp, {r0-r12}		/* Save the SVC mode regs */

	/* Get the correct values of r13(sp), r14(lr), r15(pc)
	 * and CPSR in r1-r4 */

	add	r1, sp, #XCPTCONTEXT_SIZE
	mov	r2, r14			/* R14 is altered on return from SWI */
	mov	r3, r14			/* Save r14 as the PC as well */
	mrs	r4, spsr		/* Get the saved CPSR */

	add	r0, sp, #(4*REG_SP)	/* Offset to pc, cpsr storage */
	stmia	r0, {r1-r4}

	/* Then call the SWI handler with interrupts disabled.
	 * void arm_syscall(struct xcptcontext *xcp)
	 */

	mov	fp, #0			/* Init frame pointer */
	mov	r0, sp			/* Get r0=xcp */
	bl	arm_syscall		/* Call the handler */

	/* Restore the CPSR, SVC mode registers and return */

	ldr	r0, [sp, #(4*REG_CPSR)]	/* Setup the SVC mode SPSR */
	msr	spsr, r0
	ldmia	sp, {r0-r15}^		/* Return */
	.size	arm_vectorswi, . - arm_vectorswi

	.align	5

/************************************************************************************
 * Name: arm_vectordata
 *
 * Description:
 *   This is the data abort exception dispatcher. The ARM data abort exception occurs
 *   when a memory fault is detected during a data transfer.  This handler saves the
 *   current processor state and gives control to data abort handler.  This function
 *   is entered in ABORT mode with spsr = SVC CPSR, lr = SVC PC
 *
 ************************************************************************************/

	.globl	arm_vectordata
	.type	arm_vectordata, %function
arm_vectordata:
	/* On entry we are free to use the ABORT mode registers
	 * r13 and r14
	 */

	ldr	r13, .Ldaborttmp	/* Points to temp storage */
	sub	lr, lr, #8		/* Fixup return */
	str	lr, [r13]		/* Save in temp storage */
	mrs	lr, spsr		/* Get SPSR */
	str	lr, [r13, #4]		/* Save in temp storage */

	/* Then switch back to SVC mode */

	bic	lr, lr, #MODE_MASK	/* Keep F and T bits */
	orr	lr, lr, #(SVC_MODE | PSR_I_BIT)
	msr	cpsr_c, lr		/* Switch to SVC mode */

	/* Create a context structure.  First set aside a stack frame
	 * and store r0-r12 into the frame.
	 */

	sub	sp, sp, #XCPTCONTEXT_SIZE
	stmia	sp, {r0-r12}		/* Save the SVC mode regs */

	/* Get the correct values of r13(sp) and r14(lr) in r1 and r2 */

	add	r1, sp, #XCPTCONTEXT_SIZE
	mov	r2, r14

	/* Get the values for r15(pc) and CPSR in r3 and r4 */

	ldr	r0, .Ldaborttmp		/* Points to temp storage */
	ldmia	r0, {r3, r4}		/* Recover r1=lr_IRQ, r2=spsr_IRQ */

	add	r0, sp, #(4*REG_SP)	/* Offset to pc, cpsr storage */
	stmia	r0, {r1-r4}

	/* Then call the data abort handler with interrupts disabled.
	 * void arm_dataabort(struct xcptcontext *xcp)
	 */

	mov	fp, #0			/* Init frame pointer */
	mov	r0, sp			/* Get r0=xcp */
#ifdef CONFIG_PAGING
	mrc	p15, 0, r2, c5, c0, 0	/* Get r2=FSR */
	mrc	p15, 0, r1, c6, c0, 0	/* Get R1=FAR */
#endif
	bl	arm_dataabort		/* Call the handler */

	/* Restore the CPSR, SVC mode registers and return */

	ldr	r0, [sp, #(4*REG_CPSR)]	/* Setup the SVC mode SPSR */
	msr	spsr_cxsf, r0
	ldmia	sp, {r0-r15}^		/* Return */

.Ldaborttmp:
	.word	g_aborttmp
	.size	arm_vectordata, . - arm_vectordata

	.align	5

/************************************************************************************
 * Name: arm_vectorprefetch
 *
 * Description:
 *   This is the prefetch abort exception dispatcher. The ARM prefetch abort exception
 *   occurs when a memory fault is detected during an an instruction fetch.  This
 *   handler saves the current processor state and gives control to prefetch abort
 *   handler.  This function is entered in ABT mode with spsr = SVC CPSR, lr = SVC PC.
 *
 ************************************************************************************/

	.globl	arm_vectorprefetch
	.type	arm_vectorprefetch, %function
arm_vectorprefetch:
	/* On entry we are free to use the ABORT mode registers
	 * r13 and r14
	 */

	ldr	r13, .Lpaborttmp	/* Points to temp storage */
	sub	lr, lr, #4		/* Fixup return */
	str	lr, [r13]		/* Save in temp storage */
	mrs	lr, spsr		/* Get SPSR */
	str	lr, [r13, #4]		/* Save in temp storage */

	/* Then switch back to SVC mode */

	bic	lr, lr, #MODE_MASK	/* Keep F and T bits */
	orr	lr, lr, #(SVC_MODE | PSR_I_BIT)
	msr	cpsr_c, lr		/* Switch to SVC mode */

	/* Create a context structure.  First set aside a stack frame
	 * and store r0-r12 into the frame.
	 */

	sub	sp, sp, #XCPTCONTEXT_SIZE
	stmia	sp, {r0-r12}		/* Save the SVC mode regs */

	/* Get the correct values of r13(sp) and r14(lr) in r1 and r2 */

	add	r1, sp, #XCPTCONTEXT_SIZE
	mov	r2, r14

	/* Get the values for r15(pc) and CPSR in r3 and r4 */

	ldr	r0, .Lpaborttmp		/* Points to temp storage */
	ldmia	r0, {r3, r4}		/* Recover r1=lr_IRQ, r2=spsr_IRQ */

	add	r0, sp, #(4*REG_SP)	/* Offset to pc, cpsr storage */
	stmia	r0, {r1-r4}

	/* Then call the prefetch abort handler with interrupts disabled.
	 * void arm_prefetchabort(struct xcptcontext *xcp)
	 */

	mov	fp, #0			/* Init frame pointer */
	mov	r0, sp			/* Get r0=xcp */
	bl	arm_prefetchabort	/* Call the handler */

	/* Restore the CPSR, SVC mode registers and return */

	ldr	r0, [sp, #(4*REG_CPSR)]	/* Setup the SVC mode SPSR */
	msr	spsr_cxsf, r0
	ldmia	sp, {r0-r15}^		/* Return */

.Lpaborttmp:
	.word	g_aborttmp
	.size	arm_vectorprefetch, . - arm_vectorprefetch

	.align	5

/************************************************************************************
 * Name: arm_vectorundefinsn
 *
 * Description:
 *   Undefined instruction entry exception.  Entered in UND mode, spsr = SVC  CPSR,
 *   lr = SVC PC
 *
 ************************************************************************************/

	.globl	arm_vectorundefinsn
	.type	arm_vectorundefinsn, %function
arm_vectorundefinsn:
	/* On entry we are free to use the UND mode registers
	 * r13 and r14
	 */

	ldr	r13, .Lundeftmp		/* Points to temp storage */
	str	lr, [r13]		/* Save in temp storage */
	mrs	lr, spsr		/* Get SPSR */
	str	lr, [r13, #4]		/* Save in temp storage */

	/* Then switch back to SVC mode */

	bic	lr, lr, #MODE_MASK	/* Keep F and T bits */
	orr	lr, lr, #(SVC_MODE | PSR_I_BIT)
	msr	cpsr_c, lr		/* Switch to SVC mode */

	/* Create a context structure.  First set aside a stack frame
	 * and store r0-r12 into the frame.
	 */

	sub	sp, sp, #XCPTCONTEXT_SIZE
	stmia	sp, {r0-r12}		/* Save the SVC mode regs */

	/* Get the correct values of r13(sp) and r14(lr) in r1 and r2 */

	add	r1, sp, #XCPTCONTEXT_SIZE
	mov	r2, r14

	/* Get the values for r15(pc) and CPSR in r3 and r4 */

	ldr	r0, .Lundeftmp		/* Points to temp storage */
	ldmia	r0, {r3, r4}		/* Recover r1=lr_IRQ, r2=spsr_IRQ */

	add	r0, sp, #(4*REG_SP)	/* Offset to pc, cpsr storage */
	stmia	r0, {r1-r4}

	/* Then call the undef insn handler with interrupts disabled.
	 * void arm_undefinedinsn(struct xcptcontext *xcp)
	 */

	mov	fp, #0			/* Init frame pointer */
	mov	r0, sp			/* Get r0=xcp */
	bl	arm_undefinedinsn	/* Call the handler */

	/* Restore the CPSR, SVC mode registers and return */

	ldr	r0, [sp, #(4*REG_CPSR)]	/* Setup the SVC mode SPSR */
	msr	spsr_cxsf, r0
	ldmia	sp, {r0-r15}^		/* Return */

.Lundeftmp:
	.word	g_undeftmp
	.size	arm_vectorundefinsn, . - arm_vectorundefinsn

	.align	5

/************************************************************************************
 * Name: arm_vectorfiq
 *
 * Description:
 *   Shouldn't happen
 *
 ************************************************************************************/

	.globl	arm_vectorfiq
	.type	arm_vectorfiq, %function
arm_vectorfiq:
	subs	pc, lr, #4
	.size	arm_vectorfiq, . - arm_vectorfiq

/************************************************************************************
 *  Name: g_intstackalloc/g_intstackbase
 ************************************************************************************/

#if CONFIG_ARCH_INTERRUPTSTACK > 3
	.bss
	.balign	4
	.globl	g_intstackalloc
	.type	g_intstackalloc, object
	.globl	g_intstackbase
	.type	g_intstackbase, object
g_intstackalloc:
	.skip	(CONFIG_ARCH_INTERRUPTSTACK & ~3)
g_intstackbase:
	.skip	4
	.size	g_intstackbase, 4
	.size	g_intstackalloc, (CONFIG_ARCH_INTERRUPTSTACK & ~3)
#endif
	.end
