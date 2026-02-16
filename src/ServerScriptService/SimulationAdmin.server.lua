-- SimulationAdmin.server.lua
-- Script para simular inversión de Robux y probar el sistema de recompensas diarias
-- Uso: Escribe en la consola del servidor: _G.SimularInversion(jugador, cantidad)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BrainrotData = require(ServerScriptService:WaitForChild("BrainrotData"))
local DailyRewardManager = require(ServerScriptService:WaitForChild("DailyRewardManager"))

_G.SimularInversion = function(player, amount)
    if not player or not amount then 
        warn("Uso: _G.SimularInversion(game.Players.TuNombre, 5000)")
        return 
    end
    
    print("-----------------------------------------")
    print("🚀 SIMULACIÓN DE INVERSIÓN INICIADA")
    print("Jugador:", player.Name)
    print("Cantidad a simular:", amount, "R$")
    
    -- 1. Inyectamos la inversión en el sistema de datos
    BrainrotData.trackRobuxSpent(player, amount)
    
    -- 2. Verificamos el nuevo nivel de donador
    local info = DailyRewardManager.getDonorInfo(player)
    print("✅ Nuevo Nivel Alcanzado:", info.Name)
    print("✅ Item de Recompensa:", info.RewardId)
    
    -- 3. Forzar actualización visual en el stall del cliente
    -- (El cliente se actualiza automáticamente cada 30s por el bucle que hicimos,
    -- pero para feedback instantáneo, el jugador puede re-entrar al stall)
    
    print("✅ Datos sincronizados y guardados en DataStore.")
    print("💡 CONSEJO: Abre la UI de Recompensas Diarias para ver la nueva barra de progreso.")
    print("-----------------------------------------")
end

-- Comando para resetear (solo para pruebas)
_G.ResetearInversion = function(player)
    local data = BrainrotData.getPlayerSession(player)
    if data then
        data.TotalRobuxSpent = 0
        print("♻️ Inversión reseteada a 0 para", player.Name)
    end
end

print("🛠️ Módulo de Simulación Admin cargado. Usa _G.SimularInversion en la consola.")
