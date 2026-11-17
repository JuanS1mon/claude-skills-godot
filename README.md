# claude-skills-godot

Plugin de Claude Code con skills para hacer juegos en Godot 4.

- `godot-2d-en-3d`: estética 2D dentro de un mundo 3D (2.5D / HD-2D), personaje de plataformas, toon shader, pruebas con input simulado.
- `godot-juego-movil`: juegos 2D móviles en GDScript (escenas, UI táctil, economía, exportar a Android).

## Instalar como plugin (recomendado)

En Claude Code:

```
/plugin marketplace add JuanS1mon/claude-skills-godot
/plugin install godot-skills@claude-skills-godot
```

Los skills quedan como `/godot-skills:godot-2d-en-3d` y `/godot-skills:godot-juego-movil`, y Claude los usa solo cuando el trabajo encaja.

## Instalar a mano

Copiar las carpetas de `skills/` dentro de `~/.claude/skills/` (en Windows: `C:\Users\<usuario>\.claude\skills\`).
