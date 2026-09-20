#!/usr/bin/env bash
# ==============================================================================
# Allwinner A13 / sun5i - U-Boot Builder & Flasher TUI Manager
# ==============================================================================

# Directorio base de u-boot
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBOOT_DIR="$SCRIPT_DIR"
TOOLCHAIN_DIR="/home/dev/toolchain/bin"
BIN_OUTPUT="$UBOOT_DIR/u-boot-sunxi-with-spl.bin"

# Colores y Formato
BOLD="\033[1m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

# Configuración del entorno de compilación
setup_env() {
    if [ -d "$TOOLCHAIN_DIR" ]; then
        export PATH="$TOOLCHAIN_DIR:$PATH"
    fi
    export ARCH=arm
    export CROSS_COMPILE=arm-none-linux-gnueabihf-
}

check_toolchain() {
    setup_env
    if command -v ${CROSS_COMPILE}gcc >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

draw_header() {
    clear 2>/dev/null || true
    echo -e "${CYAN}====================================================================${RESET}"
    echo -e "${BOLD}${MAGENTA}       ALLWINNER A13 (sun5i) - U-BOOT TUI MANAGER & FLASHER        ${RESET}"
    echo -e "${CYAN}====================================================================${RESET}"
    echo -e "${BLUE} Directorio U-Boot:${RESET} $UBOOT_DIR"
    if check_toolchain; then
        local gcc_ver
        gcc_ver=$(${CROSS_COMPILE}gcc --version 2>/dev/null | head -n1)
        echo -e "${BLUE} Toolchain:${RESET} ${GREEN}$gcc_ver${RESET}"
    else
        echo -e "${BLUE} Toolchain:${RESET} ${RED}No detectado${RESET}"
    fi
    if [ -f "$BIN_OUTPUT" ]; then
        local bin_size=$(ls -lh "$BIN_OUTPUT" | awk '{print $5}')
        local bin_date=$(ls -lh "$BIN_OUTPUT" | awk '{print $6, $7, $8}')
        echo -e "${BLUE} Binario SPL:${RESET} ${GREEN}u-boot-sunxi-with-spl.bin ($bin_size - $bin_date)${RESET}"
    else
        echo -e "${BLUE} Binario SPL:${RESET} ${YELLOW}No compilado aún${RESET}"
    fi
    echo -e "${CYAN}--------------------------------------------------------------------${RESET}"
}

menu_compile() {
    setup_env
    while true; do
        draw_header
        echo -e "${BOLD}--- MENÚ DE COMPILACIÓN ---${RESET}\n"
        echo -e " ${GREEN}1)${RESET} Compilar para iNet-86VE / 86VS (${BOLD}inet86ve_defconfig${RESET}) [Recomendado]"
        echo -e " ${GREEN}2)${RESET} Compilar para Q8 Tablet genérica (${BOLD}q8_a13_tablet_defconfig${RESET})"
        echo -e " ${GREEN}3)${RESET} Compilar para Olimex A13-OLinuXino (${BOLD}A13-OLinuXino_defconfig${RESET})"
        echo -e " ${GREEN}4)${RESET} Recompilar rápido (ejecutar ${BOLD}make -j\$(nproc)${RESET} con config actual)"
        echo -e " ${GREEN}5)${RESET} Abrir menú de configuración gráfica (${BOLD}menuconfig${RESET})"
        echo -e " ${GREEN}6)${RESET} Limpieza completa (${BOLD}make mrproper${RESET})"
        echo -e " ${YELLOW}0)${RESET} Volver al menú principal\n"
        read -rp "Seleccione una opción: " opt

        case $opt in
            1)
                echo -e "\n${CYAN}>>> Configurando inet86ve_defconfig (sun5i-a13-inet-86vs DTS)...${RESET}"
                cd "$UBOOT_DIR"
                make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- inet86ve_defconfig
                echo -e "${CYAN}>>> Compilando U-Boot...${RESET}"
                make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- -j"$(nproc)"
                echo -e "${GREEN}>>> ¡Compilación finalizada con éxito!${RESET}"
                read -rp "Presione [Enter] para continuar..."
                ;;
            2)
                echo -e "\n${CYAN}>>> Configurando A13-OLinuXino_defconfig...${RESET}"
                cd "$UBOOT_DIR"
                make A13-OLinuXino_defconfig
                echo -e "${CYAN}>>> Compilando U-Boot...${RESET}"
                make -j"$(nproc)"
                echo -e "${GREEN}>>> ¡Compilación finalizada con éxito!${RESET}"
                read -rp "Presione [Enter] para continuar..."
                ;;
            3)
                echo -e "\n${CYAN}>>> Configurando A13-OLinuXinoM_defconfig...${RESET}"
                cd "$UBOOT_DIR"
                make A13-OLinuXinoM_defconfig
                echo -e "${CYAN}>>> Compilando U-Boot...${RESET}"
                make -j"$(nproc)"
                echo -e "${GREEN}>>> ¡Compilación finalizada con éxito!${RESET}"
                read -rp "Presione [Enter] para continuar..."
                ;;
            4)
                echo -e "\n${CYAN}>>> Recompilando con make -j\$(nproc)...${RESET}"
                cd "$UBOOT_DIR"
                make -j"$(nproc)"
                echo -e "${GREEN}>>> ¡Compilación finalizada con éxito!${RESET}"
                read -rp "Presione [Enter] para continuar..."
                ;;
            5)
                cd "$UBOOT_DIR"
                make menuconfig
                ;;
            6)
                echo -e "\n${YELLOW}>>> Limpiando artefactos de compilación...${RESET}"
                cd "$UBOOT_DIR"
                make mrproper
                echo -e "${GREEN}>>> Limpieza completada.${RESET}"
                read -rp "Presione [Enter] para continuar..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Opción no válida.${RESET}"
                sleep 1
                ;;
        esac
    done
}

