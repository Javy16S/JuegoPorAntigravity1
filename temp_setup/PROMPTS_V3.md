# 📋 Prompt Optimizado para Desarrollo Headless v3.0

## Prompt Principal (Copia y Pega)

```markdown
🚀 **DESARROLLO HEADLESS AUTÓNOMO - ROBLOX v3.0**

**Skill**: roblox-rojo-autonomous v3.0 (headless validation)
**Modo**: Autónomo con validación automática en cada archivo

## CONFIGURACIÓN DEL PIPELINE:

**Pipeline de Validación Obligatorio:**
Para CADA archivo .lua que crees, ejecuta este flujo SIN EXCEPCIONES:

1. ✅ Generar código completo (sin TODOs)
2. ✅ Pre-validación mental (mostrar [Pre-Flight Syntax Check])
3. ✅ Escribir archivo a disco
4. ✅ **EJECUTAR:** `python3 scripts/validate_and_continue.py <filepath>`
5. ✅ **Esperar resultado:**
   - Si ✅ VALIDACIÓN EXITOSA → Marcar tarea como COMPLETADA & VALIDADA
   - Si ❌ ERROR DETECTADO → DETENER, corregir, re-validar, solo continuar cuando PASS
6. ✅ Solo después de validación exitosa → Continuar siguiente tarea

**REGLA CRÍTICA:** NUNCA avances a la siguiente tarea sin validación exitosa (exit code 0).

## HERRAMIENTAS DISPONIBLES:

✅ `luau-analyze` - Validación de sintaxis y tipos
✅ `selene` - Linting y best practices  
✅ `stylua` - Auto-formatting
✅ `rojo build` - Verificación de proyecto
✅ Python scripts - Automatización del pipeline

## FORMATO DE OUTPUT ESPERADO:

```
[Tarea 1.1: Crear EventManager.server.lua]

[Pre-Flight Syntax Check]
✓ Function blocks: 3 opens, 3 closes
✓ If statements: 2 opens, 2 closes
✓ For loops: 1 open, 1 close
✓ Mental validation PASSED

[Escribiendo archivo...]
Creado: src/ServerScriptService/EventManager.server.lua

[Ejecutando validación headless...]
$ python3 scripts/validate_and_continue.py src/ServerScriptService/EventManager.server.lua

🔍 VALIDACIÓN HEADLESS: EventManager.server.lua
[1/4] Validando sintaxis Luau...
   ✓ Sintaxis válida - Sin errores
[2/4] Ejecutando linter...
   ✓ Linting limpio - Sin warnings
[3/4] Verificando formato...
   ✓ Formato correcto
[4/4] Intentando Rojo build...
   ✓ Rojo build exitoso

✅ VALIDACIÓN EXITOSA - ARCHIVO APROBADO

✓ [1.1] EventManager.server.lua COMPLETADO & VALIDADO

[Continuando inmediatamente con tarea 1.2...]
```

## ROADMAP:

### 1. [SISTEMA 1]
1.1. [Tarea específica]
1.2. [Tarea específica]
1.3. [Tarea específica]

### 2. [SISTEMA 2]
2.1. [Tarea específica]
2.2. [Tarea específica]

### 3. [SISTEMA 3]
3.1. [Tarea específica]

## MANEJO DE ERRORES:

Si la validación falla:
```
❌ ERROR DE SINTAXIS DETECTADO
──────────────────────────────────────────────────────────────────
src/ServerScriptService/Broken.lua:15:1: Expected 'end' (to close 'function' at line 10), got <eof>
──────────────────────────────────────────────────────────────────
```

**Acción requerida:**
1. DETENER inmediatamente
2. Leer references/syntax-debugging.md si es necesario
3. Corregir el error en el archivo
4. Re-ejecutar validación
5. Solo continuar cuando veas ✅ VALIDACIÓN EXITOSA

## NOTAS ESPECIALES:

[Opcional: Contexto adicional específico de tu proyecto]

---

**EMPIEZA AHORA** con la tarea 1.1.

Recuerda el flujo: Generar → Pre-check → Escribir → **Validar** → (si PASS) Completar → Continuar.

NO saltes la validación. NO acumules errores. Un archivo a la vez, validado antes de continuar.
```

---

## Variaciones del Prompt

### Para Proyectos Grandes (20+ tareas)

```markdown
🚀 **DESARROLLO HEADLESS MASIVO**

Skill: roblox-rojo-autonomous v3.0
Roadmap extenso - Validación headless en cada paso

## ESTRATEGIA:

Trabajarás en [X] tareas secuencialmente. Después de cada 5 tareas, harás un resumen de progreso.

Para CADA archivo:
1. Generar código completo
2. Pre-validación mental  
3. Escribir archivo
4. `python3 scripts/validate_and_continue.py <file>`
5. Solo continuar si PASS

## ROADMAP:

[Tu roadmap extenso aquí]

Trabaja autónomamente. Si llegas a la tarea 10 y necesitas pausa, dilo. De lo contrario, completa todo.

EMPIEZA CON 1.1.
```

### Para Debugging de Errores Existentes

```markdown
🔧 **MODO FIX: Validar y Corregir Proyecto Existente**

Skill: roblox-rojo-autonomous v3.0

## OBJETIVO:

Tengo errores de sintaxis acumulados en mi proyecto. Necesito que:

1. Ejecutes: `python3 scripts/batch_validate.py --all`
2. Identifiques todos los archivos con errores
3. Para cada archivo con error:
   - Leas el error
   - Consultes references/syntax-debugging.md
   - Corrijas el error
   - Re-valides hasta que pase
4. Reportes resumen final

## ACCIÓN:

Empieza ejecutando batch_validate.py ahora.
```

