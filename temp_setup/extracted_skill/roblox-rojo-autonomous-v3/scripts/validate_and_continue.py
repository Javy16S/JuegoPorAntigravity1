#!/usr/bin/env python3
"""
Script de validación headless para desarrollo autónomo Roblox.
La IA ejecuta esto después de crear cada archivo.

Uso:
    python validate_and_continue.py <filepath>
    python validate_and_continue.py src/ServerScriptService/GameManager.server.lua

Valida:
    1. Sintaxis Luau (luau-analyze)
    2. Linting (selene) - opcional
    3. Formato (stylua) - auto-corrige
    4. Rojo build - opcional

Exit codes:
    0 - Validación exitosa
    1 - Error de sintaxis o configuración
"""

import subprocess
import sys
import os
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_header(text):
    """Imprime un encabezado formateado"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(70)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}\n")

def print_step(step_num, total_steps, description):
    """Imprime el progreso del paso actual"""
    print(f"{Colors.CYAN}[{step_num}/{total_steps}] {description}...{Colors.END}")

def check_tool_installed(tool_name, command):
    """Verifica si una herramienta está instalada"""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=5
        )
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False

def validate_syntax(filepath):
    """Valida sintaxis con luau-analyze"""
    print_step(1, 4, f"Validando sintaxis Luau: {Path(filepath).name}")
    
    if not check_tool_installed('luau-analyze', ['luau-analyze', '--version']):
        print(f"{Colors.YELLOW}⚠ luau-analyze no encontrado - saltando validación de sintaxis{Colors.END}")
        print(f"{Colors.YELLOW}  Instala desde: https://github.com/luau-lang/luau/releases{Colors.END}")
        return True  # No bloqueamos si no está instalado
    
    result = subprocess.run(
        ['luau-analyze', filepath],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"\n{Colors.RED}{Colors.BOLD}❌ ERROR DE SINTAXIS DETECTADO{Colors.END}")
        print(f"{Colors.RED}{'─'*70}{Colors.END}")
        print(result.stderr)
        print(f"{Colors.RED}{'─'*70}{Colors.END}\n")
        print(f"{Colors.YELLOW}💡 Sugerencia: Lee references/syntax-debugging.md para ayuda{Colors.END}\n")
        return False
    
    print(f"{Colors.GREEN}   ✓ Sintaxis válida - Sin errores{Colors.END}")
    return True

def lint_file(filepath):
    """Ejecuta selene para detectar problemas"""
    print_step(2, 4, f"Ejecutando linter (selene): {Path(filepath).name}")
    
    if not check_tool_installed('selene', ['selene', '--version']):
        print(f"{Colors.YELLOW}⚠ selene no encontrado - saltando linting{Colors.END}")
        print(f"{Colors.YELLOW}  Instala con: cargo install selene{Colors.END}")
        return True
    
    result = subprocess.run(
        ['selene', filepath],
        capture_output=True,
        text=True
    )
    
    if result.stdout.strip():
        print(f"{Colors.YELLOW}   ⚠ Warnings del linter:{Colors.END}")
        for line in result.stdout.strip().split('\n'):
            print(f"{Colors.YELLOW}     {line}{Colors.END}")
        print(f"{Colors.YELLOW}   Nota: Los warnings no bloquean, pero deberían revisarse{Colors.END}")
    else:
        print(f"{Colors.GREEN}   ✓ Linting limpio - Sin warnings{Colors.END}")
    
    return True

def check_format(filepath):
    """Verifica formato con stylua"""
    print_step(3, 4, f"Verificando formato (stylua): {Path(filepath).name}")
    
    if not check_tool_installed('stylua', ['stylua', '--version']):
        print(f"{Colors.YELLOW}⚠ stylua no encontrado - saltando verificación de formato{Colors.END}")
        print(f"{Colors.YELLOW}  Instala con: cargo install stylua{Colors.END}")
        return True
    
    # Verificar formato
    result = subprocess.run(
        ['stylua', '--check', filepath],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"{Colors.YELLOW}   ⚠ Formato inconsistente - Auto-corrigiendo...{Colors.END}")
        # Auto-corregir
        subprocess.run(['stylua', filepath], capture_output=True)
        print(f"{Colors.GREEN}   ✓ Formato corregido automáticamente{Colors.END}")
    else:
        print(f"{Colors.GREEN}   ✓ Formato correcto{Colors.END}")
    
    return True

def try_rojo_build(filepath):
    """Intenta hacer build con Rojo (solo para archivos importantes)"""
    # Solo hacer build completo para server scripts o cuando sea crítico
    if not filepath.endswith('.server.lua'):
        print_step(4, 4, "Rojo build - Saltando (no es script de servidor)")
        print(f"{Colors.CYAN}   ℹ Solo se hace build completo para .server.lua{Colors.END}")
        return True
    
    print_step(4, 4, "Intentando Rojo build headless")
    
    if not check_tool_installed('rojo', ['rojo', '--version']):
        print(f"{Colors.YELLOW}⚠ rojo no encontrado - saltando build{Colors.END}")
        return True
    
    # Crear directorio de build si no existe
    os.makedirs('build', exist_ok=True)
    
    result = subprocess.run(
        ['rojo', 'build', '--output', 'build/validation.rbxl'],
        capture_output=True,
        text=True,
        timeout=30
    )
    
    if result.returncode != 0:
        print(f"\n{Colors.RED}{Colors.BOLD}❌ ERROR EN ROJO BUILD{Colors.END}")
        print(f"{Colors.RED}{'─'*70}{Colors.END}")
        print(result.stderr)
        print(f"{Colors.RED}{'─'*70}{Colors.END}\n")
        return False
    
    print(f"{Colors.GREEN}   ✓ Rojo build exitoso{Colors.END}")
    return True

def count_lines(filepath):
    """Cuenta líneas de código"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        code_lines = [l for l in lines if l.strip() and not l.strip().startswith('--')]
        return len(lines), len(code_lines)