get_disks() {
    # Lista discos excluyendo sda, zram, loop
    lsblk -d -n -o NAME,SIZE,MODEL,TRAN,RM 2>/dev/null | while read -r name size model tran rm; do
        # Omitir sda (sistema) y zram/loop
        if [[ "$name" =~ ^(sda|zram|loop) ]]; then
            continue
        fi
        echo "$name|$size|$model|$tran|$rm"
    done
}

menu_flash() {
    while true; do
        draw_header
        echo -e "${BOLD}--- INSTALACIÓN EN MEMORIA / TARJETA SD ---${RESET}\n"
        if [ ! -f "$BIN_OUTPUT" ]; then
            echo -e "${RED}[AVISO] No se encuentra $BIN_OUTPUT.${RESET}"
            echo -e "${YELLOW}Primero compila U-Boot antes de intentar grabarlo.${RESET}\n"
            read -rp "Presione [Enter] para volver..."
            break
        fi

        echo -e "${CYAN}Dispositivos de almacenamiento detectados:${RESET}\n"
        
        # Mapear discos
        local disk_array=()
        local idx=1
        while IFS='|' read -r name size model tran rm; do
            [ -z "$name" ] && continue
            disk_array+=("$name")
            local extra=""
            [ "$tran" == "usb" ] && extra="[USB]"
            [ "$rm" == "1" ] && extra="$extra [Extraíble]"
            printf " ${GREEN}%d)${RESET} /dev/%-6s  Tamaño: %-7s  Modelo: %-20s %s\n" "$idx" "$name" "$size" "$model" "$extra"
            # Mostrar particiones montadas
            lsblk -n -o NAME,SIZE,MOUNTPOINTS "/dev/$name" 2>/dev/null | tail -n +2 | while read -r pname psize pmount; do
                echo -e "     └─ $pname ($psize) ${YELLOW}$pmount${RESET}"
            done
            ((idx++))
        done < <(get_disks)

        if [ ${#disk_array[@]} -eq 0 ]; then
            echo -e "${YELLOW}(No se detectaron unidades USB o SD adicionales).${RESET}"
            echo -e "${BLUE}Inserta tu memoria USB/SD y vuelve a entrar a este menú.${RESET}\n"
        fi

        echo -e "\n ${YELLOW}m)${RESET} Ingresar dispositivo manualmente (ej. /dev/sdc)"
        echo -e " ${YELLOW}0)${RESET} Volver al menú principal\n"
        read -rp "Seleccione el disco donde desea instalar: " choice

        if [ "$choice" == "0" ]; then
            break
        elif [ "$choice" == "m" ]; then
            read -rp "Ingrese la ruta completa del dispositivo (ej: /dev/sdc): " target_dev
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#disk_array[@]} ]; then
            target_dev="/dev/${disk_array[$((choice-1))]}"
        else
            echo -e "${RED}Selección no válida.${RESET}"
            sleep 1
            continue
        fi

        if [ ! -b "$target_dev" ]; then
            echo -e "${RED}[ERROR] $target_dev no es un dispositivo de bloque válido.${RESET}"
            read -rp "Presione [Enter] para continuar..."
            continue
        fi

        # Doble verificación de seguridad para sda
        if [[ "$target_dev" == *"/sda"* ]]; then
            echo -e "${RED}${BOLD}[PELIGRO] /dev/sda es el disco principal del sistema. Operación cancelada.${RESET}"
            read -rp "Presione [Enter] para continuar..."
            continue
        fi

        echo -e "\n${YELLOW}======================================================${RESET}"
        echo -e "${RED}${BOLD}  ¡ATENCIÓN! SE GRABARÁ EN: $target_dev               ${RESET}"
        echo -e "${YELLOW}======================================================${RESET}"
        lsblk "$target_dev"
        echo -e ""
        read -rp "¿Está 100% seguro de proceder con $target_dev? (escriba 'SI' en mayúsculas): " confirm
        if [ "$confirm" != "SI" ]; then
            echo -e "${YELLOW}Operación cancelada por el usuario.${RESET}"
            read -rp "Presione [Enter] para continuar..."
            continue
        fi

        echo -e "\n${CYAN}1. Desmontando todas las particiones activas en $target_dev...${RESET}"
        sudo umount -f "${target_dev}"* 2>/dev/null || true
        for part in $(lsblk -ln -o NAME "$target_dev"); do
            sudo umount -f "/dev/$part" 2>/dev/null || true
        done

        echo -e "\n${CYAN}2. ¿Desea particionar y formatear la memoria para el Sistema Operativo?${RESET}"
        echo -e " ${GREEN}1)${RESET} Formato ${BOLD}EXT4${RESET} (Recomendado para Alpine Linux / Debian rootfs)"
        echo -e " ${GREEN}2)${RESET} Formato ${BOLD}FAT32${RESET} (Para arranque clásico por script FAT)"
        echo -e " ${YELLOW}3)${RESET} No formatear (solo escribir U-Boot)"
        read -rp "Seleccione [1-3]: " fs_choice

        if [ "$fs_choice" == "1" ] || [ "$fs_choice" == "2" ]; then
            echo -e "\n${CYAN}Creando tabla de particiones MBR (msdos) y partición a partir de 1 MiB (sector 2048)...${RESET}"
            # 1. Crear tabla MBR
            sudo parted -s "$target_dev" mklabel msdos
            # 2. Crear partición a partir de 2048 sectores (1MB) dejando intacto el espacio para U-Boot (8K - 1M)
            if [ "$fs_choice" == "1" ]; then
                sudo parted -s -a optimal "$target_dev" mkpart primary ext4 2048s 100%
            else
                sudo parted -s -a optimal "$target_dev" mkpart primary fat32 2048s 100%
                sudo parted -s "$target_dev" set 1 boot on
            fi
            
            # Sincronizar tabla de particiones
            sudo partprobe "$target_dev" 2>/dev/null || true
            sleep 1

            local new_part="${target_dev}1"
            if [ -b "${target_dev}p1" ]; then
                new_part="${target_dev}p1"
            fi

            if [ "$fs_choice" == "1" ]; then
                echo -e "${CYAN}Formateando $new_part como EXT4 (Label: rootfs)...${RESET}"
                sudo mkfs.ext4 -F -L "rootfs" "$new_part"
            else
                echo -e "${CYAN}Formateando $new_part como FAT32 (Label: BOOT)...${RESET}"
                sudo mkfs.vfat -F 32 -n "BOOT" "$new_part"
            fi
            echo -e "${GREEN}✓ Partición $new_part creada y formateada con éxito.${RESET}"
        fi

        echo -e "\n${CYAN}3. Escribiendo u-boot-sunxi-with-spl.bin en $target_dev (offset 8 KiB / sector 16)...${RESET}"
        sudo dd if="$BIN_OUTPUT" of="$target_dev" bs=1k seek=8 status=progress conv=fsync

        echo -e "\n${GREEN}${BOLD}======================================================${RESET}"
        echo -e "${GREEN}${BOLD}  ¡U-Boot grabado y memoria lista para usar!          ${RESET}"
        echo -e "${GREEN}${BOLD}======================================================${RESET}"
        lsblk -f "$target_dev"

        read -rp "Presione [Enter] para volver al menú..."
        break
    done
}

menu_serial() {
    draw_header
    echo -e "${BOLD}--- MONITOR SERIE UART ---${RESET}\n"
    local uarts=($(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true))
    if [ ${#uarts[@]} -eq 0 ]; then
        echo -e "${YELLOW}No se detectaron adaptadores USB-UART conectados (/dev/ttyUSB* o /dev/ttyACM*).${RESET}\n"
        read -rp "Presione [Enter] para continuar..."
        return
    fi

    echo -e "${CYAN}Puertos serie detectados:${RESET}"
    local idx=1
    for u in "${uarts[@]}"; do
        echo -e " ${GREEN}$idx)${RESET} $u"
        ((idx++))
    done
    echo -e " ${YELLOW}0)${RESET} Cancelar\n"
    read -rp "Seleccione un puerto para abrir (115200 baudios): " pchoice

    if [[ "$pchoice" =~ ^[0-9]+$ ]] && [ "$pchoice" -ge 1 ] && [ "$pchoice" -le ${#uarts[@]} ]; then
        local port="${uarts[$((pchoice-1))]}"
        echo -e "\n${GREEN}Abriendo $port a 115200 baudios... (Presione Ctrl+A luego Ctrl+X para salir en picocom)${RESET}"
        if command -v picocom >/dev/null 2>&1; then
            picocom -b 115200 "$port"
        elif command -v screen >/dev/null 2>&1; then
            screen "$port" 115200
        elif command -v minicom >/dev/null 2>&1; then
            minicom -D "$port" -b 115200
        else
            echo -e "${RED}No se encontró picocom, screen ni minicom. Instala uno con: sudo pacman -S picocom${RESET}"
            read -rp "Presione [Enter] para continuar..."
        fi
    fi
}

main() {
    while true; do
        draw_header
        echo -e "${BOLD}--- MENÚ PRINCIPAL ---${RESET}\n"
        echo -e " ${GREEN}1)${RESET} Compilar U-Boot (Selección de perfiles / menuconfig)"
        echo -e " ${GREEN}2)${RESET} Instalar / Flashear U-Boot en Tarjeta SD / USB"
        echo -e " ${GREEN}3)${RESET} Abrir Monitor Serie UART (115200 baud)"
        echo -e " ${YELLOW}0)${RESET} Salir\n"
        read -rp "Seleccione una opción [1-3, 0]: " main_opt

        case $main_opt in
            1) menu_compile ;;
            2) menu_flash ;;
            3) menu_serial ;;
            0) echo -e "\n${GREEN}¡Hasta luego!${RESET}\n"; exit 0 ;;
            *) echo -e "${RED}Opción no válida.${RESET}"; sleep 1 ;;
        esac
    done
}

main "$@"
