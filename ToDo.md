# 📋 Brainrot Tsunami - ToDo & Roadmap

## 🔥 Prioridad Alta (Bugs/Fixes)
- [x] **UI de Unidades:** Verificar que aparece correctamente sobre Brainrots colocados *Por revisar
- [x] **Upgrade Button:** Arreglar que el botón UPGRADE funcione y suba el nivel del Brainrot *Por revisar
- [x] **Economía:** Confirmar que los ingresos se acumulan y muestran correctamente *Por revisar
- [x] **Valores Oscilantes:** Cada Brainrot tiene multiplicador único (x1-x10) al INGRESO/S *Por revisar
- [x] **Tienda de Venta:** Arreglados handlers para buscar por UnitId en lugar de nombre *Por revisar

## 🎮 Core Features Pendientes
- [x] **Sistema de Achievements:** Logros por coleccionar Brainrots, alcanzar dinero, etc.
- [x] **Leaderboards:** Ranking de jugadores por dinero total / Brainrots raros
- [x] **Save/Load:** Verificar persistencia de datos (slots, inventario, mejoras)

## 🌊 Tsunami & Map
- [x] **Nuevos Tipos de Lava:** Más variaciones visuales y efectos
- [x] **Zonas Seguras:** Añadir plataformas/refugios temporales
- [x] **Eventos Especiales:** Meteoritos, erupciones extra, etc.

## 🎨 Polish Visual
- [x] **Animaciones de Mejora:** Efecto visual al subir de nivel un Brainrot
- [x] **Ui de Inventario:** Permitir arrastrar brainrots a slots vacíos y que se muevan fluidamente, permitir slots vacíos en el inventario principal (Hotbar). 
- [x] **Partículas Shinies:** Mejorar el efecto de las unidades Shiny
- [x] **Sonidos:** SFX para clicks, upgrades, oleadas de tsunami

## Mutaciones
- [x] **Categoría:** Crear tipos de mutaciones a partir de cambios en las meshes de los brainrots y la adición de partículas y efectos visuales.
- [x] **Sistema:** Crear sistema de mutación aleatoria por probabilidad para que aparezca sobre un brainrot.
- [x] **Interfaz:** Añadir al HUD del brainrot el espacio necesario para que se vea el texto de la mutación con el color asignado. (Una mutación radioactiva mostrará texto en color radioactivo, una de dinero lo mostrará en color dorado, etc.) 
- [x] **Eventos:** Añadir a la tabla de eventos posibles un Evento de mutación aleatoria para todos los brainrots.

## 💰 Economía Avanzada
- [x] **Rebirth System:** Reiniciar progreso por multiplicadores permanentes
- [ ] **Pets/Boosts:** (Plan: [implementation_plan_pets_boosts.md](file:///c:/Users/javie/.gemini/antigravity/brain/2fdef565-bb7f-478f-a63e-b16062c6446b/implementation_plan_pets_boosts.md)) items que permiten a los jugadores por tiempo limitado obtener beneficios.
- [x] **Trading:** Intercambio de Brainrots entre jugadores
- [x] **Reajuste de calidad de Brainrots** Hay brainrots que puntuan como Transcendents, Cosmic o Eternal que deberían ser categorías muy superiores por lo espectaculares que son. 

## 🔧 Técnico/Refactor (Skill: roblox-scripting-expert)
- [x] **Strict Typing:** Added `--!strict` to all core modules.
- [x] **Event Cleanup:** Implemented `Maid` system in server and client.
- [x] **Input Validation:** Completed security sweep on all Remote handlers.
- [ ] **Modularización:** Separar scripts grandes en módulos más pequeños
- [ ] **Limpiar Logs de Debug:** Quitar prints innecesarios una vez estable
- [ ] **Optimización:** Reducir lag con muchos Brainrots activos
- [ ] **Tests Unitarios:** Añadir tests para EconomyLogic, FusionManager

## 📊 Métricas (Opcional)
- [ ] **Analytics:** Tracking de qué huevos/tiers son más populares
- [ ] **A/B Testing:** Probar diferentes balances de economía

---
*Última actualización: 2026-02-09*
