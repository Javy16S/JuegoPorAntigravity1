# 🚀 Guía Rápida - Skill v3.0 Headless Validation

## ⚡ Setup Rápido (Primera Vez) - 30 minutos

### Paso 1: Descargar e Instalar Skill (2 min)

1. Elimina la Skill anterior de Claude.ai o Antigravity
2. Importa `roblox-rojo-autonomous-v3.skill`
3. La Skill se activará automáticamente

### Paso 2: Extraer Scripts al Proyecto (3 min)

La Skill contiene scripts Python que necesitas en tu proyecto:

```bash
# En la raíz de tu proyecto Roblox
mkdir -p scripts

# La IA copiará automáticamente los scripts cuando los necesite, O:
# Extrae manualmente el .skill (es un ZIP) y copia scripts/ a tu proyecto
```

Archivos que necesitas:
```
tu-proyecto/
├── scripts/
│   ├── validate_and_continue.py  ← Script principal
│   └── batch_validate.py          ← Validación múltiple
├── selene.toml                    ← Config linter
├── stylua.toml                    ← Config formatter
└── src/                           ← Tu código
```

### Paso 3: Instalar Herramientas (20-25 min)

**CRÍTICAS (obligatorias):**

```bash
# 1. luau-analyze
# Windows: https://github.com/luau-lang/luau/releases → luau-win64.zip
# macOS: brew install luau
# Linux: wget + install (ver installation-guide.md)

# Verificar
luau-analyze --version
```

**RECOMENDADAS (mejor calidad):**

```bash
# 2. Instalar Rust (si no lo tienes)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Windows: https://rustup.rs/

# 3. selene (linter)
cargo install selene

# 4. stylua (formatter)
cargo install stylua

# Verificar todo
luau-analyze --version && selene --version && stylua --version
```

**Si tienes prisa:** Solo instala `luau-analyze`. Es suficiente para empezar.

---

## 🎯 Uso Diario

### Prompt para la IA

```markdown
🚀 DESARROLLO HEADLESS AUTÓNOMO

**Skill**: roblox-rojo-autonomous v3.0
**Modo**: Headless con validación automática

## WORKFLOW OBLIGATORIO:

Para CADA archivo .lua creado:
1. Generar código completo
2. Pre-validación mental
3. Escribir archivo
4. EJECUTAR: python3 scripts/validate_and_continue.py <filepath>
5. Si ✅ PASS → Marcar completado y continuar
6. Si ❌ FAIL → Corregir → Re-validar → Continuar solo cuando PASS

NO marques NINGUNA tarea como completada sin validación headless exitosa.

## ROADMAP:

[Tu roadmap aquí]

---

EMPIEZA AHORA con 1.1. Recuerda: Código → Validar → Continuar.
```

### Ejemplo de Ejecución

**Tú escribes:**
```
1. Sistema de Misiones
   1.1. QuestDefinitions.lua
   1.2. QuestManager.server.lua
   1.3. QuestUI.client.lua
```

**La IA hace:**
```
[Generando QuestDefinitions.lua...]

[Pre-Flight Syntax Check]
✓ Function blocks: 2 opens, 2 closes
✓ Table literals: 5 opens, 5 closes
✓ Mental validation PASSED

[Escribiendo archivo src/shared/Modules/QuestDefinitions.lua...]

[Ejecutando validación headless...]
$ python3 scripts/validate_and_continue.py src/shared/Modules/QuestDefinitions.lua

🔍 VALIDACIÓN HEADLESS: QuestDefinitions.lua
[1/4] Validando sintaxis Luau...
   ✓ Sintaxis válida
[2/4] Linting...
   ✓ Linting limpio
[3/4] Formato...
   ✓ Formato correcto
[4/4] Rojo build...
   ℹ Saltando (no es .server.lua)

✅ VALIDACIÓN EXITOSA - ARCHIVO APROBADO

✓ [1.1] QuestDefinitions.lua COMPLETADO & VALIDADO

[Continuando con 1.2...]
```

---

## 🔧 Troubleshooting

### "Command not found: luau-analyze"

```bash
# Verifica que esté en PATH
which luau-analyze  # macOS/Linux
where luau-analyze  # Windows

# Si no aparece, añade al PATH
export PATH="$PATH:/ruta/donde/instalaste"
```

### "Validation keeps failing"

1. Lee el error cuidadosamente
2. Dile a la IA: `"Lee references/syntax-debugging.md y corrige el error"`
3. La IA corregirá automáticamente

### "Herramientas opcionales no instaladas"

¡No pasa nada! El script mostrará warnings pero no bloqueará:

```
⚠ selene no encontrado - saltando linting
⚠ stylua no encontrado - saltando formato
```

Solo `luau-analyze` es crítico.

---

## 📊 Comparación vs Versiones Anteriores

| Feature | v1.0 | v2.0 | v3.0 |
|---------|------|------|------|
| Validación mental | ❌ | ✅ | ✅ |
| Validación real | ❌ | ❌ | ✅ |
| Headless pipeline | ❌ | ❌ | ✅ |
| Auto-corrección | ❌ | ❌ | ✅ |
| 100% consola | ❌ | ❌ | ✅ |
| Errores acumulados | ⚠️ Sí | ⚠️ Pocos | ✅ Cero |

---

## 🎯 Tips Pro

### 1. Validación Batch

Si la IA crea 5 archivos en una tarea:

```bash
python3 scripts/batch_validate.py src/ServerScriptService/*.lua
```

### 2. Validar Todo el Proyecto

```bash
python3 scripts/batch_validate.py --all
```

Útil antes de hacer push a Git.

### 3. CI/CD Integration

Añade a `.github/workflows/validate.yml`:

```yaml
name: Validate Luau
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install luau
        run: |
          wget https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
          unzip luau-ubuntu.zip
          sudo mv luau-analyze /usr/local/bin/
      - name: Validate All
        run: python3 scripts/batch_validate.py --all
```

### 4. Pre-Commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
python3 scripts/batch_validate.py --all
if [ $? -ne 0 ]; then
    echo "❌ Validation failed. Commit aborted."
    exit 1
fi
```

---

## ✅ Checklist de Verificación

Antes de empezar tu primera sesión:

- [ ] Skill v3.0 instalada en Claude.ai
- [ ] Scripts copiados a `scripts/` en tu proyecto
- [ ] `luau-analyze` instalado y en PATH
- [ ] (Opcional) `selene` y `stylua` instalados
- [ ] Configs `selene.toml` y `stylua.toml` en raíz del proyecto
- [ ] Test: `python3 scripts/validate_and_continue.py <archivo-test.lua>`

---

## 🚀 ¡Listo para Empezar!

Ya tienes todo configurado. Ahora puedes:

1. **Dar el prompt a la IA** con tu roadmap
2. **Observar** cómo valida automáticamente cada archivo
3. **Disfrutar** de desarrollo sin errores acumulados
4. **Iterar rápido** con confianza total en el código

**El sistema ahora trabaja completamente desde consola, validando cada paso antes de continuar. ¡Cero errores acumulados! 🎉**
