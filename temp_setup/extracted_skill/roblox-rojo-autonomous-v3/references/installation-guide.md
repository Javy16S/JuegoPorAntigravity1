# Guía de Instalación - Herramientas Headless

Esta guía te ayudará a instalar todas las herramientas necesarias para validación headless.

## ⚙️ Herramientas Necesarias

### 1. luau-analyze (CRÍTICO) ⭐

Valida sintaxis y tipos de Luau sin necesidad de Roblox Studio.

**Windows:**
```powershell
# 1. Descargar desde GitHub
# Ve a: https://github.com/luau-lang/luau/releases
# Descarga: luau-win64.zip (latest release)

# 2. Extraer el archivo
# Extrae luau-analyze.exe a una carpeta, ejemplo: C:\Tools\Luau

# 3. Añadir al PATH
# Panel de Control → Sistema → Variables de entorno
# Editar "Path" del sistema → Nuevo → C:\Tools\Luau

# 4. Verificar instalación
luau-analyze --version
```

**macOS:**
```bash
# Con Homebrew (recomendado)
brew install luau

# Verificar
luau-analyze --version
```

**Linux (Ubuntu/Debian):**
```bash
# Descargar binary
wget https://github.com/luau-lang/luau/releases/download/0.607/luau-ubuntu.zip

# Extraer
unzip luau-ubuntu.zip

# Mover a /usr/local/bin
sudo mv luau-analyze /usr/local/bin/
sudo chmod +x /usr/local/bin/luau-analyze

# Verificar
luau-analyze --version
```

---

### 2. Rust (para selene y stylua)

**Todas las plataformas:**
```bash
# Instalar Rust con rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# En Windows, descarga desde: https://rustup.rs/
# Sigue el instalador

# Reinicia tu terminal después de instalar

# Verificar
rustc --version
cargo --version
```

---

### 3. selene (Recomendado)

Linter avanzado para Luau con soporte específico de Roblox.

```bash
# Instalar con cargo
cargo install selene

# Verificar
selene --version
```

**Tiempo de instalación:** 5-10 minutos (compila desde source)

---

### 4. stylua (Recomendado)

Auto-formateador de código Luau.

```bash
# Instalar con cargo
cargo install stylua

# Verificar
stylua --version
```

**Tiempo de instalación:** 3-5 minutos

---

### 5. Python 3 (Ya deberías tenerlo)

```bash
# Verificar versión (necesitas 3.7+)
python3 --version

# Si no tienes Python:
# Windows: https://www.python.org/downloads/
# macOS: brew install python3
# Linux: sudo apt install python3
```

---

## ✅ Verificación de Instalación

Ejecuta este script para verificar todas las herramientas:

```bash
# Crea un archivo check_tools.sh
cat > check_tools.sh << 'EOF'
#!/bin/bash

echo "🔍 Verificando herramientas instaladas..."
echo ""

# luau-analyze
if command -v luau-analyze &> /dev/null; then
    echo "✅ luau-analyze: $(luau-analyze --version)"
else
    echo "❌ luau-analyze: NO INSTALADO (CRÍTICO)"
fi

# selene
if command -v selene &> /dev/null; then
    echo "✅ selene: $(selene --version)"
else
    echo "⚠️  selene: NO INSTALADO (opcional)"
fi

# stylua
if command -v stylua &> /dev/null; then
    echo "✅ stylua: $(stylua --version)"
else
    echo "⚠️  stylua: NO INSTALADO (opcional)"
fi

# rojo
if command -v rojo &> /dev/null; then
    echo "✅ rojo: $(rojo --version)"
else
    echo "⚠️  rojo: NO INSTALADO (recomendado)"
fi

# python
if command -v python3 &> /dev/null; then
    echo "✅ python3: $(python3 --version)"
else
    echo "❌ python3: NO INSTALADO (CRÍTICO)"
fi

echo ""
echo "Estado de instalación:"
echo "  CRÍTICO: luau-analyze, python3"
echo "  RECOMENDADO: rojo"
echo "  OPCIONAL: selene, stylua"
EOF

chmod +x check_tools.sh
./check_tools.sh
```

**En Windows (PowerShell):**
```powershell
# check_tools.ps1
Write-Host "🔍 Verificando herramientas instaladas..."
Write-Host ""

# luau-analyze
if (Get-Command luau-analyze -ErrorAction SilentlyContinue) {
    Write-Host "✅ luau-analyze instalado"
} else {
    Write-Host "❌ luau-analyze: NO INSTALADO (CRÍTICO)"
}

# selene
if (Get-Command selene -ErrorAction SilentlyContinue) {
    Write-Host "✅ selene instalado"
} else {
    Write-Host "⚠️  selene: NO INSTALADO (opcional)"
}

# stylua
if (Get-Command stylua -ErrorAction SilentlyContinue) {
    Write-Host "✅ stylua instalado"
} else {
    Write-Host "⚠️  stylua: NO INSTALADO (opcional)"
}

# python
if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Host "✅ python instalado"
} else {
    Write-Host "❌ python: NO INSTALADO (CRÍTICO)"
}
```