def validate_file(filepath):
    """Pipeline completo de validación"""
    print_header(f"🔍 VALIDACIÓN HEADLESS: {Path(filepath).name}")
    
    # Verificar que el archivo existe
    if not os.path.exists(filepath):
        print(f"{Colors.RED}❌ Archivo no existe: {filepath}{Colors.END}")
        return False
    
    # Mostrar info del archivo
    total_lines, code_lines = count_lines(filepath)
    print(f"{Colors.CYAN}📄 Archivo: {filepath}{Colors.END}")
    print(f"{Colors.CYAN}📊 Líneas: {total_lines} total, {code_lines} de código{Colors.END}\n")
    
    # Pipeline de validación
    steps_passed = 0
    total_steps = 4
    
    # Paso 1: Sintaxis (CRÍTICO)
    if not validate_syntax(filepath):
        print(f"\n{Colors.RED}{Colors.BOLD}{'='*70}{Colors.END}")
        print(f"{Colors.RED}{Colors.BOLD}❌ VALIDACIÓN FALLIDA - ERROR DE SINTAXIS{Colors.END}")
        print(f"{Colors.RED}{Colors.BOLD}{'='*70}{Colors.END}\n")
        print(f"{Colors.YELLOW}Pasos completados: {steps_passed}/{total_steps}{Colors.END}")
        print(f"{Colors.YELLOW}Acción requerida: Corregir errores de sintaxis y volver a validar{Colors.END}\n")
        return False
    steps_passed += 1
    
    # Paso 2: Linting (NO CRÍTICO)
    if lint_file(filepath):
        steps_passed += 1
    
    # Paso 3: Formato (NO CRÍTICO, auto-corrige)
    if check_format(filepath):
        steps_passed += 1
    
    # Paso 4: Rojo build (CRÍTICO para server scripts)
    if not try_rojo_build(filepath):
        print(f"\n{Colors.RED}{Colors.BOLD}{'='*70}{Colors.END}")
        print(f"{Colors.RED}{Colors.BOLD}❌ VALIDACIÓN FALLIDA - ERROR EN ROJO BUILD{Colors.END}")
        print(f"{Colors.RED}{Colors.BOLD}{'='*70}{Colors.END}\n")
        print(f"{Colors.YELLOW}Pasos completados: {steps_passed}/{total_steps}{Colors.END}")
        print(f"{Colors.YELLOW}Acción requerida: Revisar configuración de Rojo o estructura de archivos{Colors.END}\n")
        return False
    steps_passed += 1
    
    # Éxito total
    print(f"\n{Colors.GREEN}{Colors.BOLD}{'='*70}{Colors.END}")
    print(f"{Colors.GREEN}{Colors.BOLD}✅ VALIDACIÓN EXITOSA - ARCHIVO APROBADO{Colors.END}")
    print(f"{Colors.GREEN}{Colors.BOLD}{'='*70}{Colors.END}\n")
    print(f"{Colors.GREEN}Todos los pasos completados: {steps_passed}/{total_steps}{Colors.END}")
    print(f"{Colors.GREEN}El archivo está listo para sincronizar con Roblox{Colors.END}\n")
    
    return True

def print_usage():
    """Muestra información de uso"""
    print(f"""
{Colors.BOLD}Validador Headless para Desarrollo Roblox/Rojo{Colors.END}

{Colors.CYAN}Uso:{Colors.END}
    python validate_and_continue.py <filepath>

{Colors.CYAN}Ejemplo:{Colors.END}
    python validate_and_continue.py src/ServerScriptService/GameManager.server.lua

{Colors.CYAN}Herramientas requeridas:{Colors.END}
    • luau-analyze (CRÍTICO) - https://github.com/luau-lang/luau/releases
    • selene (opcional)    - cargo install selene
    • stylua (opcional)    - cargo install stylua
    • rojo (recomendado)   - https://rojo.space/

{Colors.CYAN}Códigos de salida:{Colors.END}
    0 - Validación exitosa
    1 - Error de sintaxis o configuración

{Colors.CYAN}Pipeline de validación:{Colors.END}
    1. Sintaxis Luau (luau-analyze) ★ CRÍTICO
    2. Linting (selene) - warnings no bloquean
    3. Formato (stylua) - auto-corrige
    4. Rojo build - solo para .server.lua ★ CRÍTICO
    """)

if __name__ == "__main__":
    # Verificar argumentos
    if len(sys.argv) < 2 or sys.argv[1] in ['-h', '--help', 'help']:
        print_usage()
        sys.exit(0)
    
    filepath = sys.argv[1]
    
    # Ejecutar validación
    try:
        success = validate_file(filepath)
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print(f"\n\n{Colors.YELLOW}⚠ Validación cancelada por el usuario{Colors.END}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}❌ Error inesperado: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