### Para Revisión de Calidad

```markdown
🔍 **MODO AUDIT: Revisión de Calidad del Código**

Skill: roblox-rojo-autonomous v3.0

## OBJETIVO:

Revisar la calidad de código existente sin modificar funcionalidad.

Para cada archivo en src/:
1. Ejecutar validación headless
2. Si pasa → Reportar "✓ OK"
3. Si falla o tiene warnings → Corregir y optimizar
4. Aplicar mejores prácticas de la skill

## ARCHIVOS A REVISAR:

- src/ServerScriptService/*.server.lua
- src/shared/Modules/*.lua

Genera un reporte de calidad al final.

EMPIEZA AHORA.
```

---

## Modificadores Útiles

### Añade al prompt según necesidad:

**Modo Verbose (Explicativo):**
```markdown
**MODO DEBUG**: Muestra tu razonamiento en cada paso.
Explica qué estás validando y por qué cada paso pasa o falla.
```

**Modo Silencioso (Resultados Solo):**
```markdown
**MODO CONCISO**: Solo muestra:
- ✓ [X.Y] COMPLETADO & VALIDADO
- ❌ [X.Y] ERROR (si falla)
Omite output de validación si pasa.
```

**Modo Paranoid (Extra Seguro):**
```markdown
**MODO PARANOID**: 
- Lee references/syntax-debugging.md ANTES de cada tarea
- Ejecuta batch_validate.py después de cada 3 archivos creados
- Doble-check mental antes de marcar completado
```

**Modo Rápido (Mínima Validación):**
```markdown
**MODO RÁPIDO**:
Solo valida con luau-analyze (sintaxis).
Salta selene y stylua para velocidad.
```

---

## Ejemplos Reales Listos para Usar

### Ejemplo 1: Sistema de Achievements

```markdown
🚀 DESARROLLO HEADLESS - SISTEMA DE ACHIEVEMENTS

Skill: roblox-rojo-autonomous v3.0

Pipeline: Generar → Pre-check → Escribir → Validar → (PASS) Continuar

ROADMAP:

### 1. Sistema de Logros
1.1. AchievementDefinitions.lua - 15 achievements (Common a Legendary)
1.2. AchievementManager.server.lua - Tracking y unlock logic
1.3. AchievementNotifier.client.lua - UI animada con TweenService
1.4. AchievementData integration - Guardar en ProfileService

NOTAS:
- Achievements: "First Blood", "Millionaire", "Rare Collector", etc.
- UI: Estilo notificación top-right con slide-in animation
- Data: Tabla separada en BrainrotData.Achievements

EMPIEZA CON 1.1 AHORA.
```

### Ejemplo 2: Sistema de Eventos Rotatorios

```markdown
🚀 DESARROLLO HEADLESS - EVENTOS DINÁMICOS

Skill: roblox-rojo-autonomous v3.0

Pipeline obligatorio con validación en cada archivo.

ROADMAP:

### 1. Event System
1.1. EventDefinitions.lua - Config de 8 eventos
1.2. EventManager.server.lua - Weighted random selection + rotation
1.3. MeteorEvent.lua - Lluvia de meteoritos con explosiones
1.4. LavaRiseEvent.lua - Aceleración temporal de lava
1.5. GoldenHourEvent.lua - SuperEvento x10 income
1.6. EventNotifier.client.lua - UI de evento activo

NOTAS:
- Eventos rotan cada 5 minutos
- Advertencia 10s antes de cambio
- SuperEventos tienen 2% chance

EMPIEZA CON 1.1.
```

### Ejemplo 3: Migración/Refactor

```markdown
🔧 REFACTOR HEADLESS - LIMPIAR CÓDIGO LEGACY

Skill: roblox-rojo-autonomous v3.0

OBJETIVO: Refactorizar archivos existentes con validación.

ARCHIVOS A REFACTORIZAR:

1. src/ServerScriptService/OldManager.server.lua
   - Separar en módulos
   - Aplicar convenciones de naming
   - Validar cada módulo nuevo

2. src/shared/Modules/MessyUtils.lua
   - Reorganizar funciones
   - Añadir type annotations
   - Validar resultado

REGLAS:
- Mantener funcionalidad exacta
- Mejorar estructura y legibilidad
- Validación headless obligatoria en cada cambio

EMPIEZA CON OldManager.server.lua.
```

---

## Checklist Pre-Prompt

Antes de enviar, verifica:

- [ ] Mencionas "roblox-rojo-autonomous v3.0"
- [ ] Explicas el pipeline de validación
- [ ] Roadmap numerado y específico
- [ ] Dices "EMPIEZA AHORA" al final
- [ ] Incluyes regla de NO avanzar sin validación
- [ ] (Opcional) Contexto específico del proyecto

---

## 🎯 Prompt Minimalista (Si Ya Trabajaste con la Skill)

```markdown
Skill v3.0 headless. Valida cada archivo con validate_and_continue.py.

ROADMAP:
[Tu roadmap]

GO.
```

**Nota:** Solo usa esto si ya hiciste varias sesiones y la IA conoce el flujo.

---

¡Con estos prompts, la IA trabajará autónomamente validando cada paso! 🚀