---

## 🚀 Instalación Rápida (Recomendada)

### macOS (5 minutos)
```bash
# Instalar Homebrew si no lo tienes
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar todas las herramientas
brew install luau rust python3

# Instalar selene y stylua con cargo
cargo install selene stylua

# Verificar
luau-analyze --version && selene --version && stylua --version
```

### Ubuntu/Debian Linux (10 minutos)
```bash
# Actualizar sistema
sudo apt update

# Instalar Python y dependencias
sudo apt install -y python3 python3-pip curl wget unzip

# Instalar Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Instalar luau-analyze
wget https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
unzip luau-ubuntu.zip
sudo mv luau-analyze /usr/local/bin/
sudo chmod +x /usr/local/bin/luau-analyze

# Instalar selene y stylua
cargo install selene stylua

# Verificar
luau-analyze --version && selene --version && stylua --version
```

### Windows (15 minutos)

1. **Instalar Python:**
   - Descargar desde: https://www.python.org/downloads/
   - Durante instalación: marcar "Add Python to PATH"

2. **Instalar Rust:**
   - Descargar desde: https://rustup.rs/
   - Ejecutar instalador y seguir instrucciones
   - Reiniciar terminal

3. **Instalar luau-analyze:**
   - Descargar desde: https://github.com/luau-lang/luau/releases
   - Buscar "luau-win64.zip"
   - Extraer a `C:\Tools\Luau`
   - Añadir al PATH (Panel de Control → Sistema → Variables de entorno)

4. **Instalar selene y stylua:**
   ```powershell
   cargo install selene
   cargo install stylua
   ```

5. **Verificar todo:**
   ```powershell
   luau-analyze --version
   selene --version
   stylua --version
   python --version
   ```

---

## 📊 Comparación de Herramientas

| Herramienta | Propósito | Crítica | Tiempo Install |
|-------------|-----------|---------|----------------|
| luau-analyze | Validación sintaxis | ✅ Sí | 2 min |
| selene | Linting/warnings | ⚠️ No | 5-10 min |
| stylua | Auto-formato | ⚠️ No | 3-5 min |
| python3 | Scripts | ✅ Sí | Ya instalado |
| rojo | Build headless | ⚠️ No* | Ya instalado |

\* Rojo ya lo tienes instalado para sync, pero también se usa para builds headless.

---

## 🔧 Configuración Post-Instalación

Después de instalar, crea estos archivos en la raíz de tu proyecto:

### selene.toml
```toml
std = "roblox"

[rules]
unused_variable = "warn"
undefined_variable = "warn"
shadowing = "warn"
```

### stylua.toml
```toml
column_width = 100
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 4
quote_style = "AutoPreferDouble"
```

---

## ✅ Test de Validación

Prueba el sistema completo:

```bash
# 1. Crea un archivo de prueba
cat > test.lua << 'EOF'
local function test()
    print("Hello World")
end
EOF

# 2. Ejecuta validación
python3 scripts/validate_and_continue.py test.lua

# 3. Deberías ver:
# ✓ Sintaxis válida
# ✓ Linting limpio
# ✓ Formato correcto
# ✅ VALIDACIÓN EXITOSA
```

---

## ❓ Troubleshooting

### "luau-analyze: command not found"

**Problema:** El PATH no está configurado correctamente.

**Solución:**
```bash
# macOS/Linux: Añadir a ~/.bashrc o ~/.zshrc
export PATH="$PATH:/ruta/donde/instalaste/luau"

# Windows: Añadir al PATH del sistema
# Panel de Control → Sistema → Variables de entorno
```

### "cargo: command not found"

**Problema:** Rust no está instalado o el terminal no se reinició.

**Solución:**
1. Instalar Rust: https://rustup.rs/
2. Reiniciar terminal
3. Verificar: `cargo --version`

### Errores de permisos en Linux

```bash
# Si luau-analyze no tiene permisos
sudo chmod +x /usr/local/bin/luau-analyze

# Si cargo install falla por permisos
# Instala sin sudo, usará ~/.cargo/bin
```

---

## 📈 Tiempo Total de Instalación

| Sistema | Tiempo Estimado |
|---------|-----------------|
| macOS | 5-10 minutos |
| Linux | 10-15 minutos |
| Windows | 15-20 minutos |

**Incluye:**
- Descargas
- Instalaciones
- Configuración
- Verificación

---

## 🎯 Próximos Pasos

Una vez instaladas todas las herramientas:

1. ✅ Ejecuta `check_tools.sh` para verificar
2. ✅ Prueba `validate_and_continue.py` con un archivo
3. ✅ Lee `SKILL.md` actualizado para ver el nuevo workflow
4. ✅ Empieza a usar el desarrollo headless autónomo

---

## 💡 Tips

- **Mínimo viable:** Solo necesitas `luau-analyze` y `python3`
- **Recomendado:** Añade `selene` para mejor calidad de código
- **Opcional:** `stylua` si quieres formato automático
- **Actualiza regularmente:** `cargo install --force selene stylua`
