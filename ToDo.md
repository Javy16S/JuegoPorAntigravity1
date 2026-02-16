# 📋 Brainrot Tsunami - ToDo & Roadmap

## 🔥 Prioridad Alta (Bugs/Fixes)
- [x] **UI de Unidades:** Verificar que aparece correctamente sobre Brainrots colocados *Por revisar
- [x] **Upgrade Button:** Arreglar que el botón UPGRADE funcione y suba el nivel del Brainrot *Por revisar
- [x] **Economía:** Confirmar que los ingresos se acumulan y muestran correctamente *Por revisar
- [x] **Valores Oscilantes:** Cada Brainrot tiene multiplicador único (x1-x10) al INGRESO/S *Por revisar
- [x] **Tienda de Venta:** Arreglados handlers para buscar por UnitId en lugar de nombre *Por revisar

## 🎮 Core Features Pendientes
- [ ] **Sistema de Achievements:** Logros por coleccionar Brainrots, alcanzar dinero, etc.
- [ ] **Leaderboards:** Ranking de jugadores por dinero total / Brainrots raros
- [ ] **Save/Load:** Verificar persistencia de datos (slots, inventario, mejoras)

## 🌊 Tsunami & Map
- [ ] **Nuevos Tipos de Lava:** Más variaciones visuales y efectos
- [ ] **Zonas Seguras:** Añadir plataformas/refugios temporales
- [ ] **Eventos Especiales:** Meteoritos, erupciones extra, etc.

## 🎨 Polish Visual
- [ ] **Animaciones de Mejora:** Efecto visual al subir de nivel un Brainrot
- [ ] **Partículas Shinies:** Mejorar el efecto de las unidades Shiny
- [ ] **Sonidos:** SFX para clicks, upgrades, oleadas de tsunami

## 💰 Economía Avanzada
- [ ] **Rebirth System:** Reiniciar progreso por multiplicadores permanentes
- [ ] **Pets/Boosts:** Items temporales que multiplican ingresos
- [ ] **Trading:** Intercambio de Brainrots entre jugadores

## 🔧 Técnico/Refactor (Skill: roblox-scripting-expert)
- [ ] **Strict Typing:** Añadir `--!strict` a módulos críticos (EconomyLogic, UnitManager)
- [ ] **Event Cleanup:** Implementar Maid/Janitor para desconectar eventos y prevenir memory leaks
- [ ] **Input Validation:** Revisar que todos los RemoteEvents validen input del cliente
- [ ] **Modularización:** Separar scripts grandes en módulos más pequeños
- [ ] **Limpiar Logs de Debug:** Quitar prints innecesarios una vez estable
- [ ] **Optimización:** Reducir lag con muchos Brainrots activos
- [ ] **Tests Unitarios:** Añadir tests para EconomyLogic, FusionManager

## 📊 Métricas (Opcional)
- [ ] **Analytics:** Tracking de qué huevos/tiers son más populares
- [ ] **A/B Testing:** Probar diferentes balances de economía

---
*Última actualización: 2026-02-03*
