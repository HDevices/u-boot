Resumen de modificaciones para U-Boot DTS (sun5i-a13-inet-86ve-rev02.dts)

Objetivo
- Minimizar el Device Tree para U-Boot y dejar la mayor parte del hardware para que lo gestione el kernel.
- Asegurar que U-Boot pueda: inicializar DRAM, establecer voltajes de arranque apropiados vía AXP209, arrancar desde SD (mmc0), mostrar logo en LCD/backlight y exponer la consola por `uart1` (serial0:115200n8). Permitir además UMS vía USB OTG para acceder a la SD desde un host.

Archivos modificados
- `dts/upstream/src/arm/allwinner/sun5i-a13-inet-86ve-rev02.dts`
  - Añadido comentario en el encabezado indicando que NAND y CSI quedan fuera del soporte explícito de U-Boot.
  - Añadido nodo RTC `pcf8563@51` bajo `&i2c1` (según `script.txt: rtc_twi_addr = 81` => 0x51).
  - Fijados voltajes de arranque en el PMIC AXP209 (reguladores: dcdc2, dcdc3, ldo2, ldo3, ldo4) usando `regulator-fixed-microvolt` y alineando `min/max`:
    - `dcdc2` = 1400000 µV (core)
    - `dcdc3` = 1200000 µV
    - `ldo2`  = 3000000 µV
    - `ldo3`  = 3300000 µV
    - `ldo4`  = 3300000 µV
  - Se mantuvieron y verificaron nodos esenciales ya presentes: `memory@40000000` (DRAM), `&mmc0` con `vmmc-supply = <&reg_ldo3>`, alias `serial0 = &uart1`, `chosen.stdout-path = "serial0:115200n8"`, `&usb_otg` en modo `peripheral`, `&usbphy`, `&tcon0`/`panel`/`backlight` y `&pwm`.

Decisiones de diseño
- NAND y CSI (cámaras) quedan intencionadamente fuera del DTS de U-Boot para evitar conflictos y mantener un DTS mínimo para el proceso de arranque. El kernel debe contener los nodos y controladores completos para esos periféricos.
- `uart1` fue elegido como consola por estar libre de multiplexación con la SD (evita conflicto con `uart0`).
- Los voltajes siguen las especificaciones encontradas en `script.txt` para que el PMIC arranque con niveles seguros.

Instrucciones rápidas para pruebas en U-Boot
- Conecta tu adaptador TTL a `uart1` y abre la consola a `115200 8N1`.
- Inserta la tarjeta SD y arranca. U-Boot debería usar `mmc0` para el arranque; si tu build de U-Boot incluye el comando UMS, puedes exponer la SD al host con (ejemplo):

  ums 0 mmc 0

  (Si el comando no está disponible, recompila U-Boot con CONFIG_CMD_UMS y soporte USB gadget apropiado.)

Notas finales
- Si quieres que U-Boot probe o soporte NAND/CSI de forma limitada (por ejemplo, para debug temprano), puedo añadir nodos "disabled" o placeholders con `status = "disabled"` para documentar pines sin activarlos.
- Próximo paso: aplicar cambios adicionales mínimos si lo deseas (ej: asegurar que el pinctrl de `uart1` mapea al conector físico correcto, añadir propiedades de `memory` timings en caso de necesitar ajustes en U-Boot, o crear un parche listo para commit).

Fecha: 2025-12-01
Autor: Equipo de integración
