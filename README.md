Spellhance Priority HUD v1.2.0
================================
World of Warcraft WotLK 3.3.5a / Warmane
Compatible con cliente en español: usa IDs internos y nombres localizados por GetSpellInfo().

INSTALACION / ACTUALIZACION
1. Cierra WoW o vuelve a selección de personajes.
2. Borra o reemplaza la carpeta anterior SpellhancePriority.
3. Copia la carpeta SpellhancePriority a:
   World of Warcraft/Interface/AddOns/
4. Debe quedar:
   Interface/AddOns/SpellhancePriority/SpellhancePriority.toc
5. Entra al juego y usa /reload.
6. Si no aparece, activa "Load out of date AddOns" en la pantalla de AddOns.

QUE HACE v1.2
- HUD visual con 5 habilidades: AHORA + 4 acciones proyectadas.
- El primer icono usa el estado REAL del cliente.
- Recalculo muy rápido (aprox. cada 0.04 s) y además por eventos de aura/CD/tótem/cast.
- Predicción de los próximos GCD con ETA (+1.2, +2.4, etc.).
- Stormstrike: vigila tu debuff y lo prioriza si falta.
- Maelstrom Weapon: lee cargas y pone LB a x5; en AoE pone Chain Lightning.
- Shocks con memoria del último shock usado para mantener FS -> ES -> FS de forma coherente.
- Magma Totem robusto: slot de Fuego + icono + nombre localizado + duración.
- Fire Nova solo entra con un tótem de Fuego activo y puede desactivarse.
- Lightning Shield como filler si está bajo de cargas.
- Fire Elemental opcional; modo Smart FE busca una ventana de burst / inicio de boss.
- AUTO ST/AoE estimado por objetivos distintos dañados recientemente.
- Puedes forzar ST o AoE si prefieres control manual.
- Banner separado de Corte de viento cuando el target castea algo interrumpible.
- Aviso grande + sonido al llegar a MW x5.
- Segundo aviso si mantienes MW x5 demasiado tiempo sin gastarlo.
- Barra de MW y barra del tótem de Fuego.
- Indicadores de SS, FS, último shock, tótem y buffs de burst.
- Aviso si falta un imbue temporal en MH/OH.
- Animación/glow/rebote al cambiar la recomendación.
- Modo entrenamiento: al terminar combate resume seguimiento de prioridad, MWx5,
  tiempo capado en MW, tiempo sin Magma, tiempo sin FS y cortes realizados.
- Perfiles por boss/objetivo para recordar ST/AoE, FE, Corte y Fire Nova.
- /spr debug muestra exactamente qué está leyendo el addon para diagnosticar Warmane.

PRIORIDAD SPELLHANCE BASE
1. Stormstrike si falta tu debuff.
2. Lightning Bolt con Maelstrom x5; Chain Lightning en AoE.
3. Flame Shock / Earth Shock alternados.
4. Magma Totem si falta o queda aproximadamente <=2 s; no pisa Fire Elemental.
5. Fire Nova.
6. Stormstrike.
7. Lava Lash.
8. Lightning Shield si falta o tiene menos de 3 cargas.

IMPORTANTE SOBRE LOS 5 ICONOS
El icono 1 (AHORA) se basa en auras, cooldowns, rango y tótem reales.
Los iconos 2-5 son una PREDICCION. El addon no puede saber de antemano cuándo
vas a generar una nueva carga de Maelstrom. Si aparece un proc o cambia cualquier
estado, la cola completa se reconstruye inmediatamente.

AUTO ST / AOE
/spr auto              Modo automático (predeterminado en instalación limpia).
/spr st                Fuerza single target.
/spr aoe               Fuerza AoE.
/spr autotargets 2     AUTO entra en AoE desde 2 objetivos recientes (2-5).
/spr autowindow 2.5    Ventana de detección de objetivos en segundos (1-6).

El conteo AUTO es una estimación de 3.3.5: usa GUIDs de enemigos a los que TU
personaje haya hecho daño recientemente. No existe una API perfecta de "enemigos
en rango" para addons de esta versión. Si un encuentro da falsos positivos, fuerza ST.

FIRE ELEMENTAL
/spr fe on|off         Mete/saca Fire Elemental de la prioridad.
/spr smartfe on|off    Con Smart FE intenta usarlo con burst o al inicio de un boss.

Por seguridad FE viene OFF: es un cooldown largo y no conviene que un recomendador
lo gaste automáticamente en cualquier pull. El addon nunca pulsa habilidades por ti.

ALERTAS / HUD
/spr sound on|off      Sonido de MW x5.
/spr alert on|off      Aviso grande de MW x5.
/spr waste on|off      Segundo aviso si retienes MW x5.
/spr threshold 1.2     Segundos en x5 antes del aviso de desperdicio (0.4-5).
/spr corte on|off      Banner de Corte de viento.
/spr burst on|off      Indicadores de burst / Lobos listos.
/spr nova on|off       Permitir o suprimir Fire Nova.
/spr anim on|off       Animaciones y glow.
/spr status on|off     Línea de estado inferior.
/spr size 48-120       Tamaño del icono principal.
/spr unlock            Permite arrastrar el HUD.
/spr lock              Bloquea el HUD.

ENTRENAMIENTO
/spr trainer on|off
Al salir de combate muestra un resumen. "Prioridad seguida" compara tus casts de
rotación con la recomendación que estaba en AHORA en ese momento. Es una ayuda de
entrenamiento, no un log/sim perfecto: mecánicas, movimiento y decisiones manuales
pueden hacer correcto desviarse de la sugerencia.

PERFILES POR BOSS / OBJETIVO
Selecciona el objetivo y configura el addon como quieras, después:
/spr profile save      Guarda modo, FE, Corte y Fire Nova para ese nombre.
/spr profile delete    Borra el perfil del objetivo seleccionado.
/spr profile list      Lista perfiles guardados.
/spr profile on|off    Activa/desactiva la carga automática de perfiles.

DIAGNOSTICO
/spr debug
Imprime modo, enemigos recientes, MW, SS, FS y datos exactos del slot de Fuego.
Si Magma volviera a detectarse mal en tu servidor, copia esa línea y pásamela.

OTROS
/spr reset             Restaura configuración.
/spr                   Muestra el resumen de comandos.

NOTAS TECNICAS
- No automatiza casts ni genera inputs; solo recomienda.
- Mantiene compatibilidad con SavedVariables de v1.1.x.
- Lightning Bolt usa el hechizo normal de rango 14 (ID 49238). Maelstrom hace que
  ese cast sea instantáneo; no se usa el ID interno de Lightning Overload.
- La predicción usa CDs conocidos y el GCD observado; procs futuros siempre son inciertos.
