/****************************************************************************
 * arch/arm/src/s32k1xx/s32k1xx_lpspi.h
 *
 *   Copyright (C) 2019 Gregory Nutt. All rights reserved.
 *   Authors: Ivan Ucherdzhiev <ivanucherdjiev@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 * 3. Neither the name NuttX nor the names of its contributors may be
 *    used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************/

#ifndef __ARCH_ARM_SRC_S32K1XX_S32K1XX_LPSPI_H
#define __ARCH_ARM_SRC_S32K1XX_S32K1XX_LPSPI_H

/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <nuttx/config.h>

#include <stdbool.h>

#include <nuttx/spi/spi.h>

#include "chip.h"
#include "hardware/s32k1xx_lpspi.h"

/****************************************************************************
 * Public Functions Prototypes
 ****************************************************************************/

#ifndef __ASSEMBLY__

#undef EXTERN
#if defined(__cplusplus)
#define EXTERN extern "C"
extern "C"
{
#else
#define EXTERN extern
#endif

struct spi_dev_s; /* Forward reference */

/****************************************************************************
 * Name: s32k1xx_lpspibus_initialize
 *
 * Description:
 *   Initialize the selected SPI bus
 *
 * Input Parameters:
 *   bus number (for hardware that has multiple SPI interfaces)
 *
 * Returned Value:
 *   Valid SPI device structure reference on success; a NULL on failure
 *
 ****************************************************************************/

FAR struct spi_dev_s *s32k1xx_lpspibus_initialize(int bus);

/****************************************************************************
 * Name:  s32k1xx_lpspi0/1/2/select and s32k1xx_lpspi0/1/2/status
 *
 * Description:
 *   The external functions, s32k1xx_lpspi001/2/select,
 *   s32k1xx_lpspi0/1/2/status, and s32k1xx_lpspi0/1/2/cmddata must be
 *   provided by board-specific logic. These are implementations of the
 *   select, status, and cmddata methods of the SPI interface defined by
 *   struct spi_ops_s (see include/nuttx/spi/spi.h). All other methods
 *   (including s32k1xx_lpspibus_initialize()) are provided by common
 *   S32K1XX logic.  To use this common SPI logic on your board:
 *
 *   1. Provide logic in s32k1xx_boardinitialize() to configure SPI chip
 *      select pins.
 *   2. Provide s32k1xx_lpspi0/1/2/select() and s32k1xx_lpspi0/1/2/status()
 *      functions in your  board-specific logic.  These functions will
 *      perform chip selection and status operations using GPIOs in the way
 *      your board is configured.
 *   3. If CONFIG_SPI_CMDDATA is defined in your NuttX configuration file,
 *      then provide s32k1xx_lpspi0/1/2/cmddata() functions in your
 *      board-specific logic. These functions will perform cmd/data selection
 *      operations using GPIOs in the way your board is configured.
 *   4. Add a calls to s32k1xx_lpspibus_initialize() in your low level
 *      application initialization logic
 *   5. The handle returned by s32k1xx_lpspibus_initialize() may then be
 *      used to bind the SPI driver to higher level logic (e.g., calling
 *      mmcsd_spislotinitialize(), for example, will bind the SPI driver to
 *      the SPI MMC/SD driver).
 *
 ****************************************************************************/

#ifdef CONFIG_S32K1XX_LPSPI0
void s32k1xx_lpspi0select(FAR struct spi_dev_s *dev,
                          uint32_t devid, bool selected);
uint8_t s32k1xx_lpspi0status(FAR struct spi_dev_s *dev, uint32_t devid);
int s32k1xx_lpspi0cmddata(FAR struct spi_dev_s *dev,
                          uint32_t devid, bool cmd);
#endif

#ifdef CONFIG_S32K1XX_LPSPI1
void s32k1xx_lpspi1select(FAR struct spi_dev_s *dev,
                          uint32_t devid, bool selected);
uint8_t s32k1xx_lpspi1status(FAR struct spi_dev_s *dev, uint32_t devid);
int s32k1xx_lpspi1cmddata(FAR struct spi_dev_s *dev,
                          uint32_t devid, bool cmd);
#endif

#ifdef CONFIG_S32K1XX_LPSPI2
void s32k1xx_lpspi2select(FAR struct spi_dev_s *dev,
                          uint32_t devid, bool selected);
uint8_t s32k1xx_lpspi2status(FAR struct spi_dev_s *dev, uint32_t devid);
int s32k1xx_lpspi2cmddata(FAR struct spi_dev_s *dev,
                          uint32_t devid, bool cmd);
#endif

/****************************************************************************
 * Name: s32k1xx_lpspi0/1/2/register
 *
 * Description:
 *   If the board supports a card detect callback to inform the SPI-based
 *   MMC/SD driver when an SD card is inserted or removed, then
 *   CONFIG_SPI_CALLBACK should be defined and the following function(s)
 *   must be implemented.  These functions implements the registercallback
 *   method of the SPI interface (see include/nuttx/spi/spi.h for details)
 *
 * Input Parameters:
 *   dev -      Device-specific state data
 *   callback - The function to call on the media change
 *   arg -      A caller provided value to return with the callback
 *
 * Returned Value:
 *   0 on success; negated errno on failure.
 *
 ****************************************************************************/

#ifdef CONFIG_SPI_CALLBACK
#ifdef CONFIG_S32K1XX_LPSPI0
int s32k1xx_lpspi0register(FAR struct spi_dev_s *dev,
                           spi_mediachange_t callback,
                           FAR void *arg);
#endif

#ifdef CONFIG_S32K1XX_LPSPI1
int s32k1xx_lpspi1register(FAR struct spi_dev_s *dev,
                           spi_mediachange_t callback,
                           FAR void *arg);
#endif

#ifdef CONFIG_S32K1XX_LPSPI2
int s32k1xx_lpspi2register(FAR struct spi_dev_s *dev,
                           spi_mediachange_t callback,
                           FAR void *arg);
#endif
#endif

#undef EXTERN
#if defined(__cplusplus)
}
#endif

#endif /* __ASSEMBLY__ */
#endif /* __ARCH_ARM_SRC_S32K1XX_S32K1XX_LPSPI_H */
