#!/usr/bin/env python3
"""
Validador batch para múltiples archivos Luau.
Útil cuando la IA crea varios archivos en una tarea.

Uso:
    python batch_validate.py src/ServerScriptService/*.lua
    python batch_validate.py --all  # Valida todo el proyecto
"""

import subprocess
import sys
import os
from pathlib import Path
import glob

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'

def find_all_lua_files():
    """Encuentra todos los archivos .lua en src/"""
    lua_files = []
    for pattern in ['src/**/*.lua', 'src/**/*.server.lua', 'src/**/*.client.lua']:
        lua_files.extend(glob.glob(pattern, recursive=True))
    return lua_files

def validate_batch(files):
    """Valida múltiples archivos"""
    total = len(files)
    passed = 0
    failed = 0
    failed_files = []
    
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}VALIDACIÓN BATCH - {total} archivos{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}\n")
    
    for i, filepath in enumerate(files, 1):
        print(f"{Colors.CYAN}[{i}/{total}] Validando: {Path(filepath).name}{Colors.END}")
        
        result = subprocess.run(
            ['python3', 'scripts/validate_and_continue.py', filepath],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            passed += 1
            print(f"{Colors.GREEN}✓ Pasó{Colors.END}\n")
        else:
            failed += 1
            failed_files.append(filepath)
            print(f"{Colors.RED}✗ Falló{Colors.END}")
            # Mostrar solo la parte relevante del error
            lines = result.stdout.split('\n')
            for line in lines:
                if 'ERROR' in line or '❌' in line:
                    print(f"{Colors.RED}  {line}{Colors.END}")
            print()
    
    # Resumen
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}RESUMEN DE VALIDACIÓN{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}\n")
    
    print(f"Total de archivos: {total}")
    print(f"{Colors.GREEN}Pasaron: {passed} ({passed/total*100:.1f}%){Colors.END}")
    print(f"{Colors.RED}Fallaron: {failed} ({failed/total*100:.1f}%){Colors.END}\n")
    
    if failed_files:
        print(f"{Colors.RED}Archivos con errores:{Colors.END}")
        for filepath in failed_files:
            print(f"{Colors.RED}  • {filepath}{Colors.END}")
        print()
        return False
    else:
        print(f"{Colors.GREEN}{Colors.BOLD}✅ ¡Todos los archivos validados exitosamente!{Colors.END}\n")
        return True

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] in ['-h', '--help']:
        print(f"""
{Colors.BOLD}Validador Batch para Roblox/Rojo{Colors.END}

{Colors.CYAN}Uso:{Colors.END}
    python batch_validate.py <archivos...>
    python batch_validate.py --all
    python batch_validate.py src/ServerScriptService/*.lua

{Colors.CYAN}Ejemplos:{Colors.END}
    python batch_validate.py --all
    python batch_validate.py src/ServerScriptService/GameManager.server.lua src/shared/Modules/EventManager.lua
    python batch_validate.py src/**/*.server.lua
        """)
        sys.exit(0)
    
    if sys.argv[1] == '--all':
        files = find_all_lua_files()
        if not files:
            print(f"{Colors.RED}No se encontraron archivos .lua en src/{Colors.END}")
            sys.exit(1)
    else:
        files = sys.argv[1:]
    
    success = validate_batch(files)
    sys.exit(0 if success else 1)
